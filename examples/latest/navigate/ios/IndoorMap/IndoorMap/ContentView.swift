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

struct ContentView: View {

    @State private var mapView = MapView()
    @StateObject private var indoorMapExample: IndoorMapExample
    @State private var drawerHeight: CGFloat = 105
    @State private var searchText: String = ""
    @State private var keyboardHeight: CGFloat = 0

    private var maxDrawerHeight: CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        let bottomInset = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 0
        let availableHeight = screenHeight - bottomInset
        if keyboardHeight > 0 {
            return availableHeight - keyboardHeight + bottomInset
        }
        return availableHeight
    }

    init() {
        let mapView = MapView()
        _mapView = State(initialValue: mapView)
        _indoorMapExample = StateObject(wrappedValue: IndoorMapExample(mapView))
    }

    var body: some View {
        ZStack {
            WrappedMapView(mapView: $mapView)

            // Top Panel - shown when venue is loaded
            if indoorMapExample.venueLoaded {
                TopPanelView(indoorMapExample: indoorMapExample)
            }

            // Level Switcher & Drawing Switcher - right side
            if indoorMapExample.venueLoaded && indoorMapExample.levelSwitcherModel.isVisible {
                VStack {
                    Spacer()

                    HStack {
                        Spacer()

                        VStack(alignment: .center, spacing: 20) {
                            LevelSwitcherView(model: indoorMapExample.levelSwitcherModel)

                            if indoorMapExample.drawingSwitcherModel.isVisible {
                                DrawingSwitcherButton(model: indoorMapExample.drawingSwitcherModel)
                                    .frame(width: 60)
                                    .overlay(
                                        Group {
                                            if indoorMapExample.drawingSwitcherModel.showList {
                                                DrawingSwitcherListView(model: indoorMapExample.drawingSwitcherModel)
                                                    .fixedSize(horizontal: true, vertical: true)
                                                    .offset(x: -70, y: -10)
                                            }
                                        }, alignment: .bottomTrailing
                                    )
                            }
                        }
                        .padding(.trailing, 15)
                    }

                    Spacer()
                }
            }

            // Bottom Drawer (hidden when routing UI is active)
            if indoorMapExample.indoorRoutingViewModel.currentState == .closed {
                BottomDrawerView(
                    indoorMapExample: indoorMapExample,
                    mapView: mapView,
                    drawerHeight: $drawerHeight,
                    searchText: $searchText,
                    keyboardHeight: $keyboardHeight
                )
            }

            // Centered loading overlay when a venue is being loaded
            if indoorMapExample.isLoadingSelectedVenue {
                VenueLoadingSpinner()
            }

            // Centered loading overlay when a route is being calculated
            if indoorMapExample.indoorRoutingHandler.isCalculatingRoute {
                VenueLoadingSpinner()
            }

            // Route error banner
            if let routeError = indoorMapExample.indoorRoutingViewModel.routeError {
                RouteErrorBanner(message: routeError) {
                    indoorMapExample.indoorRoutingHandler.routeError = nil
                }
            }

            // Topology Details - bottom sheet shown when a topology is tapped
            if indoorMapExample.venueTapHandler?.isTopologyTapped == true,
               let topology = indoorMapExample.venueTapHandler?.selectedTopology {
                VStack {
                    Spacer()
                    TopologyDetailsView(topology: topology)
                }
                .transition(.move(edge: .bottom))
                .animation(.spring(), value: indoorMapExample.venueTapHandler?.isTopologyTapped)
            }

            // Routing bottom sheet (for venues with topologies)
            if indoorMapExample.indoorRoutingViewModel.currentState != .closed {
                RoutingBottomSheetView(indoorMapExample: indoorMapExample)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: indoorMapExample.isLoadingVenues) { isLoading in
            if isLoading && drawerHeight == 105 {
                withAnimation(.spring()) {
                    drawerHeight = maxDrawerHeight
                }
                indoorMapExample.updateWatermarkPosition(drawerHeight: maxDrawerHeight)
            }
        }
        .onChange(of: indoorMapExample.venueTapHandler?.isGeometryTapped) { isTapped in
            if isTapped == true && indoorMapExample.indoorRoutingViewModel.currentState == .closed {
                withAnimation(.spring()) {
                    drawerHeight = 180
                }
                indoorMapExample.updateWatermarkPosition(drawerHeight: 180)
            } else if isTapped != true && drawerHeight == 180 {
                withAnimation(.spring()) {
                    drawerHeight = 105
                }
                indoorMapExample.updateWatermarkPosition(drawerHeight: 105)
            }
        }
        .onChange(of: indoorMapExample.venueTapHandler?.isTopologyTapped) { isTapped in
            if isTapped == true {
                indoorMapExample.updateWatermarkPosition(drawerHeight: 130)
            } else {
                indoorMapExample.updateWatermarkPosition(drawerHeight: drawerHeight)
            }
        }
        .onChange(of: indoorMapExample.indoorRoutingViewModel.currentState) { newState in
            if newState == .routingUI && indoorMapExample.topologyVisible {
                indoorMapExample.toggleTopology()
            }
            switch newState {
            case .closed:
                // Routing dismissed - restore watermark based on the venue drawer height.
                indoorMapExample.updateWatermarkPosition(drawerHeight: drawerHeight)
            case .spaceSelected:
                // Space details sheet is open - lift the watermark above it.
                indoorMapExample.updateWatermarkPosition(drawerHeight: 110)
            case .routingUI:
                // Routing UI panel is open - lift the watermark above it.
                indoorMapExample.updateWatermarkPosition(drawerHeight: 110)
            case .showSpaceList:
                // Full-screen space list - lift the watermark to its highest allowed position.
                indoorMapExample.updateWatermarkPosition(drawerHeight: UIScreen.main.bounds.height)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            drawerHeight = 105
            indoorMapExample.updateWatermarkPosition(drawerHeight: 105)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation(.spring()) {
                    keyboardHeight = frame.height
                    if drawerHeight > maxDrawerHeight {
                        drawerHeight = maxDrawerHeight
                    }
                }
                indoorMapExample.updateWatermarkPosition(drawerHeight: drawerHeight)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.spring()) {
                keyboardHeight = 0
            }
            indoorMapExample.updateWatermarkPosition(drawerHeight: drawerHeight)
        }
        .alert("Authentication Error", isPresented: $indoorMapExample.showAuthError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(indoorMapExample.authErrorMessage)
        }
    }
}

// MARK: - Route Error Banner

private struct RouteErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            HStack {
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.leading, 15)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.trailing, 12)
            }
            .frame(height: 56)
            .background(Color(red: 0.812, green: 0, blue: 0.102))
            .cornerRadius(10)
            .padding(.horizontal, 10)
            .padding(.top, 60)

            Spacer()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
