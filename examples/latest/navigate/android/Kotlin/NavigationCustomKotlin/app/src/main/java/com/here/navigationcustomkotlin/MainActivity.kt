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
package com.here.navigationcustomkotlin

import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.here.navigationcustomkotlin.ui.theme.NavigationCustomTheme
import com.here.sdk.animation.AnimationListener
import com.here.sdk.animation.AnimationState
import com.here.sdk.core.Anchor2D
import com.here.sdk.core.Color
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.core.GeoCoordinatesUpdate
import com.here.sdk.core.GeoOrientationUpdate
import com.here.sdk.core.Location
import com.here.sdk.core.LocationListener
import com.here.sdk.core.engine.AuthenticationMode
import com.here.sdk.core.engine.SDKNativeEngine
import com.here.sdk.core.engine.SDKOptions
import com.here.sdk.core.errors.InstantiationErrorException
import com.here.sdk.mapview.LocationIndicator
import com.here.sdk.mapview.LocationIndicator.IndicatorStyle
import com.here.sdk.mapview.MapCameraAnimationFactory
import com.here.sdk.mapview.MapFeatureModes
import com.here.sdk.mapview.MapFeatures
import com.here.sdk.mapview.MapMarker3DModel
import com.here.sdk.mapview.MapMeasure
import com.here.sdk.mapview.MapScheme
import com.here.sdk.mapview.MapView
import com.here.sdk.navigation.FixedCameraBehavior
import com.here.sdk.navigation.LocationSimulator
import com.here.sdk.navigation.LocationSimulatorOptions
import com.here.sdk.navigation.RouteProgressColors
import com.here.sdk.navigation.VisualNavigator
import com.here.sdk.navigation.VisualNavigatorColors
import com.here.sdk.routing.CalculateRouteCallback
import com.here.sdk.routing.CarOptions
import com.here.sdk.routing.Route
import com.here.sdk.routing.RoutingEngine
import com.here.sdk.routing.RoutingError
import com.here.sdk.routing.SectionTransportMode
import com.here.sdk.routing.Waypoint
import com.here.time.Duration
import java.util.Date
import com.here.sdk.units.core.utils.EnvironmentLogger
import com.here.sdk.units.core.utils.PermissionsRequestor

class MainActivity : ComponentActivity() {


    private val environmentLogger = EnvironmentLogger()
    private lateinit var permissionsRequestor: PermissionsRequestor
    private var mapView: MapView? = null
    private var routingEngine: RoutingEngine? = null
    private var visualNavigator: VisualNavigator? = null
    private var locationSimulator: LocationSimulator? = null
    private lateinit var defaultLocationIndicator: LocationIndicator
    private lateinit var customLocationIndicator: LocationIndicator
    private var lastKnownLocation: Location? = null
    private lateinit var routeStartGeoCoordinates: GeoCoordinates
    private var isDefaultLocationIndicator: Boolean = true
    private var isCustomHaloColor: Boolean = false
    private var defaultHaloColor = Color(0f, 0f, 0f, 0f)
    private val defaultHaloAccurarcyInMeters = 30.0
    private val cameraTiltInDegrees = 40.0
    private val cameraDistanceInMeters = 200.0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Needs to be called before the activity is started.

        // Log application and device details.
        // It expects a string parameter that describes the application source language.
        environmentLogger.logEnvironment("Kotlin")
        permissionsRequestor = PermissionsRequestor(this)

        // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
        // Before creating a MapView instance please make sure that the HERE SDK is initialized.
        initializeHERESDK()

        try {
            routingEngine = RoutingEngine()
        } catch (e: InstantiationErrorException) {
            throw java.lang.RuntimeException("Initialization of RoutingEngine failed: " + e.error.name)
        }

        try {
            visualNavigator = VisualNavigator()
        } catch (e: InstantiationErrorException) {
            throw java.lang.RuntimeException("Initialization of VisualNavigator failed: " + e.error.name)
        }

        routeStartGeoCoordinates = GeoCoordinates(52.520798, 13.409408)

        enableEdgeToEdge()

        setContent {
            NavigationCustomTheme {
                Scaffold(
                    modifier = Modifier.fillMaxSize()
                ) { paddingValues ->
                    Box(modifier = Modifier.padding(paddingValues)) {
                        HereMapView(savedInstanceState)
                        ButtonRows()
                    }
                }
            }
        }
    }

    // Wrap the MapView into a Composable in order to use it with Jetpack Compose.
    @Composable
    private fun HereMapView(savedInstanceState: Bundle?) {
        AndroidView(factory = { context ->
            MapView(context).apply {
                mapView = this
                mapView?.onCreate(savedInstanceState)

                // Note that for this app handling of permissions is optional as no sensitive permissions
                // are required.
                // Only after permissions have been granted (if any), we load the map view and start the app.
                handleAndroidPermissions()
            }
        })
    }

    @Composable
    fun ButtonRows() {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                CustomButton(
                    onClick = { startButtonClicked() },
                    text = "Start simulation",
                )
                Spacer(modifier = Modifier.width(4.dp))
                CustomButton(
                    onClick = { stopButtonClicked() },
                    text = "Stop simulation",
                )
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                CustomButton(
                    onClick = { toggleStyleButtonClicked() },
                    text = "Toggle indicator style",
                )
                Spacer(modifier = Modifier.width(4.dp))
                CustomButton(
                    onClick = { togglehaloColorButtonClicked() },
                    text = "Toggle halo color",
                )
            }
        }
    }

    @Composable
    fun CustomButton(onClick: () -> Unit, text: String) {
        Button(
            onClick = onClick,
            colors = ButtonDefaults.buttonColors(
                containerColor = androidx.compose.ui.graphics.Color(0xFF005CB9),
                contentColor = androidx.compose.ui.graphics.Color.White
            )
        ) {
            Text(text,
                fontSize = 12.sp,
                textAlign = TextAlign.Center,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis)
        }
    }

    // Convenience method to check all permissions that have been added to the AndroidManifest.
    private fun handleAndroidPermissions() {
        permissionsRequestor.request(object :
            PermissionsRequestor.ResultListener {
            override fun permissionsGranted() {
                loadMapScene()
            }

            override fun permissionsDenied() {
                Log.e(TAG, "Permissions denied by user.")
            }
        })
    }

    private fun initializeHERESDK() {
        // Set your credentials for the HERE SDK.
        val accessKeyID = "YOUR_ACCESS_KEY_ID"
        val accessKeySecret = "YOUR_ACCESS_KEY_SECRET"
        val authenticationMode = AuthenticationMode.withKeySecret(accessKeyID, accessKeySecret)
        val options = SDKOptions(authenticationMode)
        try {
            val context = this
            SDKNativeEngine.makeSharedInstance(context, options)
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("Initialization of HERE SDK failed: " + e.error.name)
        }
    }

    private fun loadMapScene() {
        val mapViewNonNull = mapView ?: run {
            Log.e(TAG, "mapView is null. Cannot load map scene.")
            return
        }

        // Load a scene from the HERE SDK to render the map with a map scheme.
        mapViewNonNull.mapScene.loadScene(MapScheme.NORMAL_DAY) { mapError ->
            if (mapError == null) {
                // Configure the map.
                val mapMeasureZoom = MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, DISTANCE_IN_METERS)
                mapViewNonNull.camera.lookAt(
                    routeStartGeoCoordinates, mapMeasureZoom
                )

                // Enable a few map layers that might be useful to see for drivers.
                val mapFeatures: MutableMap<String, String> = HashMap()
                mapFeatures[MapFeatures.TRAFFIC_FLOW] = MapFeatureModes.TRAFFIC_FLOW_WITH_FREE_FLOW
                mapFeatures[MapFeatures.TRAFFIC_INCIDENTS] = MapFeatureModes.DEFAULT
                mapFeatures[MapFeatures.SAFETY_CAMERAS] = MapFeatureModes.DEFAULT
                mapFeatures[MapFeatures.VEHICLE_RESTRICTIONS] = MapFeatureModes.DEFAULT

                // Optionally, enable textured 3D landmarks.
                mapFeatures[MapFeatures.LANDMARKS] = MapFeatureModes.LANDMARKS_TEXTURED
                mapView!!.mapScene.enableFeatures(mapFeatures)

                defaultLocationIndicator = createDefaultLocationIndicator()
                customLocationIndicator = createCustomLocationIndicator()

                // Show indicator on map. We start with the built-in default LocationIndicator.
                isDefaultLocationIndicator = true
                switchToPedestrianLocationIndicator()
            } else {
                Log.d(TAG, "Loading of map failed: mapError: ${mapError.name}")
            }
        }
    }

    private fun createDefaultLocationIndicator(): LocationIndicator {
        val locationIndicator = LocationIndicator()
        locationIndicator.isAccuracyVisualized = true
        locationIndicator.locationIndicatorStyle = IndicatorStyle.PEDESTRIAN
        defaultHaloColor = locationIndicator.getHaloColor(locationIndicator.locationIndicatorStyle)
        return locationIndicator
    }

    private fun createCustomLocationIndicator(): LocationIndicator {
        val pedGeometryFile = "custom_location_indicator_pedestrian.obj"
        val pedTextureFile = "custom_location_indicator_pedestrian.png"
        val pedestrianMapMarker3DModel = MapMarker3DModel(pedGeometryFile, pedTextureFile)

        val navGeometryFile = "custom_location_indicator_navigation.obj"
        val navTextureFile = "custom_location_indicator_navigation.png"
        val navigationMapMarker3DModel = MapMarker3DModel(navGeometryFile, navTextureFile)

        val locationIndicator = LocationIndicator()
        val scaleFactor = 3.0

        // Note: For this example app, we use only simulated location data.
        // Therefore, we do not create a custom LocationIndicator for
        // MarkerType.PEDESTRIAN_INACTIVE and MarkerType.NAVIGATION_INACTIVE.
        // If set with a gray texture model, the type can be switched by calling locationIndicator.setActive(false)
        // when the GPS accuracy is weak or no location was found.
        locationIndicator.setMarker3dModel(
            pedestrianMapMarker3DModel,
            scaleFactor,
            LocationIndicator.MarkerType.PEDESTRIAN
        )
        locationIndicator.setMarker3dModel(
            navigationMapMarker3DModel,
            scaleFactor,
            LocationIndicator.MarkerType.NAVIGATION
        )

        locationIndicator.isAccuracyVisualized = true
        locationIndicator.locationIndicatorStyle = IndicatorStyle.PEDESTRIAN

        return locationIndicator
    }

    // Calculate a fixed route for testing and start guidance simulation along the route.
    private fun startButtonClicked() {
        if (visualNavigator?.isRendering() == true) {
            return
        }

        if (routingEngine != null) {
            val startWaypoint = Waypoint(getLastKnownLocation().coordinates)
            val destinationWaypoint = Waypoint(GeoCoordinates(52.530905, 13.385007))
            routingEngine!!.calculateRoute(
                arrayListOf(startWaypoint, destinationWaypoint),
                CarOptions(),
                object : CalculateRouteCallback {
                    override fun onRouteCalculated(routingError: RoutingError?, routes: List<Route>?) {
                        if (routingError == null) {
                            val route: Route = routes!![0]
                            animateToRouteStart(route)
                        } else {
                            Log.e("Route calculation error", routingError.toString());
                        }
                    }
                })
        }
    }

    // Stop guidance simulation and switch pedestrian LocationIndicator on.
    private fun stopButtonClicked() {
        stopGuidance()
    }

    // Toggle between the default LocationIndicator and custom LocationIndicator.
    // The default LocationIndicator uses a 3D asset that is part of the HERE SDK.
    // The custom LocationIndicator uses different 3D assets, see asset folder.
    private fun toggleStyleButtonClicked() {
        // Toggle state.
        isDefaultLocationIndicator = !isDefaultLocationIndicator

        // Select pedestrian or navigation assets.
        if (visualNavigator?.isRendering() == true) {
            switchToNavigationLocationIndicator()
        } else {
            switchToPedestrianLocationIndicator()
        }
    }

    // Toggle the halo color of the default LocationIndicator.
    private fun togglehaloColorButtonClicked() {
        // Toggle state.
        isCustomHaloColor = !isCustomHaloColor;
        setSelectedHaloColor()
    }

    private fun setSelectedHaloColor() {
        if (isCustomHaloColor) {
            val customHaloColor = Color(255f, 255f, 0f, 0.30f)
            defaultLocationIndicator.setHaloColor(defaultLocationIndicator.locationIndicatorStyle, customHaloColor);
            customLocationIndicator.setHaloColor(customLocationIndicator.locationIndicatorStyle, customHaloColor);
        } else {
            defaultLocationIndicator.setHaloColor(defaultLocationIndicator.locationIndicatorStyle, defaultHaloColor);
            customLocationIndicator.setHaloColor(customLocationIndicator.locationIndicatorStyle, defaultHaloColor);
        }
    }

    private fun switchToPedestrianLocationIndicator() {
        if (isDefaultLocationIndicator) {
            defaultLocationIndicator?.enable(mapView!!)
            defaultLocationIndicator?.setLocationIndicatorStyle(IndicatorStyle.PEDESTRIAN)
            customLocationIndicator?.disable()
        } else {
            defaultLocationIndicator?.disable()
            customLocationIndicator?.enable(mapView!!)
            customLocationIndicator?.setLocationIndicatorStyle(IndicatorStyle.PEDESTRIAN)
        }

        // Set last location from LocationSimulator.
        defaultLocationIndicator?.updateLocation(getLastKnownLocation())
        customLocationIndicator?.updateLocation(getLastKnownLocation())

        setSelectedHaloColor()
    }

    private fun switchToNavigationLocationIndicator() {
        if (isDefaultLocationIndicator) {
            // By default, the VisualNavigator adds a LocationIndicator on its own.
            // This can be kept by calling visualNavigator.customLocationIndicator = nil
            // However, here we want to be able to customize the halo for the default location indicator.
            // Therefore, we still need to set our own instance to the VisualNavigator.
            customLocationIndicator.disable()
            defaultLocationIndicator.enable(mapView!!)
            defaultLocationIndicator.locationIndicatorStyle = IndicatorStyle.NAVIGATION
            visualNavigator?.customLocationIndicator = defaultLocationIndicator

        } else {
            defaultLocationIndicator.disable()
            customLocationIndicator.enable(mapView!!)
            customLocationIndicator.locationIndicatorStyle = IndicatorStyle.NAVIGATION
            visualNavigator?.customLocationIndicator = customLocationIndicator

            // Note that the type of the LocationIndicator is taken from the route's TransportMode.
            // It cannot be overridden during guidance.
            // During tracking mode (not shown in this app) you can specify the marker type via:
            // visualNavigator.setTrackingTransportMode(TransportMode.PEDESTRIAN);
        }

        // By default, during navigation the location of the indicator is controlled by the VisualNavigator.

        setSelectedHaloColor()
    }

    private fun getLastKnownLocation(): Location {
        if (lastKnownLocation == null) {
            // A LocationIndicator is intended to mark the user's current location,
            // including a bearing direction.
            // For testing purposes, we create below a Location object. Usually, you want to get this from
            // a GPS sensor instead. Check the Positioning example app for this.
            val location = Location(routeStartGeoCoordinates)
            location.time = Date()
            location.horizontalAccuracyInMeters = defaultHaloAccurarcyInMeters
            return location
        }
        // This location is taken from the LocationSimulator that provides locations along the route.
        return lastKnownLocation!!
    }

    // Animate to custom guidance perspective, centered on start location of route.
    private fun animateToRouteStart(route: Route) {
        // The first coordinate marks the start location of the route.
        val startOfRoute = route.geometry.vertices[0]
        val geoCoordinatesUpdate = GeoCoordinatesUpdate(startOfRoute)

        val bearingInDegrees: Double? = null
        val orientationUpdate = GeoOrientationUpdate(bearingInDegrees, cameraTiltInDegrees)
        val mapMeasureZoom = MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, cameraDistanceInMeters)

        val bowFactor = 1.0
        val animation = MapCameraAnimationFactory.flyTo(
            geoCoordinatesUpdate, orientationUpdate, mapMeasureZoom, bowFactor, Duration.ofSeconds(3)
        )

        mapView!!.camera.startAnimation(animation, object : AnimationListener {
            override fun onAnimationStateChanged(animationState: AnimationState) {
                if (animationState === AnimationState.COMPLETED
                    || animationState === AnimationState.CANCELLED
                ) {
                    startGuidance(route)
                }
            }
        })
    }

    private fun animateToDefaultMapPerspective() {
        val targetLocation = mapView!!.camera.state.targetCoordinates
        val geoCoordinatesUpdate = GeoCoordinatesUpdate(targetLocation)

        // By setting null we keep the current bearing rotation of the map.
        val bearingInDegrees: Double? = null
        val tiltInDegrees = 0.0
        val orientationUpdate = GeoOrientationUpdate(bearingInDegrees, tiltInDegrees)

        val mapMeasureZoom = MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, DISTANCE_IN_METERS)
        val bowFactor = 1.0
        val animation = MapCameraAnimationFactory.flyTo(
            geoCoordinatesUpdate, orientationUpdate, mapMeasureZoom, bowFactor, Duration.ofSeconds(3)
        )
        mapView!!.camera.startAnimation(animation)
    }

    private fun startGuidance(route: Route) {
        if (visualNavigator?.isRendering() == true) {
            return
        }

        // Set the route and maneuver arrow color.
        customizeVisualNavigatorColors()

        // Set custom guidance perspective.
        customizeGuidanceView()

        // This enables a navigation view and adds a LocationIndicator.
        visualNavigator?.startRendering(mapView!!)

        // Note: By default, when VisualNavigator starts rendering, a default LocationIndicator is added
        // by the HERE SDK automatically.
        visualNavigator?.customLocationIndicator = customLocationIndicator
        switchToNavigationLocationIndicator()

        // Set a route to follow. This leaves tracking mode.
        visualNavigator?.setRoute(route)

        // This app does not use real location updates. Instead it provides location updates based
        // on the geographic coordinates of a route using HERE SDK's LocationSimulator.
        startRouteSimulation(route)
    }

    private fun stopGuidance() {
        visualNavigator?.stopRendering()

        if (locationSimulator != null) {
            locationSimulator?.stop()
        }

        // Note: By default, when VisualNavigator stops rendering, no LocationIndicator is visible.
        switchToPedestrianLocationIndicator()

        animateToDefaultMapPerspective()
    }

    private fun customizeVisualNavigatorColors() {
        val routeAheadColor: Color = Color.valueOf(android.graphics.Color.BLUE)
        val routeBehindColor: Color = Color.valueOf(android.graphics.Color.RED)
        val routeAheadOutlineColor: Color = Color.valueOf(android.graphics.Color.YELLOW)
        val routeBehindOutlineColor: Color = Color.valueOf(android.graphics.Color.DKGRAY)
        val maneuverArrowColor: Color = Color.valueOf(android.graphics.Color.GREEN)

        val visualNavigatorColors = VisualNavigatorColors.dayColors()
        val routeProgressColors = RouteProgressColors(
            routeAheadColor,
            routeBehindColor,
            routeAheadOutlineColor,
            routeBehindOutlineColor
        )

        // Sets the color used to draw maneuver arrows.
        visualNavigatorColors.setManeuverArrowColor(maneuverArrowColor)
        // Sets route color for a single transport mode. Other modes are kept using defaults.
        visualNavigatorColors.setRouteProgressColors(SectionTransportMode.CAR, routeProgressColors)
        // Sets the adjusted colors for route progress and maneuver arrows based on the day color scheme.
        visualNavigator?.setColors(visualNavigatorColors)
    }

    private fun customizeGuidanceView() {
        val cameraBehavior = FixedCameraBehavior()
        // Set custom zoom level and tilt.
        cameraBehavior.cameraDistanceInMeters = cameraDistanceInMeters
        cameraBehavior.cameraTiltInDegrees = cameraTiltInDegrees
        // Disable North-Up mode by setting null. Enable North-up mode by setting Double.valueOf(0).
        // By default, North-Up mode is disabled.
        cameraBehavior.cameraBearingInDegrees = null
        cameraBehavior.normalizedPrincipalPoint = Anchor2D(0.5, 0.5)

        // The CameraBehavior can be updated during guidance at any time as often as desired.
        // Alternatively, use DynamicCameraBehavior for auto-zoom.
        visualNavigator?.setCameraBehavior(cameraBehavior)
    }

    private val myLocationListener: LocationListener = object : LocationListener {
        override fun onLocationUpdated(location: Location) {
            // By default, accuracy is nil during simulation, but we want to customize the halo,
            // so we hijack the location object and add an accuracy value.
            val updatedLocation = addHorizontalAccuracy(location)
            // Feed location data into the VisualNavigator.
            visualNavigator?.onLocationUpdated(updatedLocation)
            lastKnownLocation = updatedLocation
        }
    }

    private fun addHorizontalAccuracy(simulatedLocation: Location): Location {
        val location = Location(simulatedLocation.coordinates)
        location.time = simulatedLocation.time
        location.bearingInDegrees = simulatedLocation.bearingInDegrees
        location.horizontalAccuracyInMeters = defaultHaloAccurarcyInMeters
        return location
    }

    private fun startRouteSimulation(route: Route) {
        locationSimulator?.stop()

        try {
            // Provides fake GPS signals based on the route geometry.
            locationSimulator = LocationSimulator(route, LocationSimulatorOptions())
        } catch (e: InstantiationErrorException) {
            throw java.lang.RuntimeException("Initialization of LocationSimulator failed: " + e.error.name)
        }

        locationSimulator?.listener = myLocationListener
        locationSimulator?.start()
    }

    override fun onPause() {
        mapView?.onPause()
        super.onPause()
    }

    override fun onResume() {
        mapView?.onResume()
        super.onResume()
    }

    override fun onDestroy() {
        mapView?.onDestroy()
        disposeHERESDK()
        super.onDestroy()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        mapView?.onSaveInstanceState(outState)
        super.onSaveInstanceState(outState)
    }

    private fun disposeHERESDK() {
        // Free HERE SDK resources before the application shuts down.
        // Usually, this should be called only on application termination.
        // Afterwards, the HERE SDK is no longer usable unless it is initialized again.
        SDKNativeEngine.getSharedInstance()?.dispose()
        // For safety reasons, we explicitly set the shared instance to null to avoid situations,
        // where a disposed instance is accidentally reused.
        SDKNativeEngine.setSharedInstance(null)
    }

    private companion object {
        private val TAG = MainActivity::class.java.simpleName
        private const val DISTANCE_IN_METERS: Double = 1000.0
    }
}
