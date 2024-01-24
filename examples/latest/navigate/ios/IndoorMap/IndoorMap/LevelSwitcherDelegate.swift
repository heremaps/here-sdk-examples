/*
* Copyright (C) 2020 HERE Europe B.V.
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

class LevelSwitcherDelegate: VenueSelectionDelegate, VenueDrawingSelectionDelegate, VenueLevelSelectionDelegate {
    private(set) weak var levelSwitcher: LevelSwitcher?
    var viewController: ViewController?

    init(levelSwitcher: LevelSwitcher) {
        self.levelSwitcher = levelSwitcher
    }
    
    init(viewController: ViewController) {
        self.viewController = viewController
    }

    func updateLevelSwitcherVenue(_ venue: Venue?) {
        weak var wself = self
        DispatchQueue.main.async {
            guard let sself = wself else {
                return
            }
            sself.levelSwitcher?.setup(with: venue)
        }
    }

    // Sets a selected drawing for this LevelSwitcher.
    func onDrawingSelected(venue: Venue, deselectedDrawing: VenueDrawing?, selectedDrawing: VenueDrawing) {
        if levelSwitcher == nil {
            return
        }

        updateLevelSwitcherVenue(venue)
    }

    // Sets a selected venue for this LevelSwitcher.
    func onSelectedVenueChanged(deselectedVenue: Venue?, selectedVenue: Venue?) {
        updateLevelSwitcherVenue(selectedVenue)
    }

    // Sets a new selected level for this LevelSwitcher.
    func onLevelSelected(venue: Venue,
                         drawing: VenueDrawing,
                         deselectedLevel: VenueLevel?,
                         selectedLevel: VenueLevel) {
        DispatchQueue.main.async { [weak self] in
            self?.levelSwitcher?.setCurrentLevel(venue.selectedLevelIndex)
        }
    }
}
