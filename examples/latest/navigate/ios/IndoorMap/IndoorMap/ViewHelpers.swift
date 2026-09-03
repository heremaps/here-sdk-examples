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
    func makeUIView(context: Context) -> MapView { return mapView }
    func updateUIView(_ mapView: MapView, context: Context) { }
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
