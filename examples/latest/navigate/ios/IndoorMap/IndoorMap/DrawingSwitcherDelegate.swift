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

class DrawingSwitcherDelegate: VenueSelectionDelegate, VenueDrawingSelectionDelegate {
    private weak var drawingSwitcher: DrawingSwitcher?
    private weak var viewController: ViewController?

    init(drawingSwitcher: DrawingSwitcher) {
        self.drawingSwitcher = drawingSwitcher
    }
    
    init(viewController: ViewController) {
        self.viewController = viewController
    }

    func onDrawingSelected(venue: Venue, deselectedDrawing: VenueDrawing?, selectedDrawing: VenueDrawing) {
        update(venue)
    }

    func onSelectedVenueChanged(
        deselectedVenue deselectedController: Venue?, selectedVenue selectedController: Venue?) {
        if let selectedVenue = selectedController {
            update(selectedVenue)
        }
    }

    func update(_ venue: Venue) {
        drawingSwitcher?.updateDrawing(forVenue: venue)
    }

}
