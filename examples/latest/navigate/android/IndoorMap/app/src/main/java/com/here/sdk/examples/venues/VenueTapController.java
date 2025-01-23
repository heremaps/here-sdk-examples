/*
 * Copyright (C) 2019-2025 HERE Europe B.V.
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

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.RelativeLayout;
import android.widget.TextView;

import com.google.android.material.bottomsheet.BottomSheetBehavior;
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
import com.here.sdk.venue.data.VenueTopology;
import com.here.sdk.venue.routing.VenueTransportMode;
import com.here.sdk.venue.style.VenueGeometryStyle;
import com.here.sdk.venue.style.VenueLabelStyle;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

class SpaceSelectionHolder extends RecyclerView.ViewHolder{

    public TextView spaceName, spaceAddress;

    public SpaceSelectionHolder(@NonNull View itemView) {
        super(itemView);
        spaceName = itemView.findViewById(R.id.SpaceName);
        spaceAddress = itemView.findViewById(R.id.SpaceAddress);
    }
}

class SpaceSelectionAdapter extends RecyclerView.Adapter<SpaceSelectionHolder> {
    private Context context;
    private VenueGeometry geometry;

    public SpaceSelectionAdapter(Context context, VenueGeometry item){
        this.context = context;
        this.geometry = item;
    }
    @NonNull
    @Override
    public SpaceSelectionHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        return new SpaceSelectionHolder(LayoutInflater.from(context).inflate(R.layout.space_selection, parent, false));
    }

    @Override
    public void onBindViewHolder(@NonNull SpaceSelectionHolder holder, int position) {
        String spaceName, spaceAddress;
        spaceName = geometry.getName() + ", " + geometry.getLevel().getName();
        spaceAddress = geometry.getInternalAddress() != null? geometry.getInternalAddress().getAddress() : "";
        holder.spaceName.setText(spaceName);
        holder.spaceAddress.setText(spaceAddress);
    }

    @Override
    public int getItemCount() {
        return 1;
    }
}

class TopologyMeta {
    List<VenueTransportMode> modes;
    VenueTopology.TopologyDirectionality direction;
}

class TopologySelectionHolder extends RecyclerView.ViewHolder{

    public LinearLayout linearLayout;
    public TextView topoDirectionText;
    public TopologySelectionHolder(@NonNull View itemView) {
        super(itemView);
        linearLayout = itemView.findViewById(R.id.topology_images);
        topoDirectionText = itemView.findViewById(R.id.TopologyDirectionText);
    }
}

class TopologySelectionAdapter extends RecyclerView.Adapter<TopologySelectionHolder> {

    private Context context;
    private List<TopologyMeta> directions;

    public TopologySelectionAdapter(Context context, List<TopologyMeta> directions) {
        this.context = context;
        this.directions = directions;
    }


    @NonNull
    @Override
    public TopologySelectionHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        return new TopologySelectionHolder(LayoutInflater.from(context).inflate(R.layout.topology_direction, parent, false));
    }

    @Override
    public void onBindViewHolder(@NonNull TopologySelectionHolder holder, int position) {
        holder.topoDirectionText.setText(directions.get(position).direction.name());
        List<VenueTransportMode> modes = directions.get(position).modes;
        for(int i = 0; i < modes.size(); i++) {
            ImageView imageView = new ImageView(context);
            switch (modes.get(i)) {
                case AUTO:
                    imageView.setImageResource(R.drawable.car);
                    break;
                case TAXI:
                    imageView.setImageResource(R.drawable.taxi);
                    break;
                case MOTORCYCLE:
                    imageView.setImageResource(R.drawable.bike);
                    break;
                case EMERGENCY_VEHICLE:
                    imageView.setImageResource(R.drawable.ambulance);
                    break;
                case PEDESTRIAN:
                    imageView.setImageResource(R.drawable.pedestrian);
                    break;
            }
            LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(50, 50);
            params.setMargins(10, 10, 10, 10);
            imageView.setLayoutParams(params);
            holder.linearLayout.addView(imageView);
        }
    }

    @Override
    public int getItemCount() {
        return directions.size();
    }
}

public class VenueTapController {
    private static Color SELECTED_COLOR = Color.valueOf(0.282f, 0.733f, 0.96f);
    private static Color SELECTED_OUTLINE_COLOR = Color.valueOf(0.118f, 0.667f, 0.921f);
    private static Color SELECTED_TEXT_COLOR = Color.valueOf(1.0f, 1.0f, 1.0f);
    private static Color SELECTED_TEXT_OUTLINE_COLOR = Color.valueOf(0.f, 0.51f, 0.765f);
    private static Color SELECTED_TOPOLOGY_COLOR = Color.valueOf(0.353f, 0.769f, 0.757f);

    private VenueEngine venueEngine;
    private MapView mapView;
    private VenueMap venueMap;

    private MapImage markerImage;
    private MapMarker marker = null;
    private Venue selectedVenue = null;
    private VenueGeometry selectedGeometry = null;
    private VenueTopology selectedTopology = null;
    private BottomSheetBehavior sheetBehavior;
    private RecyclerView recyclerView, topologyRecycle;
    private TextView topologyID;
    private LinearLayout topologyLayout;

    // Create geometry and label styles for the selected geometry.
    private final VenueGeometryStyle geometryStyle = new VenueGeometryStyle(
            SELECTED_COLOR, SELECTED_OUTLINE_COLOR, 1);
    private final VenueLabelStyle labelStyle = new VenueLabelStyle(
            SELECTED_TEXT_COLOR, SELECTED_TEXT_OUTLINE_COLOR, 1, 28);
    private final VenueGeometryStyle selectedTopologyStyle =
            new VenueGeometryStyle(SELECTED_COLOR, SELECTED_TOPOLOGY_COLOR, 4);
    private Context context;
    private List<VenueGeometry> geometryList;

    VenueTapController(VenueEngine venueEngine, MapView mapView, AppCompatActivity activity, BottomSheetBehavior sheetBehav, RecyclerView RvView) {
        this.venueEngine = venueEngine;
        this.mapView = mapView;
        this.sheetBehavior = sheetBehav;
        this.recyclerView = RvView;
        this.context = activity;

        // Get an image for MapMarker.
        markerImage = MapImageFactory.fromResource(activity.getResources(), R.drawable.marker);
        topologyID = activity.findViewById(R.id.topology_id);
        topologyLayout = activity.findViewById(R.id.topologyLayout);
        topologyRecycle = activity.findViewById(R.id.TopologyDirection);
        topologyLayout.setVisibility(View.GONE);
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
            deselectTopolgy();
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

        recyclerView.setAdapter(new SpaceSelectionAdapter(context, geometry));

        sheetBehavior.setPeekHeight(500);

        // Set a selected style for the geometry.
        ArrayList<VenueGeometry> geometries =
                new ArrayList<>(Collections.singletonList(geometry));
        selectedVenue.setCustomStyle(geometries, geometryStyle, labelStyle);

        if (center) {
            mapView.getCamera().lookAt(position);
        }
    }

    public void selectTopology(VenueTopology topology, GeoCoordinates position) {
        deselectTopolgy();
        selectedVenue = venueMap.getSelectedVenue();
        if (selectedVenue == null) {
            return;
        }
        selectedVenue.setSelectedDrawing(topology.getLevel().getDrawing());
        selectedVenue.setSelectedLevel(topology.getLevel());
        selectedTopology = topology;
        topologyID.setText(topology.getIdentifier());
        List<TopologyMeta> directions = new ArrayList<>();
        for(VenueTopology.AccessCharacteristics access : topology.getAccessibility()) {
            VenueTopology.TopologyDirectionality direction = access.getDirection();
            VenueTransportMode mode = access.getMode();
            if(mode == VenueTransportMode.PEDESTRIAN) {
                List<VenueTransportMode> modes = new ArrayList<>();
                modes.add(mode);
                TopologyMeta meta = new TopologyMeta();
                meta.direction = direction;
                meta.modes = modes;
                directions.add(0, meta);
                continue;
            }
            int size = directions.size();
            int i;
            for(i = 0; i<size; i++) {
                if(directions.get(i).direction == direction && mode != VenueTransportMode.PEDESTRIAN && directions.get(i).modes.get(0) != VenueTransportMode.PEDESTRIAN) {
                    directions.get(i).modes.add(mode);
                    break;
                }
            }
            if(i >= size) {
                List<VenueTransportMode> modes = new ArrayList<>();
                modes.add(mode);
                TopologyMeta meta = new TopologyMeta();
                meta.direction = direction;
                meta.modes = modes;
                directions.add(meta);
            }
        }
        topologyRecycle.setLayoutManager(new LinearLayoutManager(context));
        topologyRecycle.setAdapter(new TopologySelectionAdapter(context, directions));
        sheetBehavior.setPeekHeight(0);
        topologyLayout.setVisibility(View.VISIBLE);

        // Set a selected style for the geometry.
        ArrayList<VenueTopology> topologies = new ArrayList<>(Collections.singletonList(topology));
        selectedVenue.setCustomStyle(topologies, selectedTopologyStyle);
    }

    private void deselectGeometry() {
        sheetBehavior.setPeekHeight(300);

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
        if (geometryList != null)
            recyclerView.setAdapter(new SpaceAdapter(context, geometryList, (MainActivity) context));
    }

    public void deselectTopolgy() {
        topologyLayout.setVisibility(View.GONE);
        sheetBehavior.setPeekHeight(300);
        // If there is a selected geometry, reset its style.
        if (selectedVenue != null && selectedTopology != null) {
            ArrayList<VenueTopology> topologies =
                    new ArrayList<>(Collections.singletonList(selectedTopology));
            selectedVenue.setCustomStyle(topologies, null);
        }
        selectedTopology = null;
        selectedVenue = null;
    }

    public void setGeometries(List<VenueGeometry> list) {
        geometryList = list;
    }

    // Tap listener for MapView
    public void onTap(@NonNull final Point2D origin) {
        if (selectedGeometry != null) {
            deselectGeometry();
            selectedGeometry = null;
        }

        if (selectedTopology != null) {
            deselectTopolgy();
            selectedTopology = null;
        }

        // Get geo coordinates of the tapped point.
        GeoCoordinates position = mapView.viewToGeoCoordinates(origin);
        if (position == null) {
            return;
        }

        VenueMap venueMap = venueEngine.getVenueMap();
        VenueTopology topology = venueMap.getTopology(position);
        if (topology != null) {
            selectTopology(topology, position);
        }
        else {
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
    }

    private void onLevelChanged(Venue venue) {
        if (venue == selectedVenue && selectedGeometry != null
        && venue.getSelectedLevel() == selectedGeometry.getLevel()) {
            return;
        }
        // Deselect the geometry in case of a selection of a venue, a drawing or a level.
        deselectGeometry();
        deselectTopolgy();
    }

    private final VenueSelectionListener venueSelectionListener =
            (deselectedController, selectedController) -> onLevelChanged(selectedController);

    private final VenueDrawingSelectionListener drawingSelectionListener =
            (venue, deselectedController, selectedController) -> onLevelChanged(venue);

    private final VenueLevelSelectionListener levelChangeListener =
            (venue, drawing, oldLevel, newLevel) -> onLevelChanged(venue);
}
