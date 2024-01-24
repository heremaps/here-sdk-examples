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

package com.here.navigation;

import android.content.Context;
import android.util.Log;
import android.widget.TextView;

import androidx.appcompat.app.AlertDialog;

import com.here.sdk.core.Color;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.GeoPolyline;
import com.here.sdk.core.Location;
import com.here.sdk.gestures.GestureState;
import com.here.sdk.mapview.LineCap;
import com.here.sdk.mapview.MapImage;
import com.here.sdk.mapview.MapImageFactory;
import com.here.sdk.mapview.MapMarker;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapMeasureDependentRenderSize;
import com.here.sdk.mapview.MapPolyline;
import com.here.sdk.mapview.MapView;
import com.here.sdk.mapview.RenderSize;
import com.here.sdk.routing.Route;
import com.here.sdk.routing.Waypoint;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

// An app that allows to calculate a route and start navigation, using either platform positioning or
// simulated locations.
public class App {

    public static final GeoCoordinates DEFAULT_MAP_CENTER = new GeoCoordinates(52.520798, 13.409408);
    public static final int DEFAULT_DISTANCE_IN_METERS = 1000 * 2;

    private final Context context;
    private final MapView mapView;
    private final List<MapMarker> mapMarkerList = new ArrayList<>();
    private final List<MapPolyline> mapPolylines = new ArrayList<>();
    private Waypoint startWaypoint;
    private Waypoint destinationWaypoint;
    private boolean setLongpressDestination;
    private final RouteCalculator routeCalculator;
    private final NavigationExample navigationExample;
    private final TextView messageView;

    public App(Context context, MapView mapView, TextView messageView) {
        this.context = context;
        this.mapView = mapView;
        this.messageView = messageView;
        MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE, DEFAULT_DISTANCE_IN_METERS);
        this.mapView.getCamera().lookAt(DEFAULT_MAP_CENTER, mapMeasureZoom);

        routeCalculator = new RouteCalculator();

        navigationExample = new NavigationExample(context, mapView, messageView);
        navigationExample.startLocationProvider();

        setLongPressGestureHandler();

        messageView.setText("Long press to set start/destination or use random ones.");
    }

    // Calculate a route and start navigation using a location simulator.
    // Start is map center and destination location is set random within viewport,
    // unless a destination is set via long press.
    public void addRouteSimulatedLocation() {
        calculateRoute(true);
    }

    // Calculate a route and start navigation using locations from device.
    // Start is current location and destination is set random within viewport,
    // unless a destination is set via long press.
    public void addRouteDeviceLocation() {
        calculateRoute(false);
    }

    public void clearMapButtonPressed() {
        clearMap();
    }

    public void toggleTrackingButtonOnClicked() {
        // By default, this is enabled.
        navigationExample.startCameraTracking();
    }

    public void toggleTrackingButtonOffClicked() {
        navigationExample.stopCameraTracking();
    }

    private void calculateRoute(boolean isSimulated) {
        clearMap();

        if (!determineRouteWaypoints(isSimulated)) {
            return;
        }

        // Calculates a car route.
        routeCalculator.calculateRoute(startWaypoint, destinationWaypoint, (routingError, routes) -> {
            if (routingError == null) {
                Route route = routes.get(0);
                showRouteOnMap(route);
                showRouteDetails(route, isSimulated);
            } else {
                showDialog("Error while calculating a route:", routingError.toString());
            }
        });
    }

    private boolean determineRouteWaypoints(boolean isSimulated) {
        if (!isSimulated && navigationExample.getLastKnownLocation() == null) {
            showDialog("Error", "No GPS location found.");
            return false;
        }

        // When using real GPS locations, we always start from the current location of user.
        if (!isSimulated) {
            Location location = navigationExample.getLastKnownLocation();
            startWaypoint = new Waypoint(location.coordinates);
            // If a driver is moving, the bearing value can help to improve the route calculation.
            startWaypoint.headingInDegrees = location.bearingInDegrees;
            mapView.getCamera().lookAt(location.coordinates);
        }

        if (startWaypoint == null) {
            startWaypoint = new Waypoint(createRandomGeoCoordinatesAroundMapCenter());
        }

        if (destinationWaypoint == null) {
            destinationWaypoint = new Waypoint(createRandomGeoCoordinatesAroundMapCenter());
        }

        return true;
    }

    private void showRouteDetails(Route route, boolean isSimulated) {
        long estimatedTravelTimeInSeconds = route.getDuration().getSeconds();
        int lengthInMeters = route.getLengthInMeters();

        String routeDetails =
                "Travel Time: " + formatTime(estimatedTravelTimeInSeconds)
                        + ", Length: " + formatLength(lengthInMeters);

        showStartNavigationDialog("Route Details", routeDetails, route, isSimulated);
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
        // Show route as polyline.
        GeoPolyline routeGeoPolyline = route.getGeometry();
        float widthInPixels = 20;
        Color polylineColor = Color.valueOf(0, 0.56f, 0.54f, 0.63f);
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
    }

    public void clearMap() {
        clearWaypointMapMarker();
        clearRoute();

        navigationExample.stopNavigation();
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

    private void setLongPressGestureHandler() {
        mapView.getGestures().setLongPressListener((gestureState, touchPoint) -> {
            GeoCoordinates geoCoordinates = mapView.viewToGeoCoordinates(touchPoint);
            if (geoCoordinates == null) {
                return;
            }
            if (gestureState == GestureState.BEGIN) {
                if (setLongpressDestination) {
                    destinationWaypoint = new Waypoint(geoCoordinates);
                    addCircleMapMarker(geoCoordinates, R.drawable.green_dot);
                    messageView.setText("New long press destination set.");
                } else {
                    startWaypoint = new Waypoint(geoCoordinates);
                    addCircleMapMarker(geoCoordinates, R.drawable.green_dot);
                    messageView.setText("New long press starting point set.");
                }
                setLongpressDestination = !setLongpressDestination;
            }
        });
    }

    private GeoCoordinates createRandomGeoCoordinatesAroundMapCenter() {
        GeoCoordinates centerGeoCoordinates = getMapViewCenter();
        double lat = centerGeoCoordinates.latitude;
        double lon = centerGeoCoordinates.longitude;
        return new GeoCoordinates(getRandom(lat - 0.02, lat + 0.02),
                getRandom(lon - 0.02, lon + 0.02));
    }

    private double getRandom(double min, double max) {
        return min + Math.random() * (max - min);
    }

    private GeoCoordinates getMapViewCenter() {
        return mapView.getCamera().getState().targetCoordinates;
    }

    private void addCircleMapMarker(GeoCoordinates geoCoordinates, int resourceId) {
        MapImage mapImage = MapImageFactory.fromResource(context.getResources(), resourceId);
        MapMarker mapMarker = new MapMarker(geoCoordinates, mapImage);

        mapView.getMapScene().addMapMarker(mapMarker);
        mapMarkerList.add(mapMarker);
    }

    private void showDialog(String title, String message) {
        AlertDialog.Builder builder = new AlertDialog.Builder(context);
        builder.setTitle(title)
               .setMessage(message)
               .show();
    }

    private void showStartNavigationDialog(String title, String message, Route route, boolean isSimulated) {
        String buttonText = isSimulated ? "Start navigation (simulated)" : "Start navigation (device location)";
        AlertDialog.Builder builder = new AlertDialog.Builder(context);
        builder.setTitle(title)
               .setMessage(message)
               .setNeutralButton(buttonText,
                       (dialog, which) -> {
                           navigationExample.startNavigation(route, isSimulated);
                       })
               .show();
    }

    public void detach() {
        // Disables TBT guidance (if running) and enters tracking mode.
        navigationExample.stopNavigation();
        // Disables positioning.
        navigationExample.stopLocating();
        // Disables rendering.
        navigationExample.stopRendering();
    }
}
