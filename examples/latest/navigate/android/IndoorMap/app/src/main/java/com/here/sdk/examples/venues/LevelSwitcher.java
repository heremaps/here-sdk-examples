/*
 * Copyright (C) 2019-2022 HERE Europe B.V.
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

package com.here.sdk.examples.venues;

import android.content.Context;
import android.util.AttributeSet;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.ListView;

import com.here.sdk.venue.control.VenueDrawingSelectionListener;
import com.here.sdk.venue.control.VenueLevelSelectionListener;
import com.here.sdk.venue.control.VenueSelectionListener;
import com.here.sdk.venue.control.Venue;
import com.here.sdk.venue.control.VenueMap;
import com.here.sdk.venue.data.VenueDrawing;
import com.here.sdk.venue.data.VenueLevel;

import java.util.List;

// Allows to select a level inside a venue trough UI.
public class LevelSwitcher extends LinearLayout {
    private VenueMap venueMap = null;
    private VenueDrawing drawing = null;
    private int maxLevelIndex = -1;
    private ListView listView;

    public LevelSwitcher(Context context, AttributeSet attrs) {
        super(context, attrs);

        LayoutInflater.from(context).inflate(R.layout.level_switcher, this, true);
        listView = (ListView) getChildAt(0);
        // Select a level, if the user clicks on the item.
        listView.setOnItemClickListener((parent, view, position, id) -> {
            if (venueMap.getSelectedVenue() != null) {
                // Revers an index, as levels in LevelSwitcher appear in a different order
                venueMap.getSelectedVenue().setSelectedLevelIndex(maxLevelIndex - position);
            }
        });
        setVisibility(View.GONE);
    }

    // Sets a selected drawing of a new selected venue for this LevelSwitcher.
    private final VenueSelectionListener venueSelectionListener =
            (deselectedController, selectedController) -> setCurrentDrawing(
                    selectedController != null ? selectedController.getSelectedDrawing() : null);

    // Sets a new selected drawing for this LevelSwitcher.
    private final VenueDrawingSelectionListener drawingSelectionListener =
            (venue,
             deselectedController,
             selectedController) -> setCurrentDrawing(selectedController);

    // Sets a new selected level for this LevelSwitcher.
    private final VenueLevelSelectionListener levelChangeListener =
            (venue, drawing, oldLevel, newLevel)
                    -> setSelectedLevelIndex(venue.getSelectedLevelIndex());

    public void setVenueMap(VenueMap venueMap) {
        if (this.venueMap == venueMap) {
            return;
        }

        // Remove old venue map listeners.
        removeListeners();
        // Set VenueMap for this LevelSwitcher.
        this.venueMap = venueMap;
        drawing = null;

        setVisibility(View.GONE);

        if (this.venueMap != null) {
            this.venueMap.add(venueSelectionListener);
            this.venueMap.add(drawingSelectionListener);
            this.venueMap.add(levelChangeListener);

            // Set a selected drawing if a venue is selected.
            Venue venue = this.venueMap.getSelectedVenue();
            if (venue != null) {
                setCurrentDrawing(venue.getSelectedDrawing());
            }
        }
    }

    @Override
    protected void finalize() throws Throwable {
        removeListeners();
        super.finalize();
    }

    private void removeListeners() {
        if (venueMap != null) {
            venueMap.remove(venueSelectionListener);
            venueMap.remove(drawingSelectionListener);
            venueMap.remove(levelChangeListener);
        }
    }

    private void setCurrentDrawing(final VenueDrawing drawing) {
        if (this.drawing == drawing) {
            return;
        }
        this.drawing = drawing;
        if (drawing != null) {
            // Set a new level adapter with the list of levels.
            List<VenueLevel> levels = drawing.getLevels();
            maxLevelIndex = levels.size() - 1;
            LevelAdapter adapter = new LevelAdapter(levels);
            listView.setAdapter(adapter);
            setVisibility(View.VISIBLE);
            adapter.notifyDataSetChanged();

            // Set a currently selected level if there is the selected venue.
            Venue venue = venueMap.getSelectedVenue();
            if (venue!= null)
                setSelectedLevelIndex(venue.getSelectedLevelIndex());
        } else {
            setVisibility(View.GONE);
        }
    }

    private void setSelectedLevelIndex(int levelIndex) {
        // Revers an index, as levels in LevelSwitcher appear in a different order
        int index = maxLevelIndex - levelIndex;

        int checkedItemPosition = listView.getCheckedItemPosition();
        if (checkedItemPosition == index) {
            return;
        }

        listView.smoothScrollToPosition(index);
        listView.setItemChecked(index, true);
    }
}
