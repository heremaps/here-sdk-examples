/*
 * Copyright (C) 2019-2020 HERE Europe B.V.
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
import UIKit

// Shows how to start and stop turn-by-turn navigation.
// By default, tracking mode is enabled. When navigation is stopped, tracking mode is enabled again.
// The preferred device language determines the language for voice notifications used for TTS.
// (Make sure to set language + region in device settings.)
class NavigationExample : NavigableLocationDelegate,
                          RouteProgressDelegate,
                          RouteDeviationDelegate,
                          ManeuverNotificationDelegate {

    private let viewController: UIViewController
    private let mapView: MapView
    private let navigator: Navigator
    private let locationProvider: LocationProviderImplementation
    private let voiceAssistant: VoiceAssistant
    private var previousManeuverIndex: Int32 = -1
    private lazy var navigationArrow = createArrow(asset: "arrow_blue.png")
    private lazy var trackingArrow = createArrow(asset: "arrow_green.png")

    init(viewController: UIViewController, mapView: MapView) {
        self.viewController = viewController
        self.mapView = mapView

        locationProvider = LocationProviderImplementation()
        locationProvider.start()

        do {
            // Without a route set, this starts tracking mode.
            try navigator = Navigator(locationProvider: locationProvider)
        } catch let engineInstantiationError {
            fatalError("Failed to initialize navigator. Cause: \(engineInstantiationError)")
        }

        // A helper class for TTS.
        voiceAssistant = VoiceAssistant()

        navigator.navigableLocationDelegate = self
        navigator.routeDeviationDelegate = self
        navigator.routeProgressDelegate = self
        navigator.maneuverNotificationDelegate = self
    }

    private func createArrow(asset: String) -> MapMarker {
        guard
            let image = UIImage(named: asset),
            let imageData = image.pngData() else {
                fatalError("Image data not available.")
        }

        let mapImage = MapImage(pixelData: imageData,
                                imageFormat: ImageFormat.png)
        let mapMarker = MapMarker(at: ConstantsEnum.DEFAULT_MAP_CENTER,
                                  image: mapImage)
        return mapMarker
    }

    // Conform to RouteProgressDelegate.
    // Notifies on the progress along the route including maneuver instructions.
    func onRouteProgressUpdated(_ routeProgress: RouteProgress) {
        // [SectionProgress] is guaranteed to be non-empty.
        let distanceToDestination = routeProgress.sectionProgress.last!.remainingDistanceInMeters
        print("Distance to destination in meters: \(distanceToDestination)")
        let trafficDelayAhead = routeProgress.sectionProgress.last!.trafficDelayInSeconds
        print("Traffic delay ahead in seconds: \(trafficDelayAhead)")

        let maneuverIndex = routeProgress.currentManeuverIndex
        guard let maneuver = navigator.getManeuver(index: maneuverIndex) else {
            print("No maneuver available.")
            return
        }

        let action = maneuver.action
        let nextRoadName = maneuver.nextRoadName
        var road = nextRoadName == nil ? maneuver.nextRoadNumber : nextRoadName
        if action == ManeuverAction.arrive {
            // We are reaching destination, so there's no next road.
            let roadName = maneuver.roadName
            road = roadName == nil ? maneuver.roadNumber : roadName
        }

        let logMessage = "'\(String(describing: action))' on \(road ?? "unnamed road") in \(routeProgress.currentManeuverRemainingDistanceInMeters) meters."

        if previousManeuverIndex != maneuverIndex {
            // Log only new maneuvers and ignore changes in distance.
            showMessage("New maneuver: " + logMessage)
        }

        previousManeuverIndex = maneuverIndex
    }

    // Conform to NavigableLocationDelegate.
    // Notifies on the current map-matched location and other useful information while driving or walking.
    func onNavigableLocationUpdated(_ navigableLocation: NavigableLocation) {
        guard let mapMatchedLocation = navigableLocation.mapMatchedLocation else {
            showMessage("This new location could not be map-matched. Using raw location.")
            updateMapView(currentGeoCoordinates: navigableLocation.originalLocation.coordinates,
                          bearingInDegrees: navigableLocation.originalLocation.bearingInDegrees)
            return
        }

        print("Current street: \(String(describing: navigableLocation.streetName))")

        // Get speed limits for drivers.
        if navigableLocation.speedLimitInMetersPerSecond == nil {
            print("Warning: Speed limits unkown, data could not be retrieved.")
        } else if navigableLocation.speedLimitInMetersPerSecond == 0 {
            print("No speed limits on this road! Drive as fast as you feel safe ...")
        } else {
            print("Current speed limit (m/s): \(String(describing: navigableLocation.speedLimitInMetersPerSecond))")
        }

        updateMapView(currentGeoCoordinates: mapMatchedLocation.coordinates,
                      bearingInDegrees: mapMatchedLocation.bearingInDegrees)
    }

    // Conform to RouteDeviationDelegate.
    // Notifies on a possible deviation from the route.
    func onRouteDeviation(_ routeDeviation: RouteDeviation) {
        guard let lastLocationOnRoute = routeDeviation.lastLocationOnRoute else {
            print("User was never following the route.")
            return
        }

        var currentGeoCoordinates = routeDeviation.currentLocation.originalLocation.coordinates
        if let currentMapMatchedLocation = routeDeviation.currentLocation.mapMatchedLocation {
            currentGeoCoordinates = currentMapMatchedLocation.coordinates
        }

        var lastGeoCoordinates = lastLocationOnRoute.originalLocation.coordinates
        if let lastMapMatchedLocationOnRoute = lastLocationOnRoute.mapMatchedLocation {
            lastGeoCoordinates = lastMapMatchedLocationOnRoute.coordinates
        }

        let distanceInMeters = currentGeoCoordinates.distance(to: lastGeoCoordinates)
        print("RouteDeviation in meters is \(distanceInMeters)")
    }

    // Conform to ManeuverNotificationDelegate.
    // Notifies on voice maneuver messages.
    func onManeuverNotification(_ text: String) {
        voiceAssistant.speak(message: text)
    }

    // Update location and rotation of map. Update location of arrow.
    private func updateMapView(currentGeoCoordinates: GeoCoordinates,
                               bearingInDegrees: Double?) {
        var orientation = MapCamera.OrientationUpdate()
        orientation.bearing = bearingInDegrees

        mapView.camera.lookAt(point: currentGeoCoordinates,
                              orientation: orientation,
                              distanceInMeters: ConstantsEnum.DEFAULT_DISTANCE_IN_METERS)
        navigationArrow.coordinates = currentGeoCoordinates
        trackingArrow.coordinates = currentGeoCoordinates
    }

    func startNavigation(route: Route,
                                isSimulated: Bool) {
        navigator.route = route

        setupVoiceGuidance()

        if isSimulated {
            locationProvider.enableRoutePlayback(route: route)
        } else {
            locationProvider.enableDevicePositioning()
        }

        mapView.mapScene.addMapMarker(navigationArrow)
        updateArrowLocations()
    }

    func stopNavigation() {
        navigator.route = nil
        mapView.mapScene.removeMapMarker(navigationArrow)
    }

    func startTracking() {
        // Reset route in case TBT was started before.
        navigator.route = nil
        locationProvider.enableDevicePositioning()

        mapView.mapScene.addMapMarker(trackingArrow)
        updateArrowLocations()
        showMessage("Free tracking: Running.")
    }

    func stopTracking() {
        mapView.mapScene.removeMapMarker(trackingArrow)
        showMessage("Free tracking: Stopped.")
    }

    private func updateArrowLocations() {
        guard let lastKnownLocation = getLastKnownGeoCoordinates() else {
            print("No location found.")
            return
        }

        navigationArrow.coordinates = lastKnownLocation
        trackingArrow.coordinates = lastKnownLocation
    }

    func getLastKnownGeoCoordinates() -> GeoCoordinates? {
        return locationProvider.lastKnownLocation?.coordinates
    }

    private func setupVoiceGuidance() {
        let ttsLanguageCode = getLanguageCodeForDevice(supportedVoiceSkins: navigator.supportedLanguages())
        navigator.maneuverNotificationOptions = ManeuverNotificationOptions(language: ttsLanguageCode,
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

    private var messageTextView = UITextView()
    private func showMessage(_ message: String) {
        messageTextView.text = message
        messageTextView.textColor = .white
        messageTextView.backgroundColor = UIColor(red: 0, green: 144 / 255, blue: 138 / 255, alpha: 1)
        messageTextView.layer.cornerRadius = 8
        messageTextView.isEditable = false
        messageTextView.textAlignment = NSTextAlignment.center
        messageTextView.font = .systemFont(ofSize: 14)
        messageTextView.frame = CGRect(x: 0, y: 0, width: mapView.frame.width * 0.9, height: 50)
        messageTextView.center = CGPoint(x: mapView.frame.width * 0.5, y: mapView.frame.height * 0.9)

        UIView.transition(with: mapView, duration: 0.2, options: [.transitionCrossDissolve], animations: {
            self.mapView.addSubview(self.messageTextView)
        })

        // Hide message after 5 seconds.
        let messageDurationInSeconds: Double = 5
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + messageDurationInSeconds) {
            UIView.transition(with: self.mapView, duration: 0.2, options: [.transitionCrossDissolve], animations: {
                self.messageTextView.removeFromSuperview()
            })
        }
    }
}
