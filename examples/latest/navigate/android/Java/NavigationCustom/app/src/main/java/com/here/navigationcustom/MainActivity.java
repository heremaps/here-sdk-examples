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

package com.here.navigationcustom;

import static com.here.sdk.mapview.LocationIndicator.IndicatorStyle;

import android.content.Context;
import android.os.Bundle;
import android.util.Log;
import android.view.View;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;

import com.here.sdk.animation.AnimationListener;
import com.here.sdk.animation.AnimationState;
import com.here.sdk.core.Anchor2D;
import com.here.sdk.core.Color;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.GeoCoordinatesUpdate;
import com.here.sdk.core.GeoOrientationUpdate;
import com.here.sdk.core.Location;
import com.here.sdk.core.LocationListener;
import com.here.sdk.core.engine.AuthenticationMode;
import com.here.sdk.core.engine.SDKNativeEngine;
import com.here.sdk.core.engine.SDKOptions;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.mapview.LocationIndicator;
import com.here.sdk.mapview.MapCameraAnimation;
import com.here.sdk.mapview.MapCameraAnimationFactory;
import com.here.sdk.mapview.MapError;
import com.here.sdk.mapview.MapFeatureModes;
import com.here.sdk.mapview.MapFeatures;
import com.here.sdk.mapview.MapMarker3DModel;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapScene;
import com.here.sdk.mapview.MapScheme;
import com.here.sdk.mapview.MapView;
import com.here.sdk.navigation.FixedCameraBehavior;
import com.here.sdk.navigation.LocationSimulator;
import com.here.sdk.navigation.LocationSimulatorOptions;
import com.here.sdk.navigation.RouteProgressColors;
import com.here.sdk.navigation.VisualNavigator;
import com.here.sdk.navigation.VisualNavigatorColors;
import com.here.sdk.routing.CarOptions;
import com.here.sdk.routing.Route;
import com.here.sdk.routing.RoutingEngine;
import com.here.sdk.routing.SectionTransportMode;
import com.here.sdk.routing.Waypoint;
import com.here.time.Duration;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;
import com.here.sdk.units.core.utils.EnvironmentLogger;
import com.here.sdk.units.core.utils.PermissionsRequestor;

public class MainActivity extends AppCompatActivity {

    private EnvironmentLogger environmentLogger = new EnvironmentLogger();
    private static final String TAG = MainActivity.class.getSimpleName();
    private static final double DISTANCE_IN_METERS = 1000;

    private PermissionsRequestor permissionsRequestor;
    private MapView mapView;
    private RoutingEngine routingEngine;
    private VisualNavigator visualNavigator;
    private LocationSimulator locationSimulator;
    private LocationIndicator defaultLocationIndicator;
    private LocationIndicator customLocationIndicator;
    private Location lastKnownLocation = null;
    private GeoCoordinates routeStartGeoCoordinates;
    private boolean isDefaultLocationIndicator = true;
    private boolean isCustomHaloColor;
    private Color defaultHaloColor;
    private final double defaultHaloAccurarcyInMeters = 30.0;
    private final double cameraTiltInDegrees = 40.0;
    private final double cameraDistanceInMeters = 200.0;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Log application and device details.
        // It expects a string parameter that describes the application source language.
        environmentLogger.logEnvironment("Java");

        // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
        initializeHERESDK();

        setContentView(R.layout.activity_main);

        // Get a MapView instance from the layout.
        mapView = findViewById(R.id.map_view);
        mapView.onCreate(savedInstanceState);

        handleAndroidPermissions();

        try {
            routingEngine = new RoutingEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of RoutingEngine failed: " + e.error.name());
        }

        try {
            // Without a route set, this starts tracking mode.
            visualNavigator = new VisualNavigator();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of VisualNavigator failed: " + e.error.name());
        }

        showDialog("Custom Navigation",
                "Start / stop simulated route guidance. Toggle between custom / default LocationIndicator.");
    }

    private void initializeHERESDK() {
        // Set your credentials for the HERE SDK.
        String accessKeyID = "YOUR_ACCESS_KEY_ID";
        String accessKeySecret = "YOUR_ACCESS_KEY_SECRET";
        AuthenticationMode authenticationMode = AuthenticationMode.withKeySecret(accessKeyID, accessKeySecret);
        SDKOptions options = new SDKOptions(authenticationMode);
        try {
            Context context = this;
            SDKNativeEngine.makeSharedInstance(context, options);
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of HERE SDK failed: " + e.error.name());
        }
    }

    private void handleAndroidPermissions() {
        permissionsRequestor = new PermissionsRequestor(this);
        permissionsRequestor.request(new PermissionsRequestor.ResultListener() {

            @Override
            public void permissionsGranted() {
                loadMapScene();
            }

            @Override
            public void permissionsDenied() {
                Log.e(TAG, "Permissions denied by user.");
            }
        });
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        permissionsRequestor.onRequestPermissionsResult(requestCode, grantResults);
    }

    private void loadMapScene() {
        routeStartGeoCoordinates = new GeoCoordinates(52.520798, 13.409408);

        // Configure the map.
        MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, DISTANCE_IN_METERS);
        mapView.getCamera().lookAt(
                routeStartGeoCoordinates, mapMeasureZoom);

        // Load a scene from the HERE SDK to render the map with a map scheme.
        mapView.getMapScene().loadScene(MapScheme.NORMAL_DAY, new MapScene.LoadSceneCallback() {
            @Override
            public void onLoadScene(@Nullable MapError mapError) {
                if (mapError == null) {
                    // Enable a few map layers that might be useful to see for drivers.
                    Map<String, String> mapFeatures = new HashMap<>();
                    mapFeatures.put(MapFeatures.TRAFFIC_FLOW, MapFeatureModes.TRAFFIC_FLOW_WITH_FREE_FLOW);
                    mapFeatures.put(MapFeatures.TRAFFIC_INCIDENTS, MapFeatureModes.DEFAULT);
                    mapFeatures.put(MapFeatures.SAFETY_CAMERAS, MapFeatureModes.DEFAULT);
                    mapFeatures.put(MapFeatures.VEHICLE_RESTRICTIONS, MapFeatureModes.DEFAULT);

                    // Optionally, enable textured 3D landmarks.
                    mapFeatures.put(MapFeatures.LANDMARKS, MapFeatureModes.LANDMARKS_TEXTURED);
                    mapView.getMapScene().enableFeatures(mapFeatures);

                    defaultLocationIndicator = createDefaultLocationIndicator();
                    customLocationIndicator = createCustomLocationIndicator();

                    // We start with the built-in default LocationIndicator.
                    isDefaultLocationIndicator = true;
                    switchToPedestrianLocationIndicator();
                } else {
                    Log.d(TAG, "Loading map failed: mapError: " + mapError.name());
                }
            }
        });
    }

    private LocationIndicator createDefaultLocationIndicator() {
        LocationIndicator locationIndicator = new LocationIndicator();
        locationIndicator.setAccuracyVisualized(true);
        locationIndicator.setLocationIndicatorStyle(IndicatorStyle.PEDESTRIAN);
        defaultHaloColor = locationIndicator.getHaloColor(locationIndicator.getLocationIndicatorStyle());
        return locationIndicator;
    }

    private LocationIndicator createCustomLocationIndicator() {
        String pedGeometryFile = "custom_location_indicator_pedestrian.obj";
        String pedTextureFile = "custom_location_indicator_pedestrian.png";
        MapMarker3DModel pedestrianMapMarker3DModel = new MapMarker3DModel(pedGeometryFile, pedTextureFile);

        String navGeometryFile = "custom_location_indicator_navigation.obj";
        String navTextureFile = "custom_location_indicator_navigation.png";
        MapMarker3DModel navigationMapMarker3DModel = new MapMarker3DModel(navGeometryFile, navTextureFile);

        LocationIndicator locationIndicator = new LocationIndicator();
        double scaleFactor = 3;

        // Note: For this example app, we use only simulated location data.
        // Therefore, we do not create a custom LocationIndicator for
        // MarkerType.PEDESTRIAN_INACTIVE and MarkerType.NAVIGATION_INACTIVE.
        // If set with a gray texture model, the type can be switched by calling locationIndicator.setActive(false)
        // when the GPS accuracy is weak or no location was found.
        locationIndicator.setMarker3dModel(pedestrianMapMarker3DModel, scaleFactor, LocationIndicator.MarkerType.PEDESTRIAN);
        locationIndicator.setMarker3dModel(navigationMapMarker3DModel, scaleFactor, LocationIndicator.MarkerType.NAVIGATION);

        locationIndicator.setAccuracyVisualized(true);
        locationIndicator.setLocationIndicatorStyle(IndicatorStyle.PEDESTRIAN);
        
        return locationIndicator;
    }

    // Calculate a fixed route for testing and start guidance simulation along the route.
    public void startButtonClicked(View view) {
        if (visualNavigator.isRendering()) {
            return;
        }

        Waypoint startWaypoint = new Waypoint(getLastKnownLocation().coordinates);
        Waypoint destinationWaypoint = new Waypoint(new GeoCoordinates(52.530905, 13.385007));
        routingEngine.calculateRoute(
                new ArrayList<>(Arrays.asList(startWaypoint, destinationWaypoint)),
                new CarOptions(),
                (routingError, routes) -> {
                    if (routingError == null) {
                        Route route = routes.get(0);
                        animateToRouteStart(route);
                    } else {
                        Log.e("Route calculation error", routingError.toString());
                    }
                });
    }

    // Stop guidance simulation and switch pedestrian LocationIndicator on.
    public void stopButtonClicked(View view) {
        stopGuidance();
    }

    // Toggle between the default LocationIndicator and custom LocationIndicator.
    // The default LocationIndicator uses a 3D asset that is part of the HERE SDK.
    // The custom LocationIndicator uses different 3D assets, see asset folder.
    public void toggleStyleButtonClicked(View view) {
        // Toggle state.
        isDefaultLocationIndicator = !isDefaultLocationIndicator;

        // Select pedestrian or navigation assets.
        if (visualNavigator.isRendering()) {
            switchToNavigationLocationIndicator();
        } else {
            switchToPedestrianLocationIndicator();
        }
    }

    // Toggle the halo color of the default LocationIndicator.
    public void togglehaloColorButtonClicked(View view) {
        // Toggle state.
        isCustomHaloColor = !isCustomHaloColor;
        setSelectedHaloColor();
    }

    private void setSelectedHaloColor() {
        if (isCustomHaloColor) {
            Color customHaloColor = new Color(255F, 255F, 0F, 0.30F);
            defaultLocationIndicator.setHaloColor(defaultLocationIndicator.getLocationIndicatorStyle(), customHaloColor);
            customLocationIndicator.setHaloColor(customLocationIndicator.getLocationIndicatorStyle(), customHaloColor);
        } else {
            defaultLocationIndicator.setHaloColor(defaultLocationIndicator.getLocationIndicatorStyle(), defaultHaloColor);
            customLocationIndicator.setHaloColor(customLocationIndicator.getLocationIndicatorStyle(), defaultHaloColor);
        }
    }

    private void switchToPedestrianLocationIndicator() {
        if (isDefaultLocationIndicator) {
            defaultLocationIndicator.enable(mapView);
            defaultLocationIndicator.setLocationIndicatorStyle(IndicatorStyle.PEDESTRIAN);
            customLocationIndicator.disable();
        } else {
            defaultLocationIndicator.disable();
            customLocationIndicator.enable(mapView);
            customLocationIndicator.setLocationIndicatorStyle(IndicatorStyle.PEDESTRIAN);
        }

        // Set last location from LocationSimulator.
        defaultLocationIndicator.updateLocation(getLastKnownLocation());
        customLocationIndicator.updateLocation(getLastKnownLocation());

        setSelectedHaloColor();
    }

    private void switchToNavigationLocationIndicator() {
        if (isDefaultLocationIndicator) {
            // By default, the VisualNavigator adds a LocationIndicator on its own.
            // This can be kept by calling visualNavigator.customLocationIndicator = nil
            // However, here we want to be able to customize the halo for the default location indicator.
            // Therefore, we still need to set our own instance to the VisualNavigator.
            customLocationIndicator.disable();
            defaultLocationIndicator.enable(mapView);
            defaultLocationIndicator.setLocationIndicatorStyle(IndicatorStyle.NAVIGATION);
            visualNavigator.setCustomLocationIndicator(defaultLocationIndicator);
        } else {
            defaultLocationIndicator.disable();
            customLocationIndicator.enable(mapView);
            customLocationIndicator.setLocationIndicatorStyle(IndicatorStyle.NAVIGATION);
            visualNavigator.setCustomLocationIndicator(customLocationIndicator);

            // Note that the type of the LocationIndicator is taken from the route's TransportMode.
            // It cannot be overridden during guidance.
            // During tracking mode (not shown in this app) you can specify the marker type via:
            // visualNavigator.setTrackingTransportMode(TransportMode.PEDESTRIAN);
        }

        setSelectedHaloColor();
    }

    private Location getLastKnownLocation() {
        if (lastKnownLocation == null) {
            // A LocationIndicator is intended to mark the user's current location,
            // including a bearing direction.
            // For testing purposes, we create below a Location object. Usually, you want to get this from
            // a GPS sensor instead. Check the Positioning example app for this.
            Location location = new Location(routeStartGeoCoordinates);
            location.time = new Date();
            location.horizontalAccuracyInMeters = defaultHaloAccurarcyInMeters;
            return location;
        }
        // This location is taken from the LocationSimulator that provides locations along the route.
        return lastKnownLocation;
    }

    // Animate to custom guidance perspective, centered on start location of route.
    private void animateToRouteStart(Route route) {
        // The first coordinate marks the start location of the route.
        GeoCoordinates startOfRoute = route.getGeometry().vertices.get(0);
        GeoCoordinatesUpdate geoCoordinatesUpdate = new GeoCoordinatesUpdate(startOfRoute);

        Double bearingInDegrees = null;
        double tiltInDegrees = cameraTiltInDegrees;
        GeoOrientationUpdate orientationUpdate = new GeoOrientationUpdate(bearingInDegrees, tiltInDegrees);

        double distanceInMeters = cameraDistanceInMeters;
        MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, distanceInMeters);

        double bowFactor = 1;
        MapCameraAnimation animation = MapCameraAnimationFactory.flyTo(
                geoCoordinatesUpdate, orientationUpdate, mapMeasureZoom, bowFactor, Duration.ofSeconds(3));
        mapView.getCamera().startAnimation(animation, new AnimationListener() {
            @Override
            public void onAnimationStateChanged(@NonNull AnimationState animationState) {
                if (animationState == AnimationState.COMPLETED
                        || animationState == AnimationState.CANCELLED) {
                    startGuidance(route);
                }
            }
        });
    }

    private void animateToDefaultMapPerspective() {
        GeoCoordinates targetLocation = mapView.getCamera().getState().targetCoordinates;
        GeoCoordinatesUpdate geoCoordinatesUpdate = new GeoCoordinatesUpdate(targetLocation);

        // By setting null we keep the current bearing rotation of the map.
        Double bearingInDegrees = null;
        double tiltInDegrees = 0;
        GeoOrientationUpdate orientationUpdate = new GeoOrientationUpdate(bearingInDegrees, tiltInDegrees);

        MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, DISTANCE_IN_METERS);
        double bowFactor = 1;
        MapCameraAnimation animation = MapCameraAnimationFactory.flyTo(
                geoCoordinatesUpdate, orientationUpdate, mapMeasureZoom, bowFactor, Duration.ofSeconds(3));
        mapView.getCamera().startAnimation(animation);
    }

    private void startGuidance(Route route) {
        if (visualNavigator.isRendering()) {
            return;
        }

        // Set the route and maneuver arrow color.
        customizeVisualNavigatorColors();

        // Set custom guidance perspective.
        customizeGuidanceView();

        // This enables a navigation view and adds a LocationIndicator.
        visualNavigator.startRendering(mapView);

        // Note: By default, when VisualNavigator starts rendering, a default LocationIndicator is added
        // by the HERE SDK automatically.
        visualNavigator.setCustomLocationIndicator(customLocationIndicator);
        switchToNavigationLocationIndicator();

        // Set a route to follow. This leaves tracking mode.
        visualNavigator.setRoute(route);

        // This app does not use real location updates. Instead it provides location updates based
        // on the geographic coordinates of a route using HERE SDK's LocationSimulator.
        startRouteSimulation(route);
    }

    private void stopGuidance() {
        visualNavigator.stopRendering();

        if (locationSimulator != null) {
            locationSimulator.stop();
        }

        // Note: By default, when VisualNavigator stops rendering, no LocationIndicator is visible.
        switchToPedestrianLocationIndicator();

        animateToDefaultMapPerspective();
    }

    private void customizeVisualNavigatorColors() {
        Color routeAheadColor =  Color.valueOf(android.graphics.Color.BLUE);
        Color routeBehindColor = Color.valueOf(android.graphics.Color.RED);
        Color routeAheadOutlineColor = Color.valueOf(android.graphics.Color.YELLOW);
        Color routeBehindOutlineColor = Color.valueOf(android.graphics.Color.DKGRAY);
        Color maneuverArrowColor = Color.valueOf(android.graphics.Color.GREEN);

        VisualNavigatorColors visualNavigatorColors = VisualNavigatorColors.dayColors();
        RouteProgressColors routeProgressColors = new RouteProgressColors(
                routeAheadColor,
                routeBehindColor,
                routeAheadOutlineColor,
                routeBehindOutlineColor);

        // Sets the color used to draw maneuver arrows.
        visualNavigatorColors.setManeuverArrowColor(maneuverArrowColor);
        // Sets route color for a single transport mode. Other modes are kept using defaults.
        visualNavigatorColors.setRouteProgressColors(SectionTransportMode.CAR, routeProgressColors);
        // Sets the adjusted colors for route progress and maneuver arrows based on the day color scheme.
        visualNavigator.setColors(visualNavigatorColors);
    }

    private void customizeGuidanceView() {
        FixedCameraBehavior cameraBehavior = new FixedCameraBehavior();
        // Set custom zoom level and tilt.
        cameraBehavior.setCameraDistanceInMeters(cameraDistanceInMeters);
        cameraBehavior.setCameraTiltInDegrees(cameraTiltInDegrees);
        // Disable North-Up mode by setting null. Enable North-up mode by setting Double.valueOf(0).
        // By default, North-Up mode is disabled.
        cameraBehavior.setCameraBearingInDegrees(null);
        cameraBehavior.setNormalizedPrincipalPoint(new Anchor2D(0.5, 0.5));

        // The CameraBehavior can be updated during guidance at any time as often as desired.
        // Alternatively, use DynamicCameraBehavior for auto-zoom.
        visualNavigator.setCameraBehavior(cameraBehavior);
    }

    private final LocationListener myLocationListener = new LocationListener() {
        @Override
        public void onLocationUpdated(@NonNull Location location) {
            // By default, accuracy is null during simulation, but we want to customize the halo,
            // so we hijack the location object and add an accuracy value.
            // Do not do this when using real GPS locations!
            location.horizontalAccuracyInMeters = defaultHaloAccurarcyInMeters;
            // Feed location data into the VisualNavigator.
            visualNavigator.onLocationUpdated(location);
            lastKnownLocation = location;
        }
    };

    private void startRouteSimulation(Route route) {
        if (locationSimulator != null) {
            // Make sure to stop an existing LocationSimulator before starting a new one.
            locationSimulator.stop();
        }

        try {
            // Provides fake GPS signals based on the route geometry.
            locationSimulator = new LocationSimulator(route, new LocationSimulatorOptions());
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of LocationSimulator failed: " + e.error.name());
        }

        locationSimulator.setListener(myLocationListener);
        locationSimulator.start();
    }

    @Override
    protected void onPause() {
        mapView.onPause();
        super.onPause();
    }

    @Override
    protected void onResume() {
        mapView.onResume();
        super.onResume();
    }

    @Override
    protected void onDestroy() {
        visualNavigator.stopRendering();
        locationSimulator.stop();
        mapView.onDestroy();
        disposeHERESDK();
        super.onDestroy();
    }

    @Override
    protected void onSaveInstanceState(@NonNull Bundle outState) {
        mapView.onSaveInstanceState(outState);
        super.onSaveInstanceState(outState);
    }

    private void disposeHERESDK() {
        // Free HERE SDK resources before the application shuts down.
        // Usually, this should be called only on application termination.
        // Afterwards, the HERE SDK is no longer usable unless it is initialized again.
        SDKNativeEngine sdkNativeEngine = SDKNativeEngine.getSharedInstance();
        if (sdkNativeEngine != null) {
            sdkNativeEngine.dispose();
            // For safety reasons, we explicitly set the shared instance to null to avoid situations,
            // where a disposed instance is accidentally reused.
            SDKNativeEngine.setSharedInstance(null);
        }
    }

    private void showDialog(String title, String message) {
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setTitle(title)
                .setMessage(message)
                .show();
    }
}
