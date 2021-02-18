/*
 * Copyright (C) 2019-2021 HERE Europe B.V.
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

import android.support.annotation.NonNull;
import android.support.v7.app.AppCompatActivity;
import android.view.View;
import android.widget.TextView;

import com.here.sdk.core.Anchor2D;
import com.here.sdk.core.Color;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.Point2D;
import com.here.sdk.mapview.MapImage;
import com.here.sdk.mapview.MapImageFactory;
import com.here.sdk.mapview.MapMarker;
import com.here.sdk.mapview.MapView;
import com.here.sdk.venue.VenueEngine;
import com.here.sdk.venue.control.Venue;
import com.here.sdk.venue.control.VenueDrawingSelectionListener;
import com.here.sdk.venue.control.VenueLevelSelectionListener;
import com.here.sdk.venue.control.VenueMap;
import com.here.sdk.venue.control.VenueSelectionListener;
import com.here.sdk.venue.data.VenueGeometry;
import com.here.sdk.venue.style.VenueGeometryStyle;
import com.here.sdk.venue.style.VenueLabelStyle;

import java.util.ArrayList;
import java.util.Collections;

public class VenueTapController {
    private static Color SELECTED_COLOR = Color.valueOf(0.282f, 0.733f, 0.96f);
    private static Color SELECTED_OUTLINE_COLOR = Color.valueOf(0.118f, 0.667f, 0.921f);
    private static Color SELECTED_TEXT_COLOR = Color.valueOf(1.0f, 1.0f, 1.0f);
    private static Color SELECTED_TEXT_OUTLINE_COLOR = Color.valueOf(0.f, 0.51f, 0.765f);

    private VenueEngine venueEngine;
    private MapView mapView;
    private VenueMap venueMap;

    private MapImage markerImage;
    private MapMarker marker = null;
    private Venue selectedVenue = null;
    private VenueGeometry selectedGeometry = null;

    // Create geometry and label styles for the selected geometry.
    private final VenueGeometryStyle geometryStyle = new VenueGeometryStyle(
            SELECTED_COLOR, SELECTED_OUTLINE_COLOR, 1);
    private final VenueLabelStyle labelStyle = new VenueLabelStyle(
            SELECTED_TEXT_COLOR, SELECTED_TEXT_OUTLINE_COLOR, 1, 28);

    private View geometryInfo;
    private TextView geometryNameText;

    VenueTapController(VenueEngine venueEngine, MapView mapView, AppCompatActivity activity) {
        this.venueEngine = venueEngine;
        this.mapView = mapView;

        // Get an image for MapMarker.
        markerImage = MapImageFactory.fromResource(activity.getResources(), R.drawable.marker);

        geometryInfo = activity.findViewById(R.id.geometry_info);
        geometryNameText = activity.findViewById(R.id.geometry_name);
    }

    @Override
    protected void finalize() throws Throwable {
        removeListeners();
        super.finalize();
    }

    private void removeListeners() {

        if (this.venueMap != null) {
            this.venueMap.remove(venueSelectionListener);
            this.venueMap.remove(drawingSelectionListener);
            this.venueMap.remove(levelChangeListener);
        }
    }

    void setVenueMap(VenueMap venueMap) {
        if (this.venueMap == venueMap) {
            return;
        }

        // Remove old venue map listeners.
        removeListeners();
        this.venueMap = venueMap;

        if (this.venueMap != null) {
            this.venueMap.add(venueSelectionListener);
            this.venueMap.add(drawingSelectionListener);
            this.venueMap.add(levelChangeListener);
            deselectGeometry();
        }
    }

    public void selectGeometry(VenueGeometry geometry, GeoCoordinates position, boolean center) {
        deselectGeometry();
        selectedVenue = venueMap.getSelectedVenue();
        if (selectedVenue == null) {
            return;
        }
        selectedVenue.setSelectedDrawing(geometry.getLevel().getDrawing());
        selectedVenue.setSelectedLevel(geometry.getLevel());
        selectedGeometry = geometry;

        if (geometry.getLookupType() == VenueGeometry.LookupType.ICON) {
            // Put a marker on top of geometry.
            marker = new MapMarker(position, markerImage, new Anchor2D(0.5f, 1f));
            mapView.getMapScene().addMapMarker(marker);
        }

        // Set a geometry name to the text view and show it.
        geometryNameText.setText(geometry.getName());
        geometryInfo.setVisibility(View.VISIBLE);

        // Set a selected style for the geometry.
        ArrayList<VenueGeometry> geometries =
                new ArrayList<>(Collections.singletonList(geometry));
        selectedVenue.setCustomStyle(geometries, geometryStyle, labelStyle);

        if (center) {
            mapView.getCamera().lookAt(position);
        }
    }

    private void deselectGeometry() {
        geometryInfo.setVisibility(View.GONE);

        // If the map marker is already on the screen, remove it.
        if (marker != null) {
            mapView.getMapScene().removeMapMarker(marker);
        }

        // If there is a selected geometry, reset its style.
        if (selectedVenue != null && selectedGeometry != null) {
            ArrayList<VenueGeometry> geometries =
                    new ArrayList<>(Collections.singletonList(selectedGeometry));
            selectedVenue.setCustomStyle(geometries, null, null);
        }
    }

    // Tap listener for MapView
    public void onTap(@NonNull final Point2D origin) {
        deselectGeometry();

        // Get geo coordinates of the tapped point.
        GeoCoordinates position = mapView.viewToGeoCoordinates(origin);
        if (position == null) {
            return;
        }

        VenueMap venueMap = venueEngine.getVenueMap();
        // Get a VenueGeometry under the tapped position.
        VenueGeometry geometry = venueMap.getGeometry(position);

        if (geometry != null) {
            selectGeometry(geometry, position, false);
        } else {
            // If no geometry was tapped, check if there is a not-selected venue under
            // the tapped position. If there is one, select it.
            Venue venue = venueMap.getVenue(position);
            if (venue != null) {
                venueMap.setSelectedVenue(venue);
            }
        }
    }

    private void onLevelChanged(Venue venue) {
        if (venue == selectedVenue && selectedGeometry != null
        && venue.getSelectedLevel() == selectedGeometry.getLevel()) {
            return;
        }
        // Deselect the geometry in case of a selection of a venue, a drawing or a level.
        deselectGeometry();
    }

    private final VenueSelectionListener venueSelectionListener =
            (deselectedController, selectedController) -> onLevelChanged(selectedController);

    private final VenueDrawingSelectionListener drawingSelectionListener =
            (venue, deselectedController, selectedController) -> onLevelChanged(venue);

    private final VenueLevelSelectionListener levelChangeListener =
            (venue, drawing, oldLevel, newLevel) -> onLevelChanged(venue);
}
