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
import com.here.sdk.routing.Maneuver;
import com.here.sdk.routing.ManeuverAction;
import com.here.sdk.routing.PaymentMethod;
import com.here.sdk.routing.Route;
import com.here.sdk.routing.RoutingEngine;
import com.here.sdk.routing.RoutingError;
import com.here.sdk.routing.Section;
import com.here.sdk.routing.SectionNotice;
import com.here.sdk.routing.Span;
import com.here.sdk.routing.Toll;
import com.here.sdk.routing.TollFare;
import com.here.sdk.routing.TrafficSpeed;
import com.here.sdk.routing.Waypoint;

import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;

public class RoutingExample {

    private static final String TAG = RoutingExample.class.getName();

    private final Context context;
    private final MapView mapView;
    private final List<MapMarker> mapMarkerList = new ArrayList<>();
    private final List<MapPolyline> mapPolylines = new ArrayList<>();
    private final RoutingEngine routingEngine;
    private GeoCoordinates startGeoCoordinates;
    private GeoCoordinates destinationGeoCoordinates;

    public RoutingExample(Context context, MapView mapView) {
        this.context = context;
        this.mapView = mapView;
        MapCamera camera = mapView.getCamera();
        double distanceInMeters = 1000 * 10;
        MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE, distanceInMeters);
        camera.lookAt(new GeoCoordinates(52.520798, 13.409408), mapMeasureZoom);

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

        List<Waypoint> waypoints =
                new ArrayList<>(Arrays.asList(startWaypoint, destinationWaypoint));

        CarOptions carOptions = new CarOptions();
        carOptions.routeOptions.enableTolls = true;

        routingEngine.calculateRoute(
                waypoints,
                carOptions,
                new CalculateRouteCallback() {
                    @Override
                    public void onRouteCalculated(@Nullable RoutingError routingError, @Nullable List<Route> routes) {
                        if (routingError == null) {
                            Route route = routes.get(0);
                            showRouteDetails(route);
                            showRouteOnMap(route);
                            logRouteSectionDetails(route);
                            logRouteViolations(route);
                            logTollDetails(route);
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
            for (SectionNotice notice : section.getSectionNotices()) {
                Log.e(TAG, "This route contains the following warning: " + notice.code.toString());
            }
        }
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

        String routeDetails = "Travel Time: " + formatTime(estimatedTravelTimeInSeconds)
                + ", traffic delay: " + formatTime(estimatedTrafficDelayInSeconds)
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
                            logRouteSectionDetails(route);
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

    // This renders the traffic jam factor on top of the route as multiple MapPolylines per span.
    private void showTrafficOnRoute(Route route) {
        if (route.getLengthInMeters() / 1000 > 5000) {
            Log.d(TAG, "Skip showing traffic-on-route for longer routes.");
            return;
        }

        for (Section section : route.getSections()) {
            for (Span span : section.getSpans()) {
                TrafficSpeed trafficSpeed = span.getTrafficSpeed();
                Color lineColor = getTrafficColor(trafficSpeed.jamFactor);
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
                }  catch (MapPolyline.Representation.InstantiationException e) {
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
