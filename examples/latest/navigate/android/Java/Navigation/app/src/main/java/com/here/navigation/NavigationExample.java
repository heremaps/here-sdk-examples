/*
 * Copyright (C) 2019-2025 HERE Europe B.V.
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

import com.here.sdk.core.GeoCircle;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.GeoPolygon;
import com.here.sdk.core.Location;
import com.here.sdk.core.engine.SDKNativeEngine;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.location.LocationAccuracy;
import com.here.sdk.maploader.MapLoaderError;
import com.here.sdk.mapview.MapView;
import com.here.sdk.navigation.DynamicCameraBehavior;
import com.here.sdk.navigation.SpeedBasedCameraBehavior;
import com.here.sdk.navigation.VisualNavigator;
import com.here.sdk.prefetcher.PolygonPrefetcher;
import com.here.sdk.prefetcher.PrefetchStatusListener;
import com.here.sdk.prefetcher.RoutePrefetcher;
import com.here.sdk.routing.Route;
import com.here.sdk.routing.RoutingError;
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
    private PolygonPrefetcher polygonPrefetcher;
    private final NavigationHandler navigationHandler;
    private final TextView messageView;

    public NavigationExample(Context context, MapView mapView, TextView messageView) {
        this.messageView = messageView;

        // A class to receive real location events.
        herePositioningProvider = new HEREPositioningProvider(context);
        // A class to receive simulated location events.
        herePositioningSimulator = new HEREPositioningSimulator();
        // The RoutePrefetcher downloads map data in advance into the map cache.
        // This is not mandatory, but can help to improve the guidance experience.
        routePrefetcher = new RoutePrefetcher(SDKNativeEngine.getSharedInstance());
        polygonPrefetcher = new PolygonPrefetcher(SDKNativeEngine.getSharedInstance());

        try {
            // Without a route set, this starts tracking mode.
            visualNavigator = new VisualNavigator();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of VisualNavigator failed: " + e.error.name());
        }

        // By default, the MapView renders at 60 frames per second (fps).
        // When turn-by-turn navigation is enabled via the VisualNavigator,
        // the frame rate is reduced to 30 fps. This value can be customized;
        // for example, it is set to 60 fps below.
        visualNavigator.setGuidanceFrameRate(60);

        // This enables a navigation view including a rendered navigation arrow.
        visualNavigator.startRendering(mapView);

        createDynamicRoutingEngine();

        // A class to handle various kinds of guidance events.
        navigationHandler = new NavigationHandler(context, messageView);
        navigationHandler.setupListeners(visualNavigator, dynamicRoutingEngine);

        messageView.setText("Initialization completed.");
    }

    public void startLocationProvider() {
        // Set navigator as listener to receive locations from HERE Positioning
        // and choose a suitable accuracy for the tbt navigation use case.
        herePositioningProvider.startLocating(visualNavigator, LocationAccuracy.NAVIGATION);
    }

    private void prefetchMapData(GeoCoordinates currentGeoCoordinates) {
        // Prefetches map data around the provided location with a radius of 12 km into the map cache.
        // For the best experience, prefetch() should be called as early as possible.

        double radiusInMeters = 12000.0;

        GeoCircle geoCircle = new GeoCircle(currentGeoCoordinates, radiusInMeters);
        polygonPrefetcher.prefetch(new GeoPolygon(geoCircle), new PrefetchStatusListener() {
            @Override
            public void onProgress(int percentage) {
                messageView.setText("Prefetch progress: " + percentage + "%");
            }

            @Override
            public void onComplete(@Nullable MapLoaderError mapLoaderError) {
                if (mapLoaderError == null) {
                    messageView.setText("Prefetch completed successfully");
                } else {
                    messageView.setText("Prefetch failed: " + mapLoaderError);
                }
            }
        });

        // Prefetches map data within a fixed-length corridor of 10 km along the route that is currently set to the provided Navigator instance.
        // This happens continuously in discrete intervals to fetch new corridors as the user is progressing along the route.
        // If no route is set, no data will be prefetched.
        // Alternatively, it is also possible to prefetch an entire route in advance using prefetchGeoCorridor(...). 
        routePrefetcher.prefetchAroundRouteOnIntervals(visualNavigator);
    }

    // Use this engine to periodically search for better routes during guidance, ie. when the traffic
    // situation changes.
    //
    // Note: This code initiates periodic calls to the HERE Routing backend. Depending on your contract,
    // each call may be charged separately. It is the application's responsibility to decide how
    // often this code should be executed.
    private void createDynamicRoutingEngine() {
        DynamicRoutingEngineOptions dynamicRoutingOptions = new DynamicRoutingEngineOptions();
        // Both, minTimeDifference and minTimeDifferencePercentage, will be checked:
        // When the poll interval is reached, the smaller difference will win.
        dynamicRoutingOptions.minTimeDifference = Duration.ofSeconds(1);
        dynamicRoutingOptions.minTimeDifferencePercentage = 0.1;
        // Below, we use 10 minutes. A common range is between 5 and 15 minutes.
        dynamicRoutingOptions.pollInterval = Duration.ofMinutes(10);

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
