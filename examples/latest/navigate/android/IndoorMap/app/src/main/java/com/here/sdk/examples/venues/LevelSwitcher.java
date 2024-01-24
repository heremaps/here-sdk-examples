/*
 * Copyright (C) 2019-2024 HERE Europe B.V.
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
import android.view.ViewGroup;
import android.widget.BaseAdapter;
import android.widget.ImageButton;
import android.widget.LinearLayout;
import android.widget.ListView;
import android.widget.RelativeLayout;
import android.widget.TextView;

import com.here.sdk.venue.control.VenueDrawingSelectionListener;
import com.here.sdk.venue.control.VenueLevelSelectionListener;
import com.here.sdk.venue.control.VenueSelectionListener;
import com.here.sdk.venue.control.Venue;
import com.here.sdk.venue.control.VenueMap;
import com.here.sdk.venue.data.VenueDrawing;
import com.here.sdk.venue.data.VenueLevel;

import java.util.ArrayList;
import java.util.List;

class LevelItemView extends RelativeLayout {
    private TextView textView;
    private View separator;

    public LevelItemView(Context context) {
        super(context);

        LayoutInflater.from(context).inflate(R.layout.level_item, this, true);
        textView = findViewById(R.id.levelName);
        separator = findViewById(R.id.levelGroundSep);
    }

    public void setText(CharSequence text) {
        textView.setText(text);
    }

    public void setShowSeparator(boolean isVisible) {
        separator.setVisibility(isVisible ? View.VISIBLE : View.INVISIBLE);
    }
}

class LevelAdapter extends BaseAdapter {
    private final List<VenueLevel> levels;

    LevelAdapter(List<VenueLevel> levels) {
        this.levels = new ArrayList<>();

        for (int i = levels.size() - 1; i >= 0; i--) {
            VenueLevel level = levels.get(i);
            this.levels.add(level);
        }
    }

    @Override
    public int getCount() {
        return levels.size();
    }

    @Override
    public Object getItem(int position) {
        return levels.get(position);
    }

    @Override
    public long getItemId(int position) {
        return position;
    }

    @Override
    public View getView(int position, View convertView, ViewGroup parent) {
        LevelItemView item;
        if (convertView instanceof LevelItemView) {
            item = (LevelItemView) convertView;
        } else {
            item = new LevelItemView(parent.getContext());
        }
        VenueLevel level = levels.get(position);
        // Sets the level's short name as a text of the item.
        item.setText(level.getShortName());

        // If the level is the main one, visually separates it from the levels below it.
        item.setShowSeparator(level.isMainLevel() && position != levels.size() - 1);
        return item;
    }
}

// Allows to select a level inside a venue trough UI.
public class LevelSwitcher extends LinearLayout {
    private VenueMap venueMap = null;
    private VenueDrawing drawing = null;
    private int maxLevelIndex = -1;
    private ListView listView;
    private ImageButton levelUp, levelDown;
    private static int MAX_LEVEL_TO_SHOW = 3;

    public LevelSwitcher(Context context, AttributeSet attrs) {
        super(context, attrs);

        LayoutInflater.from(context).inflate(R.layout.level_switcher, this, true);
        listView = findViewById(R.id.levelList);
        levelUp = findViewById(R.id.LevelArrowUp);
        levelDown = findViewById(R.id.LevelArrowDown);
        // Select a level, if the user clicks on the item.
        listView.setOnItemClickListener((parent, view, position, id) -> {
            if (venueMap.getSelectedVenue() != null) {
                // Revers an index, as levels in LevelSwitcher appear in a different order
                venueMap.getSelectedVenue().setSelectedLevelIndex(maxLevelIndex - position);
            }
        });
        levelUp.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View view) {
                listView.smoothScrollByOffset(1);
            }
        });
        levelDown.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View view) {
                listView.smoothScrollByOffset(-1);
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
            View view = adapter.getView(0,null, listView);
            view.measure(0,0);
            ViewGroup.LayoutParams params = listView.getLayoutParams();
            params.height = levels.size() * view.getMeasuredHeight();
            listView.setLayoutParams(params);
            if(levels.size() > MAX_LEVEL_TO_SHOW)
            {
                view = adapter.getView(0,null, listView);
                view.measure(0,0);
                params = listView.getLayoutParams();
                params.height = MAX_LEVEL_TO_SHOW * view.getMeasuredHeight();
                listView.setLayoutParams(params);
            }


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

    public void setVisible(boolean visible) {
        setVisibility(visible ? View.VISIBLE : View.GONE);
    }
}
