/*
 * Copyright (C) 2025-2026 HERE Europe B.V.
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

@main
struct VisualLaneGuidanceApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    init() {
        // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
        initializeHERESDK()
    }

    private func initializeHERESDK() {
        // Set your credentials for the HERE SDK. Note that this app requires the Navigate license
        // and a separate license to enable visual lane guidance.
        let accessKeyID = "YOUR_ACCESS_KEY_ID"
        let accessKeySecret = "YOUR_ACCESS_KEY_SECRET"
        let authenticationMode = AuthenticationMode.withKeySecret(accessKeyId: accessKeyID, accessKeySecret: accessKeySecret)
        let options = SDKOptions(authenticationMode: authenticationMode)
        try! SDKNativeEngine.makeSharedInstance(options: options)
    }
}

struct ContentView: View {
    @State private var mapView = MapView()
    @State private var example: VisualLaneGuidanceExample?
    @State private var currentMapScheme: MapScheme = .normalDay
    @State private var statusText = "Camera: not initialized | Map scheme: NORMAL DAY | Route: not selected"
    @State private var hasStartedExample = false

    var body: some View {
        ZStack(alignment: .top) {
            WrappedMapView(mapView: $mapView)
                .edgesIgnoringSafeArea(.all)

            VStack {
                HStack {
                    VLButton(title: "Calculate Chicago") {
                        runActionWithStatusUpdate { onError in
                            example?.calculateChicagoRoute(onError: onError)
                        }
                    }
                    VLButton(title: "Calculate Berlin") {
                        runActionWithStatusUpdate { onError in
                            example?.calculateBerlinRoute(onError: onError)
                        }
                    }
                }
                HStack {
                    VLButton(title: "Start guidance") {
                        runActionWithStatusUpdate { onError in
                            example?.startGuidance(onError: onError)
                        }
                    }
                    VLButton(title: "Stop guidance") {
                        example?.stopGuidance()
                        updateStatus()
                    }
                }
                HStack {
                    VLButton(title: "Transition camera") {
                        example?.useTransitionCameraBehavior()
                        updateStatus()
                    }
                    VLButton(title: "Automotive camera") {
                        example?.useAutomotiveCameraBehavior()
                        updateStatus()
                    }
                }
                HStack {
                    VLButton(title: "NORMAL DAY") {
                        setMapScheme(.normalDay)
                    }
                    VLButton(title: "CLUSTER DAY") {
                        setMapScheme(.clusterDay)
                    }
                }

                VLStatusTextView(message: statusText)
            }
            .padding(2)
            .padding(6)
        }
        .onAppear {
            // ContentView appeared, now we start the example.
            startExample(mapView)
        }
    }

    private func startExample(_ mapView: MapView) {
        if hasStartedExample {
            return
        }
        hasStartedExample = true

        let distanceInMeters = MapMeasure(kind: .distanceInMeters, value: 1000 * 10)
        mapView.camera.lookAt(
            point: GeoCoordinates(latitude: 37.53931, longitude: -122.05891),
            zoom: distanceInMeters)

        example = VisualLaneGuidanceExample(mapView: mapView)

        // Load the map scene using a map scheme to render the map with.
        mapView.mapScene.loadScene(mapScheme: currentMapScheme, completion: onLoadScene)
    }

    // Completion handler for loadScene().
    private func onLoadScene(mapError: MapError?) {
        guard mapError == nil else {
            showError("Error: Map scene not loaded, \(String(describing: mapError))")
            return
        }
        updateStatus()
    }

    private func updateStatus() {
        guard let example = example else {
            statusText = "Camera: not initialized | Map scheme: \(mapSchemeLabel(currentMapScheme)) | Route: not selected"
            return
        }

        let routeLabel: String
        switch example.getSelectedRoute() {
        case .chicago: routeLabel = "Chicago"
        case .berlin: routeLabel = "Berlin"
        case .none: routeLabel = "not selected"
        }
        statusText = "Camera: \(example.getCameraBehaviorStatus()) | Map scheme: \(mapSchemeLabel(currentMapScheme)) | Route: \(routeLabel)"
    }

    private func setMapScheme(_ mapScheme: MapScheme) {
        currentMapScheme = mapScheme
        mapView.mapScene.loadScene(mapScheme: mapScheme, completion: onLoadScene)
    }

    private func mapSchemeLabel(_ mapScheme: MapScheme) -> String {
        if mapScheme == .normalDay {
            return "NORMAL DAY"
        }
        if mapScheme == .clusterDay {
            return "CLUSTER DAY"
        }
        return "UNKNOWN"
    }

    private func runActionWithStatusUpdate(_ action: (@escaping (String) -> Void) -> Void) {
        var didReportError = false
        action { message in
            didReportError = true
            showError(message)
        }
        if !didReportError {
            updateStatus()
        }
    }

    private func showError(_ message: String) {
        statusText = message
    }
}

private struct WrappedMapView: UIViewRepresentable {
    @Binding var mapView: MapView

    func makeUIView(context: Context) -> MapView {
        return mapView
    }

    func updateUIView(_ uiView: MapView, context: Context) {
    }
}

private struct VLButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .padding()
                .background(Color(red: 0, green: 182 / 255, blue: 178 / 255))
                .foregroundColor(.white)
                .cornerRadius(5)
        }
    }
}

private struct VLStatusTextView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 14))
            .foregroundColor(.white)
            .padding()
            .background(Color.black.opacity(0.6))
            .cornerRadius(8)
            .multilineTextAlignment(.center)
    }
}
