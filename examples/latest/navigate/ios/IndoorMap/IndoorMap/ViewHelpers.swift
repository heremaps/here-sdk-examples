/*
 * Copyright (C) 2022-2026 HERE Europe B.V.
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

// MARK: - WrappedMapView

/// The MapView provided by the HERE SDK conforms to a UIKit view, so it needs to be wrapped to conform
/// to a SwiftUI view. The map view is created in the ContentView and bound here.
struct WrappedMapView: UIViewRepresentable {
    @Binding var mapView: MapView
    func makeUIView(context: Context) -> MapView {
        #if targetEnvironment(simulator)
        context.coordinator.installTrackpadRecognizers(on: mapView)
        #endif
        return mapView
    }
    func updateUIView(_ mapView: MapView, context: Context) { }
    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        #if targetEnvironment(simulator)
        private weak var mapView: MapView?
        private var lastScale: CGFloat = 1.0
        private var lastRotation: CGFloat = 0.0

        /// Xcode 27 Device Hub can no longer send a two-finger touch to the simulator, but it forwards
        /// Mac trackpad pinch and rotate gestures as transform events. A UIPinchGestureRecognizer and a
        /// UIRotationGestureRecognizer receive them, so they are used to zoom and rotate the map.
        /// Only needed (and only compiled) for simulator builds.
        func installTrackpadRecognizers(on mapView: MapView) {
            guard self.mapView == nil else { return }
            self.mapView = mapView
            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            pinch.delegate = self
            mapView.addGestureRecognizer(pinch)

            let rotation = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
            rotation.delegate = self
            mapView.addGestureRecognizer(rotation)
        }

        /// The HERE SDK expects the camera origin in pixels, while gesture recognizers report points.
        /// Without converting, the zoom/rotation origin is off and the map drifts away from the touch point.
        private func pixelPoint(_ point: CGPoint, in view: UIView) -> Point2D {
            let scale = Double(view.contentScaleFactor)
            return Point2D(x: Double(point.x) * scale, y: Double(point.y) * scale)
        }

        @objc private func handleRotation(_ recognizer: UIRotationGestureRecognizer) {
            guard let mapView = mapView else { return }
            switch recognizer.state {
            case .began:
                lastRotation = 0.0
            case .changed:
                // The recognizer reports a cumulative rotation in radians (clockwise is positive),
                // so apply only the change since the last event.
                let deltaDegrees = Double(recognizer.rotation - lastRotation) * 180.0 / Double.pi
                lastRotation = recognizer.rotation
                let location = recognizer.location(in: mapView)
                // Increasing the camera bearing turns the map counter-clockwise, so negate the delta
                // to make the map follow the fingers.
                mapView.camera.orbitBy(GeoOrientationUpdate(bearing: -deltaDegrees, tilt: 0),
                                       around: pixelPoint(location, in: mapView))
            default:
                break
            }
        }

        @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            guard let mapView = mapView else { return }
            switch recognizer.state {
            case .began:
                lastScale = 1.0
            case .changed:
                // The recognizer reports a cumulative scale, so apply only the change since the last event.
                guard recognizer.scale > 0 else { return }
                let delta = recognizer.scale / lastScale
                lastScale = recognizer.scale
                let location = recognizer.location(in: mapView)
                mapView.camera.zoomBy(Double(delta), around: pixelPoint(location, in: mapView))
            default:
                break
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            return true
        }
        #endif
    }
}

// MARK: - VenueLoadingSpinner

/// Venue loading spinner — matches UIKit's spinnerView (96x96 white rounded view with 48x48 rotating spinner image).
struct VenueLoadingSpinner: View {
    @State private var isRotating = 0.0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .frame(width: 96, height: 96)

            Image("spinner")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 48)
                .rotationEffect(.degrees(isRotating))
                .onAppear {
                    withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                        isRotating = 360.0
                    }
                }
        }
    }
}

// MARK: - RotatingSpinner

/// Rotating blue ring spinner — matching UIKit's spinnerImg rotation.
struct RotatingSpinner: View {
    @State private var isRotating = 0.0

    var body: some View {
        Circle()
            .trim(from: 0.0, to: 0.7)
            .stroke(
                Color.blue,
                style: StrokeStyle(lineWidth: 4, lineCap: .round)
            )
            .rotationEffect(.degrees(isRotating))
            .onAppear {
                withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                    isRotating = 360.0
                }
            }
    }
}

// MARK: - RoundedCorner

/// Shape that rounds only specified corners.
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - View Extension

extension View {
    /// Apply corner radius to specific corners only.
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}
