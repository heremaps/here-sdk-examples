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

import android.app.Activity;
import android.content.Context;
import android.content.res.TypedArray;
import android.graphics.drawable.GradientDrawable;
import android.util.AttributeSet;
import android.util.Log;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.Button;
import android.widget.ImageButton;
import android.widget.LinearLayout;
import android.widget.ListAdapter;
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
public class DrawingSwitcher implements View.OnClickListener, AdapterView.OnItemClickListener {
    private Context context;
    private VenueMap venueMap;
    private Venue venue;
    private ImageButton titleView;
    private ListView listView;
    private boolean collapsed;

    public DrawingSwitcher(Context context, ImageButton imageButton, ListView listView) {

        this.context = context;
        this.titleView = imageButton;
        this.listView = listView;
        titleView.setVisibility(View.GONE);
        listView.setVisibility(View.GONE);
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
        int height = 0;
        ListAdapter listAdapter;
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

            // Set a new adapter with the new list of drawing's names.
            final StringArrayAdapter adapter =
                    new StringArrayAdapter(context, drawingNames);
            ViewGroup.MarginLayoutParams margin = (ViewGroup.MarginLayoutParams) listView.getLayoutParams();
            listView.setAdapter(adapter);
            listAdapter = listView.getAdapter();
            for(int i=0; i<count; i++){
                View childView = listAdapter.getView(i, null, listView);
                childView.measure(View.MeasureSpec.makeMeasureSpec(0,
                        View.MeasureSpec.UNSPECIFIED), View.MeasureSpec
                        .makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED));
                height += childView.getMeasuredHeight();
            }
            Log.d("DrawingSwitcher", "marginTop:" + margin.topMargin + "height: " + height);
            margin.setMargins(margin.leftMargin, 1500 - height, margin.rightMargin, margin.bottomMargin);
            setCollapsed(true);
            setVisible(true);
        }

    }

    // Updates the title with a new selected drawing.
    private void onDrawingSelected(final VenueDrawing selectedDrawing) {
        if (selectedDrawing == null) {
            return;
        }
        String selectedDrawingName = getDrawingName(selectedDrawing);
    }

    public void setVisible(boolean visible) {
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
