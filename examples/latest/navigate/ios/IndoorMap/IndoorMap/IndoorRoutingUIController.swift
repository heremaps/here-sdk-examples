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

import heresdk
import SwiftUI
import Combine

/// States for the indoor routing bottom sheet
enum IndoorRoutingState {
    case closed
    case spaceSelected
    case routingUI
    case showSpaceList
}

/// Space selection state for routing
enum SpaceSelectionState {
    case selectingArrival
    case selectingDeparture
}

/// ViewModel managing the indoor routing UI state
class IndoorRoutingViewModel: ObservableObject {
    @Published var currentState: IndoorRoutingState = .closed
    @Published var spaceSelectionState: SpaceSelectionState = .selectingArrival
    @Published var selectedArrivalGeometry: VenueGeometry?
    @Published var selectedDepartureGeometry: VenueGeometry?
    @Published var searchText: String = ""
    @Published var routeError: String?

    weak var selectedVenue: Venue?
    weak var mapView: MapView?
    weak var venueTapHandler: VenueTapHandler?

    var indoorRoutingHandler: IndoorRoutingHandler? {
        didSet {
            handlerCancellable = indoorRoutingHandler?.$routeError
                .receive(on: DispatchQueue.main)
                .sink { [weak self] error in self?.routeError = error }
        }
    }
    private var handlerCancellable: AnyCancellable?
    var markerImage: MapImage?
    var marker: MapMarker?
    var iconApplied = false

    /// Exact tapped coordinates for departure (nil means use geometry center)
    var departureCoordinates: GeoCoordinates?
    /// Exact tapped coordinates for arrival (nil means use geometry center)
    var arrivalCoordinates: GeoCoordinates?

    /// All geometries from the selected venue (for space list)
    var allGeometries: [VenueGeometry] {
        selectedVenue?.venueModel.geometries ?? []
    }

    /// Filtered geometries based on search text
    var filteredGeometries: [VenueGeometry] {
        if searchText.isEmpty {
            return allGeometries
        }
        let searchLower = searchText.lowercased()
        return allGeometries.filter {
            let displayName = $0.name.isEmpty ? $0.identifier : $0.name
            return displayName.lowercased().contains(searchLower)
                || $0.level.name.lowercased().contains(searchLower)
        }
    }

    /// Called when a space is selected (tapped) on a venue with topologies
    func showSpaceSelection(geometry: VenueGeometry, venue: Venue, mapView: MapView, tapHandler: VenueTapHandler) {
        self.selectedArrivalGeometry = geometry
        self.selectedVenue = venue
        self.mapView = mapView
        self.venueTapHandler = tapHandler
        self.currentState = .spaceSelected
    }

    /// Close the space selection view
    func closeSpaceSelection() {
        currentState = .closed
        if iconApplied, let currentMarker = marker {
            mapView?.mapScene.removeMapMarker(currentMarker)
            iconApplied = false
        }
        venueTapHandler?.deselectGeometry()
    }

    /// Transition to routing UI state
    func openRoutingUI() {
        currentState = .routingUI
        selectedVenue?.isTopologyVisible = false
        // Remove highlight from selected geometry
        if let geometry = selectedArrivalGeometry, let venue = selectedVenue {
            venue.setCustomStyle(geometries: [geometry], style: nil, labelStyle: nil)
        }
    }

    /// Close routing UI and return to space selected state
    func closeRoutingUI() {
        currentState = .spaceSelected
        selectedDepartureGeometry = nil
        departureCoordinates = nil
        arrivalCoordinates = nil
        indoorRoutingHandler?.stopRouting()
        // Re-highlight the arrival geometry with marker if it's icon type
        if let geometry = selectedArrivalGeometry {
            if geometry.lookupType == .icon {
                if let image = getMarkerImage() {
                    marker = MapMarker(at: geometry.center,
                                       image: image,
                                       anchor: Anchor2D(horizontal: 0.5, vertical: 1.0))
                    if let marker = marker {
                        mapView?.mapScene.addMapMarker(marker)
                        iconApplied = true
                    }
                }
            }
        }
    }

    /// Show space list for selecting departure or arrival
    func showSpaceList(for selection: SpaceSelectionState) {
        spaceSelectionState = selection
        searchText = ""
        currentState = .showSpaceList
    }

    /// Called when a space is picked from the space list (uses geometry center)
    func selectSpace(_ geometry: VenueGeometry) {
        if spaceSelectionState == .selectingDeparture {
            selectedDepartureGeometry = geometry
            departureCoordinates = nil // Use center of space
        } else {
            selectedArrivalGeometry = geometry
            arrivalCoordinates = nil // Use center of space
        }

        // Switch level and center map
        if let departure = selectedDepartureGeometry {
            selectedVenue?.selectedLevel = departure.level
            mapView?.camera.lookAt(point: departure.center)
        }

        // If both waypoints are set, start routing
        if let source = selectedDepartureGeometry, let destination = selectedArrivalGeometry {
            indoorRoutingHandler?.startRouting(
                source: source, destination: destination,
                sourceCoordinates: departureCoordinates,
                destinationCoordinates: arrivalCoordinates)
        }

        // Collapse back to routing UI
        searchText = ""
        currentState = .routingUI
    }

    /// Dismiss the entire routing bottom sheet
    func dismiss() {
        currentState = .closed
        selectedDepartureGeometry = nil
        departureCoordinates = nil
        arrivalCoordinates = nil
        indoorRoutingHandler?.stopRouting()
        if iconApplied, let currentMarker = marker {
            mapView?.mapScene.removeMapMarker(currentMarker)
            iconApplied = false
        }
        venueTapHandler?.deselectGeometry()
    }

    func getMarkerImage() -> MapImage? {
        if let image = markerImage {
            return image
        }
        if let image = UIImage(named: "poi"), let pngData = image.pngData() {
            markerImage = MapImage(pixelData: pngData, imageFormat: .png)
        }
        return markerImage
    }
}

// MARK: - Space Selection View

/// Space Selection View - shows space name, address, close button, and Directions button
struct SpaceSelectionView: View {
    @ObservedObject var viewModel: IndoorRoutingViewModel

    var body: some View {
        if let geometry = viewModel.selectedArrivalGeometry {
            VStack(alignment: .leading, spacing: 0) {
                // Space name
                let name: String = {
                    if !geometry.name.isEmpty {
                        return geometry.name + ", " + geometry.level.name
                    } else {
                        return geometry.identifier + ", " + geometry.level.name
                    }
                }()

                Text(name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.trailing, 40)

                // Address - 5pt below name
                if let address = geometry.internalAddress?.address, !address.isEmpty {
                    Text(address)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .padding(.top, 5)
                }

                // Directions button - 10pt below address, height 40, cornerRadius 20
                Button(action: {
                    viewModel.openRoutingUI()
                }) {
                    Text("Directions")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: "69AdF8"),
                                    Color(hex: "53D9D0")
                                ]),
                                startPoint: .bottomLeading,
                                endPoint: .topTrailing
                            )
                        )
                        .cornerRadius(20)
                }
                .padding(.top, 15)
                .padding(.bottom, 30)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
        }
    }
}

// MARK: - Indoor Routing View

/// Indoor Routing View - shows departure/arrival rows with close button
struct IndoorRoutingView: View {
    @ObservedObject var viewModel: IndoorRoutingViewModel
    var onDepartureTapped: () -> Void = {}
    var onArrivalTapped: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Departure row
            Button(action: onDepartureTapped) {
                HStack(spacing: 5) {
                    Image(systemName: "smallcircle.filled.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.black)
                        .frame(width: 20, height: 20)
                        .padding(.leading, 10)

                    Text(viewModel.selectedDepartureGeometry != nil
                         ? departureName
                         : "Choose a starting point")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Color(hex: "53D9D0"))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)

                    Spacer()
                }
                .padding(.trailing, 40)
                .frame(minHeight: 40)
            }

            // Separator
            Rectangle()
                .fill(Color(.systemGray6))
                .frame(height: 2)
                .padding(.leading, 35)
                .padding(.trailing, 80)

            // Arrival row
            Button(action: onArrivalTapped) {
                HStack(spacing: 5) {
                    Image("indoor_destination")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .padding(.leading, 10)

                    Text(arrivalName)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.black)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)

                    Spacer()
                }
                .padding(.trailing, 40)
                .frame(minHeight: 40)
            }

        }
        .padding(.top, 10)
        .padding(.bottom, 30)
    }

    private var departureName: String {
        guard let geometry = viewModel.selectedDepartureGeometry else { return "" }
        if !geometry.name.isEmpty {
            return geometry.name + ", " + geometry.level.name
        } else {
            return geometry.identifier + ", " + geometry.level.name
        }
    }

    private var arrivalName: String {
        guard let geometry = viewModel.selectedArrivalGeometry else { return "" }
        if !geometry.name.isEmpty {
            return geometry.name + ", " + geometry.level.name
        } else {
            return geometry.identifier + ", " + geometry.level.name
        }
    }
}

// MARK: - Space List View

/// Full-screen searchable list of venue geometries for selecting departure/arrival space
struct RoutingSpaceListView: View {
    @ObservedObject var viewModel: IndoorRoutingViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 0) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 17))
                    .padding(.leading, 16)
                    .padding(.trailing, 8)

                TextField("Search for Spaces", text: $viewModel.searchText)
                    .font(.system(size: 18))

                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.searchText = ""
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
            .padding(.top, 10)
            .padding(.bottom, 10)

            // Geometry list
            ScrollView {
                LazyVStack(spacing: 0) {
                    let geometries = viewModel.filteredGeometries
                    ForEach(0..<geometries.count, id: \.self) { index in
                        let geometry = geometries[index]
                        Button {
                            // Dismiss keyboard
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.resignFirstResponder),
                                to: nil, from: nil, for: nil)
                            viewModel.selectSpace(geometry)
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
                                            .foregroundColor(Color(red: 0.031, green: 0.09, blue: 0.204).opacity(0.6))
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white)
                        }

                        if index < geometries.count - 1 {
                            Divider()
                                .padding(.leading, 10)
                                .padding(.trailing, 10)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Helper extension for hex color

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}
