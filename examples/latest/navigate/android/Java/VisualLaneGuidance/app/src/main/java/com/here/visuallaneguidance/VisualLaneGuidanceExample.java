/*
 * Copyright (C) 2025-2026 HERE Europe B.V.
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

package com.here.visuallaneguidance;

import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;

import com.here.sdk.animation.Easing;
import com.here.sdk.animation.EasingFunction;
import com.here.sdk.core.Color;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.GeoOrientationUpdate;
import com.here.sdk.core.GeoPolyline;
import com.here.sdk.core.Point2D;
import com.here.sdk.core.Rectangle2D;
import com.here.sdk.core.Size2D;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.mapview.LineCap;
import com.here.sdk.mapview.MapCameraAnimation;
import com.here.sdk.mapview.MapCameraAnimationFactory;
import com.here.sdk.mapview.MapCameraUpdate;
import com.here.sdk.mapview.MapCameraUpdateFactory;
import com.here.sdk.mapview.MapImage;
import com.here.sdk.mapview.MapImageFactory;
import com.here.sdk.mapview.MapMarker;
import com.here.sdk.mapview.MapMeasureDependentRenderSize;
import com.here.sdk.mapview.MapPolyline;
import com.here.sdk.mapview.MapView;
import com.here.sdk.mapview.RenderSize;
import com.here.sdk.navigation.LocationSimulator;
import com.here.sdk.navigation.LocationSimulatorOptions;
import com.here.sdk.navigation.VisualNavigator;
import com.here.sdk.routing.Route;
import com.here.sdk.routing.RoutingEngine;
import com.here.sdk.routing.RoutingOptions;
import com.here.sdk.routing.Waypoint;
import com.here.sdk.units.core.views.UnitDialog;
import com.here.time.Duration;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

// Handles route calculation, guidance, and camera behavior switching for visual lane guidance.
// Note: Visual lane guidance is a beta feature and requires a Visual Lane Guidance license.
// Talk to your HERE representative for more information.
public class VisualLaneGuidanceExample {

    public enum RouteSelection {
        NONE,
        CHICAGO,
        BERLIN
    }

    private static final String TAG = VisualLaneGuidanceExample.class.getSimpleName();
    private final Context context;
    private final MapView mapView;
    private final RoutingEngine routingEngine;
    private final VisualNavigator visualNavigator;
    private final CameraBehaviors cameraBehaviors;
    private LocationSimulator locationSimulator;
    private Route route = null;
    private RouteSelection selectedRoute = RouteSelection.NONE;
    private MapPolyline routeMapPolyline = null;
    private final List<MapMarker> mapMarkerList = new ArrayList<>();

    private static final List<GeoCoordinates> CHICAGO_ROUTE = Arrays.asList(
            new GeoCoordinates(41.8756, -87.6622),
            new GeoCoordinates(41.8924, -87.6485)
    );

    private static final List<GeoCoordinates> BERLIN_ROUTE = Arrays.asList(
            new GeoCoordinates(52.5012, 13.2753),
            new GeoCoordinates(52.3839, 13.1509)
    );

    public VisualLaneGuidanceExample(Context context, MapView mapView) {
        this.context = context;
        this.mapView = mapView;

        try {
            routingEngine = new RoutingEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of RoutingEngine failed: " + e.error.name());
        }

        try {
            visualNavigator = new VisualNavigator();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of VisualNavigator failed: " + e.error.name());
        }

        cameraBehaviors = new CameraBehaviors(context, visualNavigator);
    }

    public void useTransitionCameraBehavior() {
        cameraBehaviors.useTransitionCameraBehavior();
    }

    public void useAutomotiveCameraBehavior() {
        cameraBehaviors.useAutomotiveCameraBehavior();
    }

    public String getCameraBehaviorStatus() {
        return cameraBehaviors.getCameraBehaviorStatus();
    }

    public boolean isGuidanceRunning() {
        return locationSimulator != null;
    }

    public RouteSelection getSelectedRoute() {
        return selectedRoute;
    }

    public void calculateRoute(RouteSelection routeSelection, @NonNull List<GeoCoordinates> geoCoordinatesList) {
        if (isGuidanceRunning()) {
            UnitDialog unitDialog = new UnitDialog(context);
            unitDialog.showDialog("Guidance is active", "Stop guidance before calculating a new route.");
            return;
        }

        selectedRoute = routeSelection;

        clearMap();
        addStartAndDestinationMarkers(geoCoordinatesList);
        List<Waypoint> waypoints = new ArrayList<>();
        for (GeoCoordinates coord : geoCoordinatesList) {
            waypoints.add(new Waypoint(coord));
        }
        routingEngine.calculateRoute(
                waypoints,
                new RoutingOptions(),
                (routingError, routes) -> {
                    if (routingError == null && routes != null && !routes.isEmpty()) {
                        route = routes.get(0);
                        showRoute(route);
                        animateToRoute(route);

                    } else {
                        UnitDialog unitDialog = new UnitDialog(context);
                        unitDialog.showDialog("Route calculation error", String.valueOf(routingError));
                    }
                });
    }

    // Adds only start and destination markers for a route.
    private void addStartAndDestinationMarkers(@NonNull List<GeoCoordinates> geoCoordinatesList) {
        GeoCoordinates start = geoCoordinatesList.get(0);
        GeoCoordinates destination = geoCoordinatesList.get(geoCoordinatesList.size() - 1);

        addMapMarker(start, R.drawable.poi_start);
        addMapMarker(destination, R.drawable.poi_destination);
    }

    // Calculates the Chicago route.
    public void calculateChicagoRoute() {
        calculateRoute(RouteSelection.CHICAGO, CHICAGO_ROUTE);
    }

    // Calculates the Berlin route.
    public void calculateBerlinRoute() {
        calculateRoute(RouteSelection.BERLIN, BERLIN_ROUTE);
    }

    // Adds a map marker at the given coordinates with the specified resource.
    private void addMapMarker(GeoCoordinates geoCoordinates, int resourceId) {
        MapImage mapImage = MapImageFactory.fromResource(context.getResources(), resourceId);
        MapMarker mapMarker = new MapMarker(geoCoordinates, mapImage);
        mapView.getMapScene().addMapMarker(mapMarker);
        mapMarkerList.add(mapMarker);
    }

    // Displays the given route as a polyline on the map.
    private void showRoute(Route route) {
        GeoPolyline routeGeoPolyline = route.getGeometry();
        float widthInPixels = 20;
        Color polylineColor = Color.valueOf(0, 0.56f, 0.54f, 0.63f);

        try {
            routeMapPolyline = new MapPolyline(routeGeoPolyline, new MapPolyline.SolidRepresentation(
                    new MapMeasureDependentRenderSize(RenderSize.Unit.PIXELS, widthInPixels),
                    polylineColor,
                    LineCap.ROUND));
        } catch (MapPolyline.Representation.InstantiationException e) {
            Log.e(TAG, "MapPolyline representation error: " + e.error.name());
            return;
        } catch (MapMeasureDependentRenderSize.InstantiationException e) {
            Log.e(TAG, "MapMeasureDependentRenderSize error: " + e.error.name());
            return;
        }

        mapView.getMapScene().addMapPolyline(routeMapPolyline);
    }

    // Animates the camera to fit the given route and applies lighting at the given coordinate.
    private void animateToRoute(Route route) {
        double bearing = 0;
        double tilt = 0;
        // We want to show the route fitting in the map view with an additional padding of 300 pixels
        Point2D origin = new Point2D(300, 300);
        Size2D sizeInPixels = new Size2D(mapView.getWidth() - 600, mapView.getHeight() - 600);
        Rectangle2D mapViewport = new Rectangle2D(origin, sizeInPixels);

        // Animate to the route within a duration of 3 seconds.
        MapCameraUpdate update = MapCameraUpdateFactory.lookAt(
                route.getBoundingBox(),
                new GeoOrientationUpdate(bearing, tilt),
                mapViewport);
        MapCameraAnimation animation =
                MapCameraAnimationFactory.createAnimation(update, Duration.ofMillis(3000), new Easing(EasingFunction.IN_CUBIC));
        mapView.getCamera().startAnimation(animation);
    }

    // Starts guidance for the current route.
    public void startGuidance() {
        if (route == null) {
            UnitDialog unitDialog = new UnitDialog(context);
            unitDialog.showDialog("Error", "Calculate a route first.");
            return;
        }

        stopGuidanceInternal(false);
        useCurrentCameraBehavior();
        removeRoutePolyline();

        // Optionally, deactivate halo visualization for better visualization of the route carpet.
        visualNavigator.setLocationAccuracyVisualized(false);

        // This enables a navigation view including a rendered navigation arrow.
        visualNavigator.startRendering(mapView);

        // Hook in one of the many listeners. Here we set up a listener to get instructions on the maneuvers to take while driving.
        // For more details, please check the "Navigation" example app and the Developer's Guide.
        visualNavigator.setEventTextListener(eventText -> Log.d("Maneuver text", eventText.text));

        // Set a route to follow. This leaves tracking mode.
        visualNavigator.setRoute(route);

        // HD lanes are rendered only while guidance is actively running.
        // Outside guidance, the map remains in the standard navigation view.

        // VisualNavigator acts as LocationListener to receive location updates directly from a location provider.
        // Any progress along the route is a result of getting a new location fed into the VisualNavigator.
        setupLocationSource(route);
    }

    // Stops guidance and clears the map.
    public void stopGuidance() {
        stopGuidanceInternal(true);
    }

    private void stopGuidanceInternal(boolean clearMapContents) {
        boolean wasGuidanceRunning = locationSimulator != null;
        visualNavigator.setRoute(null);
        visualNavigator.stopRendering();

        if (locationSimulator != null) {
            locationSimulator.stop();
            locationSimulator = null;
        }

        if (route == null) {
            return;
        }

        if (wasGuidanceRunning) {
            removeRoutePolyline();
            showRoute(route);
            animateToRoute(route);
            return;
        }

        if (clearMapContents) {
            animateToRoute(route);
            clearMap();
        }
    }

    // Removes all map markers and polylines from the map.
    private void clearMap() {
        // Clear all map markers from the map.
        for (MapMarker mapMarker : mapMarkerList) {
            mapView.getMapScene().removeMapMarker(mapMarker);
        }
        mapMarkerList.clear();

        // Clear the route polyline from the map.
        removeRoutePolyline();
    }

    private void removeRoutePolyline() {
        if (routeMapPolyline != null) {
            mapView.getMapScene().removeMapPolyline(routeMapPolyline);
            routeMapPolyline = null;
        }
    }

    // Sets up the location simulator for the given route.
    private void setupLocationSource(Route route) {
        try {
            LocationSimulatorOptions locationSimulatorOptions = new LocationSimulatorOptions();
            // Simulate with speedFactor x speed-on-current-segment.
            locationSimulatorOptions.speedFactor = 2;
            // Provides fake GPS signals based on the route geometry.
            locationSimulator = new LocationSimulator(route, locationSimulatorOptions);
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of LocationSimulator failed: " + e.error.name());
        }
        locationSimulator.setListener(location -> {
            // Feed location data into the VisualNavigator.
            visualNavigator.onLocationUpdated(location);
        });
        locationSimulator.start();
    }

    private void useCurrentCameraBehavior() {
        visualNavigator.setCameraBehavior(visualNavigator.getCameraBehavior());
    }

}
