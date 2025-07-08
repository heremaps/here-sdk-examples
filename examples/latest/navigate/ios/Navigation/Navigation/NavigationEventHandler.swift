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

import AVFoundation
import heresdk
import SwiftUI

// This class combines the various events that can be emitted during turn-by-turn navigation.
// Note that this class does not show an exhaustive list of all possible events.
class NavigationEventHandler : NavigableLocationDelegate,
                               BorderCrossingWarningDelegate,
                               CurrentSituationLaneAssistanceViewDelegate,
                               DangerZoneWarningDelegate,
                               LowSpeedZoneWarningDelegate,
                               DestinationReachedDelegate,
                               MilestoneStatusDelegate,
                               SafetyCameraWarningDelegate,
                               SpeedWarningDelegate,
                               SpeedLimitDelegate,
                               RouteProgressDelegate,
                               RouteDeviationDelegate,
                               EventTextDelegate,
                               TollStopWarningDelegate,
                               ManeuverViewLaneAssistanceDelegate,
                               JunctionViewLaneAssistanceDelegate,
                               RoadAttributesDelegate,
                               RoadSignWarningDelegate,
                               TrafficMergeWarningDelegate,
                               TruckRestrictionsWarningDelegate,
                               SchoolZoneWarningDelegate,
                               RoadTextsDelegate,
                               RealisticViewWarningDelegate {

    private let visualNavigator: VisualNavigator
    private let dynamicRoutingEngine: DynamicRoutingEngine
    private let voiceAssistant: VoiceAssistant
    private var lastMapMatchedLocation: MapMatchedLocation?
    private var previousManeuverIndex: Int32 = -1
    private let routeCalculator: RouteCalculator
    private var lastTrafficUpdateInMilliseconds: Int = 0;
    var messageDelegate: MessageDelegate?
    private let timeUtils = TimeUtils()

    init(_ visualNavigator: VisualNavigator,
         _ dynamicRoutingEngine: DynamicRoutingEngine,
         _ routeCalculator: RouteCalculator) {
        self.visualNavigator = visualNavigator
        self.dynamicRoutingEngine = dynamicRoutingEngine
        self.routeCalculator = routeCalculator

        // A helper class for TTS.
        voiceAssistant = VoiceAssistant()

        visualNavigator.navigableLocationDelegate = self
        visualNavigator.borderCrossingWarningDelegate = self
        visualNavigator.currentSituationLaneAssistanceViewDelegate = self
        visualNavigator.dangerZoneWarningListenerDelegate = self
        visualNavigator.lowSpeedZoneWarningDelegate = self
        visualNavigator.destinationReachedDelegate = self
        visualNavigator.routeDeviationDelegate = self
        visualNavigator.routeProgressDelegate = self
        visualNavigator.eventTextDelegate = self
        visualNavigator.milestoneStatusDelegate = self
        visualNavigator.safetyCameraWarningDelegate = self
        visualNavigator.speedWarningDelegate = self
        visualNavigator.speedLimitDelegate = self
        visualNavigator.tollStopWarningDelegate = self
        visualNavigator.maneuverViewLaneAssistanceDelegate = self
        visualNavigator.junctionViewLaneAssistanceDelegate = self
        visualNavigator.roadAttributesDelegate = self
        visualNavigator.roadSignWarningDelegate = self
        visualNavigator.trafficMergeWarningDelegate = self
        visualNavigator.truckRestrictionsWarningDelegate = self
        visualNavigator.schoolZoneWarningDelegate = self
        visualNavigator.roadTextsDelegate = self
        visualNavigator.realisticViewWarningDelegate = self

        setupBorderCrossingWarnings()
        setupSpeedWarnings()
        setupRoadSignWarnings()
        setupVoiceGuidance()
        setupRealisticViewWarnings()
        setupSchoolZoneWarnings()
    }

    // Conform to RouteProgressDelegate.
    // Notifies on the progress along the route including maneuver instructions.
    func onRouteProgressUpdated(_ routeProgress: RouteProgress) {
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
        let roadName = getRoadName(maneuver: nextManeuver)
        let logMessage = "'\(String(describing: action))' on \(roadName) in \(nextManeuverProgress.remainingDistanceInMeters) meters."
        var currentETAString = getETA(routeProgress: routeProgress)
        
        if previousManeuverIndex != nextManeuverIndex {
            currentETAString += "\nNew maneuver: \(logMessage)"
        } else {
            // A maneuver update contains a different distance to reach the next maneuver.
            currentETAString += "\nManeuver update: \(logMessage)"
        }
        updateMessage(currentETAString)

        previousManeuverIndex = nextManeuverIndex

        if let lastMapMatchedLocation = lastMapMatchedLocation {
            // Update the route based on the current location of the driver.
            // We periodically want to search for better traffic-optimized routes.
            dynamicRoutingEngine.updateCurrentLocation(
                mapMatchedLocation: lastMapMatchedLocation,
                sectionIndex: routeProgress.sectionIndex)
        }

        updateTrafficOnRoute(routeProgress: routeProgress)
    }

    // Periodically updates the traffic information for the current route.
    // This method checks whether the last traffic update occurred within the specified interval and skips the update if not.
    // Then it calculates the current traffic conditions along the route using the `RoutingEngine`.
    // Lastly, it updates the `VisualNavigator` with the newly calculated `TrafficOnRoute` object,
    // which affects the `RouteProgress` duration without altering the route geometry or distance.
    //
    // Note: This code initiates periodic calls to the HERE Routing backend. Depending on your contract,
    // each call may be charged separately. It is the application's responsibility to decide how and how
    // often this code should be executed.
    func updateTrafficOnRoute(routeProgress: RouteProgress) {
        guard let currentRoute = visualNavigator.route else {
            // Should never happen.
            return
        }

        // Below, we use 10 minutes. A common range is between 5 and 15 minutes.
        let trafficUpdateIntervalInMilliseconds = 10 * 60000 // 10 minutes
        let now = Int(Date().timeIntervalSince1970 * 1000) // Current time in milliseconds
        if (now - lastTrafficUpdateInMilliseconds) < trafficUpdateIntervalInMilliseconds {
            return
        }
        // Store the current time when we update trafficOnRoute.
        lastTrafficUpdateInMilliseconds = now

        let sectionProgressList = routeProgress.sectionProgress
        guard let lastSectionProgress = sectionProgressList.last else {
            // Should never happen if the list is valid.
            return
        }
        let traveledDistanceOnLastSectionInMeters =
        currentRoute.lengthInMeters - lastSectionProgress.remainingDistanceInMeters
        let lastTraveledSectionIndex = routeProgress.sectionIndex

        routeCalculator.calculateTrafficOnRoute(
            currentRoute: currentRoute,
            lastTraveledSectionIndex: Int(lastTraveledSectionIndex),
            traveledDistanceOnLastSectionInMeters: Int(traveledDistanceOnLastSectionInMeters)
        ) { routingError, trafficOnRoute in
            if let routingError = routingError {
                print("CalculateTrafficOnRoute error: \(routingError)")
                return
            }
            // Sets traffic data for the current route, affecting RouteProgress duration in SectionProgress,
            // while preserving route distance and geometry.
            self.visualNavigator.trafficOnRoute = trafficOnRoute
            print("Updated traffic on route.")
        }
    }


    func getRoadName(maneuver: Maneuver) -> String {
        let currentRoadTexts = maneuver.roadTexts
        let nextRoadTexts = maneuver.nextRoadTexts

        let currentRoadName = currentRoadTexts.names.defaultValue()
        let currentRoadNumber = currentRoadTexts.numbersWithDirection.defaultValue()
        let nextRoadName = nextRoadTexts.names.defaultValue()
        let nextRoadNumber = nextRoadTexts.numbersWithDirection.defaultValue()

        var roadName = nextRoadName == nil ? nextRoadNumber : nextRoadName

        // On highways, we want to show the highway number instead of a possible road name,
        // while for inner city and urban areas road names are preferred over road numbers.
        if maneuver.nextRoadType == RoadType.highway {
            roadName = nextRoadNumber == nil ? nextRoadName : nextRoadNumber
        }

        if maneuver.action == ManeuverAction.arrive {
            // We are approaching destination, so there's no next road.
            roadName = currentRoadName == nil ? currentRoadNumber : currentRoadName
        }

        // Nil happens only in rare cases, when also the fallback above is nil.
        return roadName ?? "unnamed road"
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
        updateMessage("Destination reached.")
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

    // Conform to SafetyCameraWarningDelegate.
    // Notifies on safety camera warnings as they appear along the road.
    func onSafetyCameraWarningUpdated(_ safetyCameraWarning: SafetyCameraWarning) {
        if safetyCameraWarning.distanceType == .ahead {
            print("Safety camera warning \(safetyCameraWarning.type) ahead in: \(safetyCameraWarning.distanceToCameraInMeters) with speed limit = \(safetyCameraWarning.speedLimitInMetersPerSecond)m/s")
        } else if safetyCameraWarning.distanceType == .passed {
            print("Safety camera warning \(safetyCameraWarning.type) passed: \(safetyCameraWarning.distanceToCameraInMeters) with speed limit = \(safetyCameraWarning.speedLimitInMetersPerSecond)m/s")
        } else if safetyCameraWarning.distanceType == .reached {
            print("Safety camera warning \(safetyCameraWarning.type) reached at: \(safetyCameraWarning.distanceToCameraInMeters) with speed limit = \(safetyCameraWarning.speedLimitInMetersPerSecond)m/s")
        }
    }

    // Conform to SpeedWarningDelegate.
    // Notifies when the current speed limit is exceeded.
    func onSpeedWarningStatusChanged(_ status: SpeedWarningStatus) {
        if status == SpeedWarningStatus.speedLimitExceeded {
            // Driver is faster than current speed limit (plus an optional offset).
            // Play a notification sound to alert the driver.
            // Note that this may not include temporary special speed limits, see SpeedLimitDelegate.
            AudioServicesPlaySystemSound(SystemSoundID(1016))
        }

        if status == SpeedWarningStatus.speedLimitRestored {
            print("Driver is again slower than current speed limit (plus an optional offset).")
        }
    }

    // Conform to TrafficMergeWarningDelegate.
    // Notifies about merging traffic to the current road.
    func onTrafficMergeWarningUpdated(_ trafficMergeWarning: TrafficMergeWarning) {
        if trafficMergeWarning.distanceType == .ahead {
            print("There is a merging \(trafficMergeWarning.distanceType) ahead in: \(trafficMergeWarning.distanceToTrafficMergeInMeters) meters, merging from the \(trafficMergeWarning.side) side, with lanes = \(trafficMergeWarning.laneCount)")
        } else if trafficMergeWarning.distanceType == .passed {
            print("A merging \(trafficMergeWarning.distanceType) passed: \(trafficMergeWarning.distanceToTrafficMergeInMeters) meters, merging from the \(trafficMergeWarning.side) side, with lanes = \(trafficMergeWarning.laneCount)")
        } else if trafficMergeWarning.distanceType == .reached {
            // Since the traffic merge warning is given relative to a single position on the route,
            // DistanceType.reached will never be given for this warning.
        }
    }

    // Conform to SpeedLimitDelegate.
    // Notifies on the current speed limit valid on the current road.
    func onSpeedLimitUpdated(_ speedLimit: SpeedLimit) {
        let speedLimit = getCurrentSpeedLimit(speedLimit)

        if speedLimit == nil {
            print("Warning: Speed limits unknown, data could not be retrieved.")
        } else if speedLimit == 0 {
            print("No speed limits on this road! Drive as fast as you feel safe ...")
        } else {
            print("Current speed limit (m/s): \(String(describing: speedLimit))")
        }
    }

    private func getCurrentSpeedLimit(_ speedLimit: SpeedLimit) -> Double? {
        // Note that all values can be nil if no data is available.

        // The regular speed limit if available. In case of unbounded speed limit, the value is zero.
        print("speedLimitInMetersPerSecond: \(String(describing: speedLimit.speedLimitInMetersPerSecond))")

        // A conditional school zone speed limit as indicated on the local road signs.
        print("schoolZoneSpeedLimitInMetersPerSecond: \(String(describing: speedLimit.schoolZoneSpeedLimitInMetersPerSecond))")

        // A conditional time-dependent speed limit as indicated on the local road signs.
        // It is in effect considering the current local time provided by the device's clock.
        print("timeDependentSpeedLimitInMetersPerSecond: \(String(describing: speedLimit.timeDependentSpeedLimitInMetersPerSecond))")

        // A conditional non-legal speed limit that recommends a lower speed,
        // for example, due to bad road conditions.
        print("advisorySpeedLimitInMetersPerSecond: \(String(describing: speedLimit.advisorySpeedLimitInMetersPerSecond))")

        // A weather-dependent speed limit as indicated on the local road signs.
        // The HERE SDK cannot detect the current weather condition, so a driver must decide
        // based on the situation if this speed limit applies.
        print("fogSpeedLimitInMetersPerSecond: \(String(describing: speedLimit.fogSpeedLimitInMetersPerSecond))")
        print("rainSpeedLimitInMetersPerSecond: \(String(describing: speedLimit.rainSpeedLimitInMetersPerSecond))")
        print("snowSpeedLimitInMetersPerSecond: \(String(describing: speedLimit.snowSpeedLimitInMetersPerSecond))")

        // For convenience, this returns the effective (lowest) speed limit between
        // - speedLimitInMetersPerSecond
        // - schoolZoneSpeedLimitInMetersPerSecond
        // - timeDependentSpeedLimitInMetersPerSecond
        return speedLimit.effectiveSpeedLimitInMetersPerSecond()
    }

    // Conform to NavigableLocationDelegate.
    // Notifies on the current map-matched location and other useful information while driving or walking.
    func onNavigableLocationUpdated(_ navigableLocation: NavigableLocation) {
        guard navigableLocation.mapMatchedLocation != nil else {
            print("The currentNavigableLocation could not be map-matched. Are you off-road?")
            return
        }

        lastMapMatchedLocation = navigableLocation.mapMatchedLocation!

        if (lastMapMatchedLocation?.isDrivingInTheWrongWay == true) {
            // For two-way streets, this value is always false. This feature is supported in tracking mode and when deviating from a route.
            print("This is a one way road. User is driving against the allowed traffic direction.")
        }

        let speed = navigableLocation.originalLocation.speedInMetersPerSecond
        let accuracy = navigableLocation.originalLocation.speedAccuracyInMetersPerSecond
        print("Driving speed: \(String(describing: speed)) plus/minus accuracy of \(String(describing: accuracy)).")
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

    // Conform to EventTextDelegate.
    // Notifies on messages that can be fed into TTS engines to guide the user with audible instructions.
    // The texts can be maneuver instructions or warn on certain obstacles, such as speed cameras.
    func onEventTextUpdated(_ eventText: heresdk.EventText) {
        // We use the built-in TTS engine to synthesize the localized text as audio.
        voiceAssistant.speak(message: eventText.text)
        // We can optionally retrieve the associated maneuver. The details will be nil if the text contains
        // non-maneuver related information, such as for speed camera warnings.
        if (eventText.type == TextNotificationType.maneuver) {
            _ = eventText.maneuverNotificationDetails?.maneuver
        }
    }

    // Conform to TollStopWarningDelegate.
    // Notifies on upcoming toll stops. Uses the same notification
    // thresholds as other warners and provides events with or without a route to follow.
    func onTollStopWarning(_ tollStop: TollStop) {
        let lanes = tollStop.lanes

        // The lane at index 0 is the leftmost lane adjacent to the middle of the road.
        // The lane at the last index is the rightmost lane.
        var laneNumber = 0
        for tollBoothLane in lanes {
            // Log which vehicles types are allowed on this lane that leads to the toll booth.
            logLaneAccess("ToolBoothLane: ", laneNumber, tollBoothLane.access)
            let tollBooth = tollBoothLane.booth
            let tollCollectionMethods = tollBooth.tollCollectionMethods
            let paymentMethods = tollBooth.paymentMethods
            // The supported collection methods like ticket or automatic / electronic.
            for collectionMethod in tollCollectionMethods {
                print("This toll stop supports collection via: \(collectionMethod).")
            }
            // The supported payment methods like cash or credit card.
            for paymentMethod in paymentMethods {
                print("This toll stop supports payment via: \(paymentMethod).")
            }
            laneNumber += 1
        }
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

    // Conform to the RoadShieldsWarningDelegate.
    // Notifies on road shields as they appear along the road.
    func onRoadSignWarningUpdated(_ roadSignWarning: RoadSignWarning) {
        let roadSignType: RoadSignType = roadSignWarning.type
        if (roadSignWarning.distanceType == DistanceType.ahead) {
            print("A RoadSignWarning of road sign type: \(roadSignType) ahead in (m): \(roadSignWarning.distanceToRoadSignInMeters)")
        } else if (roadSignWarning.distanceType == DistanceType.passed) {
            print("A RoadSignWarning of road sign type: \(roadSignType) just passed.")
        }

        if let signValue = roadSignWarning.signValue {
            // Optional text as it is printed on the local road sign.
            print("Road sign text: " + signValue.text)
        }

        // For more road sign attributes, please check the API Reference.
    }

    // Conform to the TruckRestrictionsWarningDelegate.
    // Notifies truck drivers on road restrictions ahead. Called whenever there is a change.
    // For example, there can be a bridge ahead not high enough to pass a big truck
    // or there can be a road ahead where the weight of the truck is beyond it's permissible weight.
    // This event notifies on truck restrictions in general,
    // so it will also deliver events, when the transport type was set to a non-truck transport type.
    // The given restrictions are based on the HERE database of the road network ahead.
    func onTruckRestrictionsWarningUpdated(_ restrictions: [TruckRestrictionWarning]) {
        // The list is guaranteed to be non-empty.
        for truckRestrictionWarning in restrictions {
            if truckRestrictionWarning.distanceType == DistanceType.ahead {
                print("TruckRestrictionWarning ahead in \(truckRestrictionWarning.distanceInMeters) meters.")
                if let timeRule = truckRestrictionWarning.timeRule {
                    if !timeRule.appliesTo(dateTime: Date()) {
                        // For example, during a specific time period of a day, some truck restriction warnings do not apply.
                        // If truckRestrictionWarning.timeRule is nil, the warning applies at anytime.
                        print("Note that this truck restriction warning currently does not apply.")
                    }
                }
            } else if truckRestrictionWarning.distanceType == DistanceType.reached {
                print("A restriction has been reached.")
            } else if truckRestrictionWarning.distanceType == DistanceType.passed {
                // If not preceded by a "reached"-notification, this restriction was valid only for the passed location.
                print("A restriction was just passed.")
            }

            // One of the following restrictions applies, if more restrictions apply at the same time,
            // they are part of another TruckRestrictionWarning element contained in the list.
            if truckRestrictionWarning.weightRestriction != nil {
                let type = truckRestrictionWarning.weightRestriction!.type
                let value = truckRestrictionWarning.weightRestriction!.valueInKilograms
                print("TruckRestriction for weight (kg): \(type): \(value)")
            } else if truckRestrictionWarning.dimensionRestriction != nil {
                // Can be either a length, width or height restriction of the truck. For example, a height
                // restriction can apply for a tunnel. Other possible restrictions are delivered in
                // separate TruckRestrictionWarning objects contained in the list, if any.
                let type = truckRestrictionWarning.dimensionRestriction!.type
                let value = truckRestrictionWarning.dimensionRestriction!.valueInCentimeters
                print("TruckRestriction for dimension: \(type): \(value)")
            } else {
                print("TruckRestriction: General restriction - no trucks allowed.")
            }
        }
    }

    // Conform to SchoolZoneWarningDelegate.
    // Notifies on school zones ahead.
    func onSchoolZoneWarningUpdated(_ schoolZoneWarnings: [heresdk.SchoolZoneWarning]) {
        // The list is guaranteed to be non-empty.
        for schoolZoneWarning in schoolZoneWarnings {
            if schoolZoneWarning.distanceType == DistanceType.ahead {
                print("A school zone ahead in: \(schoolZoneWarning.distanceToSchoolZoneInMeters) meters.")
                // Note that this will be the same speed limit as indicated by SpeedLimitDelegate, unless
                // already a lower speed limit applies, for example, because of a heavy truck load.
                print("Speed limit restriction for this school zone: \(schoolZoneWarning.speedLimitInMetersPerSecond) m/s.")
                if let timeRule = schoolZoneWarning.timeRule {
                    if !timeRule.appliesTo(dateTime: Date()) {
                        // For example, during night sometimes a school zone warning does not apply.
                        // If schoolZoneWarning.timeRule is nil, the warning applies at anytime.
                        print("Note that this school zone warning currently does not apply.")
                    }
                }
            } else if schoolZoneWarning.distanceType == DistanceType.reached {
                print("A school zone has been reached.")
            } else if schoolZoneWarning.distanceType == DistanceType.passed {
                print("A school zone has been passed.")
            }
        }
    }

    // Conform to RealisticViewWarningDelegate.
    // Notifies on signposts together with complex junction views.
    // Signposts are shown as they appear along a road on a shield to indicate the upcoming directions and
    // destinations, such as cities or road names.
    // Junction views appear as a 3D visualization (as a static image) to help the driver to orientate.
    //
    // Optionally, you can use a feature-configuration to preload the assets as part of a Region.
    //
    // The event matches the notification for complex junctions, see JunctionViewLaneAssistance.
    // Note that the SVG data for junction view is composed out of several 3D elements,
    // a horizon and the actual junction geometry.
    func onRealisticViewWarningUpdated(_ realisticViewWarning: RealisticViewWarning) {
        let distance = realisticViewWarning.distanceToRealisticViewInMeters
        let distanceType: DistanceType = realisticViewWarning.distanceType

        // Note that DistanceType.reached is not used for Signposts and junction views
        // as a junction is identified through a location instead of an area.
        if distanceType == DistanceType.ahead {
            print("A RealisticView ahead in: " + String(distance) + " meters.")
        } else if distanceType == DistanceType.passed {
            print("A RealisticView just passed.")
        }

        let realisticView = realisticViewWarning.realisticViewVectorImage
        guard let signpostSvgImageContent = realisticView?.signpostSvgImageContent,
              let junctionViewSvgImageContent = realisticView?.junctionViewSvgImageContent
        else {
            print("A RealisticView just passed. No SVG data delivered.")
            return
        }

        // The resolution-independent SVG data can now be used in an application to visualize the image.
        // Use a SVG library of your choice to create an SVG image out of the SVG string.
        // Both SVGs contain the same dimension and the signpostSvgImageContent should be shown on top of
        // the junctionViewSvgImageContent.
        // The images can be quite detailed, therefore it is recommended to show them on a secondary display
        // in full size.
        print("signpostSvgImage: \(signpostSvgImageContent)")
        print("junctionViewSvgImage: \(junctionViewSvgImageContent)")
    }

    // Conform to BorderCrossingWarningDelegate.
    // Notifies whenever a country border is crossed and optionally, by default, also when
    // a state borders are crossed within a country.
    func onBorderCrossingWarningUpdated(_ borderCrossingWarning: BorderCrossingWarning) {
        // Since the border crossing warning is given relative to a single location,
        // the .reached case will never be given for this warning.
        if borderCrossingWarning.distanceType == .ahead {
            print("BorderCrossing: A border is ahead in: \(borderCrossingWarning.distanceToBorderCrossingInMeters) meters.")
            print("BorderCrossing: Type (such as country or state): \(borderCrossingWarning.type)")
            print("BorderCrossing: Country code: \(borderCrossingWarning.countryCode)")

            // The state code after the border crossing. It represents the state / province code.
            // It is a 1 to 3 upper-case characters string that follows the ISO 3166-2 standard,
            // but without the preceding country code (e.g., for Texas, the state code will be TX).
            // It will be nil for countries without states or countries in which the states have very
            // similar regulations (e.g., for Germany, there will be no state borders).
            if let stateCode = borderCrossingWarning.stateCode {
                print("BorderCrossing: State code: \(stateCode)")
            }

            // The general speed limits that apply in the country / state after border crossing.
            let generalVehicleSpeedLimits = borderCrossingWarning.speedLimits
            print("BorderCrossing: Speed limit in cities (m/s): \(String(describing: generalVehicleSpeedLimits.maxSpeedUrbanInMetersPerSecond))")
            print("BorderCrossing: Speed limit outside cities (m/s): \(String(describing: generalVehicleSpeedLimits.maxSpeedRuralInMetersPerSecond))")
            print("BorderCrossing: Speed limit on highways (m/s): \(String(describing: generalVehicleSpeedLimits.maxSpeedHighwaysInMetersPerSecond))")
        } else if borderCrossingWarning.distanceType == .passed {
            print("BorderCrossing: A border has been passed.")
        }
    }

    // Conform to DangerZoneWarningDelegate.
    // Notifies on danger zones.
    // A danger zone refers to areas where there is an increased risk of traffic incidents.
    // These zones are designated to alert drivers to potential hazards and encourage safer driving behaviors.
    // The HERE SDK warns when approaching the danger zone, as well as when leaving such a zone.
    // A danger zone may or may not have one or more speed cameras in it. The exact location of such speed cameras
    // is not provided. Note that danger zones are only available in selected countries, such as France.
    func onDangerZoneWarningsUpdated(_ dangerZoneWarning: DangerZoneWarning) {
        if (dangerZoneWarning.distanceType == DistanceType.ahead) {
            print("A danger zone ahead in: \(dangerZoneWarning.distanceInMeters) meters.")
            // isZoneStart indicates if we enter the danger zone from the start.
            // It is false, when the danger zone is entered from a side street.
            // Based on the route path, the HERE SDK anticipates from where the danger zone will be entered.
            // In tracking mode, the most probable path will be used to anticipate from where
            // the danger zone is entered.
            print("isZoneStart: \(dangerZoneWarning.isZoneStart)")
        } else if (dangerZoneWarning.distanceType == DistanceType.reached) {
            print("A danger zone has been reached. isZoneStart: \(dangerZoneWarning.isZoneStart)")
        } else if (dangerZoneWarning.distanceType == DistanceType.passed) {
            print("A danger zone has been passed.")
        }
    }

    // Conform to LowSpeedZoneWarningDelegate.
    // Notifies on low speed zones ahead - as indicated also on the map when
    // MapFeatures.lowSpeedZones is set.
    func onLowSpeedZoneWarningUpdated(_ lowSpeedZoneWarning: heresdk.LowSpeedZoneWarning) {
        if (lowSpeedZoneWarning.distanceType == DistanceType.ahead) {
            print("A low speed zone ahead in: \(lowSpeedZoneWarning.distanceToLowSpeedZoneInMeters) meters.")
            print("Speed limit in low speed zone (m/s):  \(lowSpeedZoneWarning.speedLimitInMetersPerSecond)")
        } else if (lowSpeedZoneWarning.distanceType == DistanceType.reached) {
            print("A low speed zone has been reached.")
            print("Speed limit in low speed zone (m/s):  \(lowSpeedZoneWarning.speedLimitInMetersPerSecond)")
        } else if (lowSpeedZoneWarning.distanceType == DistanceType.passed) {
            print("A low speed zone has been passed.")
        }
    }

    // Conform to RoadTextsDelegate
    // Notifies whenever any textual attribute of the current road changes, i.e., the current road texts differ
    // from the previous one. This can be useful during tracking mode, when no maneuver information is provided.
    func onRoadTextsUpdated(_ roadTexts: RoadTexts) {
        // See getRoadName() how to get the current road name from the provided RoadTexts.
    }
    
    private func getETA(routeProgress: RouteProgress) -> String {
        let sectionProgressList = routeProgress.sectionProgress
        // sectionProgressList is guaranteed to be non-empty.
        let lastSectionProgress = sectionProgressList.last!

        let currentETAString = "ETA: \(timeUtils.getETAinDeviceTimeZone(estimatedTravelTimeInSeconds: Int32(lastSectionProgress.remainingDuration)))"

        print("Distance to destination in meters: \(lastSectionProgress.remainingDistanceInMeters)")
        print("Traffic delay ahead in seconds: \(lastSectionProgress.trafficDelay)")
        // Logs current ETA.
        print(currentETAString)

        return currentETAString
    }


    private func setupBorderCrossingWarnings() {
        var borderCrossingWarningOptions = BorderCrossingWarningOptions()
        // If set to true, all the state border crossing notifications will not be given.
        // If the value is false, all border crossing notifications will be given for both
        // country borders and state borders. Defaults to false
        borderCrossingWarningOptions.filterOutStateBorderWarnings = true
        visualNavigator.borderCrossingWarningOptions = borderCrossingWarningOptions
    }

    private func setupSpeedWarnings() {
        let speedLimitOffset = SpeedLimitOffset(lowSpeedOffsetInMetersPerSecond: 2,
                                                highSpeedOffsetInMetersPerSecond: 4,
                                                highSpeedBoundaryInMetersPerSecond: 25)
        visualNavigator.speedWarningOptions = SpeedWarningOptions(speedLimitOffset: speedLimitOffset)
    }

    private func setupRoadSignWarnings() {
        var roadSignWarningOptions = RoadSignWarningOptions()
        // Set a filter to get only shields relevant for trucks and heavyTrucks.
        roadSignWarningOptions.vehicleTypesFilter = [RoadSignVehicleType.trucks, RoadSignVehicleType.heavyTrucks]
        // Get notification distances for road sign alerts from visual navigator.
        var warningNotificationDistances = visualNavigator.getWarningNotificationDistances(warningType: WarningType.roadSign)

        // The distance in meters for emitting warnings when the speed limit or current speed is fast. Defaults to 1500.
        warningNotificationDistances.fastSpeedDistanceInMeters = 1600;
        // The distance in meters for emitting warnings when the speed limit or current speed is regular. Defaults to 750.
        warningNotificationDistances.regularSpeedDistanceInMeters = 800;
        // The distance in meters for emitting warnings when the speed limit or current speed is slow. Defaults to 500.
        warningNotificationDistances.slowSpeedDistanceInMeters = 600;

        // Set the warning distances for road signs.
        visualNavigator.setWarningNotificationDistances(warningType: WarningType.roadSign, warningNotificationDistances: warningNotificationDistances)
    }

    private func setupRealisticViewWarnings() {
        var realisticViewWarningOptions = RealisticViewWarningOptions(aspectRatio: AspectRatio.aspectRatio3X4, darkTheme: false)
        visualNavigator.realisticViewWarningOptions = realisticViewWarningOptions
    }

    private func setupSchoolZoneWarnings() {
        var schoolZoneWarningOptions = SchoolZoneWarningOptions()
        schoolZoneWarningOptions.filterOutInactiveTimeDependentWarnings = true
        schoolZoneWarningOptions.warningDistanceInMeters = 150
        visualNavigator.schoolZoneWarningOptions = schoolZoneWarningOptions
    }

    private func setupVoiceGuidance() {
        var maneuverNotificationOptions = ManeuverNotificationOptions()
        let ttsLanguageCode = getLanguageCodeForDevice(supportedVoiceSkins: VisualNavigator.availableLanguagesForManeuverNotifications())

        // Set the language in which the notifications will be generated.
        maneuverNotificationOptions.language = ttsLanguageCode
        // Set the measurement system used for distances.
        maneuverNotificationOptions.unitSystem = UnitSystem.metric
        visualNavigator.maneuverNotificationOptions = maneuverNotificationOptions

        print("LanguageCode for maneuver notifications: \(ttsLanguageCode).")

        // Set language to our TextToSpeech engine.
        let locale = LanguageCodeConverter.getLocale(languageCode: ttsLanguageCode)
        if voiceAssistant.setLanguage(locale: locale) {
            print("TextToSpeech engine uses this language: \(locale)")
        } else {
            print("TextToSpeech engine does not support this language: \(locale)")
        }
    }

    // Get the language preferrably used on this device.
    private func getLanguageCodeForDevice(supportedVoiceSkins: [heresdk.LanguageCode]) -> LanguageCode {

        // 1. Determine if preferred device language is supported by our TextToSpeech engine.
        let identifierForCurrenDevice = Locale.preferredLanguages.first!
        var localeForCurrenDevice = Locale(identifier: identifierForCurrenDevice)
        if !voiceAssistant.isLanguageAvailable(identifier: identifierForCurrenDevice) {
            print("TextToSpeech engine does not support: \(identifierForCurrenDevice), falling back to en-US.")
            localeForCurrenDevice = Locale(identifier: "en-US")
        }

        // 2. Determine supported voice skins from HERE SDK.
        var languageCodeForCurrenDevice = LanguageCodeConverter.getLanguageCode(locale: localeForCurrenDevice)
        if !supportedVoiceSkins.contains(languageCodeForCurrenDevice) {
            print("No voice skins available for \(languageCodeForCurrenDevice), falling back to enUs.")
            languageCodeForCurrenDevice = LanguageCode.enUs
        }

        return languageCodeForCurrenDevice
    }

    private func updateMessage(_ message: String) {
        messageDelegate?.updateMessage(message)
    }
}
