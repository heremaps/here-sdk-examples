/*
 * Copyright (c) 2021-2022 HERE Global B.V. and its affiliate(s).
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

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

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

// Provides UI elements for indoor route calculation and displays an indoor route on the map.
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

        // Initialize IndoorRoutingEngine to be able to calculate indoor routes.
        engine = new IndoorRoutingEngine(venueEngine.getVenueService());
        // Initialize IndoorRoutingController to be able to display indoor routes on the map.
        controller = new IndoorRoutingController(venueMap, mapView.getMapScene());
        // Set a long press listener.
        mapView.getGestures().setLongPressListener(this);

        // Get end setup needed UI elements.
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

        // Hide UI elements for indoor routes calculation.
        setVisible(false);
        // Hide UI elements for indoor route settings.
        setSettingsVisible(false);
        // Setup IndoorRouteStyle object.
        setUpRouteStyle();
    }

    // Get visibility of UI elements for indoor routes calculation.
    public boolean isVisible() {
        return visible;
    }

    // Setup IndoorRouteStyle object, which will be used in indoor route rendering.
    private void setUpRouteStyle() {
        // Set start, end, walk and drive markers. The start marker will be shown at the start of
        // the route and the destination marker at the destination of the route. The walk marker
        // will be shown when the route switches from drive to walk mode and the drive marker
        // vice versa.
        Anchor2D middleBottomAnchor = new Anchor2D(0.5, 1.0);
        routeStyle.setStartMarker(initMapMarker(R.drawable.ic_route_start, middleBottomAnchor));
        routeStyle.setDestinationMarker(initMapMarker(R.drawable.ic_route_end, middleBottomAnchor));
        routeStyle.setWalkMarker(initMapMarker(R.drawable.indoor_walk));
        routeStyle.setDriveMarker(initMapMarker(R.drawable.indoor_drive));

        // Set markers for some of the indoor features. The 'up' marker indicates that the route
        // is going up, and the 'down' marker indicates that the route is going down. The default
        // marker indicates that a user should exit the current indoor feature (e.g. an elevator)
        // to enter the current floor.
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

    // Creates a marker with a resource ID of an image and an anchor.
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

    // Gets a resource ID of an image based on the indoor feature and delta Z, where 0 means
    // a standard icon, 1 means that the icon shows that route is going up, and -1 that it is
    // going down.
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

    // Set visibility of UI elements for indoor routes calculation.
    private void setVisible(final boolean value) {
        if (visible == value) {
            return;
        }
        visible = value;
        indoorRoutingLayout.setVisibility(visible ? View.VISIBLE : View.GONE);
    }

    // Set visibility of UI elements for indoor routes settings.
    private void setSettingsVisible(final boolean value) {
        if (settingsVisible == value) {
            return;
        }
        settingsVisible = value;
        indoorRoutingSettings.setVisibility(settingsVisible ? View.VISIBLE : View.GONE);
    }

    // Create an indoor waypoint based on the tap point on the map.
    private @Nullable IndoorWaypoint getIndoorWaypoint(@NonNull final Point2D origin) {
        GeoCoordinates position = mapView.viewToGeoCoordinates(origin);
        if (position != null) {
            // Check if there is a venue in the tap position.
            Venue venue = venueMap.getVenue(position);
            if (venue != null) {
                VenueModel venueModel = venue.getVenueModel();
                Venue selectedVenue = venueMap.getSelectedVenue();
                if (selectedVenue != null &&
                    venueModel.getId() == selectedVenue.getVenueModel().getId()) {
                    // If the venue is the selected one, return an indoor waypoint
                    // with indoor information.
                    return new IndoorWaypoint(
                            position,
                            String.valueOf(venueModel.getId()),
                            String.valueOf(venue.getSelectedLevel().getId()));
                } else {
                    // If the venue is not the selected one, select it.
                    venueMap.setSelectedVenue(venue);
                    return null;
                }
            }

            // If the tap position is outside of any venue, return an indoor waypoint with
            // outdoor information.
            return new IndoorWaypoint(position);
        }

        return null;
    }

    // Update the text view with a new indoor waypoint.
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

    // Handle the long press events.
    @Override
    public void onLongPress(@NonNull final GestureState state, @NonNull final Point2D origin) {
        if (!visible || state != GestureState.END) {
            return;
        }
        IndoorWaypoint waypoint = getIndoorWaypoint(origin);
        if (waypoint != null) {
            // Set a start waypoint.
            startWaypoint = waypoint;
            updateWaypointTextView(startTextView, waypoint);
        }
    }

    // Handle the tap events.
    public void onTap(@NonNull final Point2D origin) {
        IndoorWaypoint waypoint = getIndoorWaypoint(origin);
        if (visible && waypoint != null) {
            // Set a destination waypoint.
            destinationWaypoint = waypoint;
            updateWaypointTextView(destinationTextView, waypoint);
        }
    }

    // Calculate an indoor route based on the start and destination waypoints, and
    // the indoor route options.
    private void calculateRoute() {
        if (startWaypoint != null && destinationWaypoint != null) {
            engine.calculateRoute(startWaypoint, destinationWaypoint, routeOptions, this::showRoute);
        }
    }

    // Show the resulting route.
    private void showRoute(
            @Nullable final RoutingError routingError, @Nullable final List<Route> routeList) {
        // Hide the existing route, if any.
        controller.hideRoute();
        if (routingError == null && routeList != null) {
            Route route = routeList.get(0);
            // Show the resulting route with predefined indoor routing styles.
            controller.showRoute(route, routeStyle);
        } else {
            // Show a toast message in case of error.
            Toast toast = Toast.makeText(
                    context, "Failed to calculate the indoor route!", Toast.LENGTH_LONG);
            toast.show();
        }
    }

    // Change optimization mode for the indoor route calculation.
    private void onRouteModeChanged() {
        if (fastRadioButton.isChecked()) {
            routeOptions.routeOptions.optimizationMode = OptimizationMode.FASTEST;
        } else {
            routeOptions.routeOptions.optimizationMode = OptimizationMode.SHORTEST;
        }
    }

    // Change transport mode for the indoor route calculation.
    private void onTransportModeChanged() {
        if (pedestrianRadioButton.isChecked()) {
            routeOptions.transportMode = IndoorTransportMode.PEDESTRIAN;
        } else {
            routeOptions.transportMode = IndoorTransportMode.CAR;
        }
    }

    // Change walking speed for the indoor route calculation.
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

    // Adds or removes avoidance features for indoor route calculation.
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

    // Get an indoor feature based on the name.
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
