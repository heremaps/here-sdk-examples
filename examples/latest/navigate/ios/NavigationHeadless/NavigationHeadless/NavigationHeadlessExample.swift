/*
 * Copyright (C) 2025 HERE Europe B.V.
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

import SwiftUI
import heresdk

// The Navigation Headless example app shows how the HERE SDK can be set up to navigate without
// following a route in the simplest way without showing a map view. The app uses the `Navigator` class.
// It loads a hardcoded GPX trace in the Berlin area to start tracking along that trace using the `LocationSimulator`.
// It does not include HERE SDK Positioning features and does no route calculation.
//
// Instead, the app provides basic notifications on the following events:
//
// - current speed limit
// - current road name
//
// Note that the GPX trace is played back faster to make it easier to see changing events.
// See `speedFactor` setting below to adjust the simulation speed.
// In addition, a timer is shown to present the elapsed time while the example app is running.
class NavigationHeadlessExample: ObservableObject, RoadTextsDelegate, SpeedLimitDelegate, LocationDelegate {
    @Published var speedLimitTextView = "Current speed limit: n/a";
    @Published var roadNameTextView = "Current road name: n/a";
    @Published var timerTextView: String = "00:00:00"
        
    private var timer: Timer?
    private var elapsedTime: Int = 0
    
    var navigator: Navigator?
    private var locationSimulator: LocationSimulator?;
    
    init() {
        startTimer()
    }
    
    func startTimer() {
        let delayMillis: TimeInterval = 1.0
        timer = Timer.scheduledTimer(withTimeInterval: delayMillis, repeats: true) { [weak self] _ in
            self?.elapsedTime += 1
            self?.updateTimerText()
        }
        
        // Loop to ensure it works even during user interactions
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    func updateTimerText() {
        let seconds = elapsedTime % 60
        let minutes = (elapsedTime % 3600) / 60
        let hours = elapsedTime / 3600
        
        // Format the time as HH:MM:SS
        timerTextView = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // Confirming to LocationDelegate protocol
    func onLocationUpdated(_ location: Location) {
        navigator?.onLocationUpdated(location)
    }
    
    // Confirming to RoadTextsDelegate protocol
    func onRoadTextsUpdated(_ roadTexts: RoadTexts) {
        let currentRoadName = roadTexts.names.defaultValue()
        let currentRoadNumber = roadTexts.numbersWithDirection.defaultValue()
        var roadName = currentRoadName ?? currentRoadNumber
        
        if roadName == nil {
            roadName = "unnamed road"
        }
        self.roadNameTextView = "Current road name: \(roadName ?? "unnamed road")"
    }
    
    // Confirming to SpeedLimitDelegate protocol
    func onSpeedLimitUpdated(_ speedLimit: SpeedLimit) {
        print("Speed limit: \(speedLimit)")
        let currentEffectiveSpeedLimit = speedLimit.effectiveSpeedLimitInMetersPerSecond()
        if currentEffectiveSpeedLimit == nil {
            speedLimitTextView = "Current speed limit: no data"
        } else if currentEffectiveSpeedLimit == 0 {
            speedLimitTextView = "Current speed limit: no speed limit"
        } else {
            speedLimitTextView = "Current speed limit: " + metersPerSecondToKilometersPerHour(currentEffectiveSpeedLimit!)
        }
    }
    
    private func metersPerSecondToKilometersPerHour(_ speed: Double) -> String {
        let kmh = speed * 3.6
        return String(format: "%.2f km/h", kmh)
    }
    
    func startGuidanceExample() async {
        // We start tracking by loading a GPX trace for location simulation.
        if let gpxTrack = await loadGPXTrack() {
            showDialog(title: "Navigation Headless Start", message: "This app shows headless tracking following a hardcoded GPX trace. Watch the logs for events.")
            startTracking(gpxTrack)
        } else {
            showDialog(title: "Error", message: "GPX track not found.")
        }
    }
    
    func loadGPXTrack() async -> GPXTrack? {
        guard let gpxString = await loadGPXString() else {
            return nil
        }
        let gpxTrack = parseGPX(gpxString)
        return gpxTrack
    }
    
    func loadGPXString() async -> String? {
        // We added a GPX file to assets/berlin_trace.gpx.
        guard let fileUrl = Bundle.main.url(forResource: "berlin_trace", withExtension: "gpx") else {
            print("GPX file not found in bundle.")
            return nil
        }
        
        do {
            let gpxString = try String(contentsOf: fileUrl, encoding: .utf8)
            return gpxString
        } catch {
            print("Error loading GPX file: \(error)")
            return nil
        }
    }
    
    func parseGPX(_ gpxString: String) -> GPXTrack? {
        do {
            let gpxDocument = try GPXDocument.fromString(content: gpxString, options: GPXOptions())
            guard let gpxTrack = gpxDocument.tracks.first else {
                return nil
            }
            return gpxTrack
        } catch {
            print("No data found")
        }
        return nil
    }
    
    private func showDialog(title: String, message: String) {
        // To ensure this runs on the main thread
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
                let alert = UIAlertController(
                    title: title,
                    message: message,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                    alert.dismiss(animated: true, completion: nil)
                }))
                rootViewController.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    func startTracking(_ gpxTrack: GPXTrack) {
        do {
            // Without a route set, this starts tracking mode.
            navigator = try Navigator()
        } catch {
            print("Initialization failed")
        }

        // For this example, we listen only to a few selected events, such as speed limits along the current road.
        setupSelectedEventHandlers();
        
        // `Navigator` acts as `LocationListener` to receive location updates directly from a location provider.
        // Any progress along the simulate locations is a result of getting a new location fed into the Navigator.
        setupLocationSource(gpxTrack: gpxTrack)
    }

    func setupSelectedEventHandlers() {
        // Notifies whenever any textual attribute of the current road changes, i.e., the current road texts differ
        // from the previous one. This can be useful during tracking mode, when no maneuver information is provided.
        navigator?.roadTextsDelegate = self

        // Notifies on the current speed limit valid on the current road.
        navigator?.speedLimitDelegate = self
    }
    
    func setupLocationSource(gpxTrack: GPXTrack) {
        do {
            let locationSimulatorOptions = LocationSimulatorOptions(speedFactor: 15, notificationInterval: 0.5)
            locationSimulator = try LocationSimulator(gpxTrack: gpxTrack, options: locationSimulatorOptions)
            locationSimulator?.delegate = self
            locationSimulator?.start()
        } catch {
            print("Error setting up location simulator")
        }
    }
}
