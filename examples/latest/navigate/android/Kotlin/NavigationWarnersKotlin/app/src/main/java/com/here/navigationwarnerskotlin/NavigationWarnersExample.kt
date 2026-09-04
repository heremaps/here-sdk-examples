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

package com.here.navigationwarnerskotlin

import android.content.Context
import android.media.RingtoneManager
import android.util.Log
import com.here.sdk.animation.Easing
import com.here.sdk.animation.EasingFunction
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.core.GeoOrientationUpdate
import com.here.sdk.core.GeoPolyline
import com.here.sdk.core.GeoPolylineDirection
import com.here.sdk.core.Point2D
import com.here.sdk.core.Rectangle2D
import com.here.sdk.core.Size2D
import com.here.sdk.core.errors.InstantiationErrorException
import com.here.sdk.mapview.MapCameraAnimationFactory
import com.here.sdk.mapview.MapCameraUpdateFactory
import com.here.sdk.mapview.MapMeasure
import com.here.sdk.mapview.MapView
import com.here.sdk.navigation.AspectRatio
import com.here.sdk.navigation.CurrentSituationLaneAssistanceView
import com.here.sdk.navigation.CurrentSituationLaneAssistanceViewListener
import com.here.sdk.navigation.CurrentSituationLaneView
import com.here.sdk.navigation.DestinationReachedListener
import com.here.sdk.navigation.JunctionViewLaneAssistance
import com.here.sdk.navigation.JunctionViewLaneAssistanceListener
import com.here.sdk.navigation.Lane
import com.here.sdk.navigation.LaneAccess
import com.here.sdk.navigation.LaneDirection
import com.here.sdk.navigation.LaneMarkings
import com.here.sdk.navigation.LaneRecommendationState
import com.here.sdk.navigation.LocationSimulator
import com.here.sdk.navigation.LocationSimulatorOptions
import com.here.sdk.navigation.ManeuverViewLaneAssistance
import com.here.sdk.navigation.ManeuverViewLaneAssistanceListener
import com.here.sdk.navigation.Milestone
import com.here.sdk.navigation.MilestoneStatus
import com.here.sdk.navigation.MilestoneStatusListener
import com.here.sdk.navigation.RoadAttributes
import com.here.sdk.navigation.RoadAttributesListener
import com.here.sdk.navigation.RoadTextsListener
import com.here.sdk.navigation.RouteDeviation
import com.here.sdk.navigation.RouteDeviationListener
import com.here.sdk.navigation.RouteProgress
import com.here.sdk.navigation.RouteProgressListener
import com.here.sdk.navigation.VisualNavigator
import com.here.sdk.navigation.WarningType
import com.here.sdk.routing.RoutingOptions
import com.here.sdk.routing.Route
import com.here.sdk.routing.RoutingEngine
import com.here.sdk.routing.Waypoint
import com.here.time.Duration
import java.util.Date
import java.util.Objects

// This class shows the various events that can be emitted during turn-by-turn navigation.
// Note that this class does not show an exhaustive list of all possible events.
// More events are shown in the "Navigation" example app.
class NavigationWarnersExample(
    private val context: Context,
    private val mapView: MapView
) {

    private val routingEngine: RoutingEngine
    private val visualNavigator: VisualNavigator
    private var locationSimulator: LocationSimulator? = null
    private var isGuidanceRunning = false
    private lateinit var currentRouteProgress: RouteProgress
    private val warnerEngineExample = WarnerEngineExample()

    init {
        try {
            visualNavigator = VisualNavigator()
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("Initialization of VisualNavigator failed: " + e.error.name)
        }

        try {
            routingEngine = RoutingEngine()
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("Initialization of RoutingEngine failed: " + e.error.name)
        }
    }

    fun isGuidanceRunning(): Boolean {
        return isGuidanceRunning
    }

    fun startGuidance(startGeoCoordinates: GeoCoordinates, destinationGeoCoordinates: GeoCoordinates) {
        routingEngine.calculateRoute(
            ArrayList(listOf(Waypoint(startGeoCoordinates), Waypoint(destinationGeoCoordinates))),
            RoutingOptions()
        ) { routingError, routes ->
            if (routingError == null && routes != null && routes.isNotEmpty()) {
                startGuidanceWithRoute(routes[0])
            } else {
                Log.e(TAG, "Route calculation error: $routingError")
            }
        }
    }

    fun stopGuidance() {
        locationSimulator?.stop()
        locationSimulator = null

        warnerEngineExample.stopWarnerEngine()
        visualNavigator.route = null
        visualNavigator.stopRendering()
        isGuidanceRunning = false
    }

    fun animateToRoutePreview(startGeoCoordinates: GeoCoordinates, destinationGeoCoordinates: GeoCoordinates) {
        val bearing = 0.0
        val tilt = 0.0
        val distanceInMeters = 1000.0 * 10.0
        // We want to show the route fitting in the map view with an additional padding of 300 pixels.
        val origin = Point2D(300.0, 300.0)
        val sizeInPixels = Size2D((mapView.width - 600).toDouble(), (mapView.height - 600).toDouble())
        val mapViewport = Rectangle2D(origin, sizeInPixels)

        val coordinatesList = listOf(startGeoCoordinates, destinationGeoCoordinates)
        val update = MapCameraUpdateFactory.lookAt(
            coordinatesList,
            mapViewport,
            GeoOrientationUpdate(bearing, tilt),
            MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, distanceInMeters)
        )
        val animation = MapCameraAnimationFactory.createAnimation(
            update,
            Duration.ofMillis(500),
            Easing(EasingFunction.IN_CUBIC)
        )
        mapView.camera.startAnimation(animation)
    }

    private fun startGuidanceWithRoute(route: Route) {
        warnerEngineExample.setupWarnerEngine(visualNavigator)
        Log.d(TAG, "Using WarnerEngine for warning handling.")
        setupListeners(visualNavigator)
        visualNavigator.startRendering(mapView)
        visualNavigator.route = route
        setupLocationSource(route)
        isGuidanceRunning = true
    }

    private fun setupLocationSource(route: Route) {
        try {
            locationSimulator = LocationSimulator(route, LocationSimulatorOptions())
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("Initialization of LocationSimulator failed: " + e.error.name)
        }

        locationSimulator?.listener = visualNavigator
        locationSimulator?.start()
    }

    private fun setupListeners(
        visualNavigator: VisualNavigator,
    ) {

        // Notifies on the progress along the route including maneuver instructions.
        visualNavigator.routeProgressListener =
            RouteProgressListener { routeProgress: RouteProgress ->
                currentRouteProgress = routeProgress

                // Contains the progress for the next maneuver ahead and the next-next maneuvers, if any.
                val nextManeuverList = routeProgress.maneuverProgress

                val nextManeuverProgress = nextManeuverList[0]
                if (nextManeuverProgress == null) {
                    Log.d(TAG, "No next maneuver available.")
                    return@RouteProgressListener
                }

                val nextManeuverIndex = nextManeuverProgress.maneuverIndex
                val nextManeuver = visualNavigator.getManeuver(nextManeuverIndex)
                    ?: // Should never happen as we retrieved the next maneuver progress above.
                    return@RouteProgressListener

                val action = nextManeuver.action

                val logMessage = "Next maneuver action: " + action.name + " in " + nextManeuverProgress.remainingDistanceInMeters + " meters."
                Log.d(TAG, logMessage)

                // Angle is null for some maneuvers like Depart, Arrive and Roundabout.
                val turnAngle = nextManeuver.turnAngleInDegrees
                if (turnAngle != null) {
                    if (turnAngle > 10) {
                        Log.d(TAG, "At the next maneuver: Make a right turn of $turnAngle degrees.")
                    } else if (turnAngle < -10) {
                        Log.d(TAG, "At the next maneuver: Make a left turn of $turnAngle degrees.")
                    } else {
                        Log.d(TAG, "At the next maneuver: Go straight.")
                    }
                }

                // Angle is null when the roundabout maneuver is not an enter, exit or keep maneuver.
                val roundaboutAngle = nextManeuver.roundaboutAngleInDegrees
                if (roundaboutAngle != null) {
                    // Note that the value is negative only for left-driving countries such as UK.
                    Log.d(TAG, "At the next maneuver: Follow the roundabout for " + roundaboutAngle + " degrees to reach the exit."
                    )
                }
            }

        // Provides lane information for the road a user is currently driving on.
        // It's supported for turn-by-turn navigation and in tracking mode.
        // It does not notify on which lane the user is currently driving on.
        visualNavigator.currentSituationLaneAssistanceViewListener =
            CurrentSituationLaneAssistanceViewListener { currentSituationLaneAssistanceView: CurrentSituationLaneAssistanceView ->
                // A list of lanes on the current road.
                val lanesList = currentSituationLaneAssistanceView.lanes
                if (lanesList.isEmpty()) {
                    Log.d("CurrentSituationLaneAssistanceView: ", "No data on lanes available.")
                } else {
                    // The lanes are sorted from left to right:
                    // The lane at index 0 is the leftmost lane adjacent to the middle of the road.
                    // The lane at the last index is the rightmost lane.
                    // This is valid for right-hand and left-hand driving countries.
                    for (i in 0..<lanesList.size) {
                        logCurrentSituationLaneViewDetails(i, lanesList.get(i))
                    }
                }
            }

        // Notifies when the destination of the route is reached.
        visualNavigator.destinationReachedListener = DestinationReachedListener {
            Log.d(TAG, "Destination reached.")
        }

        // Notifies when a waypoint on the route is reached or missed.
        visualNavigator.milestoneStatusListener =
            MilestoneStatusListener { milestone: Milestone, milestoneStatus: MilestoneStatus ->
                if (milestone.waypointIndex != null && milestoneStatus == MilestoneStatus.REACHED) {
                    Log.d(TAG, "A user-defined waypoint was reached, index of waypoint: " + milestone.waypointIndex)
                    Log.d(TAG, "Original coordinates: " + milestone.originalCoordinates)
                } else if (milestone.waypointIndex != null && milestoneStatus == MilestoneStatus.MISSED) {
                    Log.d(TAG, "A user-defined waypoint was missed, index of waypoint: " + milestone.waypointIndex)
                    Log.d(TAG, "Original coordinates: " + milestone.originalCoordinates)
                } else if (milestone.waypointIndex == null && milestoneStatus == MilestoneStatus.REACHED) {
                    // For example, when transport mode changes due to a ferry a system-defined waypoint may have been added.
                    Log.d(TAG, "A system-defined waypoint was reached at: " + milestone.mapMatchedCoordinates)
                } else if (milestone.waypointIndex == null && milestoneStatus == MilestoneStatus.MISSED) {
                    // For example, when transport mode changes due to a ferry a system-defined waypoint may have been added.
                    Log.d(TAG, "A system-defined waypoint was missed at: " + milestone.mapMatchedCoordinates)
                }
            }

        // Notifies on a possible deviation from the route.
        visualNavigator.routeDeviationListener =
            RouteDeviationListener { routeDeviation: RouteDeviation ->
                val route = visualNavigator.route
                    ?: // May happen in rare cases when route was set to null inbetween.
                    return@RouteDeviationListener
                // Get current geographic coordinates.
                val currentMapMatchedLocation = routeDeviation.currentLocation.mapMatchedLocation
                val currentGeoCoordinates = currentMapMatchedLocation?.coordinates
                    ?: routeDeviation.currentLocation.originalLocation.coordinates

                // Get last geographic coordinates on route.
                val lastGeoCoordinatesOnRoute: GeoCoordinates?
                if (routeDeviation.lastLocationOnRoute != null) {
                    val lastMapMatchedLocationOnRoute =
                        routeDeviation.lastLocationOnRoute!!.mapMatchedLocation
                    lastGeoCoordinatesOnRoute = lastMapMatchedLocationOnRoute?.coordinates
                        ?: routeDeviation.lastLocationOnRoute!!.originalLocation.coordinates
                } else {
                    Log.d(
                        TAG,
                        "User was never following the route. So, we take the start of the route instead."
                    )
                    lastGeoCoordinatesOnRoute = route.sections[0].departurePlace.originalCoordinates
                }

                val distanceInMeters = currentGeoCoordinates.distanceTo(
                    lastGeoCoordinatesOnRoute!!
                ).toInt()
                Log.d(
                    TAG,
                    "RouteDeviation in meters is $distanceInMeters"
                )

                // Now, an application needs to decide if the user has deviated far enough and
                // what should happen next: For example, you can notify the user or simply try to
                // calculate a new route. When you calculate a new route, you can, for example,
                // take the current location as new start and keep the destination - another
                // option could be to calculate a new route back to the lastMapMatchedLocationOnRoute.
                // At least, make sure to not calculate a new route every time you get a RouteDeviation
                // event as the route calculation happens asynchronously and takes also some time to
                // complete.
                // The deviation event is sent any time an off-route location is detected: It may make
                // sense to await around 3 events before deciding on possible actions.
            }

        // Notifies which lane(s) lead to the next (next) maneuvers.
        visualNavigator.maneuverViewLaneAssistanceListener =
            ManeuverViewLaneAssistanceListener { maneuverViewLaneAssistance: ManeuverViewLaneAssistance ->
                // This lane list is guaranteed to be non-empty.
                val lanes = maneuverViewLaneAssistance.lanesForNextManeuver
                logLaneRecommendations(lanes)

                val nextLanes = maneuverViewLaneAssistance.lanesForNextNextManeuver
                if (nextLanes.isNotEmpty()) {
                    Log.d(TAG, "Attention, the next next maneuver is very close.")
                    Log.d(TAG, "Please take the following lane(s) after the next maneuver: ")
                    logLaneRecommendations(nextLanes)
                }
            }

        // Notifies which lane(s) allow to follow the route.
        visualNavigator.junctionViewLaneAssistanceListener =
            JunctionViewLaneAssistanceListener { junctionViewLaneAssistance: JunctionViewLaneAssistance ->
                val lanes = junctionViewLaneAssistance.lanesForNextJunction
                if (lanes.isEmpty()) {
                    Log.d(TAG, "You have passed the complex junction.")
                } else {
                    Log.d(TAG, "Attention, a complex junction is ahead.")
                    logLaneRecommendations(lanes)
                }
            }

        // Notifies on the attributes of the current road including usage and physical characteristics.
        visualNavigator.roadAttributesListener =
            RoadAttributesListener { roadAttributes: RoadAttributes ->
                // This is called whenever any road attribute has changed.
                // If all attributes are unchanged, no new event is fired.
                // Note that a road can have more than one attribute at the same time.

                Log.d(TAG, "Received road attributes update.")

                if (roadAttributes.isBridge) {
                    // Identifies a structure that allows a road, railway, or walkway to pass over another road, railway,
                    // waterway, or valley serving map display and route guidance functionalities.
                    Log.d(TAG, "Road attributes: This is a bridge.")
                }
                if (roadAttributes.isControlledAccess) {
                    // Controlled access roads are roads with limited entrances and exits that allow uninterrupted
                    // high-speed traffic flow.
                    Log.d(TAG, "Road attributes: This is a controlled access road.")
                }
                if (roadAttributes.isDirtRoad) {
                    // Indicates whether the navigable segment is paved.
                    Log.d(TAG, "Road attributes: This is a dirt road.")
                }
                if (roadAttributes.isDividedRoad) {
                    // Indicates if there is a physical structure or painted road marking intended to legally prohibit
                    // left turns in right-side driving countries, right turns in left-side driving countries,
                    // and U-turns at divided intersections or in the middle of divided segments.
                    Log.d(TAG, "Road attributes: This is a divided road.")
                }
                if (roadAttributes.isNoThrough) {
                    // Identifies a no through road.
                    Log.d(TAG, "Road attributes: This is a no through road.")
                }
                if (roadAttributes.isPrivate) {
                    // Private identifies roads that are not maintained by an organization responsible for maintenance of
                    // public roads.
                    Log.d(TAG, "Road attributes: This is a private road.")
                }
                if (roadAttributes.isRamp) {
                    // Range is a ramp: connects roads that do not intersect at grade.
                    Log.d(TAG, "Road attributes: This is a ramp.")
                }
                if (roadAttributes.isRightDrivingSide) {
                    // Indicates if vehicles have to drive on the right-hand side of the road or the left-hand side.
                    // For example, in New York it is always true and in London always false as the United Kingdom is
                    // a left-hand driving country.
                    Log.d(
                        TAG,
                        "Road attributes: isRightDrivingSide = " + roadAttributes.isRightDrivingSide
                    )
                }
                if (roadAttributes.isRoundabout) {
                    // Indicates the presence of a roundabout.
                    Log.d(TAG, "Road attributes: This is a roundabout.")
                }
                if (roadAttributes.isTollway) {
                    // Identifies a road for which a fee must be paid to use the road.
                    Log.d(TAG, "Road attributes change: This is a road with toll costs.")
                }
                if (roadAttributes.isTunnel) {
                    // Identifies an enclosed (on all sides) passageway through or under an obstruction.
                    Log.d(TAG, "Road attributes: This is a tunnel.")
                }
            }

        // Notifies truck drivers on road restrictions ahead. Called whenever there is a change.
        // For example, there can be a bridge ahead not high enough to pass a big truck
        // or there can be a road ahead where the weight of the truck is beyond it's permissible weight.
        // This event notifies on truck restrictions in general,
        // so it will also deliver events, when the transport type was set to a non-truck transport type.
        // The given restrictions are based on the HERE database of the road network ahead.
        // Notifies whenever a border is crossed of a country and optionally, by default, also when a state
        // border of a country is crossed.
        // Notifies whenever any textual attribute of the current road changes, i.e., the current road texts differ
        // from the previous one. This can be useful during tracking mode, when no maneuver information is provided.
        visualNavigator.roadTextsListener = RoadTextsListener {
            // See getRoadName() in the "Rerouting" example app to learn how to get the current road name from the provided RoadTexts.
        }

    }

    private fun logLaneRecommendations(lanes: List<Lane>) {
        // The lane at index 0 is the leftmost lane adjacent to the middle of the road.
        // The lane at the last index is the rightmost lane.
        for ((laneNumber, lane) in lanes.withIndex()) {
            // This state is only possible if maneuverViewLaneAssistance.lanesForNextNextManeuver is not empty.
            // For example, when two lanes go left, this lanes leads only to the next maneuver,
            // but not to the maneuver after the next maneuver, while the highly recommended lane also leads
            // to this next next maneuver.
            if (lane.recommendationState == LaneRecommendationState.RECOMMENDED) {
                Log.d(
                    TAG,
                    "Lane $laneNumber leads to next maneuver, but not to the next next maneuver."
                )
            }

            // If laneAssistance.lanesForNextNextManeuver is not empty, this lane leads also to the
            // maneuver after the next maneuver.
            if (lane.recommendationState == LaneRecommendationState.HIGHLY_RECOMMENDED) {
                Log.d(
                    TAG,
                    "Lane $laneNumber leads to next maneuver and eventually to the next next maneuver."
                )
            }

            if (lane.recommendationState == LaneRecommendationState.NOT_RECOMMENDED) {
                Log.d(
                    TAG,
                    "Do not take lane $laneNumber to follow the route."
                )
            }

            logLaneDetails(laneNumber, lane)

        }
    }

    private fun logLaneDetails(laneNumber: Int, lane: Lane) {
        Log.d(TAG, "Directions for lane $laneNumber")
        // The possible lane directions are valid independent of a route.
        // If a lane leads to multiple directions and is recommended, then all directions lead to
        // the next maneuver.
        // You can use this information to visualize all directions of a lane with a set of image overlays.
        for (laneDirection in lane.directions) {
            val isLaneDirectionOnRoute = isLaneDirectionOnRoute(lane, laneDirection)
            Log.d(TAG, "LaneDirection for this lane: " + laneDirection.name)
            Log.d(TAG, "This LaneDirection is on the route: $isLaneDirectionOnRoute")
        }

        // More information on each lane is available in these bitmasks (boolean):
        // LaneType provides lane properties such as if parking is allowed or is acceleration allowed or is express lane and many more.
        val laneType = lane.type

        // LaneAccess provides which vehicle type(s) are allowed to access this lane.
        val laneAccess = lane.access
        logLaneAccess("Lane Details: ", laneNumber, laneAccess)

        // LaneMarkings indicate the visual style of dividers between lanes as visible on a road.
        val laneMarkings = lane.laneMarkings
        logLaneMarkings("Lane Details: ", laneMarkings)
    }

    private fun logCurrentSituationLaneViewDetails(laneNumber: Int, currentSituationLaneView: CurrentSituationLaneView) {
        Log.d("CurrentSituationLaneAssistanceView: ", "Directions for this CurrentSituationLaneView: $laneNumber")
        // You can use this information to visualize all directions of a lane with a set of image overlays.
        for (laneDirection in currentSituationLaneView.directions) {
            val isLaneDirectionOnRoute: Boolean = isCurrentLaneViewDirectionOnRoute(currentSituationLaneView, laneDirection)
            Log.d("CurrentSituationLaneAssistanceView: ", "LaneDirection for this CurrentSituationLaneView: " + laneDirection.name)
            // When you are on tracking mode, there is no directionsOnRoute. So, isLaneDirectionOnRoute will be false.
            Log.d("CurrentSituationLaneAssistanceView: ", "This LaneDirection is on the route: $isLaneDirectionOnRoute")
        }

        // More information on each lane is available in these bitmasks (boolean):
        // LaneType provides lane properties such as if parking is allowed or is acceleration allowed or is express lane and many more.
        val laneType = currentSituationLaneView.type

        // LaneAccess provides which vehicle type(s) are allowed to access this lane.
        val laneAccess = currentSituationLaneView.access
        logLaneAccess("CurrentSituationLaneAssistanceView: ", laneNumber, laneAccess)

        // LaneMarkings indicate the visual style of dividers between lanes as visible on a road.
        val laneMarkings = currentSituationLaneView.laneMarkings
        logLaneMarkings("CurrentSituationLaneAssistanceView: ", laneMarkings)
    }

    private fun logLaneMarkings(TAG: String, laneMarkings: LaneMarkings) {
        if (laneMarkings.centerDividerMarker != null) {
            // A CenterDividerMarker specifies the line type used for center dividers on bidirectional roads.
            Log.d(TAG, "Center divider marker for lane " + laneMarkings.centerDividerMarker!!.value)
        } else if (laneMarkings.laneDividerMarker != null) {
            // A LaneDividerMarker specifies the line type of driving lane separators present on a road.
            // It indicates the lane separator on the right side of the
            // specified lane in the lane driving direction for right-side driving countries.
            // For left-sided driving countries the it is indicating the
            // lane separator on the left side of the specified lane in the lane driving direction.
            Log.d(TAG, "Lane divider marker for lane " + laneMarkings.laneDividerMarker!!.value)
        }
    }

    // A method to check if a given LaneDirection is on route or not.
    // lane.directionsOnRoute gives only those LaneDirection that are on the route.
    // When the driver is in tracking mode without following a route, this always returns false.
    private fun isLaneDirectionOnRoute(lane: Lane, laneDirection: LaneDirection): Boolean {
        return lane.directionsOnRoute.contains(laneDirection)
    }

    private fun isCurrentLaneViewDirectionOnRoute(currentSituationLaneView: CurrentSituationLaneView, laneDirection: LaneDirection): Boolean {
        return currentSituationLaneView.directionsOnRoute.contains(laneDirection)
    }

    // Returns the GeoCoordinates for an object that is located at the end of the remaining distance.
    private fun getGeocoordinatesForRemainingDistance(
        routeProgress: RouteProgress,
        remainingObjectDistnaceInMetres: Double,
        currentRoute: Route
    ): GeoCoordinates {
        val currentCCPOffsetInMetrs = getOffsetOfCCPOnRouteInMeters(routeProgress, currentRoute)

        // Calculate the offset along the route for the given object.
        val remainingDistanceOffsetInMetres =
            currentCCPOffsetInMetrs + remainingObjectDistnaceInMetres
        return getGeoCoordinatesFromOffsetInMeters(
            currentRoute.geometry,
            remainingDistanceOffsetInMetres
        )
    }

    private fun getOffsetOfCCPOnRouteInMeters(
        routeProgress: RouteProgress,
        currentRoute: Route
    ): Double {
        val totalLength = currentRoute.lengthInMeters.toDouble()
        // [SectionProgress] is guaranteed to be non-empty.
        val remainingDistance =
            routeProgress.sectionProgress[routeProgress.sectionProgress.size - 1].remainingDistanceInMeters.toDouble()
        return totalLength - remainingDistance
    }

    // Convert an offset in meters along a GeoPolyline to GeoCoordinates using the HERE SDK's coordinatesAtOffsetInMeters.
    fun getGeoCoordinatesFromOffsetInMeters(
        geoPolyline: GeoPolyline,
        offsetInMeters: Double
    ): GeoCoordinates {
        return geoPolyline.coordinatesAtOffsetInMeters(
            offsetInMeters,
            GeoPolylineDirection.FROM_BEGINNING
        )
    }

    fun toString(geoCoordinates: GeoCoordinates): String {
        return geoCoordinates.latitude.toString() + ", " + geoCoordinates.longitude
    }

    private fun logLaneAccess(TAG: String, laneNumber: Int, laneAccess: LaneAccess) {
        Log.d(TAG, "Lane access for lane $laneNumber")
        Log.d(TAG, "Automobiles are allowed on this lane: " + laneAccess.automobiles)
        Log.d(TAG, "Buses are allowed on this lane: " + laneAccess.buses)
        Log.d(TAG, "Taxis are allowed on this lane: " + laneAccess.taxis)
        Log.d(TAG, "Carpools are allowed on this lane: " + laneAccess.carpools)
        Log.d(TAG, "Pedestrians are allowed on this lane: " + laneAccess.pedestrians)
        Log.d(TAG, "Trucks are allowed on this lane: " + laneAccess.trucks)
        Log.d(TAG, "ThroughTraffic is allowed on this lane: " + laneAccess.throughTraffic)
        Log.d(TAG, "DeliveryVehicles are allowed on this lane: " + laneAccess.deliveryVehicles)
        Log.d(TAG, "EmergencyVehicles are allowed on this lane: " + laneAccess.emergencyVehicles)
        Log.d(TAG, "Motorcycles are allowed on this lane: " + laneAccess.motorcycles)
    }

    companion object {
        private val TAG: String = NavigationWarnersExample::class.java.name
    }
}
