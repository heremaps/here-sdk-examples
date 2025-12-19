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

enum RoadType {
    case highway
    case rural
    case urban
}

// This class combines the various events that can be emitted during turn-by-turn navigation.
// Note that this class does not show an exhaustive list of all possible events.
class NavigationHandler : NavigableLocationDelegate,
                               RouteProgressDelegate,
                               EventTextDelegate {

    private let visualNavigator: VisualNavigator
    private let dynamicRoutingEngine: DynamicRoutingEngine
    private let electronicHorizonHandler: ElectronicHorizonHandler
    private let voiceAssistant: VoiceAssistant
    private var lastMapMatchedLocation: MapMatchedLocation?
    private var previousManeuverIndex: Int32 = -1
    private let routeCalculator: RouteCalculator
    private var lastTrafficUpdateInMilliseconds: Int = 0;
    var messageDelegate: MessageDelegate?
    private let timeUtils = TimeUtils()

    init(_ visualNavigator: VisualNavigator,
         _ dynamicRoutingEngine: DynamicRoutingEngine,
         _ electronicHorizonHandler: ElectronicHorizonHandler,
         _ routeCalculator: RouteCalculator) {
        self.visualNavigator = visualNavigator
        self.dynamicRoutingEngine = dynamicRoutingEngine
        self.electronicHorizonHandler = electronicHorizonHandler
        self.routeCalculator = routeCalculator

        // A helper class for TTS.
        voiceAssistant = VoiceAssistant()

        visualNavigator.navigableLocationDelegate = self
        visualNavigator.routeProgressDelegate = self
        visualNavigator.eventTextDelegate = self

        setupVoiceGuidance()
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
        let roadName = getRoadName(maneuver: nextManeuver, route: visualNavigator.route)
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
                sectionIndex: routeProgress.routeMatchedLocation.sectionIndex)
            
            // Update the ElectronicHorizon with the last map-matched location.
            electronicHorizonHandler.update(mapMatchedLocation: lastMapMatchedLocation)
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
        let lastTraveledSectionIndex = routeProgress.routeMatchedLocation.sectionIndex

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


    func getRoadName(maneuver: Maneuver, route: Route?) -> String {
        let currentRoadTexts = maneuver.roadTexts
        let nextRoadTexts = maneuver.nextRoadTexts

        let currentRoadName = currentRoadTexts.names.defaultValue()
        let currentRoadNumber = currentRoadTexts.numbersWithDirection.defaultValue()
        let nextRoadName = nextRoadTexts.names.defaultValue()
        let nextRoadNumber = nextRoadTexts.numbersWithDirection.defaultValue()

        var roadName = nextRoadName == nil ? nextRoadNumber : nextRoadName

        // On highways, we want to show the highway number instead of a possible road name,
        // while for inner city and urban areas road names are preferred over road numbers.
        if getRoadType(maneuver: maneuver, route: route!) == RoadType.highway {
            roadName = nextRoadNumber == nil ? nextRoadName : nextRoadNumber
        }

        if maneuver.action == ManeuverAction.arrive {
            // We are approaching destination, so there's no next road.
            roadName = currentRoadName == nil ? currentRoadNumber : currentRoadName
        }

        // Nil happens only in rare cases, when also the fallback above is nil.
        return roadName ?? "unnamed road"
    }

    // Determines the road type for a given maneuver based on street attributes.
    // Return The road type classification (highway, urban, or rural).
    func getRoadType(maneuver: Maneuver, route: Route) -> RoadType {
        let sectionIndex = Int(maneuver.sectionIndex)
        let section = route.sections[sectionIndex]
        let spans = section.spans

        // If attributes list is empty then the road type is rural.
        guard !spans.isEmpty else {
            return .rural
        }
        
        let spanIndex = Int(maneuver.spanIndex)
        let currentSpan = spans[spanIndex]
        let streetAttributes = currentSpan.streetAttributes

        // If attributes list contains either CONTROLLED_ACCESS_HIGHWAY, or MOTORWAY or RAMP then the road type is highway.
        // Check for highway attributes.
        if streetAttributes.contains(.controlledAccessHighway) ||
           streetAttributes.contains(.motorway) ||
           streetAttributes.contains(.ramp) {
            return .highway
        }

        // If attributes list contains BUILT_UP_AREA then the road type is urban.
        // Check for urban attributes.
        if streetAttributes.contains(.builtUpArea) {
            return .urban
        }

        // If the road type is neither urban nor highway, default to rural for all other cases.
        return .rural
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

    private func setupVoiceGuidance() {
        var maneuverNotificationOptions = ManeuverNotificationOptions()
        let ttsLanguageCode = getLanguageCodeForDevice(supportedVoiceSkins: VisualNavigator.availableLanguagesForManeuverNotifications())

        // Set the language in which the notifications will be generated.
        maneuverNotificationOptions.language = ttsLanguageCode
        // Set the measurement system used for distances.
        maneuverNotificationOptions.unitSystem = UnitSystem.metric
        visualNavigator.maneuverNotificationOptions = maneuverNotificationOptions

        print("LanguageCode for maneuver notifications: \(ttsLanguageCode).")

        // Toggle the lane recommendation in the maneuver notifications.
        // The lane recommendation, if enabled, will be given only for the ManeuverNotificationType.DISTANCE notification type.
        maneuverNotificationOptions.enableLaneRecommendation = true
        
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
