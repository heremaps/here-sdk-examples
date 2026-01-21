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

package com.here.navigationwarners;

import android.content.Context;
import android.media.Ringtone;
import android.media.RingtoneManager;
import android.net.Uri;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.GeoPolyline;
import com.here.sdk.core.GeoPolylineDirection;
import com.here.sdk.navigation.AspectRatio;
import com.here.sdk.navigation.BorderCrossingWarning;
import com.here.sdk.navigation.BorderCrossingWarningListener;
import com.here.sdk.navigation.BorderCrossingWarningOptions;
import com.here.sdk.navigation.CurrentSituationLaneAssistanceView;
import com.here.sdk.navigation.CurrentSituationLaneAssistanceViewListener;
import com.here.sdk.navigation.CurrentSituationLaneView;
import com.here.sdk.navigation.DangerZoneWarning;
import com.here.sdk.navigation.DangerZoneWarningListener;
import com.here.sdk.navigation.DestinationReachedListener;
import com.here.sdk.navigation.DimensionRestrictionType;
import com.here.sdk.navigation.DistanceType;
import com.here.sdk.navigation.JunctionViewLaneAssistance;
import com.here.sdk.navigation.JunctionViewLaneAssistanceListener;
import com.here.sdk.navigation.Lane;
import com.here.sdk.navigation.LaneAccess;
import com.here.sdk.navigation.LaneDirection;
import com.here.sdk.navigation.LaneMarkings;
import com.here.sdk.navigation.LaneRecommendationState;
import com.here.sdk.navigation.LaneType;
import com.here.sdk.navigation.LowSpeedZoneWarning;
import com.here.sdk.navigation.LowSpeedZoneWarningListener;
import com.here.sdk.navigation.ManeuverNotificationOptions;
import com.here.sdk.navigation.ManeuverProgress;
import com.here.sdk.navigation.ManeuverViewLaneAssistance;
import com.here.sdk.navigation.ManeuverViewLaneAssistanceListener;
import com.here.sdk.navigation.MapMatchedLocation;
import com.here.sdk.navigation.Milestone;
import com.here.sdk.navigation.MilestoneStatus;
import com.here.sdk.navigation.MilestoneStatusListener;
import com.here.sdk.navigation.RealisticViewVectorImage;
import com.here.sdk.navigation.RealisticViewWarning;
import com.here.sdk.navigation.RealisticViewWarningListener;
import com.here.sdk.navigation.RealisticViewWarningOptions;
import com.here.sdk.navigation.RoadAttributes;
import com.here.sdk.navigation.RoadAttributesListener;
import com.here.sdk.navigation.RoadSignType;
import com.here.sdk.navigation.RoadSignVehicleType;
import com.here.sdk.navigation.RoadSignWarning;
import com.here.sdk.navigation.RoadSignWarningListener;
import com.here.sdk.navigation.RoadSignWarningOptions;
import com.here.sdk.navigation.RoadTextsListener;
import com.here.sdk.navigation.RouteDeviation;
import com.here.sdk.navigation.RouteDeviationListener;
import com.here.sdk.navigation.RouteProgress;
import com.here.sdk.navigation.RouteProgressListener;
import com.here.sdk.navigation.SafetyCameraWarning;
import com.here.sdk.navigation.SafetyCameraWarningListener;
import com.here.sdk.navigation.SafetyCameraWarningOptions;
import com.here.sdk.navigation.SchoolZoneWarning;
import com.here.sdk.navigation.SchoolZoneWarningListener;
import com.here.sdk.navigation.SchoolZoneWarningOptions;
import com.here.sdk.navigation.SpeedLimit;
import com.here.sdk.navigation.SpeedLimitListener;
import com.here.sdk.navigation.SpeedLimitOffset;
import com.here.sdk.navigation.SpeedWarningListener;
import com.here.sdk.navigation.SpeedWarningOptions;
import com.here.sdk.navigation.SpeedWarningStatus;
import com.here.sdk.navigation.TollBooth;
import com.here.sdk.navigation.TollBoothLane;
import com.here.sdk.navigation.TollCollectionMethod;
import com.here.sdk.navigation.TollStop;
import com.here.sdk.navigation.TollStopWarningListener;
import com.here.sdk.navigation.TrafficMergeWarning;
import com.here.sdk.navigation.TrafficMergeWarningListener;
import com.here.sdk.navigation.TruckRestrictionWarning;
import com.here.sdk.navigation.TruckRestrictionsWarningListener;
import com.here.sdk.navigation.VisualNavigator;
import com.here.sdk.navigation.WarningNotificationDistances;
import com.here.sdk.navigation.WarningType;
import com.here.sdk.navigation.WeightRestrictionType;
import com.here.sdk.routing.Maneuver;
import com.here.sdk.routing.ManeuverAction;
import com.here.sdk.routing.PaymentMethod;
import com.here.sdk.routing.RoadTexts;
import com.here.sdk.routing.Route;
import com.here.sdk.routing.Section;
import com.here.sdk.routing.Span;
import com.here.sdk.routing.StreetAttributes;
import com.here.sdk.transport.GeneralVehicleSpeedLimits;

import java.util.Arrays;
import java.util.Date;
import java.util.List;
import java.util.Objects;

// This class shows the various events that can be emitted during turn-by-turn navigation.
// Note that this class does not show an exhaustive list of all possible events.
// More events are shown in the "Navigation" example app.
public class NavigationWarnersExample {
    public enum RoadType {HIGHWAY, RURAL, URBAN}
    private static final String TAG = NavigationWarnersExample.class.getName();
    private final Context context;
    private RouteProgress currentRouteProgress;
    public NavigationWarnersExample(Context context) {
        this.context = context;
    }

    // More event handling can be seen in the "Navigation" app.
    public void setupListeners(VisualNavigator visualNavigator) {

        setupSpeedWarnings(visualNavigator);
        setupSafetyCameraWarningOptions(visualNavigator);

        // Notifies on the progress along the route including maneuver instructions.
        visualNavigator.setRouteProgressListener(new RouteProgressListener() {
            @Override
            public void onRouteProgressUpdated(@NonNull RouteProgress routeProgress) {
                currentRouteProgress = routeProgress;

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

                String roadName = getRoadName(nextManeuver, visualNavigator.getRoute());

                // An example on how to retrieve the road name can be seen in the "Navigation" example app.
                String nextManeuverAction = nextManeuver.getAction().name() + " on " + roadName
                        + " in " + nextManeuverProgress.remainingDistanceInMeters + " meters.";
                Log.d(TAG, nextManeuverAction);

                // Angle is null for some maneuvers like Depart, Arrive and Roundabout.
                Double turnAngle = nextManeuver.getTurnAngleInDegrees();
                if (turnAngle != null) {
                    if (turnAngle > 10) {
                        Log.d(TAG, "At the next maneuver: Make a right turn of " + turnAngle + " degrees.");
                    } else if (turnAngle < -10) {
                        Log.d(TAG, "At the next maneuver: Make a left turn of " + turnAngle + " degrees.");
                    } else {
                        Log.d(TAG, "At the next maneuver: Go straight.");
                    }
                }

                // Angle is null when the roundabout maneuver is not an enter, exit or keep maneuver.
                Double roundaboutAngle = nextManeuver.getRoundaboutAngleInDegrees();
                if (roundaboutAngle != null) {
                    // Note that the value is negative only for left-driving countries such as UK.
                    Log.d(TAG, "At the next maneuver: Follow the roundabout for " +
                            roundaboutAngle + " degrees to reach the exit.");
                }
            }
        });


        // Provides lane information for the road a user is currently driving on.
        // It's supported for turn-by-turn navigation and in tracking mode.
        // It does not notify on which lane the user is currently driving on.
        visualNavigator.setCurrentSituationLaneAssistanceViewListener(new CurrentSituationLaneAssistanceViewListener() {
            @Override
            public void onCurrentSituationLaneAssistanceViewUpdate(@NonNull CurrentSituationLaneAssistanceView currentSituationLaneAssistanceView) {
                // A list of lanes on the current road.
                // Note: Lanes going in opposite direction are not included in the list.
                // Only the lanes for the current driving direction are included.
                List<CurrentSituationLaneView> lanesList = currentSituationLaneAssistanceView.lanes;

                if (lanesList.isEmpty()) {
                    Log.d("CurrentSituationLaneAssistanceView: ", "No data on lanes available.");
                } else {
                    // The lanes are sorted from left to right:
                    // The lane at index 0 is the leftmost lane adjacent to the middle of the road.
                    // The lane at the last index is the rightmost lane.
                    // This is valid for right-hand and left-hand driving countries.
                    for (int i = 0; i < lanesList.size(); i++) {
                        logCurrentSituationLaneViewDetails(i, lanesList.get(i));
                    }
                }
            }
        });

        // Notifies when the destination of the route is reached.
        visualNavigator.setDestinationReachedListener(new DestinationReachedListener() {
            @Override
            public void onDestinationReached() {
                Log.d(TAG, "Destination reached.");
                // Guidance has stopped. Now consider to, for example,
                // switch to tracking mode or stop rendering or locating or do anything else that may
                // be useful to support your app flow.
                // If the DynamicRoutingEngine was started before, consider to stop it now.
            }
        });

        // Notifies when a waypoint on the route is reached or missed.
        visualNavigator.setMilestoneStatusListener(new MilestoneStatusListener() {
            @Override
            public void onMilestoneStatusUpdated(@NonNull Milestone milestone, @NonNull MilestoneStatus milestoneStatus) {
                if (milestone.waypointIndex != null && milestoneStatus == MilestoneStatus.REACHED) {
                    Log.d(TAG, "A user-defined waypoint was reached, index of waypoint: " + milestone.waypointIndex);
                    Log.d(TAG, "Original coordinates: " + milestone.originalCoordinates);
                } else if (milestone.waypointIndex != null && milestoneStatus == MilestoneStatus.MISSED) {
                    Log.d(TAG, "A user-defined waypoint was missed, index of waypoint: " + milestone.waypointIndex);
                    Log.d(TAG, "Original coordinates: " + milestone.originalCoordinates);
                } else if (milestone.waypointIndex == null && milestoneStatus == MilestoneStatus.REACHED) {
                    // For example, when transport mode changes due to a ferry a system-defined waypoint may have been added.
                    Log.d(TAG, "A system-defined waypoint was reached at: " + milestone.mapMatchedCoordinates);
                } else if (milestone.waypointIndex == null && milestoneStatus == MilestoneStatus.MISSED) {
                    // For example, when transport mode changes due to a ferry a system-defined waypoint may have been added.
                    Log.d(TAG, "A system-defined waypoint was missed at: " + milestone.mapMatchedCoordinates);
                }
            }
        });

        // Notifies on safety camera warnings as they appear along the road.
        visualNavigator.setSafetyCameraWarningListener(new SafetyCameraWarningListener() {
            @Override
            public void onSafetyCameraWarningUpdated(@NonNull SafetyCameraWarning safetyCameraWarning) {
                // Safety camera warning geocoordinates can only be fetched in non-tracking mode.
                Route currentRoute = Objects.requireNonNull(visualNavigator.getRoute());
                GeoCoordinates safetyCameraGeoCoordinates  = getGeocordinatesForRemainingDistance(currentRouteProgress,
                        safetyCameraWarning.distanceToCameraInMeters,
                        currentRoute
                );

                Log.d(TAG, "Received safety camera warning update at "+ NavigationWarnersExample.toString(safetyCameraGeoCoordinates));
                if (safetyCameraWarning.distanceType == DistanceType.AHEAD) {
                    Log.d(TAG, "Safety camera warning " + safetyCameraWarning.type.name() + " ahead in: "
                            + safetyCameraWarning.distanceToCameraInMeters + "with speed limit ="
                            + safetyCameraWarning.speedLimitInMetersPerSecond + "m/s"
                            + " at geo-coordinates: " + NavigationWarnersExample.toString(safetyCameraGeoCoordinates));
                } else if (safetyCameraWarning.distanceType == DistanceType.PASSED) {
                    Log.d(TAG, "Safety camera warning " + safetyCameraWarning.type.name() + " passed: "
                            + safetyCameraWarning.distanceToCameraInMeters + "with speed limit ="
                            + safetyCameraWarning.speedLimitInMetersPerSecond + "m/s");
                } else if (safetyCameraWarning.distanceType == DistanceType.REACHED) {
                    Log.d(TAG, "Safety camera warning " + safetyCameraWarning.type.name() + " reached at: "
                            + safetyCameraWarning.distanceToCameraInMeters + "with speed limit ="
                            + safetyCameraWarning.speedLimitInMetersPerSecond + "m/s");
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
                    Log.d(TAG, "Warning: Speed limits unknown, data could not be retrieved.");
                } else if (currentSpeedLimit == 0) {
                    Log.d(TAG, "No speed limits on this road! Drive as fast as you feel safe ...");
                } else {
                    Log.d(TAG, "Current speed limit (m/s):" + currentSpeedLimit);
                }
            }
        });

        // Notifies about merging traffic to the current road.
        visualNavigator.setTrafficMergeWarningListener(new TrafficMergeWarningListener() {
            @Override
            public void onTrafficMergeWarningUpdated(@NonNull TrafficMergeWarning trafficMergeWarning) {
                if (trafficMergeWarning.distanceType == DistanceType.AHEAD) {
                    Log.d(TAG, "There is a merging " + trafficMergeWarning.roadType.name() + " ahead in: "
                            + trafficMergeWarning.distanceToTrafficMergeInMeters + "meters, merging from the "
                            + trafficMergeWarning.side.name() + "side, with lanes ="
                            + trafficMergeWarning.laneCount);
                } else if (trafficMergeWarning.distanceType == DistanceType.PASSED) {
                    Log.d(TAG, "A merging " + trafficMergeWarning.roadType.name() + " passed: "
                            + trafficMergeWarning.distanceToTrafficMergeInMeters + "meters, merging from the "
                            + trafficMergeWarning.side.name() + "side, with lanes ="
                            + trafficMergeWarning.laneCount);
                } else if (trafficMergeWarning.distanceType == DistanceType.REACHED) {
                    // Since the traffic merge warning is given relative to a single position on the route,
                    // DistanceType.REACHED will never be given for this warning.
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

                // Now, an application needs to decide if the user has deviated far enough and
                // what should happen next: For example, you can notify the user or simply try to
                // calculate a new route. When you calculate a new route, you can, for example,
                // take the current location as new start and keep the destination - another
                // option could be to calculate a new route back to the lastMapMatchedLocationOnRoute.
                // At least, make sure to not calculate a new route every time you get a RouteDeviation
                // event as the route calculation happens asynchronously and takes also some time to
                // complete.
                // The deviation event is sent any time an off-route location is detected: It may make
                // sense to await around 3 events before deciding on possible actions.
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

        // Notifies which lane(s) allow to follow the route.
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

        RoadSignWarningOptions roadSignWarningOptions = new RoadSignWarningOptions();
        // Set a filter to get only shields relevant for TRUCKS and HEAVY_TRUCKS.
        roadSignWarningOptions.vehicleTypesFilter = Arrays.asList(RoadSignVehicleType.TRUCKS, RoadSignVehicleType.HEAVY_TRUCKS);

        // Get notification distances for road sign alerts from visual navigator.
        WarningNotificationDistances warningNotificationDistances = visualNavigator.getWarningNotificationDistances(WarningType.ROAD_SIGN);
        // The distance in meters for emitting warnings when the speed limit or current speed is fast. Defaults to 1500.
        warningNotificationDistances.fastSpeedDistanceInMeters = 1600;
        // The distance in meters for emitting warnings when the speed limit or current speed is regular. Defaults to 750.
        warningNotificationDistances.regularSpeedDistanceInMeters = 800;
        // The distance in meters for emitting warnings when the speed limit or current speed is slow. Defaults to 500.
        warningNotificationDistances.slowSpeedDistanceInMeters = 600;

        // Set the warning distances for road signs.
        visualNavigator.setWarningNotificationDistances(WarningType.ROAD_SIGN, warningNotificationDistances);
        visualNavigator.setRoadSignWarningOptions(roadSignWarningOptions);

        // Notifies on road shields as they appear along the road.
        visualNavigator.setRoadSignWarningListener(new RoadSignWarningListener() {
            @Override
            public void onRoadSignWarningUpdated(@NonNull RoadSignWarning roadSignWarning) {
                RoadSignType roadSignType = roadSignWarning.type;
                if (roadSignWarning.distanceType == DistanceType.AHEAD) {
                    Log.d(TAG, "A RoadSignWarning of road sign type: " + roadSignType.name()
                    + " ahead in (m): " + roadSignWarning.distanceToRoadSignInMeters);
                } else if (roadSignWarning.distanceType == DistanceType.PASSED) {
                    Log.d(TAG, "A RoadSignWarning of road sign type: " + roadSignType.name() + " just passed.");
                }

                if (roadSignWarning.signValue != null) {
                    // Optional text as it is printed on the local road sign.
                    Log.d(TAG, "Road sign text: " + roadSignWarning.signValue.text);
                }

                // For more road sign attributes, please check the API Reference.
            }
        });

        // Notifies truck drivers on road restrictions ahead. Called whenever there is a change.
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
                        Log.d(TAG, "TruckRestrictionWarning ahead in: " + truckRestrictionWarning.distanceInMeters + " meters.");
                        if (truckRestrictionWarning.timeRule != null && !truckRestrictionWarning.timeRule.appliesTo(new Date())) {
                            // For example, during a specific time period of a day, some truck restriction warnings do not apply.
                            // If truckRestrictionWarning.timeRule is null, the warning applies at anytime.
                            Log.d(TAG, "Note that this truck restriction warning currently does not apply.");
                        }
                    } else if (truckRestrictionWarning.distanceType == DistanceType.REACHED) {
                        Log.d(TAG, "A restriction has been reached.");
                    } else if (truckRestrictionWarning.distanceType == DistanceType.PASSED) {
                        // If not preceded by a "REACHED"-notification, this restriction was valid only for the passed location.
                        Log.d(TAG, "A restriction just passed.");
                    }

                    // One of the following restrictions applies ahead, if more restrictions apply at the same time,
                    // they are part of another TruckRestrictionWarning element contained in the list.
                    if (truckRestrictionWarning.weightRestriction != null) {
                        WeightRestrictionType type = truckRestrictionWarning.weightRestriction.type;
                        int value = truckRestrictionWarning.weightRestriction.valueInKilograms;
                        Log.d(TAG, "TruckRestriction for weight (kg): " + type.name() + ": " + value);
                    } else if (truckRestrictionWarning.dimensionRestriction != null) {
                        // Can be either a length, width or height restriction of the truck. For example, a height
                        // restriction can apply for a tunnel. Other possible restrictions are delivered in
                        // separate TruckRestrictionWarning objects contained in the list, if any.
                        DimensionRestrictionType type = truckRestrictionWarning.dimensionRestriction.type;
                        int value = truckRestrictionWarning.dimensionRestriction.valueInCentimeters;
                        Log.d(TAG, "TruckRestriction for dimension: " + type.name() + ": " + value);
                    } else {
                        Log.d(TAG, "TruckRestriction: General restriction - no trucks allowed.");
                    }
                }
            }
        });

        // Notifies on school zones ahead.
        visualNavigator.setSchoolZoneWarningListener(new SchoolZoneWarningListener() {
            @Override
            public void onSchoolZoneWarningUpdated(@NonNull List<SchoolZoneWarning> list) {
                // The list is guaranteed to be non-empty.
                for (SchoolZoneWarning schoolZoneWarning : list) {
                    if (schoolZoneWarning.distanceType == DistanceType.AHEAD) {
                        Log.d(TAG, "A school zone ahead in: " + schoolZoneWarning.distanceToSchoolZoneInMeters + " meters.");
                        // Note that this will be the same speed limit as indicated by SpeedLimitListener, unless
                        // already a lower speed limit applies, for example, because of a heavy truck load.
                        Log.d(TAG, "Speed limit restriction for this school zone: " + schoolZoneWarning.speedLimitInMetersPerSecond + " m/s.");
                        if (schoolZoneWarning.timeRule != null && !schoolZoneWarning.timeRule.appliesTo(new Date())) {
                            // For example, during night sometimes a school zone warning does not apply.
                            // If schoolZoneWarning.timeRule is null, the warning applies at anytime.
                            Log.d(TAG, "Note that this school zone warning currently does not apply.");
                        }
                    } else if (schoolZoneWarning.distanceType == DistanceType.REACHED) {
                        Log.d(TAG, "A school zone has been reached.");
                    } else if (schoolZoneWarning.distanceType == DistanceType.PASSED) {
                        Log.d(TAG, "A school zone has been passed.");
                    }
                }
            }
        });

        SchoolZoneWarningOptions schoolZoneWarningOptions = new SchoolZoneWarningOptions();
        schoolZoneWarningOptions.filterOutInactiveTimeDependentWarnings = true;
        schoolZoneWarningOptions.warningDistanceInMeters = 150;
        visualNavigator.setSchoolZoneWarningOptions(schoolZoneWarningOptions);

        // Notifies whenever a border is crossed of a country and optionally, by default, also when a state
        // border of a country is crossed.
        visualNavigator.setBorderCrossingWarningListener(new BorderCrossingWarningListener() {
            @Override
            public void onBorderCrossingWarningUpdated(@NonNull BorderCrossingWarning borderCrossingWarning) {
                // Since the border crossing warning is given relative to a single location,
                // the DistanceType.REACHED will never be given for this warning.
                if (borderCrossingWarning.distanceType == DistanceType.AHEAD) {
                    Log.d(TAG, "BorderCrossing: A border is ahead in: " + borderCrossingWarning.distanceToBorderCrossingInMeters + " meters.");
                    Log.d(TAG, "BorderCrossing: Type (such as country or state): " + borderCrossingWarning.type.name());
                    Log.d(TAG, "BorderCrossing: Country code: " + borderCrossingWarning.administrativeRules.countryCode.name());

                    // The state code after the border crossing. It represents the state / province code.
                    // It is a 1 to 3 upper-case characters string that follows the ISO 3166-2 standard,
                    // but without the preceding country code (e.g. for Texas, the state code will be TX).
                    // It will be null for countries without states or countries in which the states have very
                    // similar regulations (e.g. for Germany there will be no state borders).
                    if (borderCrossingWarning.administrativeRules.stateCode != null) {
                        Log.d(TAG, "BorderCrossing: State code: " + borderCrossingWarning.administrativeRules.stateCode);
                    }

                    // The general speed limits that apply in the country / state after border crossing.
                    GeneralVehicleSpeedLimits generalVehicleSpeedLimits = borderCrossingWarning.administrativeRules.speedLimits;
                    Log.d(TAG, "BorderCrossing: Speed limit in cities (m/s): " + generalVehicleSpeedLimits.maxSpeedUrbanInMetersPerSecond);
                    Log.d(TAG, "BorderCrossing: Speed limit outside cities (m/s): " + generalVehicleSpeedLimits.maxSpeedRuralInMetersPerSecond);
                    Log.d(TAG, "BorderCrossing: Speed limit on highways (m/s): " + generalVehicleSpeedLimits.maxSpeedHighwaysInMetersPerSecond);
                } else if (borderCrossingWarning.distanceType == DistanceType.PASSED) {
                    Log.d(TAG, "BorderCrossing: A border has been passed.");
                }
            }
        });

        BorderCrossingWarningOptions borderCrossingWarningOptions = new BorderCrossingWarningOptions();
        // If set to true, all the state border crossing notifications will not be given.
        // If the value is false, all border crossing notifications will be given for both
        // country borders and state borders. Defaults to false.
        borderCrossingWarningOptions.filterOutStateBorderWarnings = true;
        visualNavigator.setBorderCrossingWarningOptions(borderCrossingWarningOptions);

        // Notifies on danger zones.
        // A danger zone refers to areas where there is an increased risk of traffic incidents.
        // These zones are designated to alert drivers to potential hazards and encourage safer driving behaviors.
        // The HERE SDK warns when approaching the danger zone, as well as when leaving such a zone.
        // A danger zone may or may not have one or more speed cameras in it. The exact location of such speed cameras
        // is not provided. Note that danger zones are only available in selected countries, such as France.
        visualNavigator.setDangerZoneWarningListener(new DangerZoneWarningListener() {
            @Override
            public void onDangerZoneWarningsUpdated(@NonNull DangerZoneWarning dangerZoneWarning) {
                if (dangerZoneWarning.distanceType == DistanceType.AHEAD) {
                    Log.d(TAG, "A danger zone ahead in: " + dangerZoneWarning.distanceInMeters + " meters.");
                    // isZoneStart indicates if we enter the danger zone from the start.
                    // It is false, when the danger zone is entered from a side street.
                    // Based on the route path, the HERE SDK anticipates from where the danger zone will be entered.
                    // In tracking mode, the most probable path will be used to anticipate from where
                    // the danger zone is entered.
                    Log.d(TAG, "isZoneStart: " + dangerZoneWarning.isZoneStart);
                } else if (dangerZoneWarning.distanceType == DistanceType.REACHED) {
                    Log.d(TAG, "A danger zone has been reached. isZoneStart: " + dangerZoneWarning.isZoneStart);
                } else if (dangerZoneWarning.distanceType == DistanceType.PASSED) {
                    Log.d(TAG, "A danger zone has been passed.");
                }
            }
        });

        // Notifies on low speed zones ahead - as indicated also on the map when MapFeatures.LOW_SPEED_ZONE is set.
        visualNavigator.setLowSpeedZoneWarningListener(new LowSpeedZoneWarningListener() {
            @Override
            public void onLowSpeedZoneWarningUpdated(@NonNull LowSpeedZoneWarning lowSpeedZoneWarning) {
                if (lowSpeedZoneWarning.distanceType == DistanceType.AHEAD) {
                    Log.d(TAG, "Low speed zone ahead in meters: " + lowSpeedZoneWarning.distanceToLowSpeedZoneInMeters);
                    Log.d(TAG, "Speed limit in low speed zone (m/s): " + lowSpeedZoneWarning.speedLimitInMetersPerSecond);
                } else if (lowSpeedZoneWarning.distanceType == DistanceType.REACHED) {
                    Log.d(TAG, "A low speed zone has been reached.");
                    Log.d(TAG, "Speed limit in low speed zone (m/s): " + lowSpeedZoneWarning.speedLimitInMetersPerSecond);
                } else if (lowSpeedZoneWarning.distanceType == DistanceType.PASSED) {
                    Log.d(TAG, "A low speed zone has been passed.");
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

        RealisticViewWarningOptions realisticViewWarningOptions = new RealisticViewWarningOptions();
        realisticViewWarningOptions.aspectRatio = AspectRatio.ASPECT_RATIO_3_X_4;
        realisticViewWarningOptions.darkTheme = false;
        visualNavigator.setRealisticViewWarningOptions(realisticViewWarningOptions);

        // Notifies on signposts together with complex junction views.
        // Signposts are shown as they appear along a road on a shield to indicate the upcoming directions and
        // destinations, such as cities or road names.
        // Junction views appear as a 3D visualization (as a static image) to help the driver to orientate.
        //
        // Optionally, you can use a feature-configuration to preload the assets as part of a Region.
        //
        // The event matches the notification for complex junctions, see JunctionViewLaneAssistance.
        // Note that the SVG data for junction view is composed out of several 3D elements,
        // a horizon and the actual junction geometry.
        visualNavigator.setRealisticViewWarningListener(new RealisticViewWarningListener() {
            @Override
            public void onRealisticViewWarningUpdated(@NonNull RealisticViewWarning realisticViewWarning) {
                double distance = realisticViewWarning.distanceToRealisticViewInMeters;
                DistanceType distanceType = realisticViewWarning.distanceType;

                // Note that DistanceType.REACHED is not used for Signposts and junction views
                // as a junction is identified through a location instead of an area.
                if (distanceType == DistanceType.AHEAD) {
                    Log.d(TAG, "A RealisticView ahead in: " + distance + " meters.");
                } else if (distanceType == DistanceType.PASSED) {
                    Log.d(TAG, "A RealisticView just passed.");
                }

                RealisticViewVectorImage realisticView = realisticViewWarning.realisticViewVectorImage;
                if (realisticView == null) {
                    Log.d(TAG, "A RealisticView just passed. No SVG data delivered.");
                    return;
                }

                String signpostSvgImageContent = realisticView.signpostSvgImageContent;
                String junctionViewSvgImageContent = realisticView.junctionViewSvgImageContent;
                // The resolution-independent SVG data can now be used in an application to visualize the image.
                // Use a SVG library of your choice to create an SVG image out of the SVG string.
                // Both SVGs contain the same dimension and the signpostSvgImageContent should be shown on top of
                // the junctionViewSvgImageContent.
                // The images can be quite detailed, therefore it is recommended to show them on a secondary display
                // in full size.
                Log.d("signpostSvgImage", signpostSvgImageContent);
                Log.d("junctionViewSvgImage", junctionViewSvgImageContent);
            }
        });

        // Notifies on upcoming toll stops. Uses the same notification
        // thresholds as other warners and provides events with or without a route to follow.
        visualNavigator.setTollStopWarningListener(new TollStopWarningListener() {
            @Override
            public void onTollStopWarning(@NonNull TollStop tollStop) {
                List<TollBoothLane> lanes = tollStop.lanes;

                // The lane at index 0 is the leftmost lane adjacent to the middle of the road.
                // The lane at the last index is the rightmost lane.
                int laneNumber = 0;
                for (TollBoothLane tollBoothLane : lanes) {
                    // Log which vehicles types are allowed on this lane that leads to the toll booth.
                    logLaneAccess("ToolBoothLane: ", laneNumber, tollBoothLane.access);
                    TollBooth tollBooth = tollBoothLane.booth;
                    List<TollCollectionMethod> tollCollectionMethods = tollBooth.tollCollectionMethods;
                    List<PaymentMethod> paymentMethods = tollBooth.paymentMethods;
                    // The supported collection methods like ticket or automatic / electronic.
                    for (TollCollectionMethod collectionMethod : tollCollectionMethods) {
                        Log.d(TAG, "This toll stop supports collection via: " + collectionMethod.name());
                    }
                    // The supported payment methods like cash or credit card.
                    for (PaymentMethod paymentMethod : paymentMethods) {
                        Log.d(TAG, "This toll stop supports payment via: " + paymentMethod.name());
                    }
                    laneNumber++;
                }
            }
        });
    }

    private void setupSafetyCameraWarningOptions(VisualNavigator visualNavigator) {
        SafetyCameraWarningOptions safetyCameraWarningOptions = new SafetyCameraWarningOptions();

        // Enable text notifications for safety camera warnings, that can be used with TTS engines.
        // Example notification text: "A safety camera is ahead in 500 meters."
        // The text can be localized via ManeuverNotificationOptions.
        // To receive text notifications, you must also set up an EventTextListener.
        // See the "Navigation" example app for a usage example. 
        safetyCameraWarningOptions.enableTextNotification = true;
        visualNavigator.setSafetyCameraWarningOptions(safetyCameraWarningOptions);
    }

    private void setupSpeedWarnings(VisualNavigator visualNavigator) {
        SpeedLimitOffset speedLimitOffset = new SpeedLimitOffset();
        speedLimitOffset.lowSpeedOffsetInMetersPerSecond = 2;
        speedLimitOffset.highSpeedOffsetInMetersPerSecond = 4;
        speedLimitOffset.highSpeedBoundaryInMetersPerSecond = 25;

        visualNavigator.setSpeedWarningOptions(new SpeedWarningOptions(speedLimitOffset));
    }

    private String getRoadName(Maneuver maneuver, Route route) {
        RoadTexts currentRoadTexts = maneuver.getRoadTexts();
        RoadTexts nextRoadTexts = maneuver.getNextRoadTexts();

        String currentRoadName = currentRoadTexts.names.getDefaultValue();
        String currentRoadNumber = currentRoadTexts.numbersWithDirection.getDefaultValue();
        String nextRoadName = nextRoadTexts.names.getDefaultValue();
        String nextRoadNumber = nextRoadTexts.numbersWithDirection.getDefaultValue();

        String roadName = nextRoadName == null ? nextRoadNumber : nextRoadName;

        // On highways, we want to show the highway number instead of a possible road name,
        // while for inner city and urban areas road names are preferred over road numbers.
        if (getRoadType(maneuver, route) == RoadType.HIGHWAY) {
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

    // Determines the road type for a given maneuver based on street attributes.
    // Return The road type classification (HIGHWAY, URBAN or RURAL).
    private RoadType getRoadType(Maneuver maneuver, Route route) {
        Section sectionOfManeuver = route.getSections().get(maneuver.getSectionIndex());
        List<Span> spansInSection = sectionOfManeuver.getSpans();
        int manueverSpanIndex = maneuver.getSpanIndex();

        // If attributes list is empty then the road type is rural.
        if(spansInSection.isEmpty()) {
            return RoadType.RURAL;
        }

        // The span index for the final maneuvers (those with ManeuverAction.ARRIVE)
        // cannot be used because they appear after the last span of the route.
        // Their span index would exceed the span list size, so the previous spanIndex is used instead.
        if (manueverSpanIndex>= spansInSection.size()){
            manueverSpanIndex = manueverSpanIndex-1;
        }

        Span currentSpan = spansInSection.get(manueverSpanIndex);
        List<StreetAttributes> streetAttributes = currentSpan.getStreetAttributes();

        // If attributes list contains either CONTROLLED_ACCESS_HIGHWAY, or MOTORWAY or RAMP then the road type is highway.
        // Check for highway attributes (highest priority)
        if (streetAttributes.contains(StreetAttributes.CONTROLLED_ACCESS_HIGHWAY)
                || streetAttributes.contains(StreetAttributes.MOTORWAY)
                || streetAttributes.contains(StreetAttributes.RAMP)) {
            return RoadType.HIGHWAY;
        }

        // If attributes list contains BUILT_UP_AREA then the road type is urban.
        // Check for urban attributes (second priority)
        if (streetAttributes.contains(StreetAttributes.BUILT_UP_AREA)) {
            return RoadType.URBAN;
        }

        // If the road type is neither urban nor highway, default to rural for all other cases.
        return RoadType.RURAL;
    }

    private void setupManeuverNotificationOptions(VisualNavigator visualNavigator) {
        ManeuverNotificationOptions maneuverNotificationOptions = new ManeuverNotificationOptions();

        // Indicates whether lane recommendation should be used when generating notifications.
        maneuverNotificationOptions.enableLaneRecommendation = true;
        visualNavigator.setManeuverNotificationOptions(maneuverNotificationOptions);
    }

    private Double getCurrentSpeedLimit(SpeedLimit speedLimit) {
        // Note that all values can be null if no data is available.

        // The regular speed limit if available. In case of unbounded speed limit, the value is zero.
        Log.d(TAG, "speedLimitInMetersPerSecond: " + speedLimit.speedLimitInMetersPerSecond);

        // A conditional school zone speed limit as indicated on the local road signs.
        Log.d(TAG, "schoolZoneSpeedLimitInMetersPerSecond: " + speedLimit.schoolZoneSpeedLimitInMetersPerSecond);

        // A conditional time-dependent speed limit as indicated on the local road signs.
        // It is in effect considering the current local time provided by the device's clock.
        Log.d(TAG, "timeDependentSpeedLimitInMetersPerSecond: " + speedLimit.timeDependentSpeedLimitInMetersPerSecond);

        // A conditional non-legal speed limit that recommends a lower speed,
        // for example, due to bad road conditions.
        Log.d(TAG, "advisorySpeedLimitInMetersPerSecond: " + speedLimit.advisorySpeedLimitInMetersPerSecond);

        // A weather-dependent speed limit as indicated on the local road signs.
        // The HERE SDK cannot detect the current weather condition, so a driver must decide
        // based on the situation if this speed limit applies.
        Log.d(TAG, "fogSpeedLimitInMetersPerSecond: " + speedLimit.fogSpeedLimitInMetersPerSecond);
        Log.d(TAG, "rainSpeedLimitInMetersPerSecond: " + speedLimit.rainSpeedLimitInMetersPerSecond);
        Log.d(TAG, "snowSpeedLimitInMetersPerSecond: " + speedLimit.snowSpeedLimitInMetersPerSecond);

        // For convenience, this returns the effective (lowest) speed limit between
        // - speedLimitInMetersPerSecond
        // - schoolZoneSpeedLimitInMetersPerSecond
        // - timeDependentSpeedLimitInMetersPerSecond
        return speedLimit.effectiveSpeedLimitInMetersPerSecond();
    }

    private void logLaneRecommendations(List<Lane> lanes) {
        // The lane at index 0 is the leftmost lane adjacent to the middle of the road.
        // The lane at the last index is the rightmost lane.
        int laneNumber = 0;
        for (Lane lane : lanes) {
            // This state is only possible if maneuverViewLaneAssistance.lanesForNextNextManeuver is not empty.
            // For example, when two lanes go left, this lanes leads only to the next maneuver,
            // but not to the maneuver after the next maneuver, while the highly recommended lane also leads
            // to this next next maneuver.
            if (lane.recommendationState == LaneRecommendationState.RECOMMENDED) {
                Log.d(TAG, "Lane " + laneNumber + " leads to next maneuver, but not to the next next maneuver.");
            }

            // If laneAssistance.lanesForNextNextManeuver is not empty, this lane leads also to the
            // maneuver after the next maneuver.
            if (lane.recommendationState == LaneRecommendationState.HIGHLY_RECOMMENDED) {
                Log.d(TAG, "Lane " + laneNumber + " leads to next maneuver and eventually to the next next maneuver.");
            }

            if (lane.recommendationState == LaneRecommendationState.NOT_RECOMMENDED) {
                Log.d(TAG, "Do not take lane " + laneNumber + " to follow the route.");
            }

            logLaneDetails(laneNumber, lane);

            laneNumber++;
        }
    }

    private void logLaneDetails(int laneNumber, Lane lane) {
        Log.d(TAG, "Directions for lane " + laneNumber);
        // The possible lane directions are valid independent of a route.
        // If a lane leads to multiple directions and is recommended, then all directions lead to
        // the next maneuver.
        // You can use this information to visualize all directions of a lane with a set of image overlays.
        for (LaneDirection laneDirection: lane.directions) {
            boolean isLaneDirectionOnRoute = isLaneDirectionOnRoute(lane, laneDirection);
            Log.d(TAG, "LaneDirection for this lane: " + laneDirection.name());
            Log.d(TAG, "This LaneDirection is on the route: " + isLaneDirectionOnRoute);
        }

        // More information on each lane is available in these bitmasks (boolean):
        // LaneType provides lane properties such as if parking is allowed or is acceleration allowed or is express lane and many more.
        LaneType laneType = lane.type;

        // LaneAccess provides which vehicle type(s) are allowed to access this lane.
        LaneAccess laneAccess = lane.access;
        logLaneAccess("Lane Deatils: ", laneNumber, laneAccess);

        // LaneMarkings indicate the visual style of dividers between lanes as visible on a road.
        LaneMarkings laneMarkings = lane.laneMarkings;
        logLaneMarkings("Lane Details: ", laneMarkings);
    }

    private void logCurrentSituationLaneViewDetails(int laneNumber, CurrentSituationLaneView currentSituationLaneView) {
        Log.d("CurrentSituationLaneAssistanceView: ", "Directions for this CurrentSituationLaneView: " + laneNumber);
        // You can use this information to visualize all directions of a lane with a set of image overlays.
        for (LaneDirection laneDirection : currentSituationLaneView.directions) {
            boolean isLaneDirectionOnRoute = isCurrentLaneViewDirectionOnRoute(currentSituationLaneView, laneDirection);
            Log.d("CurrentSituationLaneAssistanceView: ", "LaneDirection for this CurrentSituationLaneView: " + laneDirection.name());
            // When you are on tracking mode, there is no directionsOnRoute. So, isLaneDirectionOnRoute will be false.
            Log.d("CurrentSituationLaneAssistanceView: ", "This LaneDirection is on the route: " + isLaneDirectionOnRoute);
        }

        // More information on each lane is available in these bitmasks (boolean):
        // LaneType holds multiple boolean lane properties such as if parking is allowed or is acceleration allowed or is express lane and many more.
        LaneType laneType = currentSituationLaneView.type;

        // LaneAccess provides which vehicle type(s) are allowed to access this lane.
        LaneAccess laneAccess = currentSituationLaneView.access;
        logLaneAccess("CurrentSituationLaneView: ", laneNumber, laneAccess);

        // LaneMarkings indicate the visual style of dividers between lanes as visible on a road.
        LaneMarkings laneMarkings = currentSituationLaneView.laneMarkings;
        logLaneMarkings("CurrentSituationLaneView: ", laneMarkings);
    }

    private void logLaneMarkings(String TAG, LaneMarkings laneMarkings) {
        if (laneMarkings.centerDividerMarker != null) {
            // A CenterDividerMarker specifies the line type used for center dividers on bidirectional roads.
            Log.d(TAG,"Center divider marker for lane " + laneMarkings.centerDividerMarker.value);
        } else if (laneMarkings.laneDividerMarker != null) {
            // A LaneDividerMarker specifies the line type of driving lane separators present on a road.
            // It indicates the lane separator on the right side of the
            // specified lane in the lane driving direction for right-side driving countries.
            // For left-sided driving countries the it is indicating the
            // lane separator on the left side of the specified lane in the lane driving direction.
            Log.d(TAG, "Lane divider marker for lane " + laneMarkings.laneDividerMarker.value);
        }
    }

    // A method to check if a given LaneDirection is on route or not.
    // lane.directionsOnRoute gives only those LaneDirection that are on the route.
    // When the driver is in tracking mode without following a route, this always returns false.
    private boolean isLaneDirectionOnRoute(Lane lane, LaneDirection laneDirection) {
        return lane.directionsOnRoute.contains(laneDirection);
    }

    // Returns the GeoCoordinates for an object that is located at the end of the remaining distance.
    private GeoCoordinates getGeocordinatesForRemainingDistance(RouteProgress routeProgress,
                                                                double remainingObjectDistnaceInMetres,
                                                                Route currentRoute) {
        double currentCCPOffsetInMetrs = getOffsetOfCCPOnRouteInMeters(routeProgress, currentRoute);

        // Calculate the offset along the route for the given object.
        double remainingDistanceOffsetInMetres = currentCCPOffsetInMetrs + remainingObjectDistnaceInMetres;
        return getGeoCoordinatesFromOffsetInMeters(currentRoute.getGeometry(), remainingDistanceOffsetInMetres);
    }

    private Double getOffsetOfCCPOnRouteInMeters(RouteProgress routeProgress, Route currentRoute) {
        double totalLength = currentRoute.getLengthInMeters();
        // [SectionProgress] is guaranteed to be non-empty.
        double remainingDistance = routeProgress.sectionProgress.get(routeProgress.sectionProgress.size() - 1).remainingDistanceInMeters;
        return totalLength - remainingDistance;
    }

    // Convert an offset in meters along a GeoPolyline to GeoCoordinates using the HERE SDK's coordinatesAtOffsetInMeters.
    public GeoCoordinates getGeoCoordinatesFromOffsetInMeters(GeoPolyline geoPolyline, double offsetInMeters) {
        return geoPolyline.coordinatesAtOffsetInMeters(offsetInMeters, GeoPolylineDirection.FROM_BEGINNING);
    }

    private boolean isCurrentLaneViewDirectionOnRoute(CurrentSituationLaneView currentSituationLaneView, LaneDirection laneDirection) {
        return currentSituationLaneView.directionsOnRoute.contains(laneDirection);
    }

    public static String toString(GeoCoordinates geoCoordinates) {
        return geoCoordinates.latitude + ", " + geoCoordinates.longitude;
    }

    private void logLaneAccess(String TAG, int laneNumber, LaneAccess laneAccess) {
        Log.d(TAG, "Lane access for lane " + laneNumber);
        Log.d(TAG, "Automobiles are allowed on this lane: " + laneAccess.automobiles);
        Log.d(TAG, "Buses are allowed on this lane: " + laneAccess.buses);
        Log.d(TAG, "Taxis are allowed on this lane: " + laneAccess.taxis);
        Log.d(TAG, "Carpools are allowed on this lane: " + laneAccess.carpools);
        Log.d(TAG, "Pedestrians are allowed on this lane: " + laneAccess.pedestrians);
        Log.d(TAG, "Trucks are allowed on this lane: " + laneAccess.trucks);
        Log.d(TAG, "ThroughTraffic is allowed on this lane: " + laneAccess.throughTraffic);
        Log.d(TAG, "DeliveryVehicles are allowed on this lane: " + laneAccess.deliveryVehicles);
        Log.d(TAG, "EmergencyVehicles are allowed on this lane: " + laneAccess.emergencyVehicles);
        Log.d(TAG, "Motorcycles are allowed on this lane: " + laneAccess.motorcycles);
    }
}
