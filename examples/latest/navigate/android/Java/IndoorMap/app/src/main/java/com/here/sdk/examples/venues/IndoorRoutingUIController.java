/*
 * Copyright (C) 2026 HERE Europe B.V.
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
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.text.Editable;
import android.text.TextWatcher;
import android.util.Log;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.coordinatorlayout.widget.CoordinatorLayout;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.google.android.material.bottomsheet.BottomSheetBehavior;
import com.here.sdk.core.Anchor2D;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.Point2D;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.mapview.MapImage;
import com.here.sdk.mapview.MapImageFactory;
import com.here.sdk.mapview.MapMarker;
import com.here.sdk.mapview.MapView;
import com.here.sdk.routing.IndoorLevelChangeFeatures;
import com.here.sdk.routing.Route;
import com.here.sdk.venue.VenueEngine;
import com.here.sdk.venue.control.Venue;
import com.here.sdk.venue.control.VenueMap;
import com.here.sdk.venue.data.VenueGeometry;
import com.here.sdk.venue.data.VenueLevel;
import com.here.sdk.venue.data.VenueModel;
import com.here.sdk.venue.routing.IndoorRouteOptions;
import com.here.sdk.venue.routing.IndoorRouteStyle;
import com.here.sdk.venue.routing.IndoorRoutingController;
import com.here.sdk.venue.routing.IndoorRoutingEngine;
import com.here.sdk.venue.routing.IndoorRoutingError;
import com.here.sdk.venue.routing.IndoorWaypoint;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Objects;

/**
 * IndoorRoutingUIController handles Routing UI in Indoor Venues.
 * Responsibilities:
 * - Contains UI for Space selection from which routing is possible.
 * - Contains UI which allows selecting different source and destination from the list of available
 * spaces inside selected venue.
 * - Contains logic to call the route calculation api based on source and destination and render the
 * same on Venues.
 * - Also handles scenario when route is not found between given source and destination and shows the
 * alerts.
 */
public class IndoorRoutingUIController {
    private static final String TAG = IndoorRoutingUIController.class.getSimpleName();
    private final VenueEngine venueEngine;
    private final MapView mapView;
    private VenueMap venueMap;
    private final Context context;
    private final MapImage dstMarkerImage;
    private MapMarker dstMarker = null;

    private final BottomSheetBehavior<View> bottomSheetBehavior;
    private final View dragHandleRouting;
    private final Insets[] lastInset = {Insets.NONE};
    private final FrameLayout contentContainer;
    private final LinearLayout bottomSheetRoot;
    private final View viewSelectedPlacesDetails;
    private final View viewMainRoutingMenu;
    private final View viewSpaceSelectionList;
    private boolean suppressStateCallback = false;
    private enum State {
        HIDDEN, SPACE_SELECTION_DETAILS, MAIN_ROUTING_MENU, SPACE_SELECTION_LIST
    }
    private State currentState = State.HIDDEN;
    private Venue selectedVenue = null;
    private VenueGeometry selectedGeometry;
    private EditText routeSource;
    private EditText routeDestination;
    private VenueGeometry selectedSourceGeometry;
    private VenueGeometry selectedDestinationGeometry;
    private GeoCoordinates srcPosition;
    private GeoCoordinates dstPosition;
    private final IndoorRoutingEngine routingEngine;
    private final IndoorRoutingController controller;
    private final IndoorRouteOptions routeOptions = new IndoorRouteOptions();
    private final IndoorRouteStyle routeStyle = new IndoorRouteStyle();
    RecyclerView recyclerView;
    List<VenueGeometry> geometryList;
    IndoorWaypoint srcWayPoint = null;
    IndoorWaypoint dstWayPoint = null;
    Anchor2D middleBottomAnchor = new Anchor2D(0.5, 1.0);
    Anchor2D centerAnchor = new Anchor2D(0.5, 0.5);
    private enum MarkerName {
        INDOOR_NONE, INDOOR_SOURCE, INDOOR_DESTINATION, INDOOR_WALK, INDOOR_DRIVE
    }

    private boolean isRouteRenderedOnMap = false;

    IndoorRoutingUIController(VenueEngine venueEngine, MapView mapView, AppCompatActivity activity) {
        this.venueEngine = venueEngine;
        this.mapView = mapView;
        this.context = activity;
        this.venueMap = venueEngine.getVenueMap();
        routingEngine = new IndoorRoutingEngine(venueEngine.getVenueService());
        controller = new IndoorRoutingController(venueMap, mapView);
        // Get an image for MapMarker.
        dstMarkerImage = getMapImageFromSvgFile("indoor_route_end.svg");
        setUpRouteStyle();

        // Inflate bottom sheet container and add it to MainActivity coordinatorLayout.
        CoordinatorLayout coordinator = activity.findViewById(R.id.mainActivity);
        bottomSheetRoot = (LinearLayout) LayoutInflater.from(activity)
                .inflate(R.layout.routing_bottom_sheet, coordinator, false);
        coordinator.addView(bottomSheetRoot);

        // Apply Insets.
        ViewCompat.setOnApplyWindowInsetsListener(bottomSheetRoot, (v, insets) -> {
            Insets sys = insets.getInsets(WindowInsetsCompat.Type.systemBars());
            lastInset[0] = sys;
            v.setPadding(sys.left, 0, sys.right, sys.bottom);
            Log.d("TAG", "System Insets => left:" + sys.left + " top:"+sys.top + " right:"
                    + sys.right + " bottom:" + sys.bottom);

            return WindowInsetsCompat.CONSUMED;
        });
        // As this bottom sheet gets inflated separately, so need to request to apply insets manually.
        ViewCompat.requestApplyInsets(bottomSheetRoot);

        contentContainer = bottomSheetRoot.findViewById(R.id.bottomSheetRoutingContainer);
        bottomSheetBehavior = BottomSheetBehavior.from(bottomSheetRoot);
        bottomSheetBehavior.setHideable(true);
        bottomSheetBehavior.setState(BottomSheetBehavior.STATE_HIDDEN);
        dragHandleRouting = bottomSheetRoot.findViewById(R.id.dragHandle);

        bottomSheetBehavior.addBottomSheetCallback(new BottomSheetBehavior.BottomSheetCallback() {
            @Override
            public void onStateChanged(@NonNull View bottomSheet, int newState) {
                // Hide Venue/Space bottom sheet, when routing sheet is active.
                ((MainActivity) context).setVenueBottomSheetToHide(currentState != State.HIDDEN);
                Log.d(TAG, "State changed to: " + newState + ", currentState:" + currentState +
                        " and height:" + bottomSheetBehavior.getPeekHeight());

                if (suppressStateCallback) return;
                if (newState == BottomSheetBehavior.STATE_COLLAPSED && currentState == State.SPACE_SELECTION_LIST) {
                    showRoutingMenu();
                }
            }

            @Override
            public void onSlide(@NonNull View bottomSheet, float slideOffset) {
            }
         });

        viewSelectedPlacesDetails = LayoutInflater.from(context).inflate(R.layout.routing_space_selection, contentContainer, false);
        viewMainRoutingMenu = LayoutInflater.from(context).inflate(R.layout.routing_source_destination_selection, contentContainer, false);
        viewSpaceSelectionList = LayoutInflater.from(context).inflate(R.layout.routing_space_selection_list, contentContainer, false);
        contentContainer.addView(viewSelectedPlacesDetails);
        contentContainer.addView(viewMainRoutingMenu);
        contentContainer.addView(viewSpaceSelectionList);
        viewSelectedPlacesDetails.setVisibility(View.VISIBLE);
        viewMainRoutingMenu.setVisibility(View.GONE);
        viewSpaceSelectionList.setVisibility(View.GONE);
    }

    /**
     * Sets the Route Style for Routing, Creates Map Marker and passing it to SDK code, so same will
     * be used during rendering of route in Indoor Venue.
     */
    private void setUpRouteStyle() {
        routeStyle.setStartMarker(getMapMarkerFromSvgFile(MarkerName.INDOOR_SOURCE));
        routeStyle.setDestinationMarker(getMapMarkerFromSvgFile(MarkerName.INDOOR_DESTINATION));
        routeStyle.setWalkMarker(getMapMarkerFromSvgFile(MarkerName.INDOOR_WALK));
        routeStyle.setDriveMarker(getMapMarkerFromSvgFile(MarkerName.INDOOR_DRIVE));

        IndoorLevelChangeFeatures[] features = new IndoorLevelChangeFeatures[]{
                IndoorLevelChangeFeatures.ELEVATOR,
                IndoorLevelChangeFeatures.ESCALATOR,
                IndoorLevelChangeFeatures.STAIRS,
                IndoorLevelChangeFeatures.RAMP
        };
        for (IndoorLevelChangeFeatures feature : features) {
            MapMarker marker = getFeatureMapMarkerFromSvgFile(feature, 0);
            MapMarker upMarker = getFeatureMapMarkerFromSvgFile(feature, 1);
            MapMarker downMarker = getFeatureMapMarkerFromSvgFile(feature, -1);
            routeStyle.setIndoorMarkersFor(feature, upMarker, downMarker, marker);
        }
    }

    /**
     * Gets the MapMarker based on IndoorFeature and delta_z.
     * @param feature Indoor Features enum to be shown on route.
     * @param delta_z The side of MapMarker it will denote. 0 => Normal Marker, 1 => Upside marker,
     *                -1 => Downside marker.
     * @return A Map Marker which can be shown along route to describe Indoor Level change action.
     */
    private MapMarker getFeatureMapMarkerFromSvgFile(IndoorLevelChangeFeatures feature, int delta_z) {
        MapImage markerImage = null;
        String svgFileName = "";
        try {
            if (feature == IndoorLevelChangeFeatures.ELEVATOR) {
                switch (delta_z) {
                    case 0:
                        svgFileName = "indoor_elevator.svg";
                        break;
                    case 1:
                        svgFileName = "indoor_elevator_up.svg";
                        break;
                    case -1:
                        svgFileName = "indoor_elevator_down.svg";
                        break;
                }
            } else if (feature == IndoorLevelChangeFeatures.ESCALATOR) {
                switch (delta_z) {
                    case 0:
                        svgFileName = "indoor_escalator.svg";
                        break;
                    case 1:
                        svgFileName = "indoor_escalator_up.svg";
                        break;
                    case -1:
                        svgFileName = "indoor_escalator_down.svg";
                        break;
                }
            } else if (feature == IndoorLevelChangeFeatures.RAMP) {
                switch (delta_z) {
                    case 0:
                        svgFileName = "indoor_ramp.svg";
                        break;
                    case 1:
                        svgFileName = "indoor_ramp_up.svg";
                        break;
                    case -1:
                        svgFileName = "indoor_ramp_down.svg";
                        break;
                }
            } else if (feature == IndoorLevelChangeFeatures.STAIRS) {
                switch (delta_z) {
                    case 0:
                        svgFileName = "indoor_stair.svg";
                        break;
                    case 1:
                        svgFileName = "indoor_stair_up.svg";
                        break;
                    case -1:
                        svgFileName = "indoor_stair_down.svg";
                        break;
                }
            }

            if (svgFileName.isEmpty()) {
                Log.d(TAG, "No SVG file found for feature." + feature + ", delta:" + delta_z);
                return null;
            }
            markerImage = MapImageFactory.fromFile(svgFileName, 64, 64);
            return new MapMarker(new GeoCoordinates(0.0, 0.0), markerImage, middleBottomAnchor);
        } catch (InstantiationErrorException e) {
            Log.e(TAG, "Map Marker Image creation from SVG failed for feature:" + feature +
                    ", delta:" + delta_z, e);
        }
        return null;
    }

    /**
     * Gets the Indoor Map marker created for Source and destination.
     * @param name Marker which need to be created.
     * @return MapMarker object which will be used in Route Rendering.
     */
    private MapMarker getMapMarkerFromSvgFile(MarkerName name) {
        MapImage markerImage = null;
        String svgFileName = "";
        int height = 64;
        int width = 64;
        Anchor2D anchor = middleBottomAnchor;
        try {
            if (name == MarkerName.INDOOR_WALK) {
                svgFileName = "indoor_walk.svg";
            } else if (name == MarkerName.INDOOR_DRIVE) {
                svgFileName = "indoor_drive.svg";
            } else if (name == MarkerName.INDOOR_SOURCE) {
                svgFileName = "indoor_route_start.svg";
                anchor = centerAnchor;
            } else if (name == MarkerName.INDOOR_DESTINATION) {
                svgFileName = "indoor_route_end.svg";
                height = 100;
                width = 100;
            }
            if (svgFileName.isEmpty()) {
                Log.d(TAG, "No SVG file found for feature." + name);
                return null;
            }
            markerImage = MapImageFactory.fromFile(svgFileName, width, height);
            return new MapMarker(new GeoCoordinates(0.0, 0.0), markerImage, anchor);
        } catch (InstantiationErrorException e) {
            Log.e(TAG, "Map Marker Image creation from SVG failed for feature:" + name, e);
        }
        return null;
    }

    /**
     * Creates MapImage based on Svg File Name.
     * @param svgFileName SVG file name.
     * @return MapImage which will be used for putting the Map Marker.
     */
    private MapImage getMapImageFromSvgFile(String svgFileName) {
        MapImage markerImage = null;
        try {
            if (svgFileName.isEmpty()) {
                Log.d(TAG, "Empty SVG file given");
                return null;
            }
            markerImage = MapImageFactory.fromFile(svgFileName, 100, 100);
            return markerImage;
        } catch (InstantiationErrorException e) {
            Log.e(TAG, "Map Image creation from SVG failed for feature:" + svgFileName);
        }
        return null;
    }

    void setVenueMap(VenueMap venueMap) {
        if (this.venueMap == venueMap) {
            return;
        }
        this.venueMap = venueMap;
    }

    /**
     * This api handles the scenario when entire routing menu is closed directly and Venue bottom
     * sheet need to be make visible.
     */
    public void removeRoutingBottomSheetFromMap() {
        viewSelectedPlacesDetails.setVisibility(View.GONE);
        viewMainRoutingMenu.setVisibility(View.GONE);
        viewSpaceSelectionList.setVisibility(View.GONE);
        currentState = State.HIDDEN;
        bottomSheetBehavior.setHideable(true);
        bottomSheetBehavior.setState(BottomSheetBehavior.STATE_HIDDEN);
        controller.hideRoute();
        removeMarkerImageFromMap();
        selectedVenue = null;
        geometryList = null;
    }

    public void onBackButtonClickOnVenue() {
        removeRoutingBottomSheetFromMap();
    }

    /**
     * This api handles the removal of Map Marker Images from Map.
     */
    void removeMarkerImageFromMap() {
        // If the map marker is already on the screen, remove it.
        if (dstMarker != null) {
            mapView.getMapScene().removeMapMarker(dstMarker);
            dstMarker = null;
        }
    }

    /**
     * This api handles setting mandatory param which will be used when routing is activated at App side.
     */
    void setSelectedVenueParamForRouting() {
        if (venueMap != null) {
            selectedVenue = venueMap.getSelectedVenue();
            if (selectedVenue != null) {
                VenueModel venueModel = selectedVenue.getVenueModel();
                geometryList = venueModel.getGeometriesByName();
            } else {
                geometryList = null;
            }
        }
    }

    /**
     * This api switches the different view: Space Selected, Main Routing Menu and Space Selection
     * List inside the routing bottom sheet UI.
     * @param newView The name of View which will be activated in sheet.
     */
    private void switchView(View newView) {
        viewSelectedPlacesDetails.setVisibility(newView == viewSelectedPlacesDetails ? View.VISIBLE : View.GONE);
        viewMainRoutingMenu.setVisibility(newView == viewMainRoutingMenu ? View.VISIBLE : View.GONE);
        viewSpaceSelectionList.setVisibility(newView == viewSpaceSelectionList ? View.VISIBLE : View.GONE);
        newView.bringToFront();
        newView.requestLayout();
        newView.post(() -> {
            suppressStateCallback = true;
            bottomSheetBehavior.setState(BottomSheetBehavior.STATE_EXPANDED);
            newView.post(() -> suppressStateCallback = false);
        });
    }

    /**
     * This api handles the scenario when Space is selected from Venue and same need to be shown in
     * sheet as Destination. From this UI routing can be started by clicking on Directions button.
     * @param geometry Selected geometry by User when tapped on Indoor Venue.
     * @param position If no valid geometry at the given tap, then lat, long will be picked as destination.
     */
    public void showSelectedSpace(VenueGeometry geometry, GeoCoordinates position) {
        currentState = State.SPACE_SELECTION_DETAILS;
        isRouteRenderedOnMap = false;
        controller.hideRoute();
        switchView(viewSelectedPlacesDetails);

        applyTopInsetsToRoutingBottomSheet(false);
        contentContainer.post(() -> {
            bottomSheetBehavior.setHideable(false);
            bottomSheetBehavior.setState(BottomSheetBehavior.STATE_EXPANDED);
        });

        // Show the topology button when selected space menu is active.
        ((MainActivity)context).hideTopologyButtonOnMap(false);
        // Set the mandatory param required for routing.
        setSelectedVenueParamForRouting();
        // As routing window is closed, so remove the marker image as well.
        removeMarkerImageFromMap();

        TextView spaceName, spaceAddress, spaceAddressHolder;
        Button directionButton;
        ImageView cancelBtn;
        spaceName = viewSelectedPlacesDetails.findViewById(R.id.SpaceName);
        spaceAddress = viewSelectedPlacesDetails.findViewById(R.id.SpaceAddress);
        spaceAddressHolder = viewSelectedPlacesDetails.findViewById(R.id.SpaceAddressHolder);
        directionButton = viewSelectedPlacesDetails.findViewById(R.id.spaceSelectionDirectionBtn);
        cancelBtn = viewSelectedPlacesDetails.findViewById(R.id.spaceSelectionCancelBtn);
        // TODO: Add Space Type as well once spaceType api is exposed.
        String spaceNameStr = "";
        String spaceAddressStr = "";
        if (!geometry.getName().isEmpty()) {
            spaceNameStr = geometry.getName();
        } else {
            spaceNameStr = position.latitude + ", " + position.longitude;
        }
        spaceNameStr += ", " + geometry.getLevel().getName();
        spaceAddressStr = geometry.getInternalAddress() != null ? geometry.getInternalAddress().getAddress() : "";
        spaceName.setText(spaceNameStr);
        spaceAddress.setText(spaceAddressStr);
        if (spaceAddress.getText().toString().trim().isEmpty()) {
            spaceAddressHolder.setText("");
            spaceAddress.setVisibility(View.GONE);
        } else {
            String addressStr = "Address: ";
            spaceAddressHolder.setText(addressStr);
            spaceAddressHolder.setVisibility(View.VISIBLE);
            spaceAddress.setVisibility(View.VISIBLE);
        }
        directionButton.setOnClickListener(v -> showRoutingMenu());
        selectedGeometry = geometry;
        selectedDestinationGeometry = geometry;
        dstWayPoint = convertGeoCoordinatesToIndoorWayPoint(position);
        dstPosition = position;
        selectedSourceGeometry = null;
        srcPosition = null;
        cancelBtn.setOnClickListener(v -> handleBackPressed());

        // Check if same level as selected destination geometry level then put a destination marker
        // on top of geometry.
        handleDstMarkerInMapOnLevelChange();
    }

    /**
     * This api handles the Main Menu which allows selecting different source and destination. Source
     * can be selected either by clicking on Indoor Venue or from the list of Available spaces.
     * Destination can be selected from list of Available spaces only.
     */
    public void showRoutingMenu() {
        currentState = State.MAIN_ROUTING_MENU;
        switchView(viewMainRoutingMenu);
        applyTopInsetsToRoutingBottomSheet(false);
        isRouteRenderedOnMap = false;
        // hide the topology button when routing menu is active.
        ((MainActivity)context).hideTopologyButtonOnMap(true);

        // Also re-set the custom style applied to first dst selected as well.
        removeCustomStyleFromGeometry(selectedGeometry);

        routeSource = viewMainRoutingMenu.findViewById(R.id.sourceId);
        routeDestination = viewMainRoutingMenu.findViewById(R.id.destinationId);
        ImageView cancelBtn = viewMainRoutingMenu.findViewById(R.id.routingCancelBtn);
        cancelBtn.setOnClickListener(v -> handleBackPressed());

        if (selectedSourceGeometry != null) {
            String spaceNameStr;
            // TODO: Add Space Type as well once spaceType api is exposed.
            if(!selectedSourceGeometry.getName().isEmpty()) {
                spaceNameStr = selectedSourceGeometry.getName();
            } else {
                spaceNameStr = srcPosition.latitude + ", " + srcPosition.longitude;
            }
            spaceNameStr += ", " + selectedSourceGeometry.getLevel().getName();
            routeSource.setText(spaceNameStr);
        } else {
            routeSource.setText(R.string.indoor_routing_source_hint);
        }

        if (selectedDestinationGeometry != null) {
            // TODO: Add Space Type as well  once spaceType api is exposed.
            String spaceNameStr;
            if(!selectedDestinationGeometry.getName().isEmpty()) {
                spaceNameStr = selectedDestinationGeometry.getName();
            } else {
                spaceNameStr = dstPosition.latitude + ", " + dstPosition.longitude;
            }
            spaceNameStr += ", " + selectedDestinationGeometry.getLevel().getName();
            routeDestination.setText(spaceNameStr);
        }

        routeSource.setOnClickListener(v -> showSpaceSelectionList(true));
        routeDestination.setOnClickListener(v -> showSpaceSelectionList(false));

        if (selectedSourceGeometry != null && selectedDestinationGeometry != null) {
            if (srcWayPoint == null) {
                Log.d(TAG, "Source waypoint is null");
                return;
            }
            if (dstWayPoint == null) {
                Log.d(TAG, "destination waypoint is null");
                return;
            }

            // Check if source and destination are same.
            if (checkIndoorWaypointAreEqual(srcWayPoint, dstWayPoint)) {
                String errorMsg = "Selected Source and Destination are same. Please select different"
                        + " source and destination points.";
                showAlertOnRouteCalculationError(errorMsg);
                return;
            }

            ((MainActivity) context).showProgressBarOnMap(true);
            routingEngine.calculateRoute(srcWayPoint, dstWayPoint, routeOptions, this::showRouteInMap);
            Log.d(TAG, "Route calculation called with Source[levelId: " + srcWayPoint.getLevelId()
                    + ", latitude:" + srcWayPoint.getCoordinates().latitude + ", longitude:"
                    + srcWayPoint.getCoordinates().longitude + "]" + ", Destination[levelId:"
                    + dstWayPoint.getLevelId() + ", latitude:" + dstWayPoint.getCoordinates().latitude
                    + ", longitude:" + dstWayPoint.getCoordinates().longitude + "]");
        }
    }

    /**
     * This api renders the route on Indoor Venue once source and destination is given from Main Routing
     * Menu.
     * @param routingError If no route can be found between source and destination, then this will
     *                     contain the error why route was not found.
     * @param routeList If valid route is found between source and destination, then this will be
     *                  inside routeList and same can be fetched and rendered on Indoor Venue.
     */
    private void showRouteInMap(
            final IndoorRoutingError routingError,
            final List<Route> routeList) {
        ((MainActivity)context).showProgressBarOnMap(false);
        controller.hideRoute();
        if (routingError == null && routeList != null) {
            Route route = routeList.get(0);
            // check If length came as 0 it means same source and destination
            Log.d(TAG, "Route Calculation Error Msg: " + route.getLengthInMeters());
            if (route.getLengthInMeters() <= 0) {
                String errorMsg = "Selected Source and Destination are same. Please select different"
                        + " source and destination points.";
                showAlertOnRouteCalculationError(errorMsg);
                return;
            }

            controller.showRoute(route, routeStyle);

            // change current level on venue to source geometry level.
            if (selectedVenue.getSelectedLevel() != selectedSourceGeometry.getLevel()) {
                selectedVenue.setSelectedLevel(selectedSourceGeometry.getLevel());
            }

            // Move the camera to source position.
            mapView.getCamera().lookAt(srcPosition);
            // remove marker from map once route is rendered.
            removeMarkerImageFromMap();
            isRouteRenderedOnMap = true;
        } else {
            isRouteRenderedOnMap = false;
            String errorMsg;
            switch (routingError) {
                case NO_NETWORK:
                    errorMsg = "The device has no internet connectivity";
                    break;
                case BAD_REQUEST:
                    errorMsg = "A bad request was made";
                    break;
                case UNAUTHORIZED_ACCESS:
                    errorMsg = "You don't have access to routing service";
                    break;
                case FORBIDDEN:
                    errorMsg = "Cannot serve this route";
                    break;
                case NOT_FOUND:
                    errorMsg = "Resource not found";
                    break;
                case TOO_MANY_REQUESTS:
                    errorMsg = "Too many request received by service";
                    break;
                case INTERNAL_SERVER_ERROR:
                    errorMsg = "Internal server error";
                    break;
                case BAD_GATEWAY:
                    errorMsg = "Bad gateway";
                    break;
                case SERVICE_UNAVAILABLE:
                    errorMsg = "Routing service is currently unavailable";
                    break;
                case NO_ROUTE_FOUND:
                    errorMsg = "No route found between selected waypoints";
                    break;
                case COULD_NOT_MATCH_ORIGIN:
                    errorMsg = "Origin could not be matched";
                    break;
                case COULD_NOT_MATCH_DESTINATION:
                    errorMsg = "Destination could not be matched";
                    break;
                case MAP_NOT_FOUND:
                    errorMsg = "Requested map not found";
                    break;
                case PARSING_ERROR:
                    errorMsg = "Routing response not in correct format";
                    break;
                case UNKNOWN_ERROR:
                    errorMsg = "Unknown Error encountered";
                    break;
                default:
                    errorMsg = "Unknown Error encountered";
            }
            Log.d(TAG, "Route Calculation Error Msg: " + errorMsg);
            showAlertOnRouteCalculationError(errorMsg);
        }
    }

    /**
     * This api handles the UI which will allow selection of different spaces inside venues to be used
     * for source and destination.
     * @param isSource This denotes whether selection is done for Source or not.
     */
    public void showSpaceSelectionList(boolean isSource) {
        currentState = State.SPACE_SELECTION_LIST;
        switchView(viewSpaceSelectionList);
        applyTopInsetsToRoutingBottomSheet(true);

        recyclerView = viewSpaceSelectionList.findViewById(R.id.spaceListView);
        recyclerView.setLayoutManager(new LinearLayoutManager(context));
        EditText spaceSearchBar = viewSpaceSelectionList.findViewById(R.id.spaceSearchBar);
        spaceSearchBar.setText("");
        ImageView clearIcon = viewSpaceSelectionList.findViewById(R.id.clearIcon);
        clearIcon.setVisibility(View.GONE);

        if (geometryList != null) {
            recyclerView.setAdapter(new RoutingSpaceSelectionAdapter(geometryList, this, isSource));
        }

        spaceSearchBar.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {

            }

            @Override
            public void onTextChanged(CharSequence c, int start, int before, int count) {
                clearIcon.setVisibility(c.length() > 0 ? View.VISIBLE : View.GONE);
                String s = c != null ? c.toString() : "";
                s = s.trim();
                filterSpacesForRouting(s, isSource);
            }

            @Override
            public void afterTextChanged(Editable s) {

            }
        });

        clearIcon.setOnClickListener(v -> spaceSearchBar.setText(""));
    }

    /**
     * This api handles the searching of different spaces in Venue during source/destination selection.
     * @param s String which need to be searched in list.
     * @param isSource This indicates whether this search is happening for source or not.
     */
    private void filterSpacesForRouting(String s, boolean isSource) {
        recyclerView.setAdapter(null);
        List<VenueGeometry> list = new ArrayList<>();
        for(VenueGeometry geometry : geometryList) {
            if(geometry.getName().toLowerCase().contains(s.toLowerCase()) || geometry.getLevel().getName().toLowerCase().contains(s.toLowerCase())
                    || (geometry.getInternalAddress() != null ? geometry.getInternalAddress().getAddress() : "").toLowerCase().contains(s.toLowerCase())) {
                list.add(geometry);
            }
        }
        Log.d(TAG, "Search word: " + s + " Geometries size: " + geometryList.size() + " NewListSize:" + list.size());
        if(!list.isEmpty()) {
            recyclerView.setAdapter(new RoutingSpaceSelectionAdapter(list,this, isSource));
        }
    }

    void applyTopInsetsToRoutingBottomSheet(boolean val) {
        ViewGroup.LayoutParams params = bottomSheetRoot.getLayoutParams();
        int top = 0;
        int visibility = View.GONE;
        if (val) {
            // Apply top Insets and make drag handle visibility gone.
            top = lastInset[0].top;

            // Forcing the bottom sheet to match full height of screen.
            params.height = ViewGroup.LayoutParams.MATCH_PARENT;
        } else {
            // Do not apply top insets but keep drag handle visible.
            visibility = View.VISIBLE;

            // Keep bottom sheet to match the height of contents.
            params.height = ViewGroup.LayoutParams.WRAP_CONTENT;
        }
        dragHandleRouting.setVisibility(visibility);
        contentContainer.setPadding(
                contentContainer.getPaddingLeft(),
                top,
                contentContainer.getPaddingRight(),
                contentContainer.getPaddingBottom()
        );
        bottomSheetRoot.setLayoutParams(params);
    }


    /**
     * This api handles the back button press scenario from Mobile device when routing is active.
     * @return Boolean to indicates if back button event is handled or need to be handled by Venue sheet.
     */
    public boolean handleBackPressed() {
        switch (currentState) {
            case SPACE_SELECTION_LIST:
                showRoutingMenu();
                return true;
            case MAIN_ROUTING_MENU:
                showSelectedSpace(selectedDestinationGeometry, dstPosition);
                return true;
            case SPACE_SELECTION_DETAILS:
                contentContainer.post(() -> {
                    bottomSheetBehavior.setHideable(true);
                    bottomSheetBehavior.setState(BottomSheetBehavior.STATE_HIDDEN);
                });
                currentState = State.HIDDEN;
                removeMarkerImageFromMap();
                // As we are going back to Space bottom sheet, should revert back the custom style
                // applied to previously selected geometry.
                removeCustomStyleFromGeometry(selectedGeometry);
                return true;
            default:
                return false;
        }
    }

    void removeCustomStyleFromGeometry(VenueGeometry geometry) {
        if (geometry != null) {
            ArrayList<VenueGeometry> geometries = new ArrayList<>(Collections.singletonList(geometry));
            selectedVenue.setCustomStyle(geometries, null, null);
        }
    }

    public boolean isRoutingMenuActiveInBottomSheet() {
        return ((bottomSheetBehavior.getState() == BottomSheetBehavior.STATE_EXPANDED) &&
                (currentState == State.MAIN_ROUTING_MENU));
    }

    public boolean isRoutingSpaceSelectedActiveInBottomSheet() {
        return ((bottomSheetBehavior.getState() == BottomSheetBehavior.STATE_EXPANDED) &&
                (currentState == State.SPACE_SELECTION_DETAILS));
    }

    /**
     * This api handles the scenario when level changes in Venue and based on that we need to keep the
     * destination marker on Venue or remove it.
     */
    public void handleDstMarkerInMapOnLevelChange() {
        // If route is rendered on map, no need to put the marker on map.
        if(isRouteRenderedOnMap) {
            return;
        }
        if (selectedDestinationGeometry.getLevel() != selectedVenue.getSelectedLevel()) {
            removeMarkerImageFromMap();
        } else {
            // Put a destination marker on top of geometry.
            dstMarker = new MapMarker(dstPosition, dstMarkerImage, new Anchor2D(0.5, 1));
            mapView.getMapScene().addMapMarker(dstMarker);
        }
    }

    /**
     * When routing bottom sheet is active, then this api will handle the tap event occurring on map.
     * @param origin this will contain the latitude and longitude where tap event happened.
     */
    public void onTap(final Point2D origin) {
        // Get geo coordinates of the tapped point.
        GeoCoordinates position = mapView.viewToGeoCoordinates(origin);
        if (position == null) {
            // If clicked outside, need to hide any previous rendered route.
            controller.hideRoute();
            selectedSourceGeometry = null;
            srcPosition = null;
            routeSource.setText("");
            return;
        }

        if (currentState == State.MAIN_ROUTING_MENU) {
            VenueMap venueMap = venueEngine.getVenueMap();
            // Get a VenueGeometry under the tapped position.
            VenueGeometry geometry = venueMap.getGeometry(position);

            if (geometry != null) {
                selectedSourceGeometry = geometry;
                srcWayPoint = convertGeoCoordinatesToIndoorWayPoint(position);
                srcPosition = position;
                showRoutingMenu();
            }
        } else {
            controller.hideRoute();
            routeSource.setText(R.string.indoor_routing_source_hint);
        }
    }

    /**
     * This api handles the event when any space is selected from list of available spaces for routing.
     * @param geometry the geometry which was selected from list.
     * @param fromSrc this indicates whether selection happened for source or destination.
     */
    public void onSpaceItemClicked(VenueGeometry geometry, boolean fromSrc) {
        String spaceNameStr;
        spaceNameStr = geometry.getName() + ", " + geometry.getLevel().getName();
        if (fromSrc) {
            routeSource.setText(spaceNameStr);
            selectedSourceGeometry = geometry;
            srcWayPoint = convertGeoCoordinatesToIndoorWayPoint(selectedSourceGeometry.getCenter(), selectedSourceGeometry.getLevel());
            srcPosition = selectedSourceGeometry.getCenter();
        } else {
            // As destination might have changed, so removing old marker and checking if at same level
            // put the marker there.
            removeMarkerImageFromMap();
            if (selectedVenue.getSelectedLevel() == geometry.getLevel()) {
                // Put a destination marker on top of geometry.
                dstMarker = new MapMarker(geometry.getCenter(), dstMarkerImage, new Anchor2D(0.5, 1));
                mapView.getMapScene().addMapMarker(dstMarker);
            }
            routeDestination.setText(spaceNameStr);
            selectedDestinationGeometry = geometry;
            dstWayPoint = convertGeoCoordinatesToIndoorWayPoint(selectedDestinationGeometry.getCenter(), selectedDestinationGeometry.getLevel());
            dstPosition = selectedDestinationGeometry.getCenter();
        }
        ((MainActivity) context).hideKeyboard();
        showRoutingMenu();
    }

    /**
     * This api converts the geo-coordinates to Indoor Waypoint object.
     * @param coordinates lat/lng which will be converted to Indoor waypoint object.
     * @return Indoor Waypoint object.
     */
    private IndoorWaypoint convertGeoCoordinatesToIndoorWayPoint(GeoCoordinates coordinates) {
        if (coordinates != null) {
            Venue venue = venueMap.getSelectedVenue();
            if (venue != null) {
                VenueModel venueModel = venue.getVenueModel();
                Venue selectedVenue = venueMap.getSelectedVenue();
                if (selectedVenue != null &&
                        venueModel.getId() == selectedVenue.getVenueModel().getId()) {
                    return new IndoorWaypoint(coordinates, venueModel.getIdentifier(),
                            venue.getSelectedLevel().getIdentifier());
                } else {
                    venueMap.setSelectedVenue(venue);
                    return null;
                }
            }
            return new IndoorWaypoint(coordinates);
        }
        return null;
    }

    /**
     * This api converts the geo-coordinates to Indoor Waypoint object.
     * @param coordinates lat/lng which will be converted to Indoor waypoint object.
     * @param venueLevel Indoor Level which will be used in Indoor Waypoint object.
     * @return Indoor Waypoint object.
     */
    private IndoorWaypoint convertGeoCoordinatesToIndoorWayPoint(GeoCoordinates coordinates, VenueLevel venueLevel) {
        if (coordinates != null) {
            Venue venue = venueMap.getSelectedVenue();
            if (venue != null) {
                VenueModel venueModel = venue.getVenueModel();
                Venue selectedVenue = venueMap.getSelectedVenue();
                if (selectedVenue != null &&
                        venueModel.getId() == selectedVenue.getVenueModel().getId()) {
                    return new IndoorWaypoint(coordinates, venueModel.getIdentifier(),
                            venueLevel.getIdentifier());
                } else {
                    venueMap.setSelectedVenue(venue);
                    return null;
                }
            }
            return new IndoorWaypoint(coordinates);
        }
        return null;
    }

    private boolean checkIndoorWaypointAreEqual(IndoorWaypoint srcPoint, IndoorWaypoint dstPoint) {
        return (srcPoint.getCoordinates().equals(dstPoint.getCoordinates()) &&
                Objects.equals(srcPoint.getLevelId(), dstPoint.getLevelId()));
    }

    private void showAlertOnRouteCalculationError(String errorMsg) {
        AlertHandler alert = new AlertHandler(context, errorMsg);
        alert.getWindow().setBackgroundDrawable(new ColorDrawable(Color.TRANSPARENT));
        alert.getWindow().setGravity(Gravity.TOP);
        alert.show();
    }
}
