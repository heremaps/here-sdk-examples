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

package com.here.navigation;

import android.content.Context;
import android.media.Ringtone;
import android.media.RingtoneManager;
import android.net.Uri;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.google.android.material.snackbar.Snackbar;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.LanguageCode;
import com.here.sdk.core.Location;
import com.here.sdk.core.UnitSystem;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.location.LocationAccuracy;
import com.here.sdk.mapview.MapView;
import com.here.sdk.navigation.CameraTrackingMode;
import com.here.sdk.navigation.DestinationReachedListener;
import com.here.sdk.navigation.DimensionRestrictionType;
import com.here.sdk.navigation.DistanceType;
import com.here.sdk.navigation.JunctionViewLaneAssistance;
import com.here.sdk.navigation.JunctionViewLaneAssistanceListener;
import com.here.sdk.navigation.Lane;
import com.here.sdk.navigation.LaneRecommendationState;
import com.here.sdk.navigation.ManeuverNotificationListener;
import com.here.sdk.navigation.ManeuverNotificationOptions;
import com.here.sdk.navigation.ManeuverProgress;
import com.here.sdk.navigation.ManeuverViewLaneAssistance;
import com.here.sdk.navigation.ManeuverViewLaneAssistanceListener;
import com.here.sdk.navigation.MapMatchedLocation;
import com.here.sdk.navigation.Milestone;
import com.here.sdk.navigation.MilestoneReachedListener;
import com.here.sdk.navigation.NavigableLocation;
import com.here.sdk.navigation.NavigableLocationListener;
import com.here.sdk.navigation.RoadAttributes;
import com.here.sdk.navigation.RoadAttributesListener;
import com.here.sdk.navigation.RoadTextsListener;
import com.here.sdk.navigation.RouteDeviation;
import com.here.sdk.navigation.RouteDeviationListener;
import com.here.sdk.navigation.RouteProgress;
import com.here.sdk.navigation.RouteProgressListener;
import com.here.sdk.navigation.SectionProgress;
import com.here.sdk.navigation.SpeedLimit;
import com.here.sdk.navigation.SpeedLimitListener;
import com.here.sdk.navigation.SpeedLimitOffset;
import com.here.sdk.navigation.SpeedWarningListener;
import com.here.sdk.navigation.SpeedWarningOptions;
import com.here.sdk.navigation.SpeedWarningStatus;
import com.here.sdk.navigation.TruckRestrictionWarning;
import com.here.sdk.navigation.TruckRestrictionsWarningListener;
import com.here.sdk.navigation.VisualNavigator;
import com.here.sdk.navigation.WeightRestrictionType;
import com.here.sdk.routing.Maneuver;
import com.here.sdk.routing.ManeuverAction;
import com.here.sdk.routing.RoadTexts;
import com.here.sdk.routing.RoadType;
import com.here.sdk.routing.Route;
import com.here.sdk.routing.RoutingError;
import com.here.sdk.trafficawarenavigation.DynamicRoutingEngine;
import com.here.sdk.trafficawarenavigation.DynamicRoutingEngineOptions;
import com.here.sdk.trafficawarenavigation.DynamicRoutingListener;

import java.util.Arrays;
import java.util.List;
import java.util.Locale;

// Shows how to start and stop turn-by-turn navigation on a car route.
// By default, tracking mode is enabled. When navigation is stopped, tracking mode is enabled again.
// The preferred device language determines the language for voice notifications used for TTS.
// (Make sure to set language + region in device settings.)
public class NavigationExample {

    private static final String TAG = NavigationExample.class.getName();

    private final Context context;
    private final VisualNavigator visualNavigator;
    private final HEREPositioningProvider herePositioningProvider;
    private final HEREPositioningSimulator herePositioningSimulator;
    private DynamicRoutingEngine dynamicRoutingEngine;
    private final VoiceAssistant voiceAssistant;
    private int previousManeuverIndex = -1;
    private MapMatchedLocation lastMapMatchedLocation;

    private final Snackbar snackbar;

    public NavigationExample(Context context, MapView mapView) {
        this.context = context;

        // A class to receive real location events.
        herePositioningProvider = new HEREPositioningProvider();
        // A class to receive simulated location events.
        herePositioningSimulator = new HEREPositioningSimulator();

        try {
            // Without a route set, this starts tracking mode.
            visualNavigator = new VisualNavigator();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of VisualNavigator failed: " + e.error.name());
        }

        // This enables a navigation view including a rendered navigation arrow.
        visualNavigator.startRendering(mapView);

        // A helper class for TTS.
        voiceAssistant = new VoiceAssistant(context);

        createDynamicRoutingEngine();

        setupListeners();

        snackbar = Snackbar.make(mapView, "Initialization completed.", Snackbar.LENGTH_INDEFINITE);
        snackbar.show();
    }

    public void startLocationProvider() {
        // Set navigator as listener to receive locations from HERE Positioning
        // and choose the best accuracy for the tbt navigation use case.
        herePositioningProvider.startLocating(visualNavigator, LocationAccuracy.NAVIGATION);
    }

    private void createDynamicRoutingEngine() {
        int pollIntervalInMinutes = 5;

        // We want an update for each poll iteration, so we specify 0 difference.
        int minTimeDifferenceInSeconds = 0;
        double minTimeDifferencePercentage = 0.0;

        DynamicRoutingEngineOptions dynamicRoutingOptions =
        new DynamicRoutingEngineOptions(pollIntervalInMinutes, minTimeDifferenceInSeconds, minTimeDifferencePercentage);

        try {
            // With the dynamic routing engine you can poll the HERE backend services to search for routes with less traffic.
            // THis can happen during guidance - or you can periodically update a route that is shown in a route planner.
            dynamicRoutingEngine = new DynamicRoutingEngine(dynamicRoutingOptions);
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of DynamicRoutingEngine failed: " + e.error.name());
        }
    }

    private void setupListeners() {

        // Notifies on the progress along the route including maneuver instructions.
        visualNavigator.setRouteProgressListener(new RouteProgressListener() {
            @Override
            public void onRouteProgressUpdated(@NonNull RouteProgress routeProgress) {
                List<SectionProgress> sectionProgressList = routeProgress.sectionProgress;
                // sectionProgressList is guaranteed to be non-empty.
                SectionProgress lastSectionProgress = sectionProgressList.get(sectionProgressList.size() - 1);
                Log.d(TAG, "Distance to destination in meters: " + lastSectionProgress.remainingDistanceInMeters);
                Log.d(TAG, "Traffic delay ahead in seconds: " + lastSectionProgress.trafficDelayInSeconds);

                // Contains the progress for the next maneuver ahead and the next-next maneuvers, if any.
                List<ManeuverProgress> nextManeuverList = routeProgress.maneuverProgress;

                ManeuverProgress nextManeuverProgress = nextManeuverList.get(0);
                if (nextManeuverProgress == null) {
                    Log.d(TAG, "No next maneuver available.");
                    return;
                }

                int nextManeuverIndex = nextManeuverProgress.maneuverIndex;
                Maneuver nextManeuver = visualNavigator.getManeuver(nextManeuverIndex);
                if (nextManeuver == null) {
                    // Should never happen as we retrieved the next maneuver progress above.
                    return;
                }

                ManeuverAction action = nextManeuver.getAction();
                String roadName = getRoadName(nextManeuver);
                String logMessage = action.name() + " on " + roadName +
                        " in " + nextManeuverProgress.remainingDistanceInMeters + " meters.";

                if (previousManeuverIndex != nextManeuverIndex) {
                    snackbar.setText("New maneuver: " + logMessage).show();
                } else {
                    // A maneuver update contains a different distance to reach the next maneuver.
                    snackbar.setText("Maneuver update: " + logMessage).show();
                }

                previousManeuverIndex = nextManeuverIndex;

                 if (lastMapMatchedLocation != null) {
                    // Update the route based on the current location of the driver.
                    // We periodically want to search for better traffic-optimized routes.
                    dynamicRoutingEngine.updateCurrentLocation(lastMapMatchedLocation, routeProgress.sectionIndex);
                }
            }
        });

        // Notifies when the destination of the route is reached.
        visualNavigator.setDestinationReachedListener(new DestinationReachedListener() {
            @Override
            public void onDestinationReached() {
                String message = "Destination reached. Stopping turn-by-turn navigation.";
                snackbar.setText(message).show();
                stopNavigation();
            }
        });

        // Notifies when a waypoint on the route is reached.
        visualNavigator.setMilestoneReachedListener(new MilestoneReachedListener() {
            @Override
            public void onMilestoneReached(@NonNull Milestone milestone) {
                if (milestone.waypointIndex != null) {
                    Log.d(TAG, "A user-defined waypoint was reached, index of waypoint: " + milestone.waypointIndex);
                    Log.d(TAG,"Original coordinates: " + milestone.originalCoordinates);
                } else {
                    // For example, when transport mode changes due to a ferry.
                    Log.d(TAG,"A system defined waypoint was reached at " + milestone.mapMatchedCoordinates);
                }
            }
        });

        // Notifies when the current speed limit is exceeded.
        visualNavigator.setSpeedWarningListener(new SpeedWarningListener() {
            @Override
            public void onSpeedWarningStatusChanged(@NonNull SpeedWarningStatus speedWarningStatus) {
                if (speedWarningStatus == SpeedWarningStatus.SPEED_LIMIT_EXCEEDED) {
                    // Driver is faster than current speed limit (plus an optional offset).
                    // Play a notification sound to alert the driver.
                    // Note that this may not include temporary special speed limits, see SpeedLimitListener.
                    Uri ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION);
                    Ringtone ringtone = RingtoneManager.getRingtone(context, ringtoneUri);
                    ringtone.play();
                }

                if (speedWarningStatus == SpeedWarningStatus.SPEED_LIMIT_RESTORED) {
                    Log.d(TAG, "Driver is again slower than current speed limit (plus an optional offset).");
                }
            }
        });

        // Notifies on the current speed limit valid on the current road.
        visualNavigator.setSpeedLimitListener(new SpeedLimitListener() {
            @Override
            public void onSpeedLimitUpdated(@NonNull SpeedLimit speedLimit) {
                Double currentSpeedLimit = getCurrentSpeedLimit(speedLimit);

                if (currentSpeedLimit == null) {
                    Log.d(TAG, "Warning: Speed limits unkown, data could not be retrieved.");
                } else if (currentSpeedLimit == 0) {
                    Log.d(TAG, "No speed limits on this road! Drive as fast as you feel safe ...");
                } else {
                    Log.d(TAG, "Current speed limit (m/s):" + currentSpeedLimit);
                }
            }
        });

        // Notifies on the current map-matched location and other useful information while driving or walking.
        visualNavigator.setNavigableLocationListener(new NavigableLocationListener() {
            @Override
            public void onNavigableLocationUpdated(@NonNull NavigableLocation currentNavigableLocation) {
                lastMapMatchedLocation = currentNavigableLocation.mapMatchedLocation;
                if (lastMapMatchedLocation == null) {
                    Log.d(TAG, "The currentNavigableLocation could not be map-matched. Are you off-road?");
                    return;
                }

                Double speed = currentNavigableLocation.originalLocation.speedInMetersPerSecond;
                Double accuracy = currentNavigableLocation.originalLocation.speedAccuracyInMetersPerSecond;
                Log.d(TAG, "Driving speed (m/s): " + speed + "plus/minus an accuracy of: " +accuracy);
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
            }
        });

        // Notifies on voice maneuver messages.
        visualNavigator.setManeuverNotificationListener(new ManeuverNotificationListener() {
            @Override
            public void onManeuverNotification(@NonNull String voiceText) {
                voiceAssistant.speak(voiceText);
            }
        });

        // Notifies which lane(s) lead to the next (next) maneuvers.
        visualNavigator.setManeuverViewLaneAssistanceListener(new ManeuverViewLaneAssistanceListener() {
            @Override
            public void onLaneAssistanceUpdated(@NonNull ManeuverViewLaneAssistance maneuverViewLaneAssistance) {
                // This lane list is guaranteed to be non-empty.
                List<Lane> lanes = maneuverViewLaneAssistance.lanesForNextManeuver;
                logLaneRecommendations(lanes);

                List<Lane> nextLanes = maneuverViewLaneAssistance.lanesForNextNextManeuver;
                if (!nextLanes.isEmpty()) {
                    Log.d(TAG, "Attention, the next next maneuver is very close.");
                    Log.d(TAG, "Please take the following lane(s) after the next maneuver: ");
                    logLaneRecommendations(nextLanes);
                }
            }
        });

        // Notfies which lane(s) allow to follow the route.
        visualNavigator.setJunctionViewLaneAssistanceListener(new JunctionViewLaneAssistanceListener() {
            @Override
            public void onLaneAssistanceUpdated(@NonNull JunctionViewLaneAssistance junctionViewLaneAssistance) {
                List<Lane> lanes = junctionViewLaneAssistance.lanesForNextJunction;
                if (lanes.isEmpty()) {
                    Log.d(TAG, "You have passed the complex junction.");
                } else {
                    Log.d(TAG, "Attention, a complex junction is ahead.");
                    logLaneRecommendations(lanes);
                }
            }
        });

        // Notifies on the attributes of the current road including usage and physical characteristics.
        visualNavigator.setRoadAttributesListener(new RoadAttributesListener() {
            @Override
            public void onRoadAttributesUpdated(@NonNull RoadAttributes roadAttributes) {
                // This is called whenever any road attribute has changed.
                // If all attributes are unchanged, no new event is fired.
                // Note that a road can have more than one attribute at the same time.

                Log.d(TAG, "Received road attributes update.");

                if (roadAttributes.isBridge) {
                    // Identifies a structure that allows a road, railway, or walkway to pass over another road, railway,
                    // waterway, or valley serving map display and route guidance functionalities.
                    Log.d(TAG, "Road attributes: This is a bridge.");
                }
                if (roadAttributes.isControlledAccess) {
                    // Controlled access roads are roads with limited entrances and exits that allow uninterrupted
                    // high-speed traffic flow.
                    Log.d(TAG, "Road attributes: This is a controlled access road.");
                }
                if (roadAttributes.isDirtRoad) {
                    // Indicates whether the navigable segment is paved.
                    Log.d(TAG, "Road attributes: This is a dirt road.");
                }
                if (roadAttributes.isDividedRoad) {
                    // Indicates if there is a physical structure or painted road marking intended to legally prohibit
                    // left turns in right-side driving countries, right turns in left-side driving countries,
                    // and U-turns at divided intersections or in the middle of divided segments.
                    Log.d(TAG, "Road attributes: This is a divided road.");
                }
                if (roadAttributes.isNoThrough) {
                    // Identifies a no through road.
                    Log.d(TAG, "Road attributes: This is a no through road.");
                }
                if (roadAttributes.isPrivate) {
                    // Private identifies roads that are not maintained by an organization responsible for maintenance of
                    // public roads.
                    Log.d(TAG, "Road attributes: This is a private road.");
                }
                if (roadAttributes.isRamp) {
                    // Range is a ramp: connects roads that do not intersect at grade.
                    Log.d(TAG, "Road attributes: This is a ramp.");
                }
                if (roadAttributes.isRightDrivingSide) {
                    // Indicates if vehicles have to drive on the right-hand side of the road or the left-hand side.
                    // For example, in New York it is always true and in London always false as the United Kingdom is
                    // a left-hand driving country.
                    Log.d(TAG, "Road attributes: isRightDrivingSide = " + roadAttributes.isRightDrivingSide);
                }
                if (roadAttributes.isRoundabout) {
                    // Indicates the presence of a roundabout.
                    Log.d(TAG, "Road attributes: This is a roundabout.");
                }
                if (roadAttributes.isTollway) {
                    // Identifies a road for which a fee must be paid to use the road.
                    Log.d(TAG, "Road attributes change: This is a road with toll costs.");
                }
                if (roadAttributes.isTunnel) {
                    // Identifies an enclosed (on all sides) passageway through or under an obstruction.
                    Log.d(TAG, "Road attributes: This is a tunnel.");
                }
            }
        });

        // Notifies truck drivers on road restrictions ahead.
        // For example, there can be a bridge ahead not high enough to pass a big truck
        // or there can be a road ahead where the weight of the truck is beyond it's permissible weight.
        // This event notifies on truck restrictions in general,
        // so it will also deliver events, when the transport type was set to a non-truck transport type.
        // The given restrictions are based on the HERE database of the road network ahead.
        visualNavigator.setTruckRestrictionsWarningListener(new TruckRestrictionsWarningListener() {
            @Override
            public void onTruckRestrictionsWarningUpdated(@NonNull List<TruckRestrictionWarning> list) {
                // The list is guaranteed to be non-empty.
                for (TruckRestrictionWarning truckRestrictionWarning : list) {

                    if (truckRestrictionWarning.distanceType == DistanceType.AHEAD) {
                        Log.d(TAG, "TruckRestrictionWarning ahead in: "+ truckRestrictionWarning.distanceInMeters + " meters.");
                    } else if (truckRestrictionWarning.distanceType == DistanceType.PASSED) {
                        Log.d(TAG, "A restriction just passed.");
                    }
                    // One of the following restrictions applies ahead, if more restrictions apply at the same time,
                    // they are part of another TruckRestrictionWarning element contained in the list.
                    if (truckRestrictionWarning.weightRestriction != null) {
                        // For now only one weight type (= truck) is exposed.
                        WeightRestrictionType type = truckRestrictionWarning.weightRestriction.type;
                        int value = truckRestrictionWarning.weightRestriction.valueInKilograms;
                        Log.d(TAG, "TruckRestriction for weight (kg): " + type.name() + ": " + value);
                    }
                    if (truckRestrictionWarning.dimensionRestriction != null) {
                        // Can be either a length, width or height restriction of the truck. For example, a height
                        // restriction can apply for a tunnel. Other possible restrictions are delivered in
                        // separate TruckRestrictionWarning objects contained in the list, if any.
                        DimensionRestrictionType type = truckRestrictionWarning.dimensionRestriction.type;
                        int value = truckRestrictionWarning.dimensionRestriction.valueInCentimeters;
                        Log.d(TAG, "TruckRestriction for dimension: " + type.name() + ": " + value);
                    }
                }
            }
        });

        // Notifies whenever any textual attribute of the current road changes, i.e., the current road texts differ
        // from the previous one. This can be useful during tracking mode, when no maneuver information is provided.
        visualNavigator.setRoadTextsListener(new RoadTextsListener() {
            @Override
            public void onRoadTextsUpdated(@NonNull RoadTexts roadTexts) {
                // See getRoadName() how to get the current road name from the provided RoadTexts.
            }
        });
    }

    private String getRoadName(Maneuver maneuver) {
        RoadTexts currentRoadTexts = maneuver.getRoadTexts();
        RoadTexts nextRoadTexts = maneuver.getNextRoadTexts();

        List<Locale> locales = Arrays.asList(new Locale("eng"));
        String currentRoadName = currentRoadTexts.names.getPreferredValueForLocales(locales);
        String currentRoadNumber = currentRoadTexts.numbers.getPreferredValueForLocales(locales);
        String nextRoadName = nextRoadTexts.names.getPreferredValueForLocales(locales);
        String nextRoadNumber = nextRoadTexts.numbers.getPreferredValueForLocales(locales);

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

    private void logLaneRecommendations(List<Lane> lanes) {
        // The lane at index 0 is the leftmost lane adjacent to the middle of the road.
        // The lane at the last index is the rightmost lane.
        // Note: Left-hand countries are not yet supported.
        int laneNumber = 0;
        for (Lane lane : lanes) {
            // This state is only possible if maneuverViewLaneAssistance.lanesForNextNextManeuver is not empty.
            // For example, when two lanes go left, this lanes leads only to the next maneuver,
            // but not to the maneuver after the next maneuver, while the highly recommended lane also leads
            // to this next next maneuver.
            if (lane.recommendationState == LaneRecommendationState.RECOMMENDED) {
                Log.d(TAG,"Lane " + laneNumber + " leads to next maneuver, but not to the next next maneuver.");
            }

            // If laneAssistance.lanesForNextNextManeuver is not empty, this lane leads also to the
            // maneuver after the next maneuver.
            if (lane.recommendationState == LaneRecommendationState.HIGHLY_RECOMMENDED) {
                Log.d(TAG,"Lane " + laneNumber + " leads to next maneuver and eventually to the next next maneuver.");
            }

            if (lane.recommendationState == LaneRecommendationState.NOT_RECOMMENDED) {
                Log.d(TAG,"Do not take lane " + laneNumber + " to follow the route.");
            }

            laneNumber++;
        }
    }

    private Double getCurrentSpeedLimit(SpeedLimit speedLimit) {

        // Note that all values can be null if no data is available.

        // The regular speed limit if available. In case of unbounded speed limit, the value is zero.
        Log.d(TAG,"speedLimitInMetersPerSecond: " + speedLimit.speedLimitInMetersPerSecond);

        // A conditional school zone speed limit as indicated on the local road signs.
        Log.d(TAG,"schoolZoneSpeedLimitInMetersPerSecond: " + speedLimit.schoolZoneSpeedLimitInMetersPerSecond);

        // A conditional time-dependent speed limit as indicated on the local road signs.
        // It is in effect considering the current local time provided by the device's clock.
        Log.d(TAG,"timeDependentSpeedLimitInMetersPerSecond: " + speedLimit.timeDependentSpeedLimitInMetersPerSecond);

        // A conditional non-legal speed limit that recommends a lower speed,
        // for example, due to bad road conditions.
        Log.d(TAG,"advisorySpeedLimitInMetersPerSecond: " + speedLimit.advisorySpeedLimitInMetersPerSecond);

        // A weather-dependent speed limit as indicated on the local road signs.
        // The HERE SDK cannot detect the current weather condition, so a driver must decide
        // based on the situation if this speed limit applies.
        Log.d(TAG,"fogSpeedLimitInMetersPerSecond: " + speedLimit.fogSpeedLimitInMetersPerSecond);
        Log.d(TAG,"rainSpeedLimitInMetersPerSecond: " + speedLimit.rainSpeedLimitInMetersPerSecond);
        Log.d(TAG,"snowSpeedLimitInMetersPerSecond: " + speedLimit.snowSpeedLimitInMetersPerSecond);

        // For convenience, this returns the effective (lowest) speed limit between
        // - speedLimitInMetersPerSecond
        // - schoolZoneSpeedLimitInMetersPerSecond
        // - timeDependentSpeedLimitInMetersPerSecond
        return speedLimit.effectiveSpeedLimitInMetersPerSecond();
    }

    public void startNavigation(Route route, boolean isSimulated) {
        setupSpeedWarnings();
        setupVoiceGuidance();

        // Switches to navigation mode when no route was set before, otherwise navigation mode is kept.
        visualNavigator.setRoute(route);

        if (isSimulated) {
            enableRoutePlayback(route);
            snackbar.setText("Starting simulated navgation.").show();
        } else {
            enableDevicePositioning();
            snackbar.setText("Starting navgation.").show();
        }

        startDynamicSearchForBetterRoutes(route);
    }

    private void startDynamicSearchForBetterRoutes(Route route) {
        try {
            dynamicRoutingEngine.start(route, new DynamicRoutingListener() {
                // Notifies on traffic-optimized routes that are considered better than the current route.
                @Override
                public void onBetterRouteFound(@NonNull Route newRoute, int etaDifferenceInSeconds, int distanceDifferenceInMeters) {
                    Log.d(TAG, "DynamicRoutingEngine: Calculated a new route.");
                    Log.d(TAG, "DynamicRoutingEngine: etaDifferenceInSeconds: " + etaDifferenceInSeconds + ".");
                    Log.d(TAG, "DynamicRoutingEngine: distanceDifferenceInMeters: " + distanceDifferenceInMeters + ".");

                    String logMessage = "Calculated a new route. etaDifferenceInSeconds: " + etaDifferenceInSeconds +
                            " distanceDifferenceInMeters: " + distanceDifferenceInMeters;
                    snackbar.setText("DynamicRoutingEngine update: " + logMessage).show();

                    // An implementation can decide to switch to the new route:
                    // visualNavigator.setRoute(newRoute);
                }

                @Override
                public void onRoutingError(@NonNull RoutingError routingError) {
                    Log.d(TAG,"Error while dynamically searching for a better route: " + routingError.name());
                }
            });
        } catch (DynamicRoutingEngine.StartException e) {
            throw new RuntimeException("Start of DynamicRoutingEngine failed. Is the RouteHandle missing?");
        }
    }

    public void stopNavigation() {
        // Switches to tracking mode when a route was set before, otherwise tracking mode is kept.
        // Without a route the navigator will only notify on the current map-matched location
        // including info such as speed and current street name.
        visualNavigator.setRoute(null);
        enableDevicePositioning();
        snackbar.setText("Tracking device's location.").show();

        dynamicRoutingEngine.stop();
    }

    // Provides simulated location updates based on the given route.
    public void enableRoutePlayback(Route route) {
        herePositioningProvider.stopLocating();
        herePositioningSimulator.startLocating(visualNavigator, route);
    }

    // Provides location updates based on the device's GPS sensor.
    public void enableDevicePositioning() {
        herePositioningSimulator.stopLocating();
        herePositioningProvider.startLocating(visualNavigator, LocationAccuracy.NAVIGATION);
    }

    public void startCameraTracking() {
        visualNavigator.setCameraMode(CameraTrackingMode.ENABLED);
    }

    public void stopCameraTracking() {
        visualNavigator.setCameraMode(CameraTrackingMode.DISABLED);
    }

    @Nullable
    public Location getLastKnownLocation() {
        return herePositioningProvider.getLastKnownLocation();
    }

    private void setupSpeedWarnings() {
        double lowSpeedOffsetInMetersPerSecond = 2;
        double highSpeedOffsetInMetersPerSecond = 4;
        double highSpeedBoundaryInMetersPerSecond = 25;
        SpeedLimitOffset speedLimitOffset = new SpeedLimitOffset(
                lowSpeedOffsetInMetersPerSecond, highSpeedOffsetInMetersPerSecond, highSpeedBoundaryInMetersPerSecond);

        visualNavigator.setSpeedWarningOptions(new SpeedWarningOptions(speedLimitOffset));
    }

    private void setupVoiceGuidance() {
        LanguageCode ttsLanguageCode = getLanguageCodeForDevice(VisualNavigator.getAvailableLanguagesForManeuverNotifications());
        visualNavigator.setManeuverNotificationOptions(new ManeuverNotificationOptions(ttsLanguageCode, UnitSystem.METRIC));
        Log.d(TAG, "LanguageCode for maneuver notifications: " + ttsLanguageCode);

        // Set language to our TextToSpeech engine.
        Locale locale = LanguageCodeConverter.getLocale(ttsLanguageCode);
        if (voiceAssistant.setLanguage(locale)) {
            Log.d(TAG, "TextToSpeech engine uses this language: " + locale);
        } else {
            Log.e(TAG, "TextToSpeech engine does not support this language: " + locale);
        }
    }

    // Get the language preferrably used on this device.
    private LanguageCode getLanguageCodeForDevice(List<LanguageCode> supportedVoiceSkins) {

        // 1. Determine if preferred device language is supported by our TextToSpeech engine.
        Locale localeForCurrenDevice = Locale.getDefault();
        if (!voiceAssistant.isLanguageAvailable(localeForCurrenDevice)) {
            Log.e(TAG, "TextToSpeech engine does not support: " + localeForCurrenDevice + ", falling back to EN_US.");
            localeForCurrenDevice = new Locale("en", "US");
        }

        // 2. Determine supported voice skins from HERE SDK.
        LanguageCode languageCodeForCurrenDevice = LanguageCodeConverter.getLanguageCode(localeForCurrenDevice);
        if (!supportedVoiceSkins.contains(languageCodeForCurrenDevice)) {
            Log.e(TAG, "No voice skins available for " + languageCodeForCurrenDevice + ", falling back to EN_US.");
            languageCodeForCurrenDevice = LanguageCode.EN_US;
        }

        return languageCodeForCurrenDevice;
    }

    public void stopLocating() {
        herePositioningProvider.stopLocating();
    }
}
