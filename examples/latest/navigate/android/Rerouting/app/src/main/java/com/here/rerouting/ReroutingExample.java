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

package com.here.rerouting;

import android.content.Context;
import android.graphics.Bitmap;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;

import com.here.sdk.animation.EasingFunction;
import com.here.sdk.core.Anchor2D;
import com.here.sdk.core.Color;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.GeoOrientationUpdate;
import com.here.sdk.core.GeoPolyline;
import com.here.sdk.core.Point2D;
import com.here.sdk.core.Rectangle2D;
import com.here.sdk.core.RouteType;
import com.here.sdk.core.Size2D;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.gestures.GestureState;
import com.here.sdk.mapview.IconProvider;
import com.here.sdk.mapview.IconProviderError;
import com.here.sdk.mapview.MapCamera;
import com.here.sdk.mapview.MapCameraAnimation;
import com.here.sdk.mapview.MapCameraAnimationFactory;
import com.here.sdk.mapview.MapCameraUpdate;
import com.here.sdk.mapview.MapCameraUpdateFactory;
import com.here.sdk.mapview.MapImage;
import com.here.sdk.mapview.MapImageFactory;
import com.here.sdk.mapview.MapMarker;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapPolyline;
import com.here.sdk.mapview.MapScheme;
import com.here.sdk.mapview.MapView;
import com.here.sdk.mapview.RoadShieldIconProperties;
import com.here.sdk.navigation.DestinationReachedListener;
import com.here.sdk.navigation.ManeuverProgress;
import com.here.sdk.navigation.MapMatchedLocation;
import com.here.sdk.navigation.OffRoadDestinationReachedListener;
import com.here.sdk.navigation.OffRoadProgress;
import com.here.sdk.navigation.OffRoadProgressListener;
import com.here.sdk.navigation.RouteDeviation;
import com.here.sdk.navigation.RouteDeviationListener;
import com.here.sdk.navigation.RouteProgress;
import com.here.sdk.navigation.RouteProgressListener;
import com.here.sdk.navigation.VisualNavigator;
import com.here.sdk.routing.CalculateRouteCallback;
import com.here.sdk.routing.CarOptions;
import com.here.sdk.routing.LocalizedRoadNumber;
import com.here.sdk.routing.Maneuver;
import com.here.sdk.routing.ManeuverAction;
import com.here.sdk.routing.RoadTexts;
import com.here.sdk.routing.RoadType;
import com.here.sdk.routing.Route;
import com.here.sdk.routing.RoutingEngine;
import com.here.sdk.routing.RoutingError;
import com.here.sdk.routing.Section;
import com.here.sdk.routing.Span;
import com.here.sdk.routing.Waypoint;
import com.here.time.Duration;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;

// An example that shows how to handle rerouting during guidance alongside.
// The simulated driver will follow the black line showing on the map - this is done with
// a second route that is using additional waypoints. This route is set as
// location source for the LocationSimulator.
// This example also shows a maneuver panel with road shield icons.
public class ReroutingExample {

    private static final String TAG = ReroutingExample.class.getName();

    private final Context context;
    private final MapView mapView;
    private final List<MapMarker> mapMarkers = new ArrayList<>();
    private final List<MapPolyline> mapPolylines = new ArrayList<>();
    private final List<Waypoint> deviationWaypoints = new ArrayList<>();
    private final RoutingEngine routingEngine;
    // A route in Berlin - can be changed via longtap.
    private GeoCoordinates startGeoCoordinates = new GeoCoordinates(52.49047222554655, 13.296884483959285);
    private GeoCoordinates destinationGeoCoordinates = new GeoCoordinates(52.51384077118386, 13.255752692114996);
    // A default deviation point - multiple points can be added via longtap.
    private GeoCoordinates defaultDeviationGeoCoordinates = new GeoCoordinates(52.4925023888559, 13.296233624033844);
    private final MapMarker startMapMarker;
    private final MapMarker destinationMapMarker;
    private boolean changeDestination = true;
    private final VisualNavigator visualNavigator;
    private final HEREPositioningSimulator herePositioningSimulator;
    private final IconProvider iconProvider;
    private String lastRoadShieldText = "";
    private double simulationSpeedFactor = 1;
    private Route lastCalculatedRoute;
    private Route lastCalculatedDeviationRoute;
    private boolean isGuidance = false;
    private boolean setDeviationPoints = false;
    private boolean isReturningToRoute = false;
    private int deviationCounter = 0;
    private Maneuver previousManeuver = null;
    private MainActivity.UICallback uiCallback;

    public ReroutingExample(Context context, MapView mapView) {
        this.context = context;
        this.mapView = mapView;
        MapCamera camera = mapView.getCamera();

        // Center map in Berlin.
        double distanceInMeters = 1000 * 90;
        MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE, distanceInMeters);
        camera.lookAt(new GeoCoordinates(52.520798, 13.409408), mapMeasureZoom);

        try {
            routingEngine = new RoutingEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of RoutingEngine failed: " + e.error.name());
        }

        try {
            visualNavigator = new VisualNavigator();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of VisualNavigator failed: " + e.error.name());
        }

        iconProvider = new IconProvider(mapView.getMapContext());

        setupListeners();

        herePositioningSimulator = new HEREPositioningSimulator();

        // Add markers to indicate the currently selected starting point and destination.
        startMapMarker = addPOIMapMarker(startGeoCoordinates, R.drawable.poi_start);
        destinationMapMarker = addPOIMapMarker(destinationGeoCoordinates, R.drawable.poi_destination);

        // Indicate also the default deviation point - can be changed by the user via longtap.
        MapMarker deviationMapMarker = addPOIMapMarker(defaultDeviationGeoCoordinates, R.drawable.poi_deviation);
        mapMarkers.add(deviationMapMarker);

        setLongPressGestureHandler(mapView);
        showDialog("Note", "Do a long press to change start and destination coordinates.");
    }

    public void setUICallback(MainActivity.UICallback callback) {
        uiCallback = callback;
    }

    private void setupListeners() {
        visualNavigator.setRouteProgressListener(new RouteProgressListener() {
            @Override
            public void onRouteProgressUpdated(@NonNull RouteProgress routeProgress) {
                List<ManeuverProgress> maneuverProgressList = routeProgress.maneuverProgress;
                ManeuverProgress nextManeuverProgress = maneuverProgressList.get(0);
                if (nextManeuverProgress == null) {
                    Log.d(TAG, "No next maneuver available.");
                    return;
                }

                String maneuverDescription = parseManeuver(nextManeuverProgress);
                Log.d(TAG, "Next maneuver: " + maneuverDescription);

                int nextManeuverIndex = nextManeuverProgress.maneuverIndex;
                Maneuver nextManeuver = visualNavigator.getManeuver(nextManeuverIndex);

                if (previousManeuver == nextManeuver) {
                    // We are still trying to reach the next maneuver.
                    return;
                }
                previousManeuver = nextManeuver;

                // A new maneuver takes places. Hide the existing road shield icon, if any.
                uiCallback.onHideRoadShieldIcon();

                Span maneuverSpan = getSpanForManeuver(visualNavigator.getRoute(), nextManeuver);
                if (maneuverSpan != null) {
                    createRoadShieldIconForSpan(maneuverSpan);
                }
            }
        });

        // Notifies on a possible deviation from the route.
        visualNavigator.setRouteDeviationListener(new RouteDeviationListener() {
            @Override
            public void onRouteDeviation(@NonNull RouteDeviation routeDeviation) {
                Route route = visualNavigator.getRoute();
                if (route == null) {
                    // May happen in rare cases when route was set to null inbetween.
                    return;
                }

                // Get current geographic coordinates.
                MapMatchedLocation currentMapMatchedLocation = routeDeviation.currentLocation.mapMatchedLocation;
                GeoCoordinates currentGeoCoordinates = currentMapMatchedLocation == null ?
                        routeDeviation.currentLocation.originalLocation.coordinates : currentMapMatchedLocation.coordinates;

                // Get last geographic coordinates on route.
                GeoCoordinates lastGeoCoordinatesOnRoute;
                if (routeDeviation.lastLocationOnRoute != null) {
                    MapMatchedLocation lastMapMatchedLocationOnRoute = routeDeviation.lastLocationOnRoute.mapMatchedLocation;
                    lastGeoCoordinatesOnRoute = lastMapMatchedLocationOnRoute == null ?
                            routeDeviation.lastLocationOnRoute.originalLocation.coordinates : lastMapMatchedLocationOnRoute.coordinates;
                } else {
                    Log.d(TAG, "User was never following the route. So, we take the start of the route instead.");
                    lastGeoCoordinatesOnRoute = route.getSections().get(0).getDeparturePlace().originalCoordinates;
                }

                int distanceInMeters = (int) currentGeoCoordinates.distanceTo(lastGeoCoordinatesOnRoute);
                Log.d(TAG, "RouteDeviation in meters is " + distanceInMeters);

                // Decide if rerouting should happen and if yes, then return to the original route.
                handleRerouting(routeDeviation, distanceInMeters, currentGeoCoordinates, currentMapMatchedLocation);
            }
        });

        // Notifies when the destination of the route is reached.
        visualNavigator.setDestinationReachedListener(new DestinationReachedListener() {
            @Override
            public void onDestinationReached() {
                if (lastCalculatedRoute == null) {
                    // A new route is calculated, drop out.
                    return;
                }

                Section lastSection = lastCalculatedRoute.getSections().get(lastCalculatedRoute.getSections().size() - 1);
                if (lastSection.getArrivalPlace().isOffRoad()) {
                    Log.d(TAG, "End of navigable route reached.");
                    String message1 = "Your destination is off-road.";
                    String message2 = "Follow the dashed line with caution.";
                    // Note that for this example we inform the user via UI.
                    uiCallback.onManeuverEvent(ManeuverAction.ARRIVE, message1, message2);
                } else {
                    Log.d(TAG, "Destination reached.");
                    String distanceText = "0 m";
                    String message = "You have reached your destination.";
                    uiCallback.onManeuverEvent(ManeuverAction.ARRIVE, distanceText, message);
                }
            }
        });

        // Enable off-road visualization (if any) with a dotted straight-line
        // between the map-matched and the original destination (which is off-road).
        // Note that the color of the dashed line can be customized, if desired.
        // The line will not be rendered if the destination is not off-road.
        // By default, this is enabled.
        visualNavigator.setOffRoadDestinationVisible(true);

        // Notifies on the progress when heading towards an off-road destination.
        // Off-road progress events will be sent only after the user has reached
        // the map-matched destination and the original destination is off-road.
        // Note that when a location cannot be map-matched to a road, then it is considered
        // to be off-road.
        visualNavigator.setOffRoadProgressListener(new OffRoadProgressListener() {
            @Override
            public void onOffRoadProgressUpdated(@NonNull OffRoadProgress offRoadProgress) {
                String distanceText = convertDistance(offRoadProgress.remainingDistanceInMeters);
                // Bearing of the destination compared to the user's current position.
                // The bearing angle indicates the direction into which the user should walk in order
                // to reach the off-road destination - when the device is held up in north-up direction.
                // For example, when the top of the screen points to true north, then 180° means that
                // the destination lies in south direction. 315° would mean the user has to head north-west, and so on.
                String message = "Direction of your destination: " + Math.round(offRoadProgress.bearingInDegrees) + "°";
                uiCallback.onManeuverEvent(ManeuverAction.ARRIVE, distanceText, message);
            }
        });

        // Notifies when the off-road destination of the route has been reached (if any).
        visualNavigator.setOffRoadDestinationReachedListener(new OffRoadDestinationReachedListener() {
            @Override
            public void onOffRoadDestinationReached() {
                Log.d(TAG, "Off-road destination reached.");
                String distanceText = "0 m";
                String message = "You have reached your off-road destination.";
                uiCallback.onManeuverEvent(ManeuverAction.ARRIVE, distanceText, message);
            }
        });

        // For more warners and events during guidance, please check the Navigation example app, available on GitHub.
    }

    private void handleRerouting(RouteDeviation routeDeviation,
                                 int distanceInMeters,
                                 GeoCoordinates currentGeoCoordinates,
                                 MapMatchedLocation currentMapMatchedLocation) {
        // Counts the number of received deviation events. When the user is following a route, no deviation
        // event will occur.
        // It is recommended to await at least 3 deviation events before deciding on an action.
        deviationCounter ++;

        if (isReturningToRoute) {
            // Rerouting is ongoing.
            Log.d(TAG, "Rerouting is ongoing ...");
            return;
        }

        // When user has deviated more than distanceThresholdInMeters. Now we try to return to the original route.
        int distanceThresholdInMeters = 50;
        if (distanceInMeters > distanceThresholdInMeters && deviationCounter >= 3) {
            isReturningToRoute = true;

            // Use current location as new starting point for the route.
            Waypoint newStartingPoint = new Waypoint(currentGeoCoordinates);

            // Improve the route calculation by setting the heading direction.
            if (currentMapMatchedLocation != null && currentMapMatchedLocation.bearingInDegrees != null) {
                newStartingPoint.headingInDegrees = currentMapMatchedLocation.bearingInDegrees;
            }

            // In general, the return.to-route algorithm will try to find the fastest way back to the original route,
            // but it will also respect the distance to the destination. The new route will try to preserve the shape
            // of the original route if possible and it will use the same route options.
            // When the user can now reach the destination faster than with the previously chosen route, a completely new
            // route is calculated.
            Log.d(TAG, "Rerouting: Calculating a new route.");
            routingEngine.returnToRoute(lastCalculatedRoute,
                                        newStartingPoint,
                                        routeDeviation.lastTraveledSectionIndex,
                                        routeDeviation.traveledDistanceOnLastSectionInMeters,
                                        (routingError, list) -> {
                // For simplicity, we use the same route handling.
                // The previous route will be still visible on the map for reference.
                handleRouteResults(routingError, list);
                // Instruct the navigator to follow the calculated route (which will be the new one if no error occurred).
                visualNavigator.setRoute(lastCalculatedRoute);
                // Reset flag and counter.
                isReturningToRoute = false;
                deviationCounter = 0;
                Log.d(TAG, "Rerouting: New route set.");
            });
        }
    }

    private String parseManeuver(ManeuverProgress nextManeuverProgress) {
        int nextManeuverIndex = nextManeuverProgress.maneuverIndex;
        Maneuver nextManeuver = visualNavigator.getManeuver(nextManeuverIndex);

        if (nextManeuver == null) {
            // Should never happen.
            return "Error: No next maneuver.";
        }

        ManeuverAction action = nextManeuver.getAction();
        String roadName = getRoadName(nextManeuver);
        String distanceText = convertDistance(nextManeuverProgress.remainingDistanceInMeters);
        String maneuverText = action.name() + " on " + roadName + " in " + distanceText;

        // Notify UI to show the next maneuver data.
        uiCallback.onManeuverEvent(action, distanceText, roadName);

        return maneuverText;
    }

    // Converts meters to a readable distance text with meters of kilometers:
    // Less than 1000 meters -> m.
    // Between 1 km and 20 km -> km with one digit after comma.
    // Greater than 20 km -> km.
    public String convertDistance(double meters) {
        if (meters < 1000) {
            // Convert meters to meters.
            return String.format("%.0f m", meters);
        } else if (meters >= 1000 && meters <= 20000) {
            // Convert meters to kilometers with one digit rounded.
            double kilometers = meters / 1000;
            return String.format("%.1f km", kilometers);
        } else {
            // Convert meters to kilometers rounded without comma.
            int kilometers = (int) Math.round(meters / 1000);
            return kilometers + " km";
        }
    }

    private String getRoadName(Maneuver maneuver) {
        RoadTexts currentRoadTexts = maneuver.getRoadTexts();
        RoadTexts nextRoadTexts = maneuver.getNextRoadTexts();

        String currentRoadName = currentRoadTexts.names.getDefaultValue();
        String currentRoadNumber = currentRoadTexts.numbersWithDirection.getDefaultValue();
        String nextRoadName = nextRoadTexts.names.getDefaultValue();
        String nextRoadNumber = nextRoadTexts.numbersWithDirection.getDefaultValue();

        String roadName = nextRoadName == null ? nextRoadNumber : nextRoadName;

        // On highways, we want to show the highway number instead of a possible road name,
        // while for inner city and urban areas road names are preferred over road numbers.
        if (maneuver.getNextRoadType() == RoadType.HIGHWAY) {
            roadName = nextRoadNumber == null ? nextRoadName : nextRoadNumber;
        }

        if (maneuver.getAction() == ManeuverAction.ARRIVE) {
            // We are approaching the destination, so there's no next road.
            roadName = currentRoadName == null ? currentRoadNumber : currentRoadName;
        }

        if (roadName == null) {
            // Happens only in rare cases, when also the fallback is null.
            roadName = "unnamed road";
        }

        return roadName;
    }

    @Nullable
    private Span getSpanForManeuver(Route route, Maneuver maneuver) {
        Section sectionOfManeuver = route.getSections().get(maneuver.getSectionIndex());
        List<Span> spansInSection = sectionOfManeuver.getSpans();

        // The last maneuver is located on the last span.
        // Note: Its offset points to the last GeoCoordinates of the route's polyline:
        // maneuver.getOffset() = sectionOfManeuver.getGeometry().vertices.size() - 1.
        if (maneuver.getAction() == ManeuverAction.ARRIVE) {
            return spansInSection.get(spansInSection.size() - 1);
        }

        int indexOfManeuverInSection = maneuver.getOffset();
        for (Span span : spansInSection) {
            // A maneuver always lies on the first point of a span. Except for the
            // the destination that is located somewhere on the last span (see above).
            int firstIndexOfSpanInSection = span.getSectionPolylineOffset();
            if (firstIndexOfSpanInSection >= indexOfManeuverInSection) {
                return span;
            }
        }

        // Should never happen.
        return null;
    }

    private void createRoadShieldIconForSpan(Span span) {
        if (span.getRoadNumbers().items.isEmpty()) {
            // Road shields are only provided for roads that have route numbers such as US-101 or A100.
            // Many streets in a city like "Invalidenstr." have no route number.
            return;
        }

        // For simplicity, we use the 1st item as fallback. There can be more numbers you can pick per desired language.
        LocalizedRoadNumber localizedRoadNumber = span.getRoadNumbers().items.get(0);
        Locale desiredLocale = Locale.US;
        for (LocalizedRoadNumber roadNumber : span.getRoadNumbers().items) {
            if (localizedRoadNumber.localizedNumber.locale == desiredLocale) {
                localizedRoadNumber = roadNumber;
            }
        }

        // The route type indicates if this is a major road or not.
        RouteType routeType = localizedRoadNumber.routeType;
        // The text that should be shown on the road shield.
        String shieldText = span.getShieldText(localizedRoadNumber);
        // This text is used to additionally determine the road shield's visuals.
        String routeNumberName = localizedRoadNumber.localizedNumber.text;

        if (lastRoadShieldText.equals(shieldText)) {
            // It looks like this shield was already created before, so we opt out.
            return;
        }

        lastRoadShieldText = shieldText;

        // Most icons can be created even if some properties are empty.
        // If countryCode is empty, then this will result in a IconProviderError.ICON_NOT_FOUND. Practically,
        // the country code should never be null, unless when there is a very rare data issue.
        String countryCode = span.getCountryCode() == null ? "" : span.getCountryCode();
        String stateCode = span.getStateCode() == null ? "" : span.getStateCode();

        RoadShieldIconProperties roadShieldIconProperties =
                new RoadShieldIconProperties(routeType, countryCode, stateCode, routeNumberName, shieldText);

        // Set the desired constraints. The icon will fit in while preserving its aspect ratio.
        long widthConstraintInPixels = ManeuverView.ROAD_SHIELD_DIM_CONSTRAINTS_IN_PIXELS;
        long heightConstraintInPixels = ManeuverView.ROAD_SHIELD_DIM_CONSTRAINTS_IN_PIXELS;

        // Create the icon offline. Several icons could be created in parallel, but in reality, the road shield
        // will not change very quickly, so that a previous icon will not be overwritten by a parallel call.
        iconProvider.createRoadShieldIcon(
                roadShieldIconProperties,
                // A road shield icon can be created to match visually the currently selected map scheme.
                MapScheme.NORMAL_DAY,
                widthConstraintInPixels,
                heightConstraintInPixels, new IconProvider.IconCallback() {
                    @Override
                    public void onCreateIconReply(@Nullable Bitmap bitmap,
                                                  @Nullable String description,
                                                  @Nullable IconProviderError iconProviderError) {
                        if (iconProviderError != null) {
                            Log.d(TAG, "Cannot create road shield icon: " + iconProviderError.name());
                            return;
                        }

                        // If iconProviderError is null, it is guaranteed that bitmap and description are not null.
                        Bitmap roadShieldIcon = bitmap;

                        // A further description of the generated icon, such as "Federal" or "Autobahn".
                        String shieldDescription = description;
                        Log.d(TAG, "New road shield icon: " + shieldDescription);

                        // An implementation can now decide to show the icon, for example, together with the
                        // next maneuver actions.
                        uiCallback.onRoadShieldEvent(roadShieldIcon);
                    }
                });
    }

    // Use a LongPress handler to define start / destination waypoints.
    private void setLongPressGestureHandler(MapView mapView) {
        mapView.getGestures().setLongPressListener((gestureState, touchPoint) -> {
            GeoCoordinates geoCoordinates = mapView.viewToGeoCoordinates(touchPoint);
            if (geoCoordinates == null) {
                showDialog("Note", "Invalid GeoCoordinates.");
            }
            if (gestureState == GestureState.BEGIN) {
                if (setDeviationPoints) {
                    defaultDeviationGeoCoordinates = null;
                    MapMarker mapMarker = addPOIMapMarker(geoCoordinates, R.drawable.poi_deviation);
                    mapMarkers.add(mapMarker);
                    deviationWaypoints.add(new Waypoint(geoCoordinates));
                } else {
                    // Set new route start or destination geographic coordinates based on long press location.
                    if (changeDestination) {
                        destinationGeoCoordinates = geoCoordinates;
                        destinationMapMarker.setCoordinates(geoCoordinates);
                    } else {
                        startGeoCoordinates = geoCoordinates;
                        startMapMarker.setCoordinates(geoCoordinates);
                    }
                    // Toggle the marker that should be updated on next long press.
                    changeDestination = !changeDestination;
                }
            }
        });
    }

    // Get the waypoint list using the last two long press points and optional deviation waypoints.
    private List<Waypoint> getCurrentWaypoints(boolean insertDeviationWaypoints) {
        Waypoint startWaypoint = new Waypoint(startGeoCoordinates);
        Waypoint destinationWaypoint = new Waypoint(destinationGeoCoordinates);
        List<Waypoint> waypoints = new ArrayList<>();

        if (insertDeviationWaypoints) {
            waypoints.add(startWaypoint);
            // If no custom deviation waypoints have been set, we use initially the default one.
            if (defaultDeviationGeoCoordinates != null) {
                waypoints.add(new Waypoint(defaultDeviationGeoCoordinates));
            }
            for (Waypoint wp : deviationWaypoints) {
                waypoints.add(wp);
            }
            waypoints.add(destinationWaypoint);
        } else {
            waypoints = new ArrayList<>(Arrays.asList(startWaypoint, destinationWaypoint));
        }

        // Log used waypoints for reference.
        Log.d(TAG, "Start Waypoint: " + startWaypoint.coordinates.latitude + ", " + startWaypoint.coordinates.longitude);
        for (Waypoint wp : deviationWaypoints) {
            Log.d(TAG, "Deviation Waypoint: " + wp.coordinates.latitude + ", " + wp.coordinates.longitude);
        }
        Log.d(TAG, "Destination Waypoint: " + destinationWaypoint.coordinates.latitude + ", " + destinationWaypoint.coordinates.longitude);

        return waypoints;
    }

    public void onDefineDeviationPointsButtonClicked() {
        setDeviationPoints = !setDeviationPoints;
        if (setDeviationPoints) {
            showDialog("Note", "Set deviation waypoints now. " +
                    "These points will become stopovers to shape the route that is used for location simulation." +
                    "The original (blue) route will be kept as before for use with the VisualNavigator." +
                    "Click button again to stop setting deviation waypoints.");
        } else {
            showDialog("Note", "Stopped setting deviation waypoints.");
        }
    }

    public void onShowRouteButtonClicked() {
        lastCalculatedRoute = null;
        lastCalculatedDeviationRoute = null;

        calculateRouteForUseWithVisualNavigator();
        calculateDeviationRouteForUseLocationSimulator();
    }

    private void calculateRouteForUseWithVisualNavigator() {
        boolean insertDeviationWaypoints = false;
        CarOptions carOptions = new CarOptions();
        // A route handle is neccessary for rerouting.
        carOptions.routeOptions.enableRouteHandle = true;
        routingEngine.calculateRoute(getCurrentWaypoints(insertDeviationWaypoints), carOptions, (routingError, routes) -> {
            handleRouteResults(routingError, routes);
        });
    }

    private void calculateDeviationRouteForUseLocationSimulator() {
        if (deviationWaypoints.isEmpty() && defaultDeviationGeoCoordinates == null) {
            // No deviation waypoints have been set by user.
            return;
        }

        // Use deviationWaypoints to create a second route and set it as source for LocationSimulator.
        boolean insertDeviationWaypoints = true;
        routingEngine.calculateRoute(getCurrentWaypoints(insertDeviationWaypoints), new CarOptions(), (routingError, routes) -> {
            handleDeviationRouteResults(routingError, routes);
        });
    }

    public void onStartStopButtonClicked() {
        if (lastCalculatedRoute == null) {
            showDialog("Note","Show a route first.");
            return;
        }

        isGuidance = !isGuidance;
        if (isGuidance) {
            // Start guidance.
            visualNavigator.setRoute(lastCalculatedRoute);
            visualNavigator.startRendering(mapView);

            // If we do not have a deviation route set for testing, we simply follow the route.
            Route sourceForLocationSimulation =
                    lastCalculatedDeviationRoute == null ? lastCalculatedRoute : lastCalculatedDeviationRoute;

            // Note that we provide location updates based on route that deviates from the original route,
            // based on the set deviation waypoints by user (if provided).
            // Note: This is for testing puproses only.
            herePositioningSimulator.setSpeedFactor(simulationSpeedFactor);
            herePositioningSimulator.startLocating(visualNavigator, sourceForLocationSimulation);
        } else {
            // Stop guidance.
            visualNavigator.setRoute(null);
            previousManeuver = null;
            visualNavigator.stopRendering();
            herePositioningSimulator.stopLocating();
            uiCallback.onHideManeuverPanel();
            untiltUnrotateMap();
        }
    }

    private void untiltUnrotateMap() {
        double bearingInDegress = 0;
        double tiltInDegress = 0;
        mapView.getCamera().setOrientationAtTarget(new GeoOrientationUpdate(bearingInDegress, tiltInDegress));
    }

    public void onSpeedButtonClicked() {
        // Toggle simulation speed factor.
        if (simulationSpeedFactor == 1) {
            simulationSpeedFactor = 8;
        } else {
            simulationSpeedFactor = 1;
        }

        showDialog("Note", "Changed simulation speed factor to " + simulationSpeedFactor +
                ". Start again to use the new value.");
    }

    private void handleRouteResults(RoutingError routingError, List<Route> routes) {
        if (routingError != null) {
            showDialog("Error while calculating a route: ", routingError.toString());
            return;
        }

        // Reset previous text, if any.
        lastRoadShieldText = "";

        // When routingError is nil, routes is guaranteed to contain at least one route.
        lastCalculatedRoute = routes.get(0);

        Color routeColor = Color.valueOf(0, 0.6f, 1, 1); // RGBA
        int routeWidthInPixels = 30;
        showRouteOnMap(lastCalculatedRoute, routeColor, routeWidthInPixels);
    }

    private void handleDeviationRouteResults(RoutingError routingError, List<Route> routes) {
        if (routingError != null) {
            showDialog("Error while calculating a deviation route: ", routingError.toString());
            return;
        }

        // When routingError is nil, routes is guaranteed to contain at least one route.
        lastCalculatedDeviationRoute = routes.get(0);

        Color blackColor = Color.valueOf(0, 0, 0, 1); // RGBA
        int routeWidthInPixels = 15;
        showRouteOnMap(lastCalculatedDeviationRoute, blackColor, routeWidthInPixels);
    }

    private void showRouteOnMap(Route route, Color color, int widthInPixels) {
        GeoPolyline routeGeoPolyline = route.getGeometry();
        MapPolyline routeMapPolyline = new MapPolyline(routeGeoPolyline, widthInPixels, color);
        mapView.getMapScene().addMapPolyline(routeMapPolyline);
        mapPolylines.add(routeMapPolyline);
        animateToRoute(route);
    }

    private void animateToRoute(Route route) {
        // We want to show the route fitting in the map view with an additional padding of 50 pixels
        Point2D origin = new Point2D(50, 50);
        Size2D sizeInPixels = new Size2D(mapView.getWidth() - 100, mapView.getHeight() - 100);
        Rectangle2D mapViewport = new Rectangle2D(origin, sizeInPixels);

        // Animate to the route within a duration of 3 seconds.
        MapCameraUpdate update = MapCameraUpdateFactory.lookAt(
                route.getBoundingBox(),
                // The animation should result in an unrotated and untilted map.
                new GeoOrientationUpdate(0.0, 0.0),
                mapViewport);
        MapCameraAnimation animation =
                MapCameraAnimationFactory.createAnimation(update, Duration.ofMillis(2000), EasingFunction.OUT_SINE);
        mapView.getCamera().startAnimation(animation);
    }

    public void onClearMapButtonClicked() {
        clearRoute();
        clearMapMarker();
        deviationWaypoints.clear();
        // Clear also the default deviation waypoint.
        defaultDeviationGeoCoordinates = null;
    }

    private void clearRoute() {
        for (MapPolyline mapPolyline : mapPolylines) {
            mapView.getMapScene().removeMapPolyline(mapPolyline);
        }
        mapPolylines.clear();
    }

    private void clearMapMarker() {
        for (MapMarker mapMarker : mapMarkers) {
            mapView.getMapScene().removeMapMarker(mapMarker);
        }
        mapMarkers.clear();
    }

    private MapMarker addPOIMapMarker(GeoCoordinates geoCoordinates, int resourceId) {
        MapImage mapImage = MapImageFactory.fromResource(context.getResources(), resourceId);
        Anchor2D anchor2D = new Anchor2D(0.5F, 1);
        MapMarker mapMarker = new MapMarker(geoCoordinates, mapImage, anchor2D);
        mapView.getMapScene().addMapMarker(mapMarker);
        return mapMarker;
    }

    private void showDialog(String title, String message) {
        AlertDialog.Builder builder =
                new AlertDialog.Builder(context);
        builder.setTitle(title);
        builder.setMessage(message);
        builder.show();
    }
}
