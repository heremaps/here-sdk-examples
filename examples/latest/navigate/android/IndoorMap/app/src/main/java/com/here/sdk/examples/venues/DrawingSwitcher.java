/*
 * Copyright (C) 2019-2023 HERE Europe B.V.
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
import android.content.res.TypedArray;
import android.graphics.drawable.GradientDrawable;
import android.util.AttributeSet;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ListView;

import com.here.sdk.venue.control.VenueDrawingSelectionListener;
import com.here.sdk.venue.control.VenueSelectionListener;
import com.here.sdk.venue.control.Venue;
import com.here.sdk.venue.control.VenueMap;
import com.here.sdk.venue.data.VenueDrawing;
import com.here.sdk.venue.data.Property;
import com.here.sdk.venue.data.VenueModel;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

// Allows to select a drawing inside a venue trough UI.
public class DrawingSwitcher
        extends LinearLayout implements View.OnClickListener, AdapterView.OnItemClickListener {

    private final Context context;
    private VenueMap venueMap;
    private Venue venue;
    private Button titleView;
    private ListView listView;
    private boolean collapsed;
    private final int listTextSize;
    private final int listTextColor;

    public DrawingSwitcher(Context context, AttributeSet attrs) {
        super(context, attrs);

        this.context = context;

        // Set up a visual style of DrawingSwitcher
        TypedArray a = context.obtainStyledAttributes(attrs, R.styleable.DrawingSwitcher, 0, 0);
        int borderWidth = a.getDimensionPixelSize(R.styleable.DrawingSwitcher_borderWidth, 2);
        int borderColor =
                a.getDimensionPixelSize(R.styleable.DrawingSwitcher_borderColor, 0xFF888888);
        int titleHeight = a.getDimensionPixelSize(R.styleable.DrawingSwitcher_titleHeight, 35);
        int titleBackground =
                a.getDimensionPixelSize(R.styleable.DrawingSwitcher_titleTextColor, 0xCCFFFFFF);
        int titleTextSize = a.getDimensionPixelSize(R.styleable.DrawingSwitcher_titleTextSize, 15);
        int titleTextColor =
                a.getDimensionPixelSize(R.styleable.DrawingSwitcher_titleTextColor, 0xFF444444);
        int listHeight = a.getDimensionPixelSize(R.styleable.DrawingSwitcher_listHeight, 140);
        int listBackground =
                a.getDimensionPixelSize(R.styleable.DrawingSwitcher_titleTextColor, 0xDDFFFFFF);
        listTextSize = a.getDimensionPixelSize(R.styleable.DrawingSwitcher_listTextSize, 14);
        listTextColor =
                a.getDimensionPixelSize(R.styleable.DrawingSwitcher_titleTextColor, 0xFF444444);
        a.recycle();

        setOrientation(LinearLayout.VERTICAL);
        setGravity(Gravity.TOP);

        // Set up a visual style of title, which contains information about the selected drawing.
        LayoutInflater.from(context).inflate(R.layout.drawing_switcher, this, true);
        titleView = findViewById(R.id.drawing_title_button);
        titleView.setVisibility(View.GONE);
        ViewGroup.LayoutParams titleViewParams = titleView.getLayoutParams();
        titleViewParams.height = titleHeight;
        titleView.setLayoutParams(titleViewParams);
        GradientDrawable titleDrawable = new GradientDrawable();
        titleDrawable.setColor(titleBackground);
        titleDrawable.setStroke(borderWidth, borderColor);
        titleView.setBackground(titleDrawable);
        titleView.setTextSize(titleTextSize);
        titleView.setTextColor(titleTextColor);

        // Set up a visual style of list with all drawings.
        listView = findViewById(R.id.drawing_list);
        listView.setVisibility(View.GONE);
        ViewGroup.LayoutParams listViewParams = listView.getLayoutParams();
        listViewParams.height = listHeight;
        listView.setLayoutParams(listViewParams);
        GradientDrawable listDrawable = new GradientDrawable();
        listDrawable.setColor(listBackground);
        listDrawable.setStroke(borderWidth, borderColor);
        listView.setBackground(listDrawable);

        // Set listeners for title and list's items clicks.
        titleView.setOnClickListener(this);
        listView.setOnItemClickListener(this);

        collapsed = true;
    }

    private final VenueSelectionListener venueSelectionListener =
            (deselectedController, selectedController) -> {
        // Update DrawingSwitcher with a new selected venue.
        DrawingSwitcher.this.setVenue(selectedController);
        if (selectedController != null) {
            // Update DrawingSwitcher with a new selected drawing.
            DrawingSwitcher.this.onDrawingSelected(selectedController.getSelectedDrawing());
        }
    };

    private final VenueDrawingSelectionListener drawingSelectionListener =
            (venue,
             deselectedController,
             selectedController) ->
                    // Update DrawingSwitcher with a new selected drawing.
                    DrawingSwitcher.this.onDrawingSelected(selectedController);

    public DrawingSwitcher(Context context) {
        this(context, null);
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
        }
    }

    public void setVenueMap(VenueMap map) {
        // Remove old venue map listeners.
        removeListeners();
        // Set VenueMap for this DrawingSwitcher.
        venueMap = map;
        venueMap.add(venueSelectionListener);
        venueMap.add(drawingSelectionListener);
    }

    @Override
    public void onClick(View v) {
        // Open of hide the list with drawings when a user clicks on the title.
        setCollapsed(!collapsed);
    }

    @Override
    public void onItemClick(AdapterView<?> parent, final View view, int position, long id) {
        titleView.setText((String) listView.getAdapter().getItem(position));
        VenueModel venueModel = venue.getVenueModel();
        // Set the selected drawing when a user clicks on the item in the list.
        venue.setSelectedDrawing(venueModel.getDrawings().get(position));
        // Hide the list.
        setCollapsed(true);
    }

    // Gets name of the drawing.
    private String getDrawingName(VenueDrawing drawing) {
        String name = "";
        Map<String, Property> properties = drawing.getProperties();
        Property property = properties.get("name");
        if (property != null) {
            name = property.getString();
        }
        return name;
    }

    // Sets a new venue for this DrawingSwitcher.
    private void setVenue(Venue venue) {
        this.venue = venue;
        int count = 0;
        if (this.venue != null) {
            // Get names of drawings.
            VenueModel venueModel = this.venue.getVenueModel();
            List<VenueDrawing> drawings = venueModel.getDrawings();
            count = drawings.size();
            final List<String> drawingNames = new ArrayList<>();
            for (VenueDrawing drawing : drawings) {
                drawingNames.add(getDrawingName(drawing));
            }

            // Set a name of the selected drawings
            String selectedDrawingName = getDrawingName(this.venue.getSelectedDrawing());
            titleView.setText(selectedDrawingName);

            // Set a new adapter with the new list of drawing's names.
            final StringArrayAdapter adapter =
                    new StringArrayAdapter(context, drawingNames, listTextSize, listTextColor);
            listView.setAdapter(adapter);
        }
        setCollapsed(true);
        // Make DrawingSwitcher visible only in there is more then one drawing in the venue.
        setVisible(count > 1);
    }

    // Updates the title with a new selected drawing.
    private void onDrawingSelected(final VenueDrawing selectedDrawing) {
        if (selectedDrawing == null) {
            return;
        }
        String selectedDrawingName = getDrawingName(selectedDrawing);
        titleView.setText(selectedDrawingName);
    }

    private void setVisible(boolean visible) {
        titleView.setVisibility(visible ? View.VISIBLE : View.GONE);
        if (!collapsed) {
            listView.setVisibility(visible ? View.VISIBLE : View.GONE);
        }
    }

    private void setCollapsed(boolean collapsed) {
        if (collapsed) {
            listView.setVisibility(View.GONE);
        } else {
            listView.setVisibility(View.VISIBLE);
        }
        this.collapsed = collapsed;
    }
}
