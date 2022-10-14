/*
 * Copyright (C) 2019-2022 HERE Europe B.V.
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
import UIKit

// Shows how to start and stop turn-by-turn navigation on a car route.
// By default, tracking mode is enabled. When navigation is stopped, tracking mode is enabled again.
// The preferred device language determines the language for voice notifications used for TTS.
// (Make sure to set language + region in device settings.)
class NavigationExample : NavigableLocationDelegate,
                          DestinationReachedDelegate,
                          MilestoneStatusDelegate,
                          SpeedWarningDelegate,
                          SpeedLimitDelegate,
                          RouteProgressDelegate,
                          RouteDeviationDelegate,
                          ManeuverNotificationDelegate,
                          ManeuverViewLaneAssistanceDelegate,
                          JunctionViewLaneAssistanceDelegate,
                          RoadAttributesDelegate,
                          DynamicRoutingDelegate,
                          RoadSignWarningDelegate,
                          TruckRestrictionsWarningDelegate,
                          RoadTextsDelegate {

    private let viewController: UIViewController
    private let mapView: MapView
    private let visualNavigator: VisualNavigator
    private var dynamicRoutingEngine: DynamicRoutingEngine?
    private let herePositioningProvider: HEREPositioningProvider
    private let herePositioningSimulator: HEREPositioningSimulator
    private let voiceAssistant: VoiceAssistant
    private var lastMapMatchedLocation: MapMatchedLocation?
    private var previousManeuverIndex: Int32 = -1
    private var messageTextView: UITextView

    init(viewController: UIViewController, mapView: MapView, messageTextView: UITextView) {
        self.viewController = viewController
        self.mapView = mapView
        self.messageTextView = messageTextView

        do {
            // Without a route set, this starts tracking mode.
            try visualNavigator = VisualNavigator()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize VisualNavigator. Cause: \(engineInstantiationError)")
        }

        // By default, enable auto-zoom during guidance.
        visualNavigator.cameraBehavior = DynamicCameraBehavior()
        
        visualNavigator.startRendering(mapView: mapView)

        // A class to receive real location events.
        herePositioningProvider = HEREPositioningProvider()
        // A class to receive simulated location events.
        herePositioningSimulator = HEREPositioningSimulator()

        // A helper class for TTS.
        voiceAssistant = VoiceAssistant()

        dynamicRoutingEngine = createDynamicRoutingEngine()

        visualNavigator.navigableLocationDelegate = self
        visualNavigator.routeDeviationDelegate = self
        visualNavigator.routeProgressDelegate = self
        visualNavigator.maneuverNotificationDelegate = self
        visualNavigator.destinationReachedDelegate = self
        visualNavigator.milestoneStatusDelegate = self
        visualNavigator.speedWarningDelegate = self
        visualNavigator.speedLimitDelegate = self
        visualNavigator.maneuverViewLaneAssistanceDelegate = self
        visualNavigator.junctionViewLaneAssistanceDelegate = self
        visualNavigator.roadAttributesDelegate = self
        visualNavigator.roadSignWarningDelegate = self
        visualNavigator.truckRestrictionsWarningDelegate = self
        visualNavigator.roadTextsDelegate = self
    }

    func startLocationProvider() {
        // Set navigator as delegate to receive locations from HERE Positioning.
        herePositioningProvider.startLocating(locationDelegate: visualNavigator,
                                              // Choose the best accuracy for the tbt navigation use case.
                                              accuracy: .navigation)
    }

    func createDynamicRoutingEngine() -> DynamicRoutingEngine {
        // We want an update for each poll iteration, so we specify 0 difference.
        let minTimeDifferencePercentage = 0.0
        let minTimeDifferenceInSeconds: TimeInterval = 0
        let pollIntervalInSeconds: TimeInterval = 5 * 60

        let dynamicRoutingOptions =
            DynamicRoutingEngineOptions(minTimeDifferencePercentage: minTimeDifferencePercentage,
                                        minTimeDifference: minTimeDifferenceInSeconds,
                                        pollInterval: pollIntervalInSeconds)

        do {
            // With the dynamic routing engine you can poll the HERE backend services to search for routes with less traffic.
            // THis can happen during guidance - or you can periodically update a route that is shown in a route planner.
            let dynamicRoutingEngine = try DynamicRoutingEngine(options: dynamicRoutingOptions)
            return dynamicRoutingEngine
        } catch let engineInstantiationError {
            fatalError("Failed to initialize DynamicRoutingEngine. Cause: \(engineInstantiationError)")
        }
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

        if previousManeuverIndex != nextManeuverIndex {
            // Log only new maneuvers and ignore changes in distance.
            showMessage("New maneuver: " + logMessage)
        } else {
            // A maneuver update contains a different distance to reach the next maneuver.
            showMessage("Maneuver update: " + logMessage)
        }

        previousManeuverIndex = nextManeuverIndex

        if let lastMapMatchedLocation = lastMapMatchedLocation {
           // Update the route based on the current location of the driver.
           // We periodically want to search for better traffic-optimized routes.
            dynamicRoutingEngine!.updateCurrentLocation(mapMatchedLocation: lastMapMatchedLocation,
                                                       sectionIndex: routeProgress.sectionIndex)
       }
    }

    func getRoadName(maneuver: Maneuver) -> String {
        let currentRoadTexts = maneuver.roadTexts
        let nextRoadTexts = maneuver.nextRoadTexts

        let currentRoadName = currentRoadTexts.names.defaultValue()
        let currentRoadNumber = currentRoadTexts.numbers.defaultValue()
        let nextRoadName = nextRoadTexts.names.defaultValue()
        let nextRoadNumber = nextRoadTexts.numbers.defaultValue()

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

    // Conform to DestinationReachedDelegate.
    // Notifies when the destination of the route is reached.
    func onDestinationReached() {
        showMessage("Destination reached. Stopping turn-by-turn navigation.")
        stopNavigation()
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
    }

    // Conform to ManeuverNotificationDelegate.
    // Notifies on voice maneuver messages.
    func onManeuverNotification(_ text: String) {
        voiceAssistant.speak(message: text)
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

            laneNumber += 1
        }
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

    // Conform to the DynamicRoutingDelegate.
    // Notifies on traffic-optimized routes that are considered better than the current route.
    func onBetterRouteFound(newRoute: Route,
                            etaDifferenceInSeconds: Int32,
                            distanceDifferenceInMeters: Int32) {
        print("DynamicRoutingEngine: Calculated a new route.")
        print("DynamicRoutingEngine: etaDifferenceInSeconds: \(etaDifferenceInSeconds).")
        print("DynamicRoutingEngine: distanceDifferenceInMeters: \(distanceDifferenceInMeters).")

        // An implementation can decide to switch to the new route:
        // visualNavigator.route = newRoute
    }

    // Conform to the DynamicRoutingDelegate.
    func onRoutingError(routingError: RoutingError) {
        print("Error while dynamically searching for a better route: \(routingError).")
    }

    // Conform to the RoadShieldsWarningDelegate.
    // Notifies on road shields as they appear along the road.
    func onRoadSignWarningUpdated(_ roadSignWarning: RoadSignWarning) {
        print("Road sign distance (m): \(roadSignWarning.distanceToRoadSignInMeters)")
        print("Road sign type: \(roadSignWarning.type.rawValue)")

        if let signValue = roadSignWarning.signValue {
            // Optional text as it is printed on the local road sign.
            print("Road sign text: " + signValue.text)
        }

        // For more road sign attributes, please check the API Reference.
    }

    // Conform to the TruckRestrictionsWarningDelegate.
    // Notifies truck drivers on road restrictions ahead.
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

    // Conform to RoadTextsDelegate
    // Notifies whenever any textual attribute of the current road changes, i.e., the current road texts differ
    // from the previous one. This can be useful during tracking mode, when no maneuver information is provided.
    func onRoadTextsUpdated(_ roadTexts: RoadTexts) {
        // See getRoadName() how to get the current road name from the provided RoadTexts.
    }

    func startNavigation(route: Route,
                                isSimulated: Bool) {
        setupSpeedWarnings()
        setupRoadSignWarnings()
        setupVoiceGuidance()

        // Switches to navigation mode when no route was set before, otherwise navigation mode is kept.
        visualNavigator.route = route

        if isSimulated {
            enableRoutePlayback(route: route)
            showMessage("Starting simulated navigation.")
        } else {
            enableDevicePositioning()
            showMessage("Starting navigation.")
        }

        startDynamicSearchForBetterRoutes(route)
    }

    private func startDynamicSearchForBetterRoutes(_ route: Route) {
        do {
            try dynamicRoutingEngine?.start(route: route, delegate: self)
        } catch let instantiationError {
            fatalError("Start of DynamicRoutingEngine failed: \(instantiationError). Is the RouteHandle missing?")
        }
    }

    func stopNavigation() {
        // Switches to tracking mode when a route was set before, otherwise tracking mode is kept.
        // Without a route the navigator will only notify on the current map-matched location
        // including info such as speed and current street name.
        dynamicRoutingEngine!.stop()
        visualNavigator.route = nil
        enableDevicePositioning()
        showMessage("Tracking device's location.")
    }

    // Provides location updates based on the given route.
    func enableRoutePlayback(route: Route) {
        herePositioningProvider.stopLocating()
        herePositioningSimulator.startLocating(locationDelegate: visualNavigator, route: route)
    }

    // Provides location updates based on the device's GPS sensor.
    func enableDevicePositioning() {
        herePositioningSimulator.stopLocating()
        herePositioningProvider.startLocating(locationDelegate: visualNavigator,
                                              accuracy: .navigation)
    }

    func startCameraTracking() {
        visualNavigator.cameraBehavior = DynamicCameraBehavior()
    }

    func stopCameraTracking() {
        visualNavigator.cameraBehavior = nil
    }

    func getLastKnownLocation() -> Location? {
        return herePositioningProvider.getLastKnownLocation()
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
        visualNavigator.roadSignWarningOptions = roadSignWarningOptions
    }
    
    private func setupVoiceGuidance() {
        let ttsLanguageCode = getLanguageCodeForDevice(supportedVoiceSkins: VisualNavigator.availableLanguagesForManeuverNotifications())
        visualNavigator.maneuverNotificationOptions = ManeuverNotificationOptions(language: ttsLanguageCode,
                                                                            unitSystem: UnitSystem.metric)

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

    // A permanent view to show log content.
    private func showMessage(_ message: String) {
        messageTextView.text = message
        messageTextView.textColor = .white
        messageTextView.layer.cornerRadius = 8
        messageTextView.isEditable = false
        messageTextView.textAlignment = NSTextAlignment.center
        messageTextView.font = .systemFont(ofSize: 14)
    }
}
