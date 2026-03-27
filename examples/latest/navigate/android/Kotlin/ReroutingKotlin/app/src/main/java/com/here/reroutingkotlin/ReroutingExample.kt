/*
 * Copyright (C) 2019-2026 HERE Europe B.V.
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
package com.here.reroutingkotlin

import android.app.AlertDialog
import android.content.Context
import android.graphics.Bitmap
import android.util.Log
import com.here.reroutingkotlin.ui.ManeuverView
import com.here.reroutingkotlin.utils.HEREPositioningSimulator
import com.here.sdk.animation.Easing
import com.here.sdk.animation.EasingFunction
import com.here.sdk.core.Anchor2D
import com.here.sdk.core.Color
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.core.GeoOrientationUpdate
import com.here.sdk.core.Point2D
import com.here.sdk.core.Rectangle2D
import com.here.sdk.core.Size2D
import com.here.sdk.core.errors.InstantiationErrorException
import com.here.sdk.gestures.GestureState
import com.here.sdk.gestures.LongPressListener
import com.here.sdk.mapview.IconProvider
import com.here.sdk.mapview.IconProvider.IconCallback
import com.here.sdk.mapview.IconProviderAssetType
import com.here.sdk.mapview.IconProviderError
import com.here.sdk.mapview.LineCap
import com.here.sdk.mapview.MapCameraAnimationFactory
import com.here.sdk.mapview.MapCameraUpdateFactory
import com.here.sdk.mapview.MapImageFactory
import com.here.sdk.mapview.MapMarker
import com.here.sdk.mapview.MapMeasure
import com.here.sdk.mapview.MapMeasureDependentRenderSize
import com.here.sdk.mapview.MapPolyline
import com.here.sdk.mapview.MapPolyline.SolidRepresentation
import com.here.sdk.mapview.MapScheme
import com.here.sdk.mapview.MapView
import com.here.sdk.mapview.RenderSize
import com.here.sdk.mapview.RoadShieldIconProperties
import com.here.sdk.navigation.DestinationReachedListener
import com.here.sdk.navigation.ManeuverProgress
import com.here.sdk.navigation.MapMatchedLocation
import com.here.sdk.navigation.OffRoadDestinationReachedListener
import com.here.sdk.navigation.OffRoadProgress
import com.here.sdk.navigation.OffRoadProgressListener
import com.here.sdk.navigation.RouteDeviation
import com.here.sdk.navigation.RouteDeviationListener
import com.here.sdk.navigation.RouteProgress
import com.here.sdk.navigation.RouteProgressListener
import com.here.sdk.navigation.VisualNavigator
import com.here.sdk.routing.CalculateRouteCallback
import com.here.sdk.routing.RoutingOptions
import com.here.sdk.routing.Maneuver
import com.here.sdk.routing.ManeuverAction
import com.here.sdk.routing.Route
import com.here.sdk.routing.RoutingEngine
import com.here.sdk.routing.RoutingError
import com.here.sdk.routing.Span
import com.here.sdk.routing.StreetAttributes
import com.here.sdk.routing.Waypoint
import com.here.time.Duration
import java.util.Locale
import kotlin.math.roundToInt

// An example that shows how to handle rerouting during guidance alongside.
// The simulated driver will follow the black line showing on the map - this is done with
// a second route that is using additional waypoints. This route is set as
// location source for the LocationSimulator.
// This example also shows a maneuver panel with road shield icons.
class ReroutingExample(private val context: Context, private val mapView: MapView) {
    enum class RoadType {
        HIGHWAY, RURAL, URBAN
    }

    private val mapMarkers: MutableList<MapMarker> = ArrayList<MapMarker>()
    private val mapPolylines: MutableList<MapPolyline> = ArrayList<MapPolyline>()
    private val deviationWaypoints: MutableList<Waypoint> = ArrayList<Waypoint>()
    private val routingEngine: RoutingEngine

    // A route in Berlin - can be changed via longtap.
    private var startGeoCoordinates: GeoCoordinates? =
        GeoCoordinates(52.49047222554655, 13.296884483959285)
    private var destinationGeoCoordinates: GeoCoordinates? =
        GeoCoordinates(52.51384077118386, 13.255752692114996)

    // A default deviation point - multiple points can be added via longtap.
    private var defaultDeviationGeoCoordinates: GeoCoordinates? =
        GeoCoordinates(52.4925023888559, 13.296233624033844)
    private val startMapMarker: MapMarker
    private val destinationMapMarker: MapMarker
    private var changeDestination = true
    private val visualNavigator: VisualNavigator
    private val herePositioningSimulator: HEREPositioningSimulator
    private val iconProvider: IconProvider
    private var lastRoadShieldText = ""
    private var simulationSpeedFactor = 1.0
    private var lastCalculatedRoute: Route? = null
    private var lastCalculatedDeviationRoute: Route? = null
    private var isGuidance = false
    private var setDeviationPoints = false
    private var isReturningToRoute = false
    private var deviationCounter = 0
    private var previousManeuver: Maneuver? = null
    private var uiCallback: MainActivity.UICallback? = null

    init {
        val camera = mapView.camera

        // Center map in Berlin.
        val distanceInMeters = (1000 * 90).toDouble()
        val mapMeasureZoom = MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, distanceInMeters)
        camera.lookAt(GeoCoordinates(52.520798, 13.409408), mapMeasureZoom)

        try {
            routingEngine = RoutingEngine()
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("Initialization of RoutingEngine failed: " + e.error.name)
        }

        try {
            visualNavigator = VisualNavigator()
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("Initialization of VisualNavigator failed: " + e.error.name)
        }

        iconProvider = IconProvider(mapView.mapContext)

        setupListeners()

        herePositioningSimulator = HEREPositioningSimulator()

        // Add markers to indicate the currently selected starting point and destination.
        startMapMarker = addPOIMapMarker(startGeoCoordinates!!, com.here.sdk.units.core.R.drawable.poi_start)
        destinationMapMarker =
            addPOIMapMarker(destinationGeoCoordinates!!, com.here.sdk.units.core.R.drawable.poi_destination)

        // Indicate also the default deviation point - can be changed by the user via longtap.
        val deviationMapMarker =
            addPOIMapMarker(defaultDeviationGeoCoordinates!!, R.drawable.poi_deviation)
        mapMarkers.add(deviationMapMarker)

        setLongPressGestureHandler(mapView)
        showDialog("Note", "Do a long press to change start and destination coordinates.")
    }

    fun setUICallback(callback: MainActivity.UICallback) {
        uiCallback = callback
    }

    private fun setupListeners() {
        visualNavigator.routeProgressListener = object : RouteProgressListener {
            override fun onRouteProgressUpdated(routeProgress: RouteProgress) {
                val maneuverProgressList = routeProgress.maneuverProgress
                val nextManeuverProgress = maneuverProgressList[0]
                if (nextManeuverProgress == null) {
                    Log.d(TAG, "No next maneuver available.")
                    return
                }

                val maneuverDescription = parseManeuver(nextManeuverProgress)
                Log.d(TAG, "Next maneuver: $maneuverDescription")

                val nextManeuverIndex = nextManeuverProgress.maneuverIndex
                val nextManeuver = visualNavigator.getManeuver(nextManeuverIndex)

                if (previousManeuver == nextManeuver) {
                    // We are still trying to reach the next maneuver.
                    return
                }
                previousManeuver = nextManeuver

                // A new maneuver takes places. Hide the existing road shield icon, if any.
                uiCallback!!.onHideRoadShieldIcon()

                val maneuverSpan = getSpanForManeuver(visualNavigator.route!!, nextManeuver!!)
                if (maneuverSpan != null) {
                    createRoadShieldIconForSpan(maneuverSpan)
                }
            }
        }

        // Notifies on a possible deviation from the route.
        visualNavigator.routeDeviationListener = object : RouteDeviationListener {
            override fun onRouteDeviation(routeDeviation: RouteDeviation) {
                val route = visualNavigator.route
                if (route == null) {
                    // May happen in rare cases when route was set to null in-between.
                    return
                }

                // Get current geographic coordinates.
                val currentMapMatchedLocation = routeDeviation.currentLocation.mapMatchedLocation
                val currentGeoCoordinates =
                    if (currentMapMatchedLocation == null) routeDeviation.currentLocation.originalLocation.coordinates else currentMapMatchedLocation.coordinates

                // Get last geographic coordinates on route.
                val lastGeoCoordinatesOnRoute: GeoCoordinates?
                if (routeDeviation.lastLocationOnRoute != null) {
                    val lastMapMatchedLocationOnRoute =
                        routeDeviation.lastLocationOnRoute!!.mapMatchedLocation
                    lastGeoCoordinatesOnRoute =
                        if (lastMapMatchedLocationOnRoute == null) routeDeviation.lastLocationOnRoute!!.originalLocation.coordinates else lastMapMatchedLocationOnRoute.coordinates
                } else {
                    Log.d(
                        TAG,
                        "User was never following the route. So, we take the start of the route instead."
                    )
                    lastGeoCoordinatesOnRoute =
                        route.sections[0].departurePlace.originalCoordinates
                }

                val distanceInMeters =
                    currentGeoCoordinates.distanceTo(lastGeoCoordinatesOnRoute!!).toInt()
                Log.d(TAG, "RouteDeviation in meters is $distanceInMeters")

                // Decide if rerouting should happen and if yes, then return to the original route.
                handleRerouting(
                    routeDeviation,
                    distanceInMeters,
                    currentGeoCoordinates,
                    currentMapMatchedLocation
                )
            }
        }

        // Notifies when the destination of the route is reached.
        visualNavigator.destinationReachedListener = object : DestinationReachedListener {
            override fun onDestinationReached() {
                if (lastCalculatedRoute == null) {
                    // A new route is calculated, drop out.
                    return
                }

                val lastSection = lastCalculatedRoute!!.sections[lastCalculatedRoute!!.sections.size - 1]
                if (lastSection.arrivalPlace.isOffRoad()) {
                    Log.d(TAG, "End of navigable route reached.")
                    val message1 = "Your destination is off-road."
                    val message2 = "Follow the dashed line with caution."
                    // Note that for this example we inform the user via UI.
                    uiCallback!!.onManeuverEvent(ManeuverAction.ARRIVE, message1, message2)
                } else {
                    Log.d(TAG, "Destination reached.")
                    val distanceText = "0 m"
                    val message = "You have reached your destination."
                    uiCallback!!.onManeuverEvent(ManeuverAction.ARRIVE, distanceText, message)
                }
            }
        }

        // Enable off-road visualization (if any) with a dotted straight-line
        // between the map-matched and the original destination (which is off-road).
        // Note that the color of the dashed line can be customized, if desired.
        // The line will not be rendered if the destination is not off-road.
        // By default, this is enabled.
        visualNavigator.isOffRoadDestinationVisible = true

        // Notifies on the progress when heading towards an off-road destination.
        // Off-road progress events will be sent only after the user has reached
        // the map-matched destination and the original destination is off-road.
        // Note that when a location cannot be map-matched to a road, then it is considered
        // to be off-road.
        visualNavigator.offRoadProgressListener = object : OffRoadProgressListener {
            override fun onOffRoadProgressUpdated(offRoadProgress: OffRoadProgress) {
                val distanceText =
                    convertDistance(offRoadProgress.remainingDistanceInMeters.toDouble())
                // Bearing of the destination compared to the user's current position.
                // The bearing angle indicates the direction into which the user should walk in order
                // to reach the off-road destination - when the device is held up in north-up direction.
                // For example, when the top of the screen points to true north, then 180° means that
                // the destination lies in south direction. 315° would mean the user has to head north-west, and so on.
                val message =
                    "Direction of your destination: " + offRoadProgress.bearingInDegrees.roundToInt() + "°"
                uiCallback!!.onManeuverEvent(ManeuverAction.ARRIVE, distanceText, message)
            }
        }

        // Notifies when the off-road destination of the route has been reached (if any).
        visualNavigator.offRoadDestinationReachedListener = object :
            OffRoadDestinationReachedListener {
            override fun onOffRoadDestinationReached() {
                Log.d(TAG, "Off-road destination reached.")
                val distanceText = "0 m"
                val message = "You have reached your off-road destination."
                uiCallback!!.onManeuverEvent(ManeuverAction.ARRIVE, distanceText, message)
            }
        }

        // For more warners and events during guidance, please check the Navigation example app, available on GitHub.
    }

    private fun handleRerouting(
        routeDeviation: RouteDeviation,
        distanceInMeters: Int,
        currentGeoCoordinates: GeoCoordinates,
        currentMapMatchedLocation: MapMatchedLocation?
    ) {
        // Counts the number of received deviation events. When the user is following a route, no deviation
        // event will occur.
        // It is recommended to await at least 3 deviation events before deciding on an action.
        deviationCounter++

        if (isReturningToRoute) {
            // Rerouting is ongoing.
            Log.d(TAG, "Rerouting is ongoing ...")
            return
        }

        // When user has deviated more than distanceThresholdInMeters. Now we try to return to the original route.
        val distanceThresholdInMeters = 50
        if (distanceInMeters > distanceThresholdInMeters && deviationCounter >= 3) {
            isReturningToRoute = true

            // Use current location as new starting point for the route.
            val newStartingPoint = Waypoint(currentGeoCoordinates)

            // Improve the route calculation by setting the heading direction.
            if (currentMapMatchedLocation != null && currentMapMatchedLocation.bearingInDegrees != null) {
                newStartingPoint.headingInDegrees = currentMapMatchedLocation.bearingInDegrees
            }

            // In general, the return.to-route algorithm will try to find the fastest way back to the original route,
            // but it will also respect the distance to the destination. The new route will try to preserve the shape
            // of the original route if possible and it will use the same route options.
            // When the user can now reach the destination faster than with the previously chosen route, a completely new
            // route is calculated.
            Log.d(TAG, "Rerouting: Calculating a new route.")
            routingEngine.returnToRoute(
                lastCalculatedRoute!!,
                newStartingPoint,
                routeDeviation.lastTraveledSectionIndex,
                routeDeviation.traveledDistanceOnLastSectionInMeters,
                CalculateRouteCallback { routingError: RoutingError?, list: List<Route?>? ->
                    // For simplicity, we use the same route handling.
                    // The previous route will be still visible on the map for reference.
                    handleRouteResults(routingError, list!!)
                    // Instruct the navigator to follow the calculated route (which will be the new one if no error occurred).
                    visualNavigator.route = lastCalculatedRoute
                    // Reset flag and counter.
                    isReturningToRoute = false
                    deviationCounter = 0
                    Log.d(TAG, "Rerouting: New route set.")
                })
        }
    }

    private fun parseManeuver(nextManeuverProgress: ManeuverProgress): String {
        val nextManeuverIndex = nextManeuverProgress.maneuverIndex
        val nextManeuver = visualNavigator.getManeuver(nextManeuverIndex)

        if (nextManeuver == null) {
            // Should never happen.
            return "Error: No next maneuver."
        }

        val action = nextManeuver.action
        val roadName = getRoadName(nextManeuver, visualNavigator.route!!)
        val distanceText =
            convertDistance(nextManeuverProgress.remainingDistanceInMeters.toDouble())
        val maneuverText = action.name + " on " + roadName + " in " + distanceText

        // Notify UI to show the next maneuver data.
        uiCallback!!.onManeuverEvent(action, distanceText, roadName)

        return maneuverText
    }

    // Converts meters to a readable distance text with meters of kilometers:
    // Less than 1000 meters -> m.
    // Between 1 km and 20 km -> km with one digit after comma.
    // Greater than 20 km -> km.
    fun convertDistance(meters: Double): String {
        if (meters < 1000) {
            // Convert meters to meters.
            return String.format("%.0f m", meters)
        } else if (meters >= 1000 && meters <= 20000) {
            // Convert meters to kilometers with one digit rounded.
            val kilometers = meters / 1000
            return String.format("%.1f km", kilometers)
        } else {
            // Convert meters to kilometers rounded without comma.
            val kilometers = (meters / 1000).roundToInt()
            return "$kilometers km"
        }
    }

    private fun getRoadName(maneuver: Maneuver, route: Route): String {
        val currentRoadTexts = maneuver.roadTexts
        val nextRoadTexts = maneuver.nextRoadTexts

        val currentRoadName = currentRoadTexts.names.getDefaultValue()
        val currentRoadNumber = currentRoadTexts.numbersWithDirection.getDefaultValue()
        val nextRoadName = nextRoadTexts.names.getDefaultValue()
        val nextRoadNumber = nextRoadTexts.numbersWithDirection.getDefaultValue()

        var roadName = if (nextRoadName == null) nextRoadNumber else nextRoadName

        // On highways, we want to show the highway number instead of a possible road name,
        // while for inner city and urban areas road names are preferred over road numbers.
        if (getRoadType(maneuver, route) == RoadType.HIGHWAY) {
            roadName = if (nextRoadNumber == null) nextRoadName else nextRoadNumber
        }

        if (maneuver.action == ManeuverAction.ARRIVE) {
            // We are approaching the destination, so there's no next road.
            roadName = if (currentRoadName == null) currentRoadNumber else currentRoadName
        }

        if (roadName == null) {
            // Happens only in rare cases, when also the fallback is null.
            roadName = "unnamed road"
        }

        return roadName
    }

    // Determines the road type for a given maneuver based on street attributes.
    // Returns the road type classification (HIGHWAY, URBAN or RURAL).
    private fun getRoadType(maneuver: Maneuver, route: Route): RoadType {
        val sectionOfManeuver = route.sections[maneuver.sectionIndex]
        val spansInSection = sectionOfManeuver.spans

        // If attributes list is empty then the road type is rural.
        if (spansInSection.isEmpty()) {
            return RoadType.RURAL
        }

        val maneuverSpan: Span

        // Arrive maneuvers are placed after the last span of the route
        // and the span index for them would be greater than the span's list size.
        if (maneuver.action == ManeuverAction.ARRIVE) {
            maneuverSpan = spansInSection[spansInSection.size - 1]
        } else {
            maneuverSpan = spansInSection[maneuver.spanIndex]
        }

        val streetAttributes = maneuverSpan.streetAttributes

        // If attributes list contains either CONTROLLED_ACCESS_HIGHWAY, or MOTORWAY or RAMP then the road type is highway.
        // Check for highway attributes (highest priority)
        if (streetAttributes.contains(StreetAttributes.CONTROLLED_ACCESS_HIGHWAY)
            || streetAttributes.contains(StreetAttributes.MOTORWAY)
            || streetAttributes.contains(StreetAttributes.RAMP)
        ) {
            return RoadType.HIGHWAY
        }

        // If attributes list contains BUILT_UP_AREA then the road type is urban.
        // Check for urban attributes (second priority)
        if (streetAttributes.contains(StreetAttributes.BUILT_UP_AREA)) {
            return RoadType.URBAN
        }

        // If the road type is neither urban nor highway, default to rural for all other cases.
        return RoadType.RURAL
    }

    private fun getSpanForManeuver(route: Route, maneuver: Maneuver): Span? {
        val sectionOfManeuver = route.sections[maneuver.sectionIndex]
        val spansInSection = sectionOfManeuver.spans

        // The last maneuver is located on the last span.
        // Note: Its offset points to the last GeoCoordinates of the route's polyline:
        // maneuver.getOffset() = sectionOfManeuver.getGeometry().vertices.size() - 1.
        if (maneuver.action == ManeuverAction.ARRIVE) {
            return spansInSection[spansInSection.size - 1]
        }

        val indexOfManeuverInSection = maneuver.offset
        for (span in spansInSection) {
            // A maneuver always lies on the first point of a span. Except for the
            // the destination that is located somewhere on the last span (see above).
            val firstIndexOfSpanInSection = span.sectionPolylineOffset
            if (firstIndexOfSpanInSection >= indexOfManeuverInSection) {
                return span
            }
        }

        // Should never happen.
        return null
    }

    private fun createRoadShieldIconForSpan(span: Span) {
        if (span.roadNumbers.items.isEmpty()) {
            // Road shields are only provided for roads that have route numbers such as US-101 or A100.
            // Many streets in a city like "Invalidenstr." have no route number.
            return
        }

        // For simplicity, we use the 1st item as fallback. There can be more numbers you can pick per desired language.
        var localizedRoadNumber = span.roadNumbers.items[0]
        val desiredLocale = Locale.US
        for (roadNumber in span.roadNumbers.items) {
            if (localizedRoadNumber.localizedNumber.locale === desiredLocale) {
                localizedRoadNumber = roadNumber
            }
        }

        // The route type indicates if this is a major road or not.
        val routeType = localizedRoadNumber.routeType
        // The text that should be shown on the road shield.
        val shieldText = span.getShieldText(localizedRoadNumber)
        // This text is used to additionally determine the road shield's visuals.
        val routeNumberName = localizedRoadNumber.localizedNumber.text

        if (lastRoadShieldText == shieldText) {
            // It looks like this shield was already created before, so we opt out.
            return
        }

        lastRoadShieldText = shieldText

        // Most icons can be created even if some properties are empty.
        // If countryCode is empty, then this will result in a IconProviderError.ICON_NOT_FOUND. Practically,
        // the country code should never be null, unless when there is a very rare data issue.
        val countryCode = if (span.countryCode == null) "" else span.countryCode
        val stateCode = if (span.stateCode == null) "" else span.stateCode

        val roadShieldIconProperties =
            RoadShieldIconProperties(
                routeType,
                countryCode!!,
                stateCode!!,
                routeNumberName,
                shieldText
            )

        // Set the desired constraints. The icon will fit in while preserving its aspect ratio.
        val widthConstraintInPixels: Long = ManeuverView.ROAD_SHIELD_DIM_CONSTRAINTS_IN_PIXELS.toLong()
        val heightConstraintInPixels: Long = ManeuverView.ROAD_SHIELD_DIM_CONSTRAINTS_IN_PIXELS.toLong()

        // Create the icon offline. Several icons could be created in parallel, but in reality, the road shield
        // will not change very quickly, so that a previous icon will not be overwritten by a parallel call.
        iconProvider.createRoadShieldIcon(
            roadShieldIconProperties,  // A road shield icon can be created to match visually the currently selected map scheme.
            MapScheme.NORMAL_DAY,
            IconProviderAssetType.UI,
            widthConstraintInPixels,
            heightConstraintInPixels, object : IconCallback {
                override fun onCreateIconReply(
                    bitmap: Bitmap?,
                    description: String?,
                    iconProviderError: IconProviderError?
                ) {
                    if (iconProviderError != null) {
                        Log.d(TAG, "Cannot create road shield icon: " + iconProviderError.name)
                        return
                    }

                    // If iconProviderError is null, it is guaranteed that bitmap and description are not null.
                    val roadShieldIcon = bitmap

                    // A further description of the generated icon, such as "Federal" or "Autobahn".
                    val shieldDescription = description
                    Log.d(TAG, "New road shield icon: $shieldDescription")

                    // An implementation can now decide to show the icon, for example, together with the
                    // next maneuver actions.
                    uiCallback!!.onRoadShieldEvent(roadShieldIcon)
                }
            })
    }

    // Use a LongPress handler to define start / destination waypoints.
    private fun setLongPressGestureHandler(mapView: MapView) {
        mapView.gestures.longPressListener =
            LongPressListener { gestureState: GestureState?, touchPoint: Point2D? ->
                val geoCoordinates = mapView.viewToGeoCoordinates(touchPoint!!)
                if (geoCoordinates == null) {
                    showDialog("Note", "Invalid GeoCoordinates.")
                }
                if (gestureState == GestureState.BEGIN) {
                    if (setDeviationPoints) {
                        defaultDeviationGeoCoordinates = null
                        val mapMarker = addPOIMapMarker(geoCoordinates!!, R.drawable.poi_deviation)
                        mapMarkers.add(mapMarker)
                        deviationWaypoints.add(Waypoint(geoCoordinates))
                    } else {
                        // Set new route start or destination geographic coordinates based on long press location.
                        if (changeDestination) {
                            destinationGeoCoordinates = geoCoordinates
                            destinationMapMarker.coordinates = geoCoordinates!!
                        } else {
                            startGeoCoordinates = geoCoordinates
                            startMapMarker.coordinates = geoCoordinates!!
                        }
                        // Toggle the marker that should be updated on next long press.
                        changeDestination = !changeDestination
                    }
                }
            }
    }

    // Get the waypoint list using the last two long press points and optional deviation waypoints.
    private fun getCurrentWaypoints(insertDeviationWaypoints: Boolean): List<Waypoint> {
        val startWaypoint = Waypoint(startGeoCoordinates!!)
        val destinationWaypoint = Waypoint(destinationGeoCoordinates!!)
        var waypoints: MutableList<Waypoint> = ArrayList<Waypoint>()

        if (insertDeviationWaypoints) {
            waypoints.add(startWaypoint)
            // If no custom deviation waypoints have been set, we use initially the default one.
            if (defaultDeviationGeoCoordinates != null) {
                waypoints.add(Waypoint(defaultDeviationGeoCoordinates!!))
            }
            for (wp in deviationWaypoints) {
                waypoints.add(wp)
            }
            waypoints.add(destinationWaypoint)
        } else {
            waypoints =
                java.util.ArrayList<Waypoint>(listOf<Waypoint?>(startWaypoint, destinationWaypoint))
        }

        // Log used waypoints for reference.
        Log.d(
            TAG,
            "Start Waypoint: " + startWaypoint.coordinates.latitude + ", " + startWaypoint.coordinates.longitude
        )
        for (wp in deviationWaypoints) {
            Log.d(
                TAG,
                "Deviation Waypoint: " + wp.coordinates.latitude + ", " + wp.coordinates.longitude
            )
        }
        Log.d(
            TAG,
            "Destination Waypoint: " + destinationWaypoint.coordinates.latitude + ", " + destinationWaypoint.coordinates.longitude
        )

        return waypoints
    }

    fun onDefineDeviationPointsButtonClicked() {
        setDeviationPoints = !setDeviationPoints
        if (setDeviationPoints) {
            showDialog(
                "Note", "Set deviation waypoints now. " +
                        "These points will become stopovers to shape the route that is used for location simulation." +
                        "The original (blue) route will be kept as before for use with the VisualNavigator." +
                        "Click button again to stop setting deviation waypoints."
            )
        } else {
            showDialog("Note", "Stopped setting deviation waypoints.")
        }
    }

    fun onShowRouteButtonClicked() {
        lastCalculatedRoute = null
        lastCalculatedDeviationRoute = null

        calculateRouteForUseWithVisualNavigator()
        calculateDeviationRouteForUseLocationSimulator()
    }

    private fun calculateRouteForUseWithVisualNavigator() {
        val insertDeviationWaypoints = false
        val routingOptions = RoutingOptions()
        // A route handle is neccessary for rerouting.
        routingOptions.routeOptions.enableRouteHandle = true
        routingEngine.calculateRoute(
            getCurrentWaypoints(insertDeviationWaypoints),
            routingOptions,
            CalculateRouteCallback { routingError: RoutingError?, routes: List<Route?>? ->
                handleRouteResults(routingError, routes!!)
            })
    }

    private fun calculateDeviationRouteForUseLocationSimulator() {
        if (deviationWaypoints.isEmpty() && defaultDeviationGeoCoordinates == null) {
            // No deviation waypoints have been set by user.
            return
        }

        // Use deviationWaypoints to create a second route and set it as source for LocationSimulator.
        val insertDeviationWaypoints = true
        routingEngine.calculateRoute(
            getCurrentWaypoints(insertDeviationWaypoints),
            RoutingOptions(),
            CalculateRouteCallback { routingError: RoutingError?, routes: List<Route>? ->
                handleDeviationRouteResults(routingError, routes!!)
            })
    }

    fun onStartStopButtonClicked() {
        if (lastCalculatedRoute == null) {
            showDialog("Note", "Show a route first.")
            return
        }

        isGuidance = !isGuidance
        if (isGuidance) {
            // Start guidance.
            visualNavigator.route = lastCalculatedRoute
            visualNavigator.startRendering(mapView)

            // If we do not have a deviation route set for testing, we simply follow the route.
            val sourceForLocationSimulation =
                if (lastCalculatedDeviationRoute == null) lastCalculatedRoute else lastCalculatedDeviationRoute

            // Note that we provide location updates based on route that deviates from the original route,
            // based on the set deviation waypoints by user (if provided).
            // Note: This is for testing puproses only.
            herePositioningSimulator.setSpeedFactor(simulationSpeedFactor)
            herePositioningSimulator.startLocating(visualNavigator, sourceForLocationSimulation!!)
        } else {
            // Stop guidance.
            visualNavigator.route = null
            previousManeuver = null
            visualNavigator.stopRendering()
            herePositioningSimulator.stopLocating()
            uiCallback!!.onHideManeuverPanel()
            untiltUnrotateMap()
        }
    }

    private fun untiltUnrotateMap() {
        val bearingInDegress = 0.0
        val tiltInDegress = 0.0
        mapView.camera
            .setOrientationAtTarget(GeoOrientationUpdate(bearingInDegress, tiltInDegress))
    }

    fun onSpeedButtonClicked() {
        // Toggle simulation speed factor.
        if (simulationSpeedFactor == 1.0) {
            simulationSpeedFactor = 8.0
        } else {
            simulationSpeedFactor = 1.0
        }

        showDialog(
            "Note", "Changed simulation speed factor to " + simulationSpeedFactor +
                    ". Start again to use the new value."
        )
    }

    private fun handleRouteResults(routingError: RoutingError?, routes: List<Route?>) {
        if (routingError != null) {
            showDialog("Error while calculating a route: ", routingError.toString())
            return
        }

        // Reset previous text, if any.
        lastRoadShieldText = ""

        // When routingError is nil, routes is guaranteed to contain at least one route.
        lastCalculatedRoute = routes[0]

        val routeColor = Color.valueOf(0f, 0.6f, 1f, 1f) // RGBA
        val routeWidthInPixels = 30
        showRouteOnMap(lastCalculatedRoute!!, routeColor, routeWidthInPixels)
    }

    private fun handleDeviationRouteResults(
        routingError: RoutingError?,
        routes: List<Route?>
    ) {
        if (routingError != null) {
            showDialog("Error while calculating a deviation route: ", routingError.toString())
            return
        }

        // When routingError is nil, routes is guaranteed to contain at least one route.
        lastCalculatedDeviationRoute = routes[0]

        val blackColor = Color.valueOf(0f, 0f, 0f, 1f) // RGBA
        val routeWidthInPixels = 15
        showRouteOnMap(lastCalculatedDeviationRoute!!, blackColor, routeWidthInPixels)
    }

    private fun showRouteOnMap(route: Route, color: Color, widthInPixels: Int) {
        val routeGeoPolyline = route.geometry
        var routeMapPolyline: MapPolyline? = null
        try {
            routeMapPolyline = MapPolyline(
                routeGeoPolyline, SolidRepresentation(
                    MapMeasureDependentRenderSize(RenderSize.Unit.PIXELS, widthInPixels.toDouble()),
                    color,
                    LineCap.ROUND
                )
            )
        } catch (e: MapPolyline.Representation.InstantiationException) {
            Log.e("MapPolyline Representation Exception:", e.error.name)
        } catch (e: MapMeasureDependentRenderSize.InstantiationException) {
            Log.e("MapMeasureDependentRenderSize Exception:", e.error.name)
        }
        mapView.mapScene.addMapPolyline(routeMapPolyline!!)
        mapPolylines.add(routeMapPolyline)
        animateToRoute(route)
    }

    private fun animateToRoute(route: Route) {
        // We want to show the route fitting in the map view with an additional padding of 50 pixels
        val origin = Point2D(50.0, 50.0)
        val sizeInPixels =
            Size2D((mapView.width - 100).toDouble(), (mapView.height - 100).toDouble())
        val mapViewport = Rectangle2D(origin, sizeInPixels)

        // Animate to the route within a duration of 3 seconds.
        val update = MapCameraUpdateFactory.lookAt(
            route.boundingBox,  // The animation should result in an unrotated and untilted map.
            GeoOrientationUpdate(0.0, 0.0),
            mapViewport
        )
        val animation =
            MapCameraAnimationFactory.createAnimation(
                update,
                Duration.ofMillis(2000),
                Easing(EasingFunction.OUT_SINE)
            )
        mapView.camera.startAnimation(animation)
    }

    fun onClearMapButtonClicked() {
        clearRoute()
        clearMapMarker()
        deviationWaypoints.clear()
        // Clear also the default deviation waypoint.
        defaultDeviationGeoCoordinates = null
    }

    private fun clearRoute() {
        for (mapPolyline in mapPolylines) {
            mapView.mapScene.removeMapPolyline(mapPolyline)
        }
        mapPolylines.clear()
    }

    private fun clearMapMarker() {
        for (mapMarker in mapMarkers) {
            mapView.mapScene.removeMapMarker(mapMarker)
        }
        mapMarkers.clear()
    }

    private fun addPOIMapMarker(geoCoordinates: GeoCoordinates, resourceId: Int): MapMarker {
        val mapImage = MapImageFactory.fromResource(context.resources, resourceId)
        val anchor2D = Anchor2D(0.5, 1.0)
        val mapMarker = MapMarker(geoCoordinates, mapImage, anchor2D)
        mapView.mapScene.addMapMarker(mapMarker)
        return mapMarker
    }

    private fun showDialog(title: String, message: String) {
        val builder: AlertDialog.Builder = AlertDialog.Builder(context)
        builder.setTitle(title)
        builder.setMessage(message)
        builder.show()
    }

    // Dispose the RoutingEngine instance to cancel any pending requests
    // and shut it down for proper resource cleanup.
    fun dispose() {
        routingEngine.dispose()
    }

    companion object {
        private val TAG: String = ReroutingExample::class.java.getName()
    }
}