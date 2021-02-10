/*
 * Copyright (c) 2021 HERE Global B.V. and its affiliate(s).
 * All rights reserved.
 *
 * This software and other materials contain proprietary information
 * controlled by HERE and are protected by applicable copyright legislation.
 * Any use and utilization of this software and other materials and
 * disclosure to any third parties is conditional upon having a separate
 * agreement with HERE for the access, use, utilization or disclosure of this
 * software. In the absence of such agreement, the use of the software is not
 * allowed.
 */

package com.here.sdk.examples.venues;

import android.content.Context;
import android.util.Log;
import android.view.KeyEvent;
import android.view.View;
import android.view.inputmethod.EditorInfo;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.RadioButton;
import android.widget.TextView;
import android.widget.Toast;

import android.support.annotation.NonNull;
import android.support.annotation.Nullable;

import com.here.sdk.core.Anchor2D;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.Point2D;
import com.here.sdk.gestures.GestureState;
import com.here.sdk.gestures.LongPressListener;
import com.here.sdk.mapview.MapImage;
import com.here.sdk.mapview.MapImageFactory;
import com.here.sdk.mapview.MapMarker;
import com.here.sdk.mapview.MapView;
import com.here.sdk.routing.IndoorFeatures;
import com.here.sdk.routing.IndoorRouteOptions;
import com.here.sdk.routing.IndoorRouteStyle;
import com.here.sdk.routing.IndoorRoutingController;
import com.here.sdk.routing.IndoorRoutingEngine;
import com.here.sdk.routing.IndoorTransportMode;
import com.here.sdk.routing.IndoorWaypoint;
import com.here.sdk.routing.OptimizationMode;
import com.here.sdk.routing.Route;
import com.here.sdk.routing.RoutingError;
import com.here.sdk.venue.VenueEngine;
import com.here.sdk.venue.control.Venue;
import com.here.sdk.venue.control.VenueMap;
import com.here.sdk.venue.data.VenueModel;

import java.util.List;
import java.util.Locale;

public class IndoorRoutingUIController implements LongPressListener {
    private static final String TAG = IndoorRoutingUIController.class.getSimpleName();
    private VenueMap venueMap;
    private MapView mapView;
    private Context context;
    private IndoorRoutingEngine engine;
    private IndoorRoutingController controller;
    private final View indoorRoutingLayout;
    private final View indoorRoutingSettings;
    private final TextView startTextView;
    private final TextView destinationTextView;
    private IndoorWaypoint startWaypoint = null;
    private IndoorWaypoint destinationWaypoint = null;
    private boolean visible = false;
    private boolean settingsVisible = false;
    private final IndoorRouteOptions routeOptions = new IndoorRouteOptions();
    private final IndoorRouteStyle routeStyle = new IndoorRouteStyle();

    private final RadioButton fastRadioButton;
    private final RadioButton pedestrianRadioButton;

    public IndoorRoutingUIController(
            VenueEngine venueEngine,
            MapView mapView,
            View indoorRoutingLayout,
            View indoorRoutingButton) {
        this.venueMap = venueEngine.getVenueMap();
        this.mapView = mapView;
        context = indoorRoutingLayout.getContext();
        mapView.getGestures().setLongPressListener(this);
        engine = new IndoorRoutingEngine(venueEngine.getVenueService());
        controller = new IndoorRoutingController(venueMap, mapView.getMapScene());
        this.indoorRoutingLayout = indoorRoutingLayout;
        indoorRoutingButton.setOnClickListener(v -> setVisible(!visible));
        indoorRoutingSettings = indoorRoutingLayout.findViewById(R.id.indoorRouteSettingsLayout);
        View settingsButton = indoorRoutingLayout.findViewById(R.id.indoorRouteSettingsButton);
        settingsButton.setOnClickListener(v -> setSettingsVisible(!settingsVisible));
        startTextView = indoorRoutingLayout.findViewById(R.id.indoorRouteStartText);
        destinationTextView = indoorRoutingLayout.findViewById(R.id.indoorRouteDestText);
        View calcRouteButton = indoorRoutingLayout.findViewById(R.id.calcIndoorRoutingButton);
        calcRouteButton.setOnClickListener(v -> calculateRoute());

        fastRadioButton = indoorRoutingLayout.findViewById(R.id.fastRadioButton);
        fastRadioButton.setOnClickListener(v -> onRouteModeChanged());
        RadioButton shortRadioButton = indoorRoutingLayout.findViewById(R.id.shortRadioButton);
        shortRadioButton.setOnClickListener(v -> onRouteModeChanged());

        pedestrianRadioButton = indoorRoutingLayout.findViewById(R.id.pedestrianRadioButton);
        pedestrianRadioButton.setOnClickListener(v -> onTransportModeChanged());
        RadioButton carRadioButton = indoorRoutingLayout.findViewById(R.id.carRadioButton);
        carRadioButton.setOnClickListener(v -> onTransportModeChanged());

        EditText walSpeedText = indoorRoutingLayout.findViewById(R.id.walkSpeedEditText);
        walSpeedText.setOnEditorActionListener(this ::onWalkSpeedEditorAction);

        int[] checkBoxesIds = {R.id.avoidElevatorCheckBox,
                R.id.avoidEscalatorCheckBox,
                R.id.avoidStairsCheckBox,
                R.id.avoidRampCheckBox,
                R.id.avoidMovingWalkwayCheckBox,
                R.id.avoidTransitionCheckBox};
        for (int checkBoxesId : checkBoxesIds) {
            indoorRoutingLayout.findViewById(checkBoxesId)
                    .setOnClickListener(this ::onAvoidFeatureChanged);
        }

        setVisible(false);
        setSettingsVisible(false);
        setUpRouteStyle();
    }

    public boolean isVisible() {
        return visible;
    }

    private void setUpRouteStyle() {
        Anchor2D middleBottomAnchor = new Anchor2D(0.5, 1.0);
        routeStyle.setStartMarker(initMapMarker(R.drawable.ic_route_start, middleBottomAnchor));
        routeStyle.setDestinationMarker(initMapMarker(R.drawable.ic_route_end, middleBottomAnchor));
        routeStyle.setWalkMarker(initMapMarker(R.drawable.indoor_walk));
        routeStyle.setDriveMarker(initMapMarker(R.drawable.indoor_drive));

        IndoorFeatures[] features = new IndoorFeatures[] {IndoorFeatures.ELEVATOR,
                                                          IndoorFeatures.ESCALATOR,
                                                          IndoorFeatures.STAIRS,
                                                          IndoorFeatures.RAMP};
        for (IndoorFeatures feature : features) {
            MapMarker marker = initMapMarker(getIndoorFeatureResource(feature, 0));
            MapMarker upMarker = initMapMarker(getIndoorFeatureResource(feature, 1));
            MapMarker downMarker = initMapMarker(getIndoorFeatureResource(feature, -1));
            routeStyle.setIndoorMarkersFor(feature, upMarker, downMarker, marker);
        }
    }

    private @Nullable MapMarker initMapMarker(final int resourceID, final Anchor2D anchor) {
        if (resourceID == 0) {
            return null;
        }
        MapImage markerImage = MapImageFactory.fromResource(context.getResources(), resourceID);
        if (markerImage != null) {
            return new MapMarker(new GeoCoordinates(0.0, 0.0), markerImage, anchor);
        }

        return null;
    }

    private int getIndoorFeatureResource(IndoorFeatures feature, int delta_z) {
        switch (feature) {
        case ELEVATOR:
            switch (delta_z) {
            case 0:
                return R.drawable.indoor_elevator;
            case 1:
                return R.drawable.indoor_elevator_up;
            case -1:
                return R.drawable.indoor_elevator_down;
            }
            break;
        case ESCALATOR:
            switch (delta_z) {
            case 0:
                return R.drawable.indoor_escalator;
            case 1:
                return R.drawable.indoor_escalator_up;
            case -1:
                return R.drawable.indoor_escalator_down;
            }
            break;
        case RAMP:
            switch (delta_z) {
            case 0:
                return R.drawable.indoor_ramp;
            case 1:
                return R.drawable.indoor_ramp_up;
            case -1:
                return R.drawable.indoor_ramp_down;
            }
            break;
        case STAIRS:
            switch (delta_z) {
            case 0:
                return R.drawable.indoor_stairs;
            case 1:
                return R.drawable.indoor_stairs_up;
            case -1:
                return R.drawable.indoor_stairs_down;
            }
            break;
        case TRANSITION:
        case MOVING_WALKWAY:
            return 0;
        }

        return 0;
    }

    private @Nullable MapMarker initMapMarker(final int resourceID) {
        return initMapMarker(resourceID, new Anchor2D());
    }

    private void setVisible(final boolean value) {
        if (visible == value) {
            return;
        }
        visible = value;
        indoorRoutingLayout.setVisibility(visible ? View.VISIBLE : View.GONE);
    }

    private void setSettingsVisible(final boolean value) {
        if (settingsVisible == value) {
            return;
        }
        settingsVisible = value;
        indoorRoutingSettings.setVisibility(settingsVisible ? View.VISIBLE : View.GONE);
    }

    private @Nullable IndoorWaypoint getIndoorWaypoint(@NonNull final Point2D origin) {
        GeoCoordinates position = mapView.viewToGeoCoordinates(origin);
        if (position != null) {
            Venue venue = venueMap.getVenue(position);
            if (venue != null) {
                VenueModel venueModel = venue.getVenueModel();
                Venue selectedVenue = venueMap.getSelectedVenue();
                if (selectedVenue != null &&
                    venueModel.getId() == selectedVenue.getVenueModel().getId()) {
                    return new IndoorWaypoint(
                            position,
                            String.valueOf(venueModel.getId()),
                            String.valueOf(venue.getSelectedLevel().getId()));
                } else {
                    venueMap.setSelectedVenue(venue);
                    return null;
                }
            }

            return new IndoorWaypoint(position);
        }

        return null;
    }

    private void updateWaypointTextView(final TextView textView, final IndoorWaypoint waypoint) {
        StringBuilder text = new StringBuilder();
        if (waypoint.getVenueId() != null && waypoint.getLevelId() != null) {
            text.append("Venue ID:")
                    .append(waypoint.getVenueId())
                    .append(", Level ID:")
                    .append(waypoint.getLevelId())
                    .append(", ");
        }
        text.append("Lat: ")
                .append(String.format(
                        Locale.getDefault(), "%1$,.6f", waypoint.getCoordinates().latitude))
                .append(", Lng: ")
                .append(String.format(
                        Locale.getDefault(), "%1$,.6f", waypoint.getCoordinates().longitude));
        textView.setText(text.toString());
    }

    public void onTap(@NonNull final Point2D origin) {
        IndoorWaypoint waypoint = getIndoorWaypoint(origin);
        if (visible && waypoint != null) {
            destinationWaypoint = waypoint;
            updateWaypointTextView(destinationTextView, waypoint);
        }
    }

    @Override
    public void onLongPress(@NonNull final GestureState state, @NonNull final Point2D origin) {
        if (!visible || state != GestureState.END) {
            return;
        }
        IndoorWaypoint waypoint = getIndoorWaypoint(origin);
        if (waypoint != null) {
            startWaypoint = waypoint;
            updateWaypointTextView(startTextView, waypoint);
        }
    }

    private void calculateRoute() {
        engine.calculateRoute(startWaypoint, destinationWaypoint, routeOptions, this ::showRoute);
    }

    private void showRoute(
            @Nullable final RoutingError routingError, @Nullable final List<Route> routeList) {
        controller.hideRoute();
        if (routingError == null && routeList != null) {
            Route route = routeList.get(0);
            controller.showRoute(route, routeStyle);
        } else {
            Toast toast = Toast.makeText(
                    context, "Failed to calculate the indoor route!", Toast.LENGTH_LONG);
            toast.show();
        }
    }

    private void onRouteModeChanged() {
        if (fastRadioButton.isChecked()) {
            routeOptions.routeOptions.optimizationMode = OptimizationMode.FASTEST;
        } else {
            routeOptions.routeOptions.optimizationMode = OptimizationMode.SHORTEST;
        }
    }

    private void onTransportModeChanged() {
        if (pedestrianRadioButton.isChecked()) {
            routeOptions.transportMode = IndoorTransportMode.PEDESTRIAN;
        } else {
            routeOptions.transportMode = IndoorTransportMode.CAR;
        }
    }

    private boolean onWalkSpeedEditorAction(TextView textView, int actionId, KeyEvent event) {
        if (actionId == EditorInfo.IME_ACTION_SEARCH || actionId == EditorInfo.IME_ACTION_DONE ||
            event != null && event.getAction() == KeyEvent.ACTION_DOWN &&
                    event.getKeyCode() == KeyEvent.KEYCODE_ENTER) {
            if (event == null || !event.isShiftPressed()) {
                String venueString = textView.getText().toString();
                try {
                    double walkSpeed = Double.parseDouble(venueString);
                    if (walkSpeed < 0.5) {
                        walkSpeed = 0.5;
                    } else if (walkSpeed > 2.0) {
                        walkSpeed = 2.0;
                    }
                    textView.setText(String.format(Locale.getDefault(), "%1$,.1f", walkSpeed));
                    routeOptions.walkSpeedInMetersPerSecond = walkSpeed;
                } catch (Exception e) {
                    Log.d(TAG, "Filed to parse walk speed", e);
                    double walkSpeed = 1.0;
                    textView.setText(String.valueOf(walkSpeed));
                    routeOptions.walkSpeedInMetersPerSecond = walkSpeed;
                }
                return true;
            }
        }
        return false;
    }

    private void onAvoidFeatureChanged(View view) {
        CheckBox checkBox = (CheckBox) view;
        if (checkBox == null) {
            return;
        }

        try {
            IndoorFeatures feature = getIndoorFeature(checkBox.getText().toString());
            if (checkBox.isChecked()) {
                routeOptions.indoorAvoidanceOptions.indoorFeatures.add(feature);
            } else {
                routeOptions.indoorAvoidanceOptions.indoorFeatures.remove(feature);
            }
        } catch (IllegalStateException e) {
            Log.d(TAG, "Failed to parse the name of the checkbox.", e);
        }
    }

    private IndoorFeatures getIndoorFeature(String checkboxName) throws IllegalStateException {
        switch (checkboxName) {
        case "Elevator":
            return IndoorFeatures.ELEVATOR;
        case "Escalator":
            return IndoorFeatures.ESCALATOR;
        case "Moving walkway":
            return IndoorFeatures.MOVING_WALKWAY;
        case "Ramp":
            return IndoorFeatures.RAMP;
        case "Stairs":
            return IndoorFeatures.STAIRS;
        case "Transition":
            return IndoorFeatures.TRANSITION;
        default:
            throw new IllegalStateException(
                    "Failed to parse the name of the checkbox: " + checkboxName);
        }
    }

    public void dispose() {
        venueMap = null;
        if (mapView != null) {
            mapView.getGestures().setLongPressListener(null);
            mapView = null;
        }
    }

    @Override
    protected void finalize() throws Throwable {
        dispose();
        super.finalize();
    }
}
