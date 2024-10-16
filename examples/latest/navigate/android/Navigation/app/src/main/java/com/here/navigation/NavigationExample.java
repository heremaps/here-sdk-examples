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

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.Location;
import com.here.sdk.core.engine.SDKNativeEngine;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.location.LocationAccuracy;
import com.here.sdk.mapview.MapView;
import com.here.sdk.navigation.DynamicCameraBehavior;
import com.here.sdk.navigation.SpeedBasedCameraBehavior;
import com.here.sdk.navigation.VisualNavigator;
import com.here.sdk.prefetcher.RoutePrefetcher;
import com.here.sdk.routing.CalculateTrafficOnRouteCallback;
import com.here.sdk.routing.Route;
import com.here.sdk.routing.RoutingError;
import com.here.sdk.routing.TrafficOnRoute;
import com.here.sdk.trafficawarenavigation.DynamicRoutingEngine;
import com.here.sdk.trafficawarenavigation.DynamicRoutingEngineOptions;
import com.here.sdk.trafficawarenavigation.DynamicRoutingListener;
import com.here.time.Duration;

// Shows how to start and stop turn-by-turn navigation on a car route.
// By default, tracking mode is enabled. When navigation is stopped, tracking mode is enabled again.
// The preferred device language determines the language for voice notifications used for TTS.
// (Make sure to set language + region in device settings.)
public class NavigationExample {

    private static final String TAG = NavigationExample.class.getName();

    private final VisualNavigator visualNavigator;
    private final HEREPositioningProvider herePositioningProvider;
    private final HEREPositioningSimulator herePositioningSimulator;
    private DynamicRoutingEngine dynamicRoutingEngine;
    private RoutePrefetcher routePrefetcher;
    private final NavigationEventHandler navigationEventHandler;
    private final TextView messageView;
    private CalculateTrafficOnRouteCallback calculateTrafficOnRouteCallback;

    public NavigationExample(Context context, MapView mapView, TextView messageView) {
        this.messageView = messageView;

        // A class to receive real location events.
        herePositioningProvider = new HEREPositioningProvider();
        // A class to receive simulated location events.
        herePositioningSimulator = new HEREPositioningSimulator();
        // The RoutePrefetcher downloads map data in advance into the map cache.
        // This is not mandatory, but can help to improve the guidance experience.
        routePrefetcher = new RoutePrefetcher(SDKNativeEngine.getSharedInstance());

        try {
            // Without a route set, this starts tracking mode.
            visualNavigator = new VisualNavigator();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of VisualNavigator failed: " + e.error.name());
        }

        // This enables a navigation view including a rendered navigation arrow.
        visualNavigator.startRendering(mapView);

        createDynamicRoutingEngine();

        // A class to handle various kinds of guidance events.
        navigationEventHandler = new NavigationEventHandler(context, messageView);
        navigationEventHandler.setupListeners(visualNavigator, dynamicRoutingEngine);

        messageView.setText("Initialization completed.");
    }

    public void startLocationProvider() {
        // Set navigator as listener to receive locations from HERE Positioning
        // and choose a suitable accuracy for the tbt navigation use case.
        herePositioningProvider.startLocating(visualNavigator, LocationAccuracy.NAVIGATION);
    }

    private void prefetchMapData(GeoCoordinates currentGeoCoordinates) {
        // Prefetches map data around the provided location with a radius of 2 km into the map cache.
        // For the best experience, prefetchAroundLocationWithRadius() should be called as early as possible.
        double radiusInMeters = 2000.0;
        routePrefetcher.prefetchAroundLocationWithRadius(currentGeoCoordinates, radiusInMeters);
        // Prefetches map data within a corridor along the route that is currently set to the provided Navigator instance.
        // This happens continuously in discrete intervals.
        // If no route is set, no data will be prefetched.
        routePrefetcher.prefetchAroundRouteOnIntervals(visualNavigator);
    }

    // Use this engine to periodically search for better routes during guidance, ie. when the traffic
    // situation changes.
    private void createDynamicRoutingEngine() {
        DynamicRoutingEngineOptions dynamicRoutingOptions = new DynamicRoutingEngineOptions();
        // Both, minTimeDifference and minTimeDifferencePercentage, will be checked:
        // When the poll interval is reached, the smaller difference will win.
        dynamicRoutingOptions.minTimeDifference = Duration.ofSeconds(1);
        dynamicRoutingOptions.minTimeDifferencePercentage = 0.1;
        dynamicRoutingOptions.pollInterval = Duration.ofMinutes(5);

        try {
            // With the dynamic routing engine you can poll the HERE backend services to search for routes with less traffic.
            // This can happen during guidance - or you can periodically update a route that is shown in a route planner.
            //
            // Make sure to call dynamicRoutingEngine.updateCurrentLocation(...) to trigger execution. If this is not called,
            // no events will be delivered even if the next poll interval has been reached.
            dynamicRoutingEngine = new DynamicRoutingEngine(dynamicRoutingOptions);
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of DynamicRoutingEngine failed: " + e.error.name());
        }
    }

    public void startNavigation(Route route, boolean isSimulated, boolean isCameraTrackingEnabled) {
        GeoCoordinates startGeoCoordinates = route.getGeometry().vertices.get(0);
        prefetchMapData(startGeoCoordinates);

        // Switches to navigation mode when no route was set before, otherwise navigation mode is kept.
        visualNavigator.setRoute(route);

        // Enable auto-zoom during guidance.
        visualNavigator.setCameraBehavior(new DynamicCameraBehavior());

        if (isSimulated) {
            enableRoutePlayback(route);
            messageView.setText("Starting simulated navgation.");
        } else {
            enableDevicePositioning();
            messageView.setText("Starting navgation.");
        }

        startDynamicSearchForBetterRoutes(route);

        // Synchronize with the toggle button state.
        updateCameraTracking(isCameraTrackingEnabled);

        navigationEventHandler.startPeriodicTrafficUpdateOnRoute((routingError, trafficOnRoute) -> {
            if (routingError != null) {
                Log.d(TAG, "CalculateTrafficOnRoute error: " + routingError.name());
                return;
            }
            Log.d(TAG, "Updated traffic on route");
            // Sets traffic data for the current route, affecting RouteProgress duration in SectionProgress, while preserving route distance and geometry.
            visualNavigator.setTrafficOnRoute(trafficOnRoute);
        }, 1000);
    }

    private void startDynamicSearchForBetterRoutes(Route route) {
        try {
            // Note that the engine will be internally stopped, if it was started before.
            // Therefore, it is not necessary to stop the engine before starting it again.
            dynamicRoutingEngine.start(route, new DynamicRoutingListener() {
                // Notifies on traffic-optimized routes that are considered better than the current route.
                @Override
                public void onBetterRouteFound(@NonNull Route newRoute, int etaDifferenceInSeconds, int distanceDifferenceInMeters) {
                    Log.d(TAG, "DynamicRoutingEngine: Calculated a new route.");
                    Log.d(TAG, "DynamicRoutingEngine: etaDifferenceInSeconds: " + etaDifferenceInSeconds + ".");
                    Log.d(TAG, "DynamicRoutingEngine: distanceDifferenceInMeters: " + distanceDifferenceInMeters + ".");

                    String logMessage = "Calculated a new route. etaDifferenceInSeconds: " + etaDifferenceInSeconds +
                            " distanceDifferenceInMeters: " + distanceDifferenceInMeters;
                    messageView.setText("DynamicRoutingEngine update: " + logMessage);

                    // An implementation needs to decide when to switch to the new route based
                    // on above criteria.
                }

                @Override
                public void onRoutingError(@NonNull RoutingError routingError) {
                    Log.d(TAG, "Error while dynamically searching for a better route: " + routingError.name());
                }
            });
        } catch (DynamicRoutingEngine.StartException e) {
            throw new RuntimeException("Start of DynamicRoutingEngine failed. Is the RouteHandle missing?");
        }
    }

    public void stopNavigation(boolean isCameraTrackingEnabled) {
        // Switches to tracking mode when a route was set before, otherwise tracking mode is kept.
        // Note that tracking mode means that the visual navigator will continue to run, but without
        // turn-by-turn instructions - this can be done with or without camera tracking.
        // Without a route the navigator will only notify on the current map-matched location
        // including info such as speed and current street name.
        visualNavigator.setRoute(null);
        // SpeedBasedCameraBehavior is recommended for tracking mode.
        visualNavigator.setCameraBehavior(new SpeedBasedCameraBehavior());
        enableDevicePositioning();
        messageView.setText("Tracking device's location.");

        dynamicRoutingEngine.stop();
        routePrefetcher.stopPrefetchAroundRoute();
        navigationEventHandler.stopPeriodicTrafficUpdateOnRoute();

        // Synchronize with the toggle button state.
        updateCameraTracking(isCameraTrackingEnabled);
    }

    private void updateCameraTracking(boolean isCameraTrackingEnabled) {
        if (isCameraTrackingEnabled) {
            startCameraTracking();
        } else {
            stopCameraTracking();
        }
    }

    // Provides simulated location updates based on the given route.
    public void enableRoutePlayback(Route route) {
        herePositioningProvider.stopLocating();
        herePositioningSimulator.startLocating(visualNavigator, route);
    }

    // Provides location updates based on the device's GPS sensor.
    public void enableDevicePositioning() {
        herePositioningSimulator.stopLocating();
        herePositioningProvider.startLocating(visualNavigator, LocationAccuracy.NAVIGATION);
    }

    public void startCameraTracking() {
        visualNavigator.setCameraBehavior(new DynamicCameraBehavior());
    }

    public void stopCameraTracking() {
        visualNavigator.setCameraBehavior(null);
    }

    @Nullable
    public Location getLastKnownLocation() {
        return herePositioningProvider.getLastKnownLocation();
    }

    public void stopLocating() {
        herePositioningProvider.stopLocating();
    }

    public void stopRendering() {
        // It is recommended to stop rendering before leaving an activity.
        // This also removes the current location marker.
        visualNavigator.stopRendering();
    }
}
