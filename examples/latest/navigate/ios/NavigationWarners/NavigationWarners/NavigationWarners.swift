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

import heresdk
import SwiftUI

// This class combines the various events that can be emitted during turn-by-turn navigation.
// Note that this class does not show an exhaustive list of all possible events.
class NavigationWarners : CurrentSituationLaneAssistanceViewDelegate,
                               DestinationReachedDelegate,
                               MilestoneStatusDelegate,
                               RouteProgressDelegate,
                               RouteDeviationDelegate,
                               ManeuverViewLaneAssistanceDelegate,
                               JunctionViewLaneAssistanceDelegate,
                               RoadAttributesDelegate,
                               RoadTextsDelegate {

    private var visualNavigator: VisualNavigator!
    private var currentRouteProgress: RouteProgress?
    
    func setupDelegates(_ visualNavigator: VisualNavigator) {
        self.visualNavigator = visualNavigator
        
        visualNavigator.currentSituationLaneAssistanceViewDelegate = self
        visualNavigator.destinationReachedDelegate = self
        visualNavigator.routeDeviationDelegate = self
        visualNavigator.routeProgressDelegate = self
        visualNavigator.milestoneStatusDelegate = self
        visualNavigator.maneuverViewLaneAssistanceDelegate = self
        visualNavigator.junctionViewLaneAssistanceDelegate = self
        visualNavigator.roadAttributesDelegate = self
        visualNavigator.roadTextsDelegate = self
        
        setupManeuverNotificationOptions()
    }

    // Conform to RouteProgressDelegate.
    // Notifies on the progress along the route including maneuver instructions.
    func onRouteProgressUpdated(_ routeProgress: RouteProgress) {
        currentRouteProgress = routeProgress
        
        // [SectionProgress] is guaranteed to be non-empty.
        let distanceToDestination = routeProgress.sectionProgress.last!.remainingDistanceInMeters
        print("Distance to destination in meters: \(distanceToDestination)")
        let trafficDelayAhead = routeProgress.sectionProgress.last!.trafficDelay
        print("Traffic delay ahead in seconds: \(trafficDelayAhead)")

        // Contains the progress for the next maneuver ahead and the next-next maneuvers, if any.
        let nextManeuverList = routeProgress.maneuverProgress
        guard let nextManeuverProgress = nextManeuverList.first else {
            print("No next maneuver available.")
            return
        }

        let nextManeuverIndex = nextManeuverProgress.maneuverIndex
        guard let nextManeuver = visualNavigator.getManeuver(index: nextManeuverIndex) else {
            // Should never happen as we retrieved the next maneuver progress above.
            return
        }

        let action = nextManeuver.action
        let logMessage = "Next maneuver action: '\(String(describing: action))' in \(nextManeuverProgress.remainingDistanceInMeters) meters."
        print(logMessage)
    }

    // Conform to CurrentSituationLaneAssistanceViewDelegate.
    // Provides lane information for the road a user is currently driving on.
    // It's supported for turn-by-turn navigation and in tracking mode.
    // It does not notify on which lane the user is currently driving on.
    func onCurrentSituationLaneAssistanceViewUpdate(_ currentSituationLaneAssistanceView: heresdk.CurrentSituationLaneAssistanceView) {
        // A list of lanes on the current road.
        let lanesList: [CurrentSituationLaneView] = currentSituationLaneAssistanceView.lanes
        
        if (lanesList.isEmpty) {
            print("CurrentSituationLaneAssistanceView: No data on lanes available.")
        } else {
            //
            // The lanes are sorted from left to right:
            // The lane at index 0 is the leftmost lane adjacent to the middle of the road.
            // The lane at the last index is the rightmost lane.
            // This is valid for right-hand and left-hand driving countries.
            for i in 0..<lanesList.count {
                logCurrentSituationLaneViewDetails(i,lanesList[i])
            }
          }
    }

    // Conform to DestinationReachedDelegate.
    // Notifies when the destination of the route is reached.
    func onDestinationReached() {
        print("Destination reached.")
        // Guidance has stopped. Now consider to, for example,
        // switch to tracking mode or stop rendering or locating or do anything else that may
        // be useful to support your app flow.
        // If the DynamicRoutingEngine was started before, consider to stop it now.
    }

    // Conform to MilestoneStatusDelegate.
    // Notifies when a waypoint on the route is reached or missed.
    func onMilestoneStatusUpdated(milestone: Milestone, status: MilestoneStatus) {
        if milestone.waypointIndex != nil && status == MilestoneStatus.reached {
            print("A user-defined waypoint was reached, index of waypoint: \(String(describing: milestone.waypointIndex))")
            print("Original coordinates: \(String(describing: milestone.originalCoordinates))")
        } else if milestone.waypointIndex != nil && status == MilestoneStatus.missed {
            print("A user-defined waypoint was missed, index of waypoint: \(String(describing: milestone.waypointIndex))")
            print("Original coordinates: \(String(describing: milestone.originalCoordinates))")
        } else if milestone.waypointIndex == nil && status == MilestoneStatus.reached {
            // For example, when transport mode changes due to a ferry a system-defined waypoint may have been added.
            print("A system-defined waypoint was reached at: \(String(describing: milestone.mapMatchedCoordinates))")
        } else if milestone.waypointIndex == nil && status == MilestoneStatus.missed {
            // For example, when transport mode changes due to a ferry a system-defined waypoint may have been added.
            print("A system-defined waypoint was missed at: \(String(describing: milestone.mapMatchedCoordinates))")
        }
    }

    // Conform to RouteDeviationDelegate.
    // Notifies on a possible deviation from the route.
    func onRouteDeviation(_ routeDeviation: RouteDeviation) {
        guard let route = visualNavigator.route else {
            // May happen in rare cases when route was set to nil inbetween.
            return
        }

        // Get current geographic coordinates.
        var currentGeoCoordinates = routeDeviation.currentLocation.originalLocation.coordinates
        if let currentMapMatchedLocation = routeDeviation.currentLocation.mapMatchedLocation {
            currentGeoCoordinates = currentMapMatchedLocation.coordinates
        }

        // Get last geographic coordinates on route.
        var lastGeoCoordinates: GeoCoordinates?
        if let lastLocationOnRoute = routeDeviation.lastLocationOnRoute {
            lastGeoCoordinates = lastLocationOnRoute.originalLocation.coordinates
            if let lastMapMatchedLocationOnRoute = lastLocationOnRoute.mapMatchedLocation {
                lastGeoCoordinates = lastMapMatchedLocationOnRoute.coordinates
            }
        } else {
            print("User was never following the route. So, we take the start of the route instead.")
            lastGeoCoordinates = route.sections.first?.departurePlace.originalCoordinates
        }

        guard let lastGeoCoordinatesOnRoute = lastGeoCoordinates else {
            print("No lastGeoCoordinatesOnRoute found. Should never happen.")
            return
        }

        let distanceInMeters = currentGeoCoordinates.distance(to: lastGeoCoordinatesOnRoute)
        print("RouteDeviation in meters is \(distanceInMeters)")

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

    // Conform to the ManeuverViewLaneAssistanceDelegate.
    // Notifies which lane(s) lead to the next (next) maneuvers.
    func onLaneAssistanceUpdated(_ laneAssistance: ManeuverViewLaneAssistance) {
        // This lane list is guaranteed to be non-empty.
        let lanes = laneAssistance.lanesForNextManeuver
        logLaneRecommendations(lanes)

        let nextLanes = laneAssistance.lanesForNextNextManeuver
        if !nextLanes.isEmpty {
            print("Attention, the next next maneuver is very close.")
            print("Please take the following lane(s) after the next maneuver: ")
            logLaneRecommendations(nextLanes)
        }
    }

    // Conform to the JunctionViewLaneAssistanceDelegate.
    // Notfies which lane(s) allow to follow the route.
    func onLaneAssistanceUpdated(_ laneAssistance: JunctionViewLaneAssistance) {
        let lanes = laneAssistance.lanesForNextJunction
        if (lanes.isEmpty) {
            print("You have passed the complex junction.")
        } else {
            print("Attention, a complex junction is ahead.")
            logLaneRecommendations(lanes)
        }
    }

    private func logLaneRecommendations(_ lanes: [Lane]) {
        // The lane at index 0 is the leftmost lane adjacent to the middle of the road.
        // The lane at the last index is the rightmost lane.
        var laneNumber = 0
        for lane in lanes {
            // This state is only possible if laneAssistance.lanesForNextNextManeuver is not empty.
            // For example, when two lanes go left, this lanes leads only to the next maneuver,
            // but not to the maneuver after the next maneuver, while the highly recommended lane also leads
            // to this next next maneuver.
            if lane.recommendationState == .recommended {
                print("Lane \(laneNumber) leads to next maneuver, but not to the next next maneuver.")
            }

            // If laneAssistance.lanesForNextNextManeuver is not empty, this lane leads also to the
            // maneuver after the next maneuver.
            if lane.recommendationState == .highlyRecommended {
                print("Lane \(laneNumber) leads to next maneuver and eventually to the next next maneuver.")
            }

            if lane.recommendationState == .notRecommended {
                print("Do not take lane \(laneNumber) to follow the route.")
            }

            logLaneDetails(laneNumber, lane)

            laneNumber += 1
        }
    }

    func logLaneDetails(_ laneNumber: Int, _ lane: Lane) {
        print("Directions for lane \(laneNumber):")
        // The possible lane directions are valid independent of a route.
        // If a lane leads to multiple directions and is recommended, then all directions lead to
        // the next maneuver.
        // You can use this information to visualize all directions of a lane with a set of image overlays.
        for laneDirection: LaneDirection in lane.directions {
            let isLaneDirectionOnRoute = isLaneDirectionOnRoute(lane, laneDirection)
            print("LaneDirection for this lane: \(laneDirection)")
            print("This LaneDirection is on the route: \(isLaneDirectionOnRoute)")
        }

        // More information on each lane is available in these bitmasks (boolean):
        // LaneType provides lane properties such as if parking is allowed or is acceleration allowed or is express lane and many more.
        _ = lane.type
        // LaneAccess provides which vehicle type(s) are allowed to access this lane.
        logLaneAccess("Lane Details: ", laneNumber, lane.access)

        // LaneMarkings indicate the visual style of dividers between lanes as visible on a road.
        let laneMarkings = lane.laneMarkings
        logLaneMarkings("Lane Details: ", laneMarkings)
    }

    func logCurrentSituationLaneViewDetails(_ laneNumber: Int, _ currentSituationLaneView: CurrentSituationLaneView) {
        print("CurrentSituationLaneAssistanceView: Directions for CurrentSituationLaneView: \(laneNumber):")
        // You can use this information to visualize all directions of a lane with a set of image overlays.
        for laneDirection: LaneDirection in currentSituationLaneView.directions {
            let isLaneDirectionOnRoute = isCurrentSituationLaneViewDirectionOnRoute(currentSituationLaneView, laneDirection)
            print("CurrentSituationLaneAssistanceView: LaneDirection for this lane: \(laneDirection)")
            // When you are on tracking mode, there is no directionsOnRoute. So, isLaneDirectionOnRoute will be false.
            print("CurrentSituationLaneAssistanceView: This LaneDirection is on the route: \(isLaneDirectionOnRoute)")
        }

        // More information on each lane is available in these bitmasks (boolean):
        // LaneType provides lane properties such as if parking is allowed or is acceleration allowed or is express lane and many more.
        _ = currentSituationLaneView.type
        // LaneAccess provides which vehicle type(s) are allowed to access this lane.
        logLaneAccess("CurrentSituationLaneAssistanceView: ", laneNumber, currentSituationLaneView.access)

        // LaneMarkings indicate the visual style of dividers between lanes as visible on a road.
        let laneMarkings = currentSituationLaneView.laneMarkings
        logLaneMarkings("CurrentSituationLaneAssistanceView: ", laneMarkings)
    }
    
    // LaneMarkings indicate the visual style of dividers between lanes as visible on a road.
    func logLaneMarkings(_ TAG: String, _ laneMarkings: LaneMarkings) {
        if let centerDividerMarker: DividerMarker = laneMarkings.centerDividerMarker {
            // A CenterDividerMarker specifies the line type used for center dividers on bidirectional roads.
            print("\(TAG) Center divider marker for lane \(String(describing: centerDividerMarker))")
        } else if let laneDividerMarker: DividerMarker = laneMarkings.laneDividerMarker {
            // A LaneDividerMarker specifies the line type of driving lane separators present on a road.
            // It indicates the lane separator on the right side of the
            // specified lane in the lane driving direction for right-side driving countries.
            // For left-sided driving countries, it indicates the
            // lane separator on the left side of the specified lane in the lane driving direction.
            print("\(TAG) Lane divider marker for lane \(String(describing: laneDividerMarker))")
        }
    }

    func logLaneAccess(_ TAG: String, _ laneNumber: Int, _ laneAccess: LaneAccess) {
        print("\(TAG) Lane access for lane \(laneNumber).")
        print("\(TAG) Automobiles are allowed on this lane: \(laneAccess.automobiles).")
        print("\(TAG) Buses are allowed on this lane: \(laneAccess.buses).")
        print("\(TAG) Taxis are allowed on this lane: \(laneAccess.taxis).")
        print("\(TAG) Carpools are allowed on this lane: \(laneAccess.carpools).")
        print("\(TAG) Pedestrians are allowed on this lane: \(laneAccess.pedestrians).")
        print("\(TAG) Trucks are allowed on this lane: \(laneAccess.trucks).")
        print("\(TAG) ThroughTraffic is allowed on this lane: \(laneAccess.throughTraffic).")
        print("\(TAG) DeliveryVehicles are allowed on this lane: \(laneAccess.deliveryVehicles).")
        print("\(TAG) EmergencyVehicles are allowed on this lane: \(laneAccess.emergencyVehicles).")
        print("\(TAG) Motorcycles are allowed on this lane: \(laneAccess.motorcycles).")
    }

    // A method to check if a given LaneDirection is on route or not.
    // lane.directionsOnRoute gives only those LaneDirection that are on the route.
    // When the driver is in tracking mode without following a route, this always returns false.
    func isLaneDirectionOnRoute(_ lane: Lane, _ laneDirection: LaneDirection) -> Bool {
        return lane.directionsOnRoute.contains(laneDirection)
    }

    func isCurrentSituationLaneViewDirectionOnRoute(_ currentSituationLaneView: CurrentSituationLaneView, _ laneDirection: LaneDirection) -> Bool {
        return currentSituationLaneView.directionsOnRoute.contains(laneDirection)
    }
    
    // Conform to the RoadAttributesDelegate.
    // Notifies on the attributes of the current road including usage and physical characteristics.
    func onRoadAttributesUpdated(_ roadAttributes: RoadAttributes) {
        // This is called whenever any road attribute has changed.
        // If all attributes are unchanged, no new event is fired.
        // Note that a road can have more than one attribute at the same time.
        print("Received road attributes update.")

        if (roadAttributes.isBridge) {
            // Identifies a structure that allows a road, railway, or walkway to pass over another road, railway,
            // waterway, or valley serving map display and route guidance functionalities.
            print("Road attributes: This is a bridge.")
        }
        if (roadAttributes.isControlledAccess) {
            // Controlled access roads are roads with limited entrances and exits that allow uninterrupted
            // high-speed traffic flow.
            print("Road attributes: This is a controlled access road.")
        }
        if (roadAttributes.isDirtRoad) {
            // Indicates whether the navigable segment is paved.
            print("Road attributes: This is a dirt road.")
        }
        if (roadAttributes.isDividedRoad) {
            // Indicates if there is a physical structure or painted road marking intended to legally prohibit
            // left turns in right-side driving countries, right turns in left-side driving countries,
            // and U-turns at divided intersections or in the middle of divided segments.
            print("Road attributes: This is a divided road.")
        }
        if (roadAttributes.isNoThrough) {
            // Identifies a no through road.
            print("Road attributes: This is a no through road.")
        }
        if (roadAttributes.isPrivate) {
            // Private identifies roads that are not maintained by an organization responsible for maintenance of
            // public roads.
            print("Road attributes: This is a private road.")
        }
        if (roadAttributes.isRamp) {
            // Range is a ramp: connects roads that do not intersect at grade.
            print("Road attributes: This is a ramp.")
        }
        if (roadAttributes.isRightDrivingSide) {
            // Indicates if vehicles have to drive on the right-hand side of the road or the left-hand side.
            // For example, in New York it is always true and in London always false as the United Kingdom is
            // a left-hand driving country.
            print("Road attributes: isRightDrivingSide = \(roadAttributes.isRightDrivingSide)")
        }
        if (roadAttributes.isRoundabout) {
            // Indicates the presence of a roundabout.
            print("Road attributes: This is a roundabout.")
        }
        if (roadAttributes.isTollway) {
            // Identifies a road for which a fee must be paid to use the road.
            print("Road attributes change: This is a road with toll costs.")
        }
        if (roadAttributes.isTunnel) {
            // Identifies an enclosed (on all sides) passageway through or under an obstruction.
            print("Road attributes: This is a tunnel.")
        }
    }

    // Conform to RoadTextsDelegate
    // Notifies whenever any textual attribute of the current road changes, i.e., the current road texts differ
    // from the previous one. This can be useful during tracking mode, when no maneuver information is provided.
    func onRoadTextsUpdated(_ roadTexts: RoadTexts) {
        // See getRoadName() in the "Rerouting" example app to learn how to get the current road name from the provided RoadTexts.
    }

    private func setupManeuverNotificationOptions() {
        var maneuverNotificationOptions = ManeuverNotificationOptions()
        
        // Indicates whether lane recommendation should be used when generating notifications.
        maneuverNotificationOptions.enableLaneRecommendation = true
        visualNavigator.maneuverNotificationOptions = maneuverNotificationOptions
    }
    
    // Returns the GeoCoordinates for an object located at the end of the remaining distance.
    private func getGeocoordinatesForRemainingDistance(
        routeProgress: RouteProgress,
        remainingObjectDistanceInMeters: Double,
        currentRoute: Route
    ) -> GeoCoordinates {
        let currentCCPOffsetInMeters = getOffsetOfCCPOnRouteInMeters(routeProgress: routeProgress, currentRoute: currentRoute)
        
        // Calculate the offset along the route for the given object.
        let remainingDistanceOffsetInMeters = currentCCPOffsetInMeters + remainingObjectDistanceInMeters
        
        return getGeoCoordinatesFromOffsetInMeters(
            geoPolyline: currentRoute.geometry,
            offsetInMeters: remainingDistanceOffsetInMeters
        )
    }
    
    // Returns the offset of the current camera position (CCP) on the route in meters.
    private func getOffsetOfCCPOnRouteInMeters(
        routeProgress: RouteProgress,
        currentRoute: Route
    ) -> Double {
        let totalLength = Double(currentRoute.lengthInMeters)
        
        // SectionProgress is guaranteed to be non-empty.
        guard let lastSectionProgress = routeProgress.sectionProgress.last else {
            return 0.0
        }
        
        let remainingDistance = Double(lastSectionProgress.remainingDistanceInMeters)
        return totalLength - remainingDistance
    }
    
    // Converts an offset in meters along a GeoPolyline to GeoCoordinates using HERE SDK's coordinatesAtOffsetInMeters.
    private func getGeoCoordinatesFromOffsetInMeters(
        geoPolyline: GeoPolyline,
        offsetInMeters: Double
    ) -> GeoCoordinates {
        return geoPolyline.coordinatesAt(offsetInMeters: offsetInMeters, direction: .fromBeginning)
    }
    
    private func geoCoordinatesToString(_ geoCoordinates: GeoCoordinates) -> String {
        return "\(geoCoordinates.latitude), \(geoCoordinates.longitude)"
    }
}
