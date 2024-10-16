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

package com.here.routing;

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
import com.here.sdk.mapview.MapCamera;
import com.here.sdk.mapview.MapImage;
import com.here.sdk.mapview.MapImageFactory;
import com.here.sdk.mapview.MapMarker;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapMeasureDependentRenderSize;
import com.here.sdk.mapview.MapPolyline;
import com.here.sdk.mapview.MapView;
import com.here.sdk.mapview.RenderSize;
import com.here.sdk.routing.CalculateRouteCallback;
import com.here.sdk.routing.CarOptions;
import com.here.sdk.routing.DynamicSpeedInfo;
import com.here.sdk.routing.Maneuver;
import com.here.sdk.routing.ManeuverAction;
import com.here.sdk.routing.PaymentMethod;
import com.here.sdk.routing.Route;
import com.here.sdk.routing.RouteRailwayCrossing;
import com.here.sdk.routing.RoutingEngine;
import com.here.sdk.routing.RoutingError;
import com.here.sdk.routing.Section;
import com.here.sdk.routing.SectionNotice;
import com.here.sdk.routing.Span;
import com.here.sdk.routing.Toll;
import com.here.sdk.routing.TollFare;
import com.here.sdk.routing.TrafficOptimizationMode;
import com.here.sdk.routing.Waypoint;

import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public class RoutingExample {

    private static final String TAG = RoutingExample.class.getName();

    private final Context context;
    private final MapView mapView;
    private final List<MapMarker> mapMarkerList = new ArrayList<>();
    private final List<MapPolyline> mapPolylines = new ArrayList<>();
    private final RoutingEngine routingEngine;
    private GeoCoordinates startGeoCoordinates;
    private GeoCoordinates destinationGeoCoordinates;
    private boolean trafficDisabled;
    private final TimeUtils timeUtils;
    List<Waypoint> waypoints = new ArrayList<>();

    public RoutingExample(Context context, MapView mapView) {
        this.context = context;
        this.mapView = mapView;
        MapCamera camera = mapView.getCamera();
        double distanceInMeters = 1000 * 10;
        MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE, distanceInMeters);
        camera.lookAt(new GeoCoordinates(52.520798, 13.409408), mapMeasureZoom);
        timeUtils = new TimeUtils();
        try {
            routingEngine = new RoutingEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of RoutingEngine failed: " + e.error.name());
        }
    }

    public void addRoute() {
        startGeoCoordinates = createRandomGeoCoordinatesAroundMapCenter();
        destinationGeoCoordinates = createRandomGeoCoordinatesAroundMapCenter();
        Waypoint startWaypoint = new Waypoint(startGeoCoordinates);
        Waypoint destinationWaypoint = new Waypoint(destinationGeoCoordinates);

        waypoints =
                new ArrayList<>(Arrays.asList(startWaypoint, destinationWaypoint));
        calculateRoute(waypoints);
    }

    private void calculateRoute(List<Waypoint> waypoints) {
        routingEngine.calculateRoute(
                waypoints,
                getCarOptions(),
                new CalculateRouteCallback() {
                    @Override
                    public void onRouteCalculated(@Nullable RoutingError routingError, @Nullable List<Route> routes) {
                        if (routingError == null) {
                            Route route = routes.get(0);
                            showRouteDetails(route);
                            showRouteOnMap(route);
                            logRouteRailwayCrossingDetails(route);
                            logRouteSectionDetails(route);
                            logRouteViolations(route);
                            logTollDetails(route);
                            showWaypointsOnMap(waypoints);
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

    public void toggleTrafficOptimization() {
        trafficDisabled = !trafficDisabled;
        if (!waypoints.isEmpty()) {
            calculateRoute(waypoints);
        }
        Toast.makeText(context, "Traffic optimization is " + (trafficDisabled ? "Disabled" : "Enabled"), Toast.LENGTH_LONG).show();
    }


    private String toString(GeoCoordinates geoCoordinates) {
        return geoCoordinates.latitude + ", " + geoCoordinates.longitude;
    }

    private void logRouteSectionDetails(Route route) {
        DateFormat dateFormat = new SimpleDateFormat("HH:mm");

        for (int i = 0; i < route.getSections().size(); i++) {
            Section section = route.getSections().get(i);

            Log.d(TAG, "Route Section : " + (i + 1));
            Log.d(TAG, "Route Section Departure Time : "
                    + dateFormat.format(section.getDepartureLocationTime().localTime));
            Log.d(TAG, "Route Section Arrival Time : "
                    + dateFormat.format(section.getArrivalLocationTime().localTime));
            Log.d(TAG, "Route Section length : " + section.getLengthInMeters() + " m");
            Log.d(TAG, "Route Section duration : " + section.getDuration().getSeconds() + " s");
        }
    }

    private void logRouteRailwayCrossingDetails(Route route) {
        for (RouteRailwayCrossing routeRailwayCrossing : route.getRailwayCrossings()) {
            // Coordinates of the route offset
            GeoCoordinates routeOffsetCoordinates = routeRailwayCrossing.coordinates;
            // Index of the corresponding route section. The start of the section indicates the start of the offset.
            int routeOffsetSectionIndex = routeRailwayCrossing.routeOffset.sectionIndex;
            // Offset from the start of the specified section to the specified location along the route.
            double routeOffsetInMeters = routeRailwayCrossing.routeOffset.offsetInMeters;

            Log.d(TAG, "A railway crossing of type " + routeRailwayCrossing.type.name() +
                    "is situated " +
                    routeOffsetInMeters + " m away from start of section: " +
                    routeOffsetSectionIndex);
        }
    }

    private void logTollDetails(Route route) {
        for (Section section : route.getSections()) {
            // The spans that make up the polyline along which tolls are required or
            // where toll booths are located.
            List<Span> spans = section.getSpans();
            List<Toll> tolls = section.getTolls();
            if (!tolls.isEmpty()) {
                Log.d(TAG, "Attention: This route may require tolls to be paid.");
            }
            for (Toll toll : tolls) {
                Log.d(TAG, "Toll information valid for this list of spans:");
                Log.d(TAG, "Toll system: " + toll.tollSystem);
                Log.d(TAG, "Toll country code (ISO-3166-1 alpha-3): " + toll.countryCode);
                Log.d(TAG, "Toll fare information: ");
                for (TollFare tollFare : toll.fares) {
                    // A list of possible toll fares which may depend on time of day, payment method and
                    // vehicle characteristics. For further details please consult the local
                    // authorities.
                    Log.d(TAG, "Toll price: " + tollFare.price + " " + tollFare.currency);
                    for (PaymentMethod paymentMethod : tollFare.paymentMethods) {
                        Log.d(TAG, "Accepted payment methods for this price: " + paymentMethod.name());
                    }
                }
            }
        }
    }

    private void showRouteDetails(Route route) {
        // estimatedTravelTimeInSeconds includes traffic delay.
        long estimatedTravelTimeInSeconds = route.getDuration().getSeconds();
        long estimatedTrafficDelayInSeconds = route.getTrafficDelay().getSeconds();
        int lengthInMeters = route.getLengthInMeters();

        // Timezones can vary depending on the device's geographic location.
        // For instance, when calculating a route, the device's current timezone may differ from that of the destination.
        // Consider a scenario where a user calculates a route from Berlin to London — each city operates in a different timezone.
        // To address this, you can display the Estimated Time of Arrival (ETA) in multiple timezones: the device's current timezone (Berlin), the destination's timezone (London), and UTC (Coordinated Universal Time), which serves as a global reference.
        String routeDetails =
                "Travel Duration: " + timeUtils.formatTime(estimatedTravelTimeInSeconds) +
                        "\nTraffic delay: " + timeUtils.formatTime(estimatedTrafficDelayInSeconds)
                        + "\nRoute length (m): " + timeUtils.formatLength(lengthInMeters) +
                        "\nETA in device timezone: " + timeUtils.getETAinDeviceTimeZone(route) +
                        "\nETA in destination timezone: " + timeUtils.getETAinDestinationTimeZone(route) +
                        "\nETA in UTC: " + timeUtils.getEstimatedTimeOfArrivalInUTC(route);

        showDialog("Route Details", routeDetails);
    }

    private void showRouteOnMap(Route route) {
        // Optionally, clear any previous route.
        clearMap();

        // Show route as polyline.
        GeoPolyline routeGeoPolyline = route.getGeometry();
        float widthInPixels = 20;
        Color polylineColor = new Color(0, (float) 0.56, (float) 0.54, (float) 0.63);
        MapPolyline routeMapPolyline = null;

        try {
            routeMapPolyline = new MapPolyline(routeGeoPolyline, new MapPolyline.SolidRepresentation(
                    new MapMeasureDependentRenderSize(RenderSize.Unit.PIXELS, widthInPixels),
                    polylineColor,
                    LineCap.ROUND));
        } catch (MapPolyline.Representation.InstantiationException e) {
            Log.e("MapPolyline Representation Exception:", e.error.name());
        } catch (MapMeasureDependentRenderSize.InstantiationException e) {
            Log.e("MapMeasureDependentRenderSize Exception:", e.error.name());
        }

        mapView.getMapScene().addMapPolyline(routeMapPolyline);
        mapPolylines.add(routeMapPolyline);

        // Optionally, render traffic on route.
        showTrafficOnRoute(route);

        // Log maneuver instructions per route section.
        List<Section> sections = route.getSections();
        for (Section section : sections) {
            logManeuverInstructions(section);
        }
    }

    private void showWaypointsOnMap(List<Waypoint> waypoints) {
        int n = waypoints.size();
        for (int i = 0; i < n; i++) {
            GeoCoordinates currentGeoCoordinates = waypoints.get(i).coordinates;
            if (i == 0 || i == n - 1) {
                // Draw a green circle to indicate starting point and destination.
                addCircleMapMarker(currentGeoCoordinates, R.drawable.green_dot);
            } else {
                // Draw a red circle to indicate intermediate waypoints, if any.
                addCircleMapMarker(currentGeoCoordinates, R.drawable.red_dot);
            }
        }
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

    public void addWaypoints() {
        if (startGeoCoordinates == null || destinationGeoCoordinates == null) {
            showDialog("Error", "Please add a route first.");
            return;
        }

        Waypoint waypoint1 = new Waypoint(createRandomGeoCoordinatesAroundMapCenter());
        Waypoint waypoint2 = new Waypoint(createRandomGeoCoordinatesAroundMapCenter());
        waypoints = new ArrayList<>(Arrays.asList(new Waypoint(startGeoCoordinates),
                waypoint1, waypoint2, new Waypoint(destinationGeoCoordinates)));
        calculateRoute(waypoints);
    }

    private CarOptions getCarOptions() {
        CarOptions carOptions = new CarOptions();
        carOptions.routeOptions.enableTolls = true;
        // Disabled - Traffic optimization is completely disabled, including long-term road closures. It helps in producing stable routes.
        // Time dependent - Traffic optimization is enabled, the shape of the route will be adjusted according to the traffic situation which depends on departure time and arrival time.
        carOptions.routeOptions.trafficOptimizationMode = trafficDisabled ?
                TrafficOptimizationMode.DISABLED :
                TrafficOptimizationMode.TIME_DEPENDENT;
        return carOptions;
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

    // This renders the traffic jam factor on top of the route as multiple MapPolylines per span.
    private void showTrafficOnRoute(Route route) {
        if (route.getLengthInMeters() / 1000 > 5000) {
            Log.d(TAG, "Skip showing traffic-on-route for longer routes.");
            return;
        }

        for (Section section : route.getSections()) {
            for (Span span : section.getSpans()) {
                DynamicSpeedInfo dynamicSpeed = span.getDynamicSpeedInfo();
                Color lineColor = getTrafficColor(dynamicSpeed.calculateJamFactor());
                if (lineColor == null) {
                    // We skip rendering low traffic.
                    continue;
                }
                float widthInPixels = 10;
                MapPolyline trafficSpanMapPolyline = null;
                try {
                    trafficSpanMapPolyline = new MapPolyline(span.getGeometry(), new MapPolyline.SolidRepresentation(
                            new MapMeasureDependentRenderSize(RenderSize.Unit.PIXELS, widthInPixels),
                            lineColor,
                            LineCap.ROUND));
                } catch (MapPolyline.Representation.InstantiationException e) {
                    Log.e("MapPolyline Representation Exception:", e.error.name());
                } catch (MapMeasureDependentRenderSize.InstantiationException e) {
                    Log.e("MapMeasureDependentRenderSize Exception:", e.error.name());
                }

                mapView.getMapScene().addMapPolyline(trafficSpanMapPolyline);
                mapPolylines.add(trafficSpanMapPolyline);
            }
        }
    }

    // Define a traffic color scheme based on the route's jam factor.
    // 0 <= jamFactor < 4: No or light traffic.
    // 4 <= jamFactor < 8: Moderate or slow traffic.
    // 8 <= jamFactor < 10: Severe traffic.
    // jamFactor = 10: No traffic, ie. the road is blocked.
    // Returns null in case of no or light traffic.
    @Nullable
    private Color getTrafficColor(Double jamFactor) {
        if (jamFactor == null || jamFactor < 4) {
            return null;
        } else if (jamFactor >= 4 && jamFactor < 8) {
            return Color.valueOf(1, 1, 0, 0.63f); // Yellow
        } else if (jamFactor >= 8 && jamFactor < 10) {
            return Color.valueOf(1, 0, 0, 0.63f); // Red
        }
        return Color.valueOf(0, 0, 0, 0.63f); // Black
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

    private void showDialog(String title, String message) {
        AlertDialog.Builder builder =
                new AlertDialog.Builder(context);
        builder.setTitle(title);
        builder.setMessage(message);
        builder.show();
    }
}
