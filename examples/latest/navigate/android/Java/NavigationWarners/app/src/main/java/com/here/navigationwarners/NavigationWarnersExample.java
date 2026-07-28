/*
 * Copyright (C) 2019-2026 HERE Europe B.V.
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

import com.here.sdk.animation.Easing;
import com.here.sdk.animation.EasingFunction;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.GeoOrientationUpdate;
import com.here.sdk.core.GeoPolyline;
import com.here.sdk.core.GeoPolylineDirection;
import com.here.sdk.core.Point2D;
import com.here.sdk.core.Rectangle2D;
import com.here.sdk.core.Size2D;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.mapview.MapCameraAnimation;
import com.here.sdk.mapview.MapCameraAnimationFactory;
import com.here.sdk.mapview.MapCameraUpdate;
import com.here.sdk.mapview.MapCameraUpdateFactory;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapView;
import com.here.sdk.navigation.CurrentSituationLaneAssistanceView;
import com.here.sdk.navigation.CurrentSituationLaneAssistanceViewListener;
import com.here.sdk.navigation.CurrentSituationLaneView;
import com.here.sdk.navigation.DestinationReachedListener;
import com.here.sdk.navigation.DistanceType;
import com.here.sdk.navigation.JunctionViewLaneAssistance;
import com.here.sdk.navigation.JunctionViewLaneAssistanceListener;
import com.here.sdk.navigation.Lane;
import com.here.sdk.navigation.LaneAccess;
import com.here.sdk.navigation.LaneDirection;
import com.here.sdk.navigation.LaneMarkings;
import com.here.sdk.navigation.LaneRecommendationState;
import com.here.sdk.navigation.LaneType;
import com.here.sdk.navigation.LocationSimulator;
import com.here.sdk.navigation.LocationSimulatorOptions;
import com.here.sdk.navigation.ManeuverProgress;
import com.here.sdk.navigation.ManeuverViewLaneAssistance;
import com.here.sdk.navigation.ManeuverViewLaneAssistanceListener;
import com.here.sdk.navigation.MapMatchedLocation;
import com.here.sdk.navigation.Milestone;
import com.here.sdk.navigation.MilestoneStatus;
import com.here.sdk.navigation.MilestoneStatusListener;
import com.here.sdk.navigation.RoadAttributes;
import com.here.sdk.navigation.RoadAttributesListener;
import com.here.sdk.navigation.RoadTextsListener;
import com.here.sdk.navigation.RouteDeviation;
import com.here.sdk.navigation.RouteDeviationListener;
import com.here.sdk.navigation.RouteProgress;
import com.here.sdk.navigation.RouteProgressListener;
import com.here.sdk.navigation.VisualNavigator;
import com.here.sdk.routing.RoutingOptions;
import com.here.sdk.routing.Maneuver;
import com.here.sdk.routing.PaymentMethod;
import com.here.sdk.routing.RoadTexts;
import com.here.sdk.routing.Route;
import com.here.sdk.routing.RoutingEngine;
import com.here.sdk.routing.Waypoint;
import com.here.time.Duration;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Date;
import java.util.List;
import java.util.Objects;

// This class shows the various events that can be emitted during turn-by-turn navigation.
// Note that this class does not show an exhaustive list of all possible events.
// More events are shown in the "Navigation" example app.
public class NavigationWarnersExample {
    private static final String TAG = NavigationWarnersExample.class.getName();
    private final Context context;
    private final MapView mapView;
    private final RoutingEngine routingEngine;
    private final VisualNavigator visualNavigator;
    private LocationSimulator locationSimulator;
    private boolean isGuidanceRunning = false;
    private RouteProgress currentRouteProgress;
    private final WarnerEngineExample warnerEngineExample = new WarnerEngineExample();

    public NavigationWarnersExample(Context context, MapView mapView) {
        this.context = context;
        this.mapView = mapView;

        try {
            this.visualNavigator = new VisualNavigator();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of VisualNavigator failed: " + e.error.name());
        }

        try {
            this.routingEngine = new RoutingEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of RoutingEngine failed: " + e.error.name());
        }
    }

    public boolean isGuidanceRunning() {
        return isGuidanceRunning;
    }

    public void startGuidance(GeoCoordinates startGeoCoordinates,
                              GeoCoordinates destinationGeoCoordinates) {
        routingEngine.calculateRoute(
                new ArrayList<>(Arrays.asList(new Waypoint(startGeoCoordinates), new Waypoint(destinationGeoCoordinates))),
                new RoutingOptions(),
                (routingError, routes) -> {
                    if (routingError == null) {
                        // When routingError is null, routes is guaranteed to contain at least one route.
                        Route route = routes.get(0);
                        startGuidanceWithRoute(route);
                    } else {
                        Log.e(TAG, "Route calculation error: " + routingError);
                    }
                }
        );
    }

    public void stopGuidance() {
        if (locationSimulator != null) {
            locationSimulator.stop();
            locationSimulator = null;
        }

        warnerEngineExample.stopWarnerEngine();
        visualNavigator.setRoute(null);
        visualNavigator.stopRendering();
        isGuidanceRunning = false;
    }

    private void startGuidanceWithRoute(Route route) {
        warnerEngineExample.setupWarnerEngine(visualNavigator);
        Log.d(TAG, "Using WarnerEngine for warning handling.");
        setupListeners(visualNavigator);
        visualNavigator.startRendering(mapView);
        visualNavigator.setRoute(route);
        setupLocationSource(route);
        isGuidanceRunning = true;
    }

    private void setupLocationSource(Route route) {
        try {
            locationSimulator = new LocationSimulator(route, new LocationSimulatorOptions());
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of LocationSimulator failed: " + e.error.name());
        }

        locationSimulator.setListener(visualNavigator);
        locationSimulator.start();
    }

    // More event handling can be seen in the "Navigation" app.
    // Note: All warning-related listeners have been removed. Use WarnerEngine for unified warning handling.
    public void setupListeners(VisualNavigator visualNavigator) {

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

                // An example on how to retrieve the road name can be seen in the "Navigation" example app.
                String nextManeuverAction = "Next maneuver action: " + nextManeuver.getAction().name() + " in " + nextManeuverProgress.remainingDistanceInMeters + " meters.";
                Log.d(TAG, nextManeuverAction);
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
        // Notifies whenever any textual attribute of the current road changes, i.e., the current road texts differ
        // from the previous one. This can be useful during tracking mode, when no maneuver information is provided.
        visualNavigator.setRoadTextsListener(new RoadTextsListener() {
            @Override
            public void onRoadTextsUpdated(@NonNull RoadTexts roadTexts) {
                // See getRoadName() in the "Rerouting" example app to learn how to get the current road name from the provided RoadTexts.
            }
        });
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

    // Animates the camera to fit the given route.
    public void animateToRoutePreview(GeoCoordinates startGeoCoordinates, GeoCoordinates destinationGeoCoordinates) {
        double bearing = 0;
        double tilt = 0;
        double distanceInMeters = 1000 * 10;
        // We want to show the route fitting in the map view with an additional padding of 300 pixels
        Point2D origin = new Point2D(300, 300);
        Size2D sizeInPixels = new Size2D(mapView.getWidth() - 600, mapView.getHeight() - 600);
        Rectangle2D mapViewport = new Rectangle2D(origin, sizeInPixels);

        List<GeoCoordinates> coordinatesList = Arrays.asList(startGeoCoordinates, destinationGeoCoordinates);

        // Animate to the route overview.
        MapCameraUpdate update = MapCameraUpdateFactory.lookAt(
                coordinatesList,
                mapViewport,
                new GeoOrientationUpdate(bearing, tilt),
                new MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, distanceInMeters)
        );
        MapCameraAnimation animation =
                MapCameraAnimationFactory.createAnimation(update, Duration.ofMillis(500), new Easing(EasingFunction.IN_CUBIC));
        mapView.getCamera().startAnimation(animation);
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
