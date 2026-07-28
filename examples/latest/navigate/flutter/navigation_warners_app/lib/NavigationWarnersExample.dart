/*
 * Copyright (C) 2019-2026 HERE Europe B.V.
 *
 * Licensed under the Apache License, Version 2.0 (the "License")
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

import 'dart:async';

import 'package:here_sdk/animation.dart' as HERE;
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/navigation.dart';
import 'package:here_sdk/routing.dart' as HERE;
import 'package:here_sdk/routing.dart';

import 'WarnerEngineExample.dart';

enum RoadType { highway, rural, urban }

// This class combines the various events that can be emitted during turn-by-turn navigation.
// Note that this class does not show an exhaustive list of all possible events.
class NavigationWarnersExample {
  final HereMapController _hereMapController;
  late final VisualNavigator _visualNavigator;
  late final HERE.RoutingEngine _routingEngine;
  LocationSimulator? _locationSimulator;
  bool _isGuidanceRunning = false;
  RouteProgress? currentRouteProgress;
  final WarnerEngineExample _warnerEngineExample = WarnerEngineExample();

  NavigationWarnersExample(this._hereMapController) {
    try {
      _visualNavigator = VisualNavigator();
    } on InstantiationException {
      throw Exception("Initialization of VisualNavigator failed.");
    }

    try {
      _routingEngine = HERE.RoutingEngine();
    } on InstantiationException {
      throw Exception('Initialization of RoutingEngine failed.');
    }
  }

  bool isGuidanceRunning() {
    return _isGuidanceRunning;
  }

  void startGuidance(GeoCoordinates startGeoCoordinates, GeoCoordinates destinationGeoCoordinates) {
    _routingEngine.calculateRouteWithRoutingOptions(
      [HERE.Waypoint(startGeoCoordinates), HERE.Waypoint(destinationGeoCoordinates)],
      HERE.RoutingOptions(),
      (HERE.RoutingError? routingError, List<HERE.Route>? routeList) {
        if (routingError == null && routeList != null && routeList.isNotEmpty) {
          _startGuidanceWithRoute(routeList.first);
        } else {
          print('Error while calculating a route: $routingError');
        }
      },
    );
  }

  void stopGuidance() {
    _locationSimulator?.stop();
    _locationSimulator = null;

    _warnerEngineExample.stopWarnerEngine();
    _visualNavigator.route = null;
    _visualNavigator.stopRendering();
    _isGuidanceRunning = false;
  }

  void animateToRoutePreview(GeoCoordinates startGeoCoordinates, GeoCoordinates destinationGeoCoordinates) {
    double bearing = 0;
    double tilt = 0;
    double distanceInMeters = 1000 * 10;

    // We want to show the route fitting in the map view with an additional padding of 300 pixels.
    Point2D origin = Point2D(300, 300);
    Size2D sizeInPixels = Size2D(
      _hereMapController.viewportSize.width - 600,
      _hereMapController.viewportSize.height - 600,
    );
    Rectangle2D mapViewport = Rectangle2D(origin, sizeInPixels);

    List<GeoCoordinates> coordinatesList = [startGeoCoordinates, destinationGeoCoordinates];

    // Animate to the route overview.
    MapCameraUpdate update = MapCameraUpdateFactory.lookAtPoints(
      coordinatesList,
      mapViewport,
      GeoOrientationUpdate(bearing, tilt),
      MapMeasure(MapMeasureKind.distanceInMeters, distanceInMeters),
    );

    MapCameraAnimation animation = MapCameraAnimationFactory.createAnimationFromUpdateWithEasing(
      update,
      const Duration(milliseconds: 500),
      HERE.Easing(HERE.EasingFunction.inCubic),
    );
    _hereMapController.camera.startAnimation(animation);
  }

  void _startGuidanceWithRoute(HERE.Route route) {
    _warnerEngineExample.setupWarnerEngine(_visualNavigator);
    print("Using WarnerEngine for warning handling.");
    _setupListeners();
    _visualNavigator.startRendering(_hereMapController);
    _visualNavigator.route = route;
    _setupLocationSource(route);
    _isGuidanceRunning = true;
  }

  void _setupLocationSource(HERE.Route route) {
    try {
      _locationSimulator = LocationSimulator.withRoute(route, LocationSimulatorOptions());
    } on InstantiationException {
      throw Exception("Initialization of LocationSimulator failed.");
    }

    _locationSimulator!.listener = _visualNavigator;
    _locationSimulator!.start();
  }

  void _setupListeners() {
    _setupManeuverNotificationOptions();

    // Notifies on the progress along the route including maneuver instructions.
    // These maneuver instructions can be used to compose a visual representation of the next maneuver actions.
    _visualNavigator.routeProgressListener = RouteProgressListener((RouteProgress routeProgress) {
      this.currentRouteProgress = routeProgress;

      // Handle results from onRouteProgressUpdated():
      List<SectionProgress> sectionProgressList = routeProgress.sectionProgress;
      // sectionProgressList is guaranteed to be non-empty.
      SectionProgress lastSectionProgress = sectionProgressList.elementAt(sectionProgressList.length - 1);
      print('Distance to destination in meters: ' + lastSectionProgress.remainingDistanceInMeters.toString());
      print('Traffic delay ahead in seconds: ' + lastSectionProgress.trafficDelay.inSeconds.toString());

      // Contains the progress for the next maneuver ahead and the next-next maneuvers, if any.
      List<ManeuverProgress> nextManeuverList = routeProgress.maneuverProgress;

      if (nextManeuverList.isEmpty) {
        print('No next maneuver available.');
        return;
      }
      ManeuverProgress nextManeuverProgress = nextManeuverList.first;

      int nextManeuverIndex = nextManeuverProgress.maneuverIndex;
      Maneuver? nextManeuver = _visualNavigator.getManeuver(nextManeuverIndex);
      if (nextManeuver == null) {
        // Should never happen as we retrieved the next maneuver progress above.
        return;
      }

      ManeuverAction action = nextManeuver.action;
      String logMessage =
          "Next maneuver action: " +
          action.name +
          ' in ' +
          nextManeuverProgress.remainingDistanceInMeters.toString() +
          ' meters.';
      print(logMessage);
    });

    // Provides lane information for the road a user is currently driving on.
    // It's supported for turn-by-turn navigation and in tracking mode.
    // It does not notify on which lane the user is currently driving on.
    _visualNavigator.currentSituationLaneAssistanceViewListener = CurrentSituationLaneAssistanceViewListener((
      CurrentSituationLaneAssistanceView currentSituationLaneAssistanceView,
    ) {
      // A list of lanes on the current road.
      List<CurrentSituationLaneView> lanesList = currentSituationLaneAssistanceView.lanes;

      if (lanesList.isEmpty) {
        print("CurrentSituationLaneAssistanceView: No data on lanes available.");
      } else {
        // The lanes are sorted from left to right:
        // The lane at index 0 is the leftmost lane adjacent to the middle of the road.
        // The lane at the last index is the rightmost lane.
        // This is valid for right-hand and left-hand driving countries.
        for (int i = 0; i < lanesList.length; i++) {
          _logCurrentSituationLaneViewDetails(i, lanesList[i]);
        }
      }
    });

    // Notifies when the destination of the route is reached.
    _visualNavigator.destinationReachedListener = DestinationReachedListener(() {
      // Handle results from onDestinationReached().
      print("Destination reached.");
      // Guidance has stopped. Now consider to, for example,
      // switch to tracking mode or stop rendering or locating or do anything else that may
      // be useful to support your app flow.
      // If the DynamicRoutingEngine was started before, consider to stop it now.
    });

    // Notifies when a waypoint on the route is reached or missed
    _visualNavigator.milestoneStatusListener = MilestoneStatusListener((
      Milestone milestone,
      MilestoneStatus milestoneStatus,
    ) {
      // Handle results from onMilestoneStatusUpdated().
      if (milestone.waypointIndex != null && milestoneStatus == MilestoneStatus.reached) {
        print("A user-defined waypoint was reached, index of waypoint: " + milestone.waypointIndex.toString());
        print("Original coordinates: " + milestone.originalCoordinates.toString());
      } else if (milestone.waypointIndex != null && milestoneStatus == MilestoneStatus.missed) {
        print("A user-defined waypoint was missed, index of waypoint: " + milestone.waypointIndex.toString());
        print("Original coordinates: " + milestone.originalCoordinates.toString());
      } else if (milestone.waypointIndex == null && milestoneStatus == MilestoneStatus.reached) {
        // For example, when transport mode changes due to a ferry a system-defined waypoint may have been added.
        print("A system-defined waypoint was reached at: " + milestone.mapMatchedCoordinates.toString());
      } else if (milestone.waypointIndex == null && milestoneStatus == MilestoneStatus.missed) {
        // For example, when transport mode changes due to a ferry a system-defined waypoint may have been added.
        print("A system-defined waypoint was missed at: " + milestone.mapMatchedCoordinates.toString());
      }
    });

    // Notifies on a possible deviation from the route.
    // When deviation is too large, an app may decide to recalculate the route from current location to destination.
    _visualNavigator.routeDeviationListener = RouteDeviationListener((RouteDeviation routeDeviation) {
      // Handle results from onRouteDeviation().
      HERE.Route? route = _visualNavigator.route;
      if (route == null) {
        // May happen in rare cases when route was set to null in between.
        return;
      }

      // Get current geographic coordinates.
      MapMatchedLocation? currentMapMatchedLocation = routeDeviation.currentLocation.mapMatchedLocation;
      GeoCoordinates currentGeoCoordinates =
          currentMapMatchedLocation == null
              ? routeDeviation.currentLocation.originalLocation.coordinates
              : currentMapMatchedLocation.coordinates;

      // Get last geographic coordinates on route.
      GeoCoordinates lastGeoCoordinatesOnRoute;
      if (routeDeviation.lastLocationOnRoute != null) {
        MapMatchedLocation? lastMapMatchedLocationOnRoute = routeDeviation.lastLocationOnRoute!.mapMatchedLocation;
        lastGeoCoordinatesOnRoute =
            lastMapMatchedLocationOnRoute == null
                ? routeDeviation.lastLocationOnRoute!.originalLocation.coordinates
                : lastMapMatchedLocationOnRoute.coordinates;
      } else {
        print("User was never following the route. So, we take the start of the route instead.");
        lastGeoCoordinatesOnRoute = route.sections.first.departurePlace.originalCoordinates!;
      }

      int distanceInMeters = currentGeoCoordinates.distanceTo(lastGeoCoordinatesOnRoute).toInt();
      print("RouteDeviation in meters is " + distanceInMeters.toString());

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
    });

    // Notifies on the attributes of the current road including usage and physical characteristics.
    _visualNavigator.roadAttributesListener = RoadAttributesListener((RoadAttributes roadAttributes) {
      // Handle results from onRoadAttributesUpdated().
      // This is called whenever any road attribute has changed.
      // If all attributes are unchanged, no new event is fired.
      // Note that a road can have more than one attribute at the same time.
      print("Received road attributes update.");

      if (roadAttributes.isBridge) {
        // Identifies a structure that allows a road, railway, or walkway to pass over another road, railway,
        // waterway, or valley serving map display and route guidance functionalities.
        print("Road attributes: This is a bridge.");
      }
      if (roadAttributes.isControlledAccess) {
        // Controlled access roads are roads with limited entrances and exits that allow uninterrupted
        // high-speed traffic flow.
        print("Road attributes: This is a controlled access road.");
      }
      if (roadAttributes.isDirtRoad) {
        // Indicates whether the navigable segment is paved.
        print("Road attributes: This is a dirt road.");
      }
      if (roadAttributes.isDividedRoad) {
        // Indicates if there is a physical structure or painted road marking intended to legally prohibit
        // left turns in right-side driving countries, right turns in left-side driving countries,
        // and U-turns at divided intersections or in the middle of divided segments.
        print("Road attributes: This is a divided road.");
      }
      if (roadAttributes.isNoThrough) {
        // Identifies a no through road.
        print("Road attributes: This is a no through road.");
      }
      if (roadAttributes.isPrivate) {
        // Private identifies roads that are not maintained by an organization responsible for maintenance of
        // public roads.
        print("Road attributes: This is a private road.");
      }
      if (roadAttributes.isRamp) {
        // Range is a ramp: connects roads that do not intersect at grade.
        print('Road attributes: This is a ramp.');
      }
      if (roadAttributes.isRightDrivingSide) {
        // Indicates if vehicles have to drive on the right-hand side of the road or the left-hand side.
        // For example, in New York it is always true and in London always false as the United Kingdom is
        // a left-hand driving country.
        print("Road attributes: isRightDrivingSide = " + roadAttributes.isRightDrivingSide.toString());
      }
      if (roadAttributes.isRoundabout) {
        // Indicates the presence of a roundabout.
        print("Road attributes: This is a roundabout.");
      }
      if (roadAttributes.isTollway) {
        // Identifies a road for which a fee must be paid to use the road.
        print("Road attributes change: This is a road with toll costs.");
      }
      if (roadAttributes.isTunnel) {
        // Identifies an enclosed (on all sides) passageway through or under an obstruction.
        print("Road attributes: This is a tunnel.");
      }
    });

    // Notifies which lane(s) lead to the next (next) maneuvers.
    _visualNavigator.maneuverViewLaneAssistanceListener = ManeuverViewLaneAssistanceListener((
      ManeuverViewLaneAssistance laneAssistance,
    ) {
      // Handle events from onLaneAssistanceUpdated().
      // This lane list is guaranteed to be non-empty.
      List<Lane> lanes = laneAssistance.lanesForNextManeuver;
      logLaneRecommendations(lanes);

      List<Lane> nextLanes = laneAssistance.lanesForNextNextManeuver;
      if (nextLanes.isNotEmpty) {
        print("Attention, the next next maneuver is very close.");
        print("Please take the following lane(s) after the next maneuver: ");
        logLaneRecommendations(nextLanes);
      }
    });

    // Notifies which lane(s) allow to follow the route.
    _visualNavigator.junctionViewLaneAssistanceListener = JunctionViewLaneAssistanceListener((
      JunctionViewLaneAssistance junctionViewLaneAssistance,
    ) {
      List<Lane> lanes = junctionViewLaneAssistance.lanesForNextJunction;
      if (lanes.isEmpty) {
        print("You have passed the complex junction.");
      } else {
        print("Attention, a complex junction is ahead.");
        logLaneRecommendations(lanes);
      }
    });

    // Notifies whenever any textual attribute of the current road changes, i.e., the current road texts differ
    // from the previous one. This can be useful during tracking mode, when no maneuver information is provided.
    _visualNavigator.roadTextsListener = RoadTextsListener((RoadTexts roadTexts) {
      // See _getRoadName() in the "rerouting_app" example app to learn how to get the current road name from the provided RoadTexts.
    });
  }

  void _setupManeuverNotificationOptions() {
    ManeuverNotificationOptions maneuverNotificationOptions = ManeuverNotificationOptions.withDefaults();

    // Indicates whether lane recommendation should be used when generating notifications.
    maneuverNotificationOptions.enableLaneRecommendation = true;
    _visualNavigator.maneuverNotificationOptions = maneuverNotificationOptions;
  }

  void logLaneRecommendations(List<Lane> lanes) {
    // The lane at index 0 is the leftmost lane adjacent to the middle of the road.
    // The lane at the last index is the rightmost lane.
    int laneNumber = 0;
    for (Lane lane in lanes) {
      // This state is only possible if laneAssistance.lanesForNextNextManeuver is not empty.
      // For example, when two lanes go left, this lanes leads only to the next maneuver,
      // but not to the maneuver after the next maneuver, while the highly recommended lane also leads
      // to this next next maneuver.
      if (lane.recommendationState == LaneRecommendationState.recommended) {
        print("Lane $laneNumber leads to next maneuver, but not to the next next maneuver.");
      }

      // If laneAssistance.lanesForNextNextManeuver is not empty, this lane leads also to the
      // maneuver after the next maneuver.
      if (lane.recommendationState == LaneRecommendationState.highlyRecommended) {
        print("Lane $laneNumber leads to next maneuver and eventually to the next next maneuver.");
      }

      if (lane.recommendationState == LaneRecommendationState.notRecommended) {
        print("Do not take lane $laneNumber to follow the route.");
      }

      _logLaneDetails(laneNumber, lane);

      laneNumber++;
    }
  }

  void _logLaneDetails(int laneNumber, Lane lane) {
    print("Directions for lane " + laneNumber.toString());
    // The possible lane directions are valid independent of a route.
    // If a lane leads to multiple directions and is recommended, then all directions lead to
    // the next maneuver.
    // You can use this information to visualize all directions of a lane with a set of image overlays.
    for (LaneDirection laneDirection in lane.directions) {
      bool isLaneDirectionOnRoute = _isLaneDirectionOnRoute(lane, laneDirection);
      print("LaneDirection for this lane: ${laneDirection.name}");
      print("This LaneDirection is on the route: $isLaneDirectionOnRoute");
    }

    // More information on each lane is available in these bitmasks (boolean):
    // LaneType provides lane properties such as if parking is allowed or is acceleration allowed or is express lane and many more.
    LaneType laneType = lane.type;

    // LaneAccess provides which vehicle type(s) are allowed to access this lane.
    LaneAccess laneAccess = lane.access;
    _logLaneAccess("LaneDetails: ", laneNumber, laneAccess);

    // LaneMarkings indicate the visual style of dividers between lanes as visible on a road.
    LaneMarkings laneMarkings = lane.laneMarkings;
    _logLaneMarkings("LaneDetails: ", laneMarkings);
  }

  void _logCurrentSituationLaneViewDetails(int laneNumber, CurrentSituationLaneView currentSituationLaneView) {
    print("CurrentSituationLaneAssistanceView: Directions for CurrentSituationLaneView " + laneNumber.toString());
    // You can use this information to visualize all directions of a lane with a set of image overlays.
    for (LaneDirection laneDirection in currentSituationLaneView.directions) {
      bool isLaneDirectionOnRoute = _isCurrentSituationLaneViewDirectionOnRoute(
        currentSituationLaneView,
        laneDirection,
      );
      print("CurrentSituationLaneAssistanceView: LaneDirection for this lane: ${laneDirection.name}");
      // When you are on tracking mode, there is no directionsOnRoute. So, isLaneDirectionOnRoute will be false.
      print("CurrentSituationLaneAssistanceView: This LaneDirection is on the route: $isLaneDirectionOnRoute");
    }

    // More information on each lane is available in these bitmasks (boolean):
    // LaneType provides lane properties such as if parking is allowed or is acceleration allowed or is express lane and many more.
    LaneType laneType = currentSituationLaneView.type;

    // LaneAccess provides which vehicle type(s) are allowed to access this lane.
    LaneAccess laneAccess = currentSituationLaneView.access;
    _logLaneAccess("CurrentSituationLaneAssistanceView: ", laneNumber, laneAccess);

    // LaneMarkings indicate the visual style of dividers between lanes as visible on a road.
    LaneMarkings laneMarkings = currentSituationLaneView.laneMarkings;
    _logLaneMarkings("CurrentSituationLaneAssistanceView: ", laneMarkings);
  }

  _logLaneMarkings(String TAG, LaneMarkings laneMarkings) {
    if (laneMarkings.centerDividerMarker != null) {
      // A CenterDividerMarker specifies the line type used for center dividers on bidirectional roads.
      print(TAG + "Center divider marker for lane ${laneMarkings.centerDividerMarker?.name}");
    } else if (laneMarkings.laneDividerMarker != null) {
      // A LaneDividerMarker specifies the line type of driving lane separators present on a road.
      // It indicates the lane separator on the right side of the
      // specified lane in the lane driving direction for right-side driving countries.
      // For left-sided driving countries, it indicates the
      // lane separator on the left side of the specified lane in the lane driving direction.
      print(TAG + "Lane divider marker for lane ${laneMarkings.laneDividerMarker?.name}");
    }
  }

  _logLaneAccess(String TAG, int laneNumber, LaneAccess laneAccess) {
    print(TAG + "Lane access for lane " + laneNumber.toString());
    print(TAG + "Automobiles are allowed on this lane: " + laneAccess.automobiles.toString());
    print(TAG + "Buses are allowed on this lane: " + laneAccess.buses.toString());
    print(TAG + "Taxis are allowed on this lane: " + laneAccess.taxis.toString());
    print(TAG + "Carpools are allowed on this lane: " + laneAccess.carpools.toString());
    print(TAG + "Pedestrians are allowed on this lane: " + laneAccess.pedestrians.toString());
    print(TAG + "Trucks are allowed on this lane: " + laneAccess.trucks.toString());
    print(TAG + "ThroughTraffic is allowed on this lane: " + laneAccess.throughTraffic.toString());
    print(TAG + "DeliveryVehicles are allowed on this lane: " + laneAccess.deliveryVehicles.toString());
    print(TAG + "EmergencyVehicles are allowed on this lane: " + laneAccess.emergencyVehicles.toString());
    print(TAG + "Motorcycles are allowed on this lane: " + laneAccess.motorcycles.toString());
  }

  // A method to check if a given LaneDirection is on route or not.
  // lane.directionsOnRoute gives only those LaneDirection that are on the route.
  // When the driver is in tracking mode without following a route, this always returns false.
  bool _isLaneDirectionOnRoute(Lane lane, LaneDirection laneDirection) {
    return lane.directionsOnRoute.contains(laneDirection);
  }

  bool _isCurrentSituationLaneViewDirectionOnRoute(
    CurrentSituationLaneView currentSituationLaneView,
    LaneDirection laneDirection,
  ) {
    return currentSituationLaneView.directionsOnRoute.contains(laneDirection);
  }

  // Returns the GeoCoordinates for an object located at the end of the remaining distance.
  GeoCoordinates getGeocoordinatesForRemainingDistance(
      RouteProgress routeProgress,
      double remainingObjectDistanceInMeters,
      Route currentRoute,) {
    final currentCCPOffsetInMeters =
    getOffsetOfCCPOnRouteInMeters(routeProgress, currentRoute);

    // Calculate the offset along the route for the given object.
    final remainingDistanceOffsetInMeters =
        currentCCPOffsetInMeters + remainingObjectDistanceInMeters;

    return getGeoCoordinatesFromOffsetInMeters(
      currentRoute.geometry,
      remainingDistanceOffsetInMeters,
    );
  }

  // Returns the offset of the current camera position (CCP) on the route in meters.
  double getOffsetOfCCPOnRouteInMeters(RouteProgress routeProgress,
      Route currentRoute,) {
    final totalLength = currentRoute.lengthInMeters.toDouble();

    // SectionProgress is guaranteed to be non-empty.
    final sectionProgressList = routeProgress.sectionProgress;
    final remainingDistance = sectionProgressList.last.remainingDistanceInMeters
        .toDouble();

    return totalLength - remainingDistance;
  }

  // Converts an offset in meters along a GeoPolyline to GeoCoordinates using HERE SDK's coordinatesAtOffsetInMeters.
  GeoCoordinates getGeoCoordinatesFromOffsetInMeters(GeoPolyline geoPolyline,
      double offsetInMeters,) {
    return geoPolyline.coordinatesAtOffsetInMeters(
      offsetInMeters,
      GeoPolylineDirection.fromBeginning,
    );
  }

  // Converts GeoCoordinates to a human-readable string.
  String geoCoordinatesToString(GeoCoordinates geoCoordinates) {
    return '${geoCoordinates.latitude}, ${geoCoordinates.longitude}';
  }

}
