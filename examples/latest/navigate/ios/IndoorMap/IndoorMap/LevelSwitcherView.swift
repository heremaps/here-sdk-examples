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

/// Manages level switching state for a venue, observing VenueMap changes.
class LevelSwitcherModel: ObservableObject {
    private weak var venueMap: VenueMap?
    
    // Levels displayed in reversed order (highest level at top)
    @Published var levels: [String] = []
    @Published var currentLevelIndex: Int32 = -1
    @Published var isVisible = false
    
    func setVenueMap(_ venueMap: VenueMap?) {
        self.venueMap = venueMap
        // Register as a delegate to observe drawing and level changes
        venueMap?.addDrawingSelectionDelegate(self)
        venueMap?.addLevelSelectionDelegate(self)
    }
    
    deinit {
        venueMap?.removeDrawingSelectionDelegate(self)
        venueMap?.removeLevelSelectionDelegate(self)
    }
    
    /// Set up levels from the selected venue's current drawing.
    func setup(with venue: Venue?) {
        currentLevelIndex = -1
        levels.removeAll()
        
        guard let drawing = venue?.selectedDrawing else {
            isVisible = false
            return
        }
        
        // Add level short names in reversed order (highest at top)
        let venueLevels = drawing.levels
        for level in venueLevels.reversed() {
            levels.append(level.shortName)
        }
        
        currentLevelIndex = venue?.selectedLevelIndex ?? -1
        isVisible = currentLevelIndex != -1
    }
    
    /// Move one level up (higher floor).
    func goUp() {
        guard let venue = venueMap?.selectedVenue else { return }
        let totalLevels = Int32(levels.count)
        if currentLevelIndex < totalLevels - 1 {
            currentLevelIndex += 1
            venue.selectedLevelIndex = currentLevelIndex
        }
    }
    
    /// Move one level down (lower floor).
    func goDown() {
        guard let venue = venueMap?.selectedVenue else { return }
        if currentLevelIndex > 0 {
            currentLevelIndex -= 1
            venue.selectedLevelIndex = currentLevelIndex
        }
    }
    
    /// Select a specific level by tapping on it in the list.
    func selectLevel(at displayIndex: Int) {
        guard let venue = venueMap?.selectedVenue else { return }
        // Display is reversed: first item in list = highest level
        let levelIndex = Int32(levels.count - displayIndex - 1)
        currentLevelIndex = levelIndex
        venue.selectedLevelIndex = currentLevelIndex
    }
    
    /// Get the display index (row in list) for the current level.
    var selectedDisplayIndex: Int {
        guard currentLevelIndex >= 0 else { return -1 }
        return levels.count - Int(currentLevelIndex) - 1
    }
}

// MARK: - VenueDrawingSelectionDelegate
extension LevelSwitcherModel: VenueDrawingSelectionDelegate {
    /// When a new drawing is selected (e.g. from structure switcher), rebuild levels for the new drawing.
    func onDrawingSelected(venue: Venue, deselectedDrawing: VenueDrawing?, selectedDrawing: VenueDrawing) {
        DispatchQueue.main.async { [weak self] in
            self?.setup(with: venue)
        }
    }
}

// MARK: - VenueLevelSelectionDelegate
extension LevelSwitcherModel: VenueLevelSelectionDelegate {
    /// When a level is selected (e.g. from space list selection), update currentLevelIndex.
    func onLevelSelected(venue: Venue, drawing: VenueDrawing, deselectedLevel: VenueLevel?, selectedLevel: VenueLevel) {
        DispatchQueue.main.async { [weak self] in
            self?.currentLevelIndex = venue.selectedLevelIndex
        }
    }
}

/// SwiftUI view for the level switcher — matching UIKit's 50pt wide stack with up/down arrows and level list.
struct LevelSwitcherView: View {
    @ObservedObject var model: LevelSwitcherModel

    // Track press state for splash effect on arrows
    @State private var upArrowPressed = false
    @State private var downArrowPressed = false

    var body: some View {
        VStack(spacing: 0) {
            // Up arrow - 50x50 with splash effect on press
            Button(action: {
                withAnimation(.easeOut(duration: 0.15)) { upArrowPressed = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.easeIn(duration: 0.15)) { upArrowPressed = false }
                }
                model.goUp()
            }) {
                Image("up-arrow-level-switcher_png")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(Color.gray.opacity(upArrowPressed ? 0.3 : 0.0))
                            .scaleEffect(upArrowPressed ? 1.0 : 0.5)
                            .animation(.easeOut(duration: 0.2), value: upArrowPressed)
                    )
            }
            .disabled(model.currentLevelIndex >= Int32(model.levels.count) - 1)

            // Divider between up arrow and level list
            Divider()

            // Level list
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(0..<model.levels.count, id: \.self) { index in
                            Button(action: {
                                model.selectLevel(at: index)
                            }) {
                                Text(model.levels[index])
                                    .font(.system(size: 16))
                                    .fontWeight(index == model.selectedDisplayIndex ? .semibold : .regular)
                                    .foregroundColor(index == model.selectedDisplayIndex ? Color(red: 0.069, green: 0.43, blue: 0.971) : .primary)
                                    .frame(width: 50, height: 44)
                                    .background(
                                        index == model.selectedDisplayIndex
                                            ? Color.gray.opacity(0.25)
                                            : Color.clear
                                    )
                            }
                            .id(index)
                        }
                    }
                }
                .frame(height: min(CGFloat(model.levels.count) * 44, 145))
                .onAppear {
                    if model.selectedDisplayIndex >= 0 {
                        proxy.scrollTo(model.selectedDisplayIndex, anchor: .center)
                    }
                }
                .onChange(of: model.selectedDisplayIndex) { newIndex in
                    withAnimation {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }

            // Divider between level list and down arrow
            Divider()

            // Down arrow - 50x50 with splash effect on press
            Button(action: {
                withAnimation(.easeOut(duration: 0.15)) { downArrowPressed = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.easeIn(duration: 0.15)) { downArrowPressed = false }
                }
                model.goDown()
            }) {
                Image("down-arrow-level-switcher_png")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(Color.gray.opacity(downArrowPressed ? 0.3 : 0.0))
                            .scaleEffect(downArrowPressed ? 1.0 : 0.5)
                            .animation(.easeOut(duration: 0.2), value: downArrowPressed)
                    )
            }
            .disabled(model.currentLevelIndex <= 0)
        }
        .frame(width: 50)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
