/*
 * Copyright (C) 2020-2026 HERE Europe B.V.
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

/// Manages drawing/structure switching state for a venue.
class DrawingSwitcherModel: ObservableObject {
    private weak var venueMap: VenueMap?
    
    @Published var structureNames: [String] = []
    @Published var selectedStructureName: String = ""
    @Published var isVisible = false
    @Published var showList = false
    
    /// Callback invoked when a structure is selected from the list.
    /// Provides the selected drawing's center coordinates for camera movement.
    var onStructureSelected: ((GeoCoordinates) -> Void)?
    
    func setVenueMap(_ venueMap: VenueMap?) {
        self.venueMap = venueMap
        // Register as delegate to track drawing changes
        venueMap?.addDrawingSelectionDelegate(self)
    }
    
    deinit {
        venueMap?.removeDrawingSelectionDelegate(self)
    }
    
    /// Populate structure names from the loaded venue's drawings.
    func setup(with venue: Venue?) {
        structureNames.removeAll()
        showList = false
        selectedStructureName = ""
        
        guard let venue = venue else {
            isVisible = false
            return
        }
        
        let drawings: [VenueDrawing] = venue.venueModel.drawings
        for drawing in drawings {
            structureNames.append(drawing.properties["name"]?.string ?? "")
        }
        
        // Track currently selected drawing name
        selectedStructureName = venue.selectedDrawing.properties["name"]?.string ?? ""
        
        // Always show the structure switcher button regardless of drawing count
        isVisible = true
    }
    
    /// Select a structure/drawing by name.
    func selectStructure(_ name: String) {
        guard let venue = venueMap?.selectedVenue else { return }
        let structures: [VenueDrawing] = venue.venueModel.drawings
        for structure in structures {
            if let structureName = structure.properties["name"]?.string, structureName == name {
                venue.selectedDrawing = structure
                selectedStructureName = name
                // Move camera to the selected structure's centre
                let center = structure.center
                onStructureSelected?(center)
                break
            }
        }
        showList = false
    }
    
    // Toggle the structure list visibility.
    func toggleList() {
        showList.toggle()
    }
    
    // Close the list.
    func closeList() {
        showList = false
    }
}

// MARK: - VenueDrawingSelectionDelegate
extension DrawingSwitcherModel: VenueDrawingSelectionDelegate {
    /// Update the selected structure name when drawing changes (e.g. from external level/space selection).
    func onDrawingSelected(venue: Venue, deselectedDrawing: VenueDrawing?, selectedDrawing: VenueDrawing) {
        DispatchQueue.main.async { [weak self] in
            self?.selectedStructureName = selectedDrawing.properties["name"]?.string ?? ""
        }
    }
}

/// Structure switcher button — shows the building icon, tappable to open the list.
struct DrawingSwitcherButton: View {
    @ObservedObject var model: DrawingSwitcherModel
    
    var body: some View {
        Button(action: {
            model.toggleList()
        }) {
            Image("structure-switch")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
        }
    }
}

/// Structure list that grows upward from the button's bottom edge.
struct DrawingSwitcherListView: View {
    @ObservedObject var model: DrawingSwitcherModel
    
    // Highlight color matching UIKit level switcher selection: UIColor(red: 0.069, green: 0.43, blue: 0.971, alpha: 0.05)
    private let highlightColor = Color(red: 0.069, green: 0.43, blue: 0.971).opacity(0.05)
    
    var body: some View {
        let itemHeight: CGFloat = 48 // approximate height per item (14 + 14 padding + text)
        let maxVisibleItems = 4
        let needsScroll = model.structureNames.count > maxVisibleItems
        
        ScrollView {
            VStack(spacing: 0) {
                ForEach(0..<model.structureNames.count, id: \.self) { index in
                    Button(action: {
                        model.selectStructure(model.structureNames[index])
                    }) {
                        Text(model.structureNames[index])
                            .font(.system(size: 16))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(
                                model.structureNames[index] == model.selectedStructureName
                                    ? highlightColor
                                    : Color.clear
                            )
                    }
                    
                    if index < model.structureNames.count - 1 {
                        Divider()
                            .padding(.horizontal, 10)
                    }
                }
            }
        }
        .frame(width: 200)
        .frame(maxHeight: needsScroll ? itemHeight * CGFloat(maxVisibleItems) : nil)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 2)
    }
}
