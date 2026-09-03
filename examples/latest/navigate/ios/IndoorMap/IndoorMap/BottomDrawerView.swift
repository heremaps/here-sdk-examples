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

/// The draggable bottom drawer containing search, venue list, and space list.
struct BottomDrawerView: View {
    @ObservedObject var indoorMapExample: IndoorMapExample
    let mapView: MapView

    @Binding var drawerHeight: CGFloat
    @Binding var searchText: String
    @Binding var keyboardHeight: CGFloat

    @State private var lastDragTranslation: CGFloat = 0

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

    var body: some View {
        VStack(spacing: 0) {
            // Drag Handle - draggable area for the drawer
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color(.systemGray4))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                // Search Bar
                HStack(spacing: 0) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 17))
                        .padding(.leading, 16)
                        .padding(.trailing, 8)

                    TextField(indoorMapExample.venueLoaded ? "Search for spaces" : "Search for venues", text: $searchText, onEditingChanged: { isEditing in
                        if isEditing {
                            drawerHeight = maxDrawerHeight
                            indoorMapExample.updateWatermarkPosition(drawerHeight: drawerHeight)
                        }
                    })
                        .font(.system(size: 18))

                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 17))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.trailing, 16)
                    }
                }
                .frame(height: 50)
                .background(Color.white)
                .cornerRadius(25)
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.black, lineWidth: 1)
                )
                .padding(.horizontal, 10)
                .padding(.top, 4)
                .padding(.bottom, 20)
            }
            .contentShape(Rectangle())
            .background(Color.white)
            .highPriorityGesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        let delta = value.translation.height - lastDragTranslation
                        lastDragTranslation = value.translation.height
                        let newHeight = drawerHeight - delta
                        drawerHeight = max(105, min(newHeight, maxDrawerHeight))
                        indoorMapExample.updateWatermarkPosition(drawerHeight: drawerHeight)
                    }
                    .onEnded { value in
                        lastDragTranslation = 0
                        let halfScreen = maxDrawerHeight / 2

                        withAnimation(.spring()) {
                            if drawerHeight > halfScreen {
                                drawerHeight = maxDrawerHeight
                            } else {
                                drawerHeight = 105
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                        }
                        indoorMapExample.updateWatermarkPosition(drawerHeight: drawerHeight)
                    }
            )

            // Content area - Loading spinner or Venue/Space list
            if drawerHeight > 105 {
                if indoorMapExample.isLoadingVenues {
                    VStack {
                        Spacer()
                        VenueLoadingSpinner()
                        Spacer()
                    }
                    .frame(height: drawerHeight - 105)
                } else if indoorMapExample.venueTapHandler?.isGeometryTapped == true,
                          let geometry = indoorMapExample.venueTapHandler?.selectedGeometry {
                    // Venue without topologies - show simple space details
                    SpaceDetailsContentView(geometry: geometry)
                        .frame(height: drawerHeight - 105, alignment: .top)
                } else if indoorMapExample.venueLoaded {
                    // Spaces List - shown when venue is loaded
                    SpacesListView(
                        indoorMapExample: indoorMapExample,
                        mapView: mapView,
                        searchText: $searchText,
                        drawerHeight: $drawerHeight
                    )
                    .frame(height: drawerHeight - 105)
                } else {
                    // Venue List
                    VenueListView(
                        indoorMapExample: indoorMapExample,
                        searchText: $searchText,
                        drawerHeight: $drawerHeight
                    )
                    .frame(height: drawerHeight - 105)
                }
            }
        }
        .background(
            Color.white
                .cornerRadius(20, corners: [.topLeft, .topRight])
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -5)
        )
        .clipShape(RoundedCorner(radius: 20, corners: [.topLeft, .topRight]))
        .frame(maxWidth: .infinity)
        .frame(height: drawerHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(
            VStack(spacing: 0) {
                Spacer()
                Color.white
                    .frame(height: 50)
            }
            .edgesIgnoringSafeArea(.bottom)
        )
    }
}

// MARK: - Space Details (tapped geometry without topologies)

private struct SpaceDetailsContentView: View {
    let geometry: VenueGeometry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Image("spacenameimage")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 21, height: 31)
                    .padding(.leading, 4)

                VStack(alignment: .leading, spacing: 2) {
                    let spaceName = geometry.name.isEmpty ? geometry.identifier : geometry.name
                    Text(spaceName + ", " + geometry.level.name)
                        .font(.system(size: 20))
                        .foregroundColor(Color(red: 0, green: 0.039, blue: 0.098).opacity(0.8))
                        .multilineTextAlignment(.leading)

                    if let address = geometry.internalAddress?.address, !address.isEmpty {
                        Text(address)
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 0.031, green: 0.09, blue: 0.204).opacity(0.6))
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Spaces List (inside a loaded venue)

private struct SpacesListView: View {
    @ObservedObject var indoorMapExample: IndoorMapExample
    let mapView: MapView
    @Binding var searchText: String
    @Binding var drawerHeight: CGFloat

    var body: some View {
        let filteredSpaces = indoorMapExample.spacesList.filter { geometry in
            if searchText.isEmpty { return true }
            let searchTextLowercased = searchText.lowercased()
            let spaceNameStr = geometry.name.isEmpty ? geometry.identifier : geometry.name
            return spaceNameStr.lowercased().contains(searchTextLowercased)
                || geometry.level.name.lowercased().contains(searchTextLowercased)
        }
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(0..<filteredSpaces.count, id: \.self) { index in
                    let geometry = filteredSpaces[index]
                    Button {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        searchText = ""
                        if let venue = indoorMapExample.venueMap?.selectedVenue {
                            if indoorMapExample.hasTopologies {
                                if let tapHandler = indoorMapExample.venueTapHandler {
                                    tapHandler.selectGeometry(venue: venue, geometry: geometry, center: true)
                                    indoorMapExample.indoorRoutingViewModel.showSpaceSelection(
                                        geometry: geometry,
                                        venue: venue,
                                        mapView: mapView,
                                        tapHandler: tapHandler
                                    )
                                }
                                withAnimation(.spring()) {
                                    drawerHeight = 105
                                }
                                indoorMapExample.updateWatermarkPosition(drawerHeight: 105)
                            } else {
                                indoorMapExample.venueTapHandler?.selectGeometry(venue: venue, geometry: geometry, center: true)
                            }
                            indoorMapExample.objectWillChange.send()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image("spacenameimage")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 21, height: 31)
                                .padding(.leading, 4)

                            VStack(alignment: .leading, spacing: 2) {
                                let spaceName = geometry.name.isEmpty ? geometry.identifier : geometry.name
                                Text(spaceName + ", " + geometry.level.name)
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(red: 0, green: 0.039, blue: 0.098).opacity(0.8))
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                if let address = geometry.internalAddress?.address, !address.isEmpty {
                                    Text(address)
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(red: 0, green: 0.039, blue: 0.098).opacity(0.8))
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }

                            Image("spacerightarrow")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 21, height: 31)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white)
                    }

                    if index < filteredSpaces.count - 1 {
                        Divider()
                            .padding(.leading, 10)
                            .padding(.trailing, 10)
                    }
                }
            }
        }
    }
}

// MARK: - Venue List (before a venue is loaded)

private struct VenueListView: View {
    @ObservedObject var indoorMapExample: IndoorMapExample
    @Binding var searchText: String
    @Binding var drawerHeight: CGFloat

    var body: some View {
        let filteredIndices = indoorMapExample.venueNamesList.indices.filter { index in
            searchText.isEmpty || indoorMapExample.venueNamesList[index].localizedCaseInsensitiveContains(searchText)
        }
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredIndices, id: \.self) { index in
                    Button {
                        let venueId = indoorMapExample.venueMapList[index]
                        let venueName = indoorMapExample.venueNamesList[index]
                        indoorMapExample.loadVenue(venueIdentifier: venueId, venueName: venueName)
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        searchText = ""
                        withAnimation(.spring()) {
                            drawerHeight = 105
                        }
                        indoorMapExample.updateWatermarkPosition(drawerHeight: 105)
                    } label: {
                        HStack(spacing: 12) {
                            Image("indoor")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                                .padding(.leading, 4)

                            Text(indoorMapExample.venueNamesList[index])
                                .font(.system(size: 16))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Image("rightaccessory")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 12, height: 21)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(Color.white)
                    }

                    if index < filteredIndices.last ?? 0 {
                        Divider()
                            .padding(.leading, 10)
                            .padding(.trailing, 10)
                    }
                }
            }
        }
    }
}
