/*
 * Copyright (C) 2019-2024 HERE Europe B.V.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 * License-Filename: LICENSE
 */

package com.here.routinghybrid;

import android.content.Context;
import android.util.Log;
import android.widget.Toast;

import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;

import com.here.sdk.core.Color;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.GeoPolyline;
import com.here.sdk.core.Point2D;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.mapview.LineCap;
import com.here.sdk.mapview.MapArrow;
import com.here.sdk.mapview.MapCamera;
import com.here.sdk.mapview.MapImage;
import com.here.sdk.mapview.MapImageFactory;
import com.here.sdk.mapview.MapMarker;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapMeasureDependentRenderSize;
import com.here.sdk.mapview.MapPolyline;
import com.here.sdk.mapview.MapView;
import com.here.sdk.mapview.RenderSize;
import com.here.sdk.navigation.VisualNavigator;
import com.here.sdk.routing.CalculateRouteCallback;
import com.here.sdk.routing.CarOptions;
import com.here.sdk.routing.Maneuver;
import com.here.sdk.routing.ManeuverAction;
import com.here.sdk.routing.OfflineRoutingEngine;
import com.here.sdk.routing.Route;
import com.here.sdk.routing.RoutingEngine;
import com.here.sdk.routing.RoutingError;
import com.here.sdk.routing.RoutingInterface;
import com.here.sdk.routing.Section;
import com.here.sdk.routing.SectionNotice;
import com.here.sdk.routing.Span;
import com.here.sdk.routing.Waypoint;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

public class RoutingExample {

    private static final String TAG = RoutingExample.class.getName();

    private final Context context;
    private final MapView mapView;
    private final List<MapMarker> mapMarkerList = new ArrayList<>();
    private final List<MapPolyline> mapPolylines = new ArrayList<>();
    private RoutingInterface routingEngine;
    private final RoutingEngine onlineRoutingEngine;
    private final OfflineRoutingEngine offlineRoutingEngine;
    private GeoCoordinates startGeoCoordinates;
    private GeoCoordinates destinationGeoCoordinates;
    private boolean isDeviceConnected = true;


    public RoutingExample(Context context, MapView mapView) {
        this.context = context;
        this.mapView = mapView;
        MapCamera camera = mapView.getCamera();
        double distanceInMeters = 5000;
        MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE, distanceInMeters);
        camera.lookAt(new GeoCoordinates(52.520798, 13.409408), mapMeasureZoom);
        try {
            onlineRoutingEngine = new RoutingEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of RoutingEngine failed: " + e.error.name());
        }

        try {
            // Allows to calculate routes on already downloaded or cached map data.
            // For downloading offline maps, please check the OfflineMaps example app.
            // This app uses only cached map data that gets downloaded when the user
            // pans the map. Please note that the OfflineRoutingEngine may not be able
            // to calculate a route, when not all map tiles are loaded. Especially, the
            // vector tiles for lower zoom levels are required to find possible paths.
            offlineRoutingEngine = new OfflineRoutingEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of OfflineRoutingEngine failed: " + e.error.name());
        }
    }

    // Calculates a route with two waypoints (start / destination).
    public void addRoute() {
        setRoutingEngine();

        startGeoCoordinates = createRandomGeoCoordinatesAroundMapCenter();
        destinationGeoCoordinates = createRandomGeoCoordinatesAroundMapCenter();
        Waypoint startWaypoint = new Waypoint(startGeoCoordinates);
        Waypoint destinationWaypoint = new Waypoint(destinationGeoCoordinates);

        List<Waypoint> waypoints =
                new ArrayList<>(Arrays.asList(startWaypoint, destinationWaypoint));

        routingEngine.calculateRoute(
                waypoints,
                new CarOptions(),
                new CalculateRouteCallback() {
                    @Override
                    public void onRouteCalculated(@Nullable RoutingError routingError, @Nullable List<Route> routes) {
                        if (routingError == null) {
                            Route route = routes.get(0);
                            showRouteDetails(route);
                            showRouteOnMap(route);
                            logRouteViolations(route);
                        } else {
                            showDialog("Error while calculating a route:", routingError.toString());
                        }
                    }
                });
    }

    // A route may contain several warnings, for example, when a certain route option could not be fulfilled.
    // An implementation may decide to reject a route if one or more violations are detected.
    private void logRouteViolations(Route route) {
        for (Section section : route.getSections()) {
            for (Span span : section.getSpans()) {
                List<GeoCoordinates> spanGeometryVertices = span.getGeometry().vertices;
                // This route violation spreads across the whole span geometry.
                GeoCoordinates violationStartPoint = spanGeometryVertices.get(0);
                GeoCoordinates violationEndPoint = spanGeometryVertices.get(spanGeometryVertices.size() - 1);
                for (int index : span.getNoticeIndexes()) {
                    SectionNotice spanSectionNotice = section.getSectionNotices().get(index);
                    // The violation code such as "VIOLATED_VEHICLE_RESTRICTION".
                    String violationCode = spanSectionNotice.code.toString();
                    Log.d(TAG, "The violation " + violationCode + " starts at " + toString(violationStartPoint) + " and ends at " + toString(violationEndPoint) + " .");
                }
            }
        }
    }

    private String toString(GeoCoordinates geoCoordinates) {
        return geoCoordinates.latitude + ", " + geoCoordinates.longitude;
    }

    private void showRouteDetails(Route route) {
        long estimatedTravelTimeInSeconds = route.getDuration().getSeconds();
        int lengthInMeters = route.getLengthInMeters();

        String routeDetails =
                "Travel Time: " + formatTime(estimatedTravelTimeInSeconds)
                        + ", Length: " + formatLength(lengthInMeters);

        showDialog("Route Details", routeDetails);
    }

    private String formatTime(long sec) {
        int hours = (int) (sec / 3600);
        int minutes = (int) ((sec % 3600) / 60);

        return String.format(Locale.getDefault(), "%02d:%02d", hours, minutes);
    }

    private String formatLength(int meters) {
        int kilometers = meters / 1000;
        int remainingMeters = meters % 1000;

        return String.format(Locale.getDefault(), "%02d.%02d km", kilometers, remainingMeters);
    }

    private void showRouteOnMap(Route route) {
        clearMap();

        // Show route as polyline.
        GeoPolyline routeGeoPolyline = route.getGeometry();
        Color polylineColor = Color.valueOf(0.051f, 0.380f, 0.871f, 1.0f);
        Color outlineColor = Color.valueOf(0.043f, 0.325f, 0.749f, 1.0f);
        MapPolyline routeMapPolyline = null;
        try {
            // Below, we're creating an instance of MapMeasureDependentRenderSize. This instance will use the scaled width values to render the route polyline.
            // We can also apply the same values to MapArrow.setMeasureDependentTailWidth().
            // The parameters for the constructor are: the kind of MapMeasure (in this case, ZOOM_LEVEL), the unit of measurement for the render size (PIXELS), and the scaled width values.
            MapMeasureDependentRenderSize mapMeasureDependentLineWidth = new MapMeasureDependentRenderSize(MapMeasure.Kind.ZOOM_LEVEL, RenderSize.Unit.PIXELS, getDefaultLineWidthValues());

            // We can also use MapMeasureDependentRenderSize to specify the outline width of the polyline.
            double outlineWidthInPixel = 1.23 * mapView.getPixelScale();
            MapMeasureDependentRenderSize mapMeasureDependentOutlineWidth = new MapMeasureDependentRenderSize(RenderSize.Unit.PIXELS, outlineWidthInPixel);
            routeMapPolyline = new MapPolyline(routeGeoPolyline, new MapPolyline.SolidRepresentation(
                    mapMeasureDependentLineWidth,
                    polylineColor,
                    mapMeasureDependentOutlineWidth,
                    outlineColor,
                    LineCap.ROUND));

        } catch (MapPolyline.Representation.InstantiationException e) {
            Log.e("MapPolyline Representation Exception:", e.error.name());
        } catch (MapMeasureDependentRenderSize.InstantiationException e) {
            Log.e("MapMeasureDependentRenderSize Exception:", e.error.name());
        }
        mapView.getMapScene().addMapPolyline(routeMapPolyline);
        mapPolylines.add(routeMapPolyline);

        GeoCoordinates startPoint =
                route.getSections().get(0).getDeparturePlace().mapMatchedCoordinates;
        GeoCoordinates destination =
                route.getSections().get(route.getSections().size() - 1).getArrivalPlace().mapMatchedCoordinates;

        // Draw a circle to indicate starting point and destination.
        addCircleMapMarker(startPoint, R.drawable.green_dot);
        addCircleMapMarker(destination, R.drawable.green_dot);

        // Log maneuver instructions per route section.
        List<Section> sections = route.getSections();
        for (Section section : sections) {
            logManeuverInstructions(section);
        }
    }

    // Retrieves the default widths of a route polyline and maneuver arrows from VisualNavigator,
    // scaling them based on the screen's pixel density.
    // Note that the VisualNavigator stores the width values per zoom level MapMeasure.Kind.
    private HashMap<Double, Double> getDefaultLineWidthValues() {
        HashMap<Double, Double> widthsPerZoomLevel = new HashMap<>();
        for (Map.Entry<MapMeasure, Double> defaultValues : VisualNavigator.defaultRouteManeuverArrowMeasureDependentWidths().entrySet()) {
            Double key = defaultValues.getKey().value;
            Double value = defaultValues.getValue() * mapView.getPixelScale();
            widthsPerZoomLevel.put(key, value);
        }
        return widthsPerZoomLevel;
    }


    private void logManeuverInstructions(Section section) {
        Log.d(TAG, "Log maneuver instructions per route section:");
        List<Maneuver> maneuverInstructions = section.getManeuvers();
        for (Maneuver maneuverInstruction : maneuverInstructions) {
            ManeuverAction maneuverAction = maneuverInstruction.getAction();
            GeoCoordinates maneuverLocation = maneuverInstruction.getCoordinates();
            String maneuverInfo = maneuverInstruction.getText()
                    + ", Action: " + maneuverAction.name()
                    + ", Location: " + maneuverLocation.toString();
            Log.d(TAG, maneuverInfo);
        }
    }

    // Calculates a route with additional waypoints.
    public void addWaypoints() {
        setRoutingEngine();

        if (startGeoCoordinates == null || destinationGeoCoordinates == null) {
            showDialog("Error", "Please add a route first.");
            return;
        }

        Waypoint waypoint1 = new Waypoint(createRandomGeoCoordinatesAroundMapCenter());
        Waypoint waypoint2 = new Waypoint(createRandomGeoCoordinatesAroundMapCenter());
        List<Waypoint> waypoints = new ArrayList<>(Arrays.asList(new Waypoint(startGeoCoordinates),
                waypoint1, waypoint2, new Waypoint(destinationGeoCoordinates)));

        routingEngine.calculateRoute(
                waypoints,
                new CarOptions(),
                new CalculateRouteCallback() {
                    @Override
                    public void onRouteCalculated(@Nullable RoutingError routingError, @Nullable List<Route> routes) {
                        if (routingError == null) {
                            Route route = routes.get(0);
                            showRouteDetails(route);
                            showRouteOnMap(route);
                            logRouteViolations(route);

                            // Draw a circle to indicate the location of the waypoints.
                            addCircleMapMarker(waypoint1.coordinates, R.drawable.red_dot);
                            addCircleMapMarker(waypoint2.coordinates, R.drawable.red_dot);
                        } else {
                            showDialog("Error while calculating a route:", routingError.toString());
                        }
                    }
                });
    }

    public void clearMap() {
        clearWaypointMapMarker();
        clearRoute();
    }

    private void clearWaypointMapMarker() {
        for (MapMarker mapMarker : mapMarkerList) {
            mapView.getMapScene().removeMapMarker(mapMarker);
        }
        mapMarkerList.clear();
    }

    private void clearRoute() {
        for (MapPolyline mapPolyline : mapPolylines) {
            mapView.getMapScene().removeMapPolyline(mapPolyline);
        }
        mapPolylines.clear();
    }

    private GeoCoordinates createRandomGeoCoordinatesAroundMapCenter() {
        GeoCoordinates centerGeoCoordinates = mapView.viewToGeoCoordinates(
                new Point2D(mapView.getWidth() / 2, mapView.getHeight() / 2));
        if (centerGeoCoordinates == null) {
            // Should never happen for center coordinates.
            throw new RuntimeException("CenterGeoCoordinates are null");
        }
        double lat = centerGeoCoordinates.latitude;
        double lon = centerGeoCoordinates.longitude;
        return new GeoCoordinates(getRandom(lat - 0.02, lat + 0.02),
                getRandom(lon - 0.02, lon + 0.02));
    }

    private double getRandom(double min, double max) {
        return min + Math.random() * (max - min);
    }

    private void addCircleMapMarker(GeoCoordinates geoCoordinates, int resourceId) {
        MapImage mapImage = MapImageFactory.fromResource(context.getResources(), resourceId);
        MapMarker mapMarker = new MapMarker(geoCoordinates, mapImage);
        mapView.getMapScene().addMapMarker(mapMarker);
        mapMarkerList.add(mapMarker);
    }

    // Sets the OfflineRoutingEngine as main engine when the device is not connected, otherwise this will set the
    // RoutingEngine that requires connectivity.
    private void setRoutingEngine() {
        if (isDeviceConnected()) {
            routingEngine = onlineRoutingEngine;
        } else {
            routingEngine = offlineRoutingEngine;
        }
    }

    public void onSwitchOnlineButtonClicked() {
        isDeviceConnected = true;
        Toast.makeText(context, "The app will now use the RoutingEngine.", Toast.LENGTH_LONG).show();
    }

    public void onSwitchOfflineButtonClicked() {
        isDeviceConnected = false;
        Toast.makeText(context, "The app will now use the OfflineRoutingEngine.", Toast.LENGTH_LONG).show();
    }

    private boolean isDeviceConnected() {
        // An application may define here a logic to determine whether a device is connected or not.
        // For this example app, the flag is set from UI.
        return isDeviceConnected;
    }

    private void showDialog(String title, String message) {
        AlertDialog.Builder builder =
                new AlertDialog.Builder(context);
        builder.setTitle(title);
        builder.setMessage(message);
        builder.show();
    }
}
