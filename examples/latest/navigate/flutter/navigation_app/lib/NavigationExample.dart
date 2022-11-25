/*
 * Copyright (C) 2019-2022 HERE Europe B.V.
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

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/location.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/navigation.dart';
import 'package:here_sdk/routing.dart' as HERE;
import 'package:here_sdk/routing.dart';
import 'package:here_sdk/trafficawarenavigation.dart';

import 'HEREPositioningProvider.dart';
import 'HEREPositioningSimulator.dart';
import 'LanguageCodeConverter.dart';

// Shows how to start and stop turn-by-turn navigation along a route.
class NavigationExample {
  final HereMapController _hereMapController;
  late VisualNavigator _visualNavigator;
  late HEREPositioningSimulator _locationSimulationProvider;
  late HEREPositioningProvider _herePositioningProvider;
  late DynamicRoutingEngine _dynamicRoutingEngine;
  MapMatchedLocation? _lastMapMatchedLocation;
  int _previousManeuverIndex = -1;
  final ValueChanged<String> _updateMessageState;

  NavigationExample(HereMapController hereMapController, ValueChanged<String> updateMessageState)
      : _hereMapController = hereMapController,
        _updateMessageState = updateMessageState {
    try {
      _visualNavigator = VisualNavigator();
    } on InstantiationException {
      throw Exception("Initialization of VisualNavigator failed.");
    }

    // Enable auto-zoom during guidance.
    _visualNavigator.cameraBehavior = DynamicCameraBehavior();

    // This enables a navigation view including a rendered navigation arrow.
    _visualNavigator.startRendering(_hereMapController);

    // For easy testing, this location provider simulates location events along a route.
    // You can use HERE positioning to feed real locations, see the "Positioning"-section in
    // our Developer's Guide for an example.
    _locationSimulationProvider = HEREPositioningSimulator();

    // Access the device's GPS sensor and other data.
    _herePositioningProvider = HEREPositioningProvider();
    _herePositioningProvider.startLocating(_visualNavigator, LocationAccuracy.navigation);

    _createDynamicRoutingEngine();

    setupListeners();
  }

  void _createDynamicRoutingEngine() {
    var dynamicRoutingOptions = DynamicRoutingEngineOptions.withAllDefaults();
    // We want an update for each poll iteration, so we specify 0 difference.
    dynamicRoutingOptions.minTimeDifference = Duration.zero;
    dynamicRoutingOptions.minTimeDifferencePercentage = 0.0;
    dynamicRoutingOptions.pollInterval = Duration(minutes: 5);

    try {
      // With the dynamic routing engine you can poll the HERE backend services to search for routes with less traffic.
      // THis can happen during guidance - or you can periodically update a route that is shown in a route planner.
      _dynamicRoutingEngine = DynamicRoutingEngine(dynamicRoutingOptions);
    } on InstantiationException {
      throw Exception("Initialization of DynamicRoutingEngine failed.");
    }
  }

  Location? getLastKnownLocation() {
    return _herePositioningProvider.getLastKnownLocation();
  }

  void startNavigationSimulation(HERE.Route route) {
    _prepareNavigation(route);

    // Stop in case it was started before.
    _herePositioningProvider.stop();

    // Simulates location events based on the given route.
    // The navigator is set as listener to receive location updates.
    _locationSimulationProvider.startLocating(route, _visualNavigator);

    _startDynamicSearchForBetterRoutes(route);
  }

  void startNavigation(HERE.Route route) {
    _prepareNavigation(route);

    // Stop in case it was started before.
    _locationSimulationProvider.stop();

    // Access the device's GPS sensor and other data.
    // The navigator is set as listener to receive location updates.
    _herePositioningProvider.startLocating(_visualNavigator, LocationAccuracy.navigation);

    _startDynamicSearchForBetterRoutes(route);
  }

  void _startDynamicSearchForBetterRoutes(HERE.Route route) {
    try {
      _dynamicRoutingEngine.start(
          route,
          // Notifies on traffic-optimized routes that are considered better than the current route.
          DynamicRoutingListener((Route newRoute, int etaDifferenceInSeconds, int distanceDifferenceInMeters) {
            _updateMessageState("DynamicRoutingEngine: Calculated a new route");
            print("DynamicRoutingEngine: etaDifferenceInSeconds: $etaDifferenceInSeconds.");
            print("DynamicRoutingEngine: distanceDifferenceInMeters: $distanceDifferenceInMeters.");

            // An implementation can decide to switch to the new route:
            // _visualNavigator.route = newRoute;
          }, (RoutingError routingError) {
            final error = routingError.toString();
            _updateMessageState("Error while dynamically searching for a better route: $error");
          }));
    } on DynamicRoutingEngineStartException {
      throw Exception("Start of DynamicRoutingEngine failed. Is the RouteHandle missing?");
    }
  }

  void _prepareNavigation(HERE.Route route) {
    setupSpeedWarnings();
    setupVoiceTextMessages();

    // Set the route to follow.
    _visualNavigator.route = route;
  }

  void setTracking(bool isTracking) {
    if (isTracking) {
      _visualNavigator.cameraBehavior = DynamicCameraBehavior();
    } else {
      _visualNavigator.cameraBehavior = null;
    }
  }

  void stopNavigation() {
    // Stop in case it was started before.
    _locationSimulationProvider.stop();
    _dynamicRoutingEngine.stop();
    startTracking();
    _updateMessageState("Tracking device's location.");
  }

  void detach() {
    // It is recommended to stop rendering before leaving the app.
    // This also removes the current location marker.
    _visualNavigator.stopRendering();

    // Stop LocationSimulator and DynamicRoutingEngine in case they were started before.
    _locationSimulationProvider.stop();
    _dynamicRoutingEngine.stop();

    // It is recommended to stop the LocationEngine before leaving the app.
    _herePositioningProvider.stop();
  }

  // Starts tracking the device's location using HERE Positioning.
  void startTracking() {
    // Leaves guidance (if it was running) and enables tracking mode. The camera may optionally follow, see toggleTracking().
    _visualNavigator.route = null;
    _herePositioningProvider.startLocating(_visualNavigator, LocationAccuracy.navigation);
  }

  String _getRoadName(Maneuver maneuver) {
    RoadTexts currentRoadTexts = maneuver.roadTexts;
    RoadTexts nextRoadTexts = maneuver.nextRoadTexts;

    String? currentRoadName = currentRoadTexts.names.getDefaultValue();
    String? currentRoadNumber = currentRoadTexts.numbers.getDefaultValue();
    String? nextRoadName = nextRoadTexts.names.getDefaultValue();
    String? nextRoadNumber = nextRoadTexts.numbers.getDefaultValue();

    String? roadName = nextRoadName == null ? nextRoadNumber : nextRoadName;

    // On highways, we want to show the highway number instead of a possible road name,
    // while for inner city and urban areas road names are preferred over road numbers.
    if (maneuver.nextRoadType == RoadType.highway) {
      roadName = nextRoadNumber == null ? nextRoadName : nextRoadNumber;
    }

    if (maneuver.action == ManeuverAction.arrive) {
      // We are approaching the destination, so there's no next road.
      roadName = currentRoadName == null ? currentRoadNumber : currentRoadName;
    }

    // Happens only in rare cases, when also the fallback above is null.
    roadName ??= 'unnamed road';

    return roadName;
  }

  void setupListeners() {
    // Notifies on the progress along the route including maneuver instructions.
    // These maneuver instructions can be used to compose a visual representation of the next maneuver actions.
    _visualNavigator.routeProgressListener = RouteProgressListener((RouteProgress routeProgress) {
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
      String roadName = _getRoadName(nextManeuver);
      String logMessage = describeEnum(action) +
          ' on ' +
          roadName +
          ' in ' +
          nextManeuverProgress.remainingDistanceInMeters.toString() +
          ' meters.';

      if (_previousManeuverIndex != nextManeuverIndex) {
        _updateMessageState('New maneuver: $logMessage');
      } else {
        // A maneuver update contains a different distance to reach the next maneuver.
        _updateMessageState("Maneuver update: $logMessage");
      }

      _previousManeuverIndex = nextManeuverIndex;

      if (_lastMapMatchedLocation != null) {
        // Update the route based on the current location of the driver.
        // We periodically want to search for better traffic-optimized routes.
        _dynamicRoutingEngine.updateCurrentLocation(_lastMapMatchedLocation!, routeProgress.sectionIndex);
      }
    });

    // Notifies on the current map-matched location and other useful information while driving or walking.
    // The map-matched location is used to update the map view.
    _visualNavigator.navigableLocationListener =
        NavigableLocationListener((NavigableLocation currentNavigableLocation) {
      // Handle results from onNavigableLocationUpdated():
      MapMatchedLocation? mapMatchedLocation = currentNavigableLocation.mapMatchedLocation;
      if (mapMatchedLocation == null) {
        print("This new location could not be map-matched. Are you off-road?");
        return;
      }

      _lastMapMatchedLocation = mapMatchedLocation;

      var speed = currentNavigableLocation.originalLocation.speedInMetersPerSecond;
      var accuracy = currentNavigableLocation.originalLocation.speedAccuracyInMetersPerSecond;
      print("Driving speed (m/s): $speed plus/minus an accuracy of: $accuracy");
    });

    // Notifies when the destination of the route is reached.
    _visualNavigator.destinationReachedListener = DestinationReachedListener(() {
      // Handle results from onDestinationReached().
      _updateMessageState("Destination reached. Stopping turn-by-turn navigation.");
      stopNavigation();
    });

    // Notifies when a waypoint on the route is reached or missed
    _visualNavigator.milestoneStatusListener =
        MilestoneStatusListener((Milestone milestone, MilestoneStatus milestoneStatus) {
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
      } else if (milestone.waypointIndex == null && milestoneStatus == MilestoneStatus.reached) {
        // For example, when transport mode changes due to a ferry a system-defined waypoint may have been added.
        print("A system-defined waypoint was missed at: " + milestone.mapMatchedCoordinates.toString());
      }
    });

    // Notifies on the current speed limit valid on the current road.
    _visualNavigator.speedLimitListener = SpeedLimitListener((SpeedLimit speedLimit) {
      // Handle results from onSpeedLimitUpdated().
      double? currentSpeedLimit = _getCurrentSpeedLimit(speedLimit);

      if (currentSpeedLimit == null) {
        print("Warning: Speed limits unknown, data could not be retrieved.");
      } else if (currentSpeedLimit == 0) {
        print("No speed limits on this road! Drive as fast as you feel safe ...");
      } else {
        print("Current speed limit (m/s): $currentSpeedLimit");
      }
    });

    // Notifies when the current speed limit is exceeded.
    _visualNavigator.speedWarningListener = SpeedWarningListener((SpeedWarningStatus speedWarningStatus) {
      // Handle results from onSpeedWarningStatusChanged().
      if (speedWarningStatus == SpeedWarningStatus.speedLimitExceeded) {
        // Driver is faster than current speed limit (plus an optional offset, see setupSpeedWarnings()).
        // Play a click sound to indicate this to the driver.
        // As Flutter itself does not provide support for sounds,
        // alternatively use a 3rd party plugin to play an alert sound of your choice.
        // Note that this may not include temporary special speed limits, see SpeedLimitListener.
        SystemSound.play(SystemSoundType.click);
        print("Speed limit exceeded.");
      }

      if (speedWarningStatus == SpeedWarningStatus.speedLimitRestored) {
        print("Driver is again slower than current speed limit (plus an optional offset.)");
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
      GeoCoordinates currentGeoCoordinates = currentMapMatchedLocation == null
          ? routeDeviation.currentLocation.originalLocation.coordinates
          : currentMapMatchedLocation.coordinates;

      // Get last geographic coordinates on route.
      GeoCoordinates lastGeoCoordinatesOnRoute;
      if (routeDeviation.lastLocationOnRoute != null) {
        MapMatchedLocation? lastMapMatchedLocationOnRoute = routeDeviation.lastLocationOnRoute!.mapMatchedLocation;
        lastGeoCoordinatesOnRoute = lastMapMatchedLocationOnRoute == null
            ? routeDeviation.lastLocationOnRoute!.originalLocation.coordinates
            : lastMapMatchedLocationOnRoute.coordinates;
      } else {
        print("User was never following the route. So, we take the start of the route instead.");
        lastGeoCoordinatesOnRoute = route.sections.first.departurePlace.originalCoordinates!;
      }

      int distanceInMeters = currentGeoCoordinates.distanceTo(lastGeoCoordinatesOnRoute) as int;
      print("RouteDeviation in meters is " + distanceInMeters.toString());
    });

    // Notifies on voice maneuver messages.
    _visualNavigator.maneuverNotificationListener = ManeuverNotificationListener((String voiceText) {
      // Handle results lambda_onManeuverNotification().
      // Flutter itself does not provide a text-to-speech engine. Use one of the available TTS plugins to speak
      // the voiceText message.
      print("Voice guidance text: $voiceText");
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
    _visualNavigator.maneuverViewLaneAssistanceListener =
        ManeuverViewLaneAssistanceListener((ManeuverViewLaneAssistance laneAssistance) {
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
    _visualNavigator.junctionViewLaneAssistanceListener =
        JunctionViewLaneAssistanceListener((JunctionViewLaneAssistance junctionViewLaneAssistance) {
      List<Lane> lanes = junctionViewLaneAssistance.lanesForNextJunction;
      if (lanes.isEmpty) {
        _updateMessageState("You have passed the complex junction.");
      } else {
        _updateMessageState("Attention, a complex junction is ahead.");
        logLaneRecommendations(lanes);
      }
    });

    RoadSignWarningOptions roadSignWarningOptions = new RoadSignWarningOptions();
    // Set a filter to get only shields relevant for TRUCKS and HEAVY_TRUCKS.
    roadSignWarningOptions.vehicleTypesFilter = [RoadSignVehicleType.trucks, RoadSignVehicleType.heavyTrucks];
    _visualNavigator.roadSignWarningOptions = roadSignWarningOptions;

    // Notifies on road shields as they appear along the road.
    _visualNavigator.roadSignWarningListener = RoadSignWarningListener((RoadSignWarning roadSignWarning) {
      print("Road sign distance (m): ${roadSignWarning.distanceToRoadSignInMeters}");
      print("Road sign type: ${roadSignWarning.type.name}");

      if (roadSignWarning.signValue != null) {
        // Optional text as it is printed on the local road sign.
        print("Road sign text: ${roadSignWarning.signValue!.text}");
      }

      // For more road sign attributes, please check the API Reference.
    });

    // Notifies truck drivers on road restrictions ahead.
    // For example, there can be a bridge ahead not high enough to pass a big truck
    // or there can be a road ahead where the weight of the truck is beyond it's permissible weight.
    // This event notifies on truck restrictions in general,
    // so it will also deliver events, when the transport type was set to a non-truck transport type.
    // The given restrictions are based on the HERE database of the road network ahead.
    _visualNavigator.truckRestrictionsWarningListener =
        TruckRestrictionsWarningListener((List<TruckRestrictionWarning> list) {
      // The list is guaranteed to be non-empty.
      for (TruckRestrictionWarning truckRestrictionWarning in list) {
        if (truckRestrictionWarning.distanceType == DistanceType.ahead) {
          print("TruckRestrictionWarning ahead in: ${truckRestrictionWarning.distanceInMeters} meters.");
        } else if (truckRestrictionWarning.distanceType == DistanceType.reached) {
          print("A restriction has been reached.");
        } else if (truckRestrictionWarning.distanceType == DistanceType.passed) {
          // If not preceded by a "reached"-notification, this restriction was valid only for the passed location.
          print("A restriction just passed.");
        }

        // One of the following restrictions applies ahead, if more restrictions apply at the same time,
        // they are part of another TruckRestrictionWarning element contained in the list.
        if (truckRestrictionWarning.weightRestriction != null) {
          WeightRestrictionType type = truckRestrictionWarning.weightRestriction!.type;
          int value = truckRestrictionWarning.weightRestriction!.valueInKilograms;
          print("TruckRestriction for weight (kg): ${type.toString()}: $value");
        } else if (truckRestrictionWarning.dimensionRestriction != null) {
          // Can be either a length, width or height restriction of the truck. For example, a height
          // restriction can apply for a tunnel. Other possible restrictions are delivered in
          // separate TruckRestrictionWarning objects contained in the list, if any.
          DimensionRestrictionType type = truckRestrictionWarning.dimensionRestriction!.type;
          int value = truckRestrictionWarning.dimensionRestriction!.valueInCentimeters;
          print("TruckRestriction for dimension: ${type.toString()}: $value");
        } else {
          print("TruckRestriction: General restriction - no trucks allowed.");
        }
      }
    });

    // Notifies whenever any textual attribute of the current road changes, i.e., the current road texts differ
    // from the previous one. This can be useful during tracking mode, when no maneuver information is provided.
    _visualNavigator.roadTextsListener = RoadTextsListener((RoadTexts roadTexts) {
      // See _getRoadName() how to get the current road name from the provided RoadTexts.
    });

    SignpostWarningOptions signpostWarningOptions = SignpostWarningOptions();
    signpostWarningOptions.aspectRatio = AspectRatio.aspectRatio3X4;
    signpostWarningOptions.darkTheme = false;
    _visualNavigator.signpostWarningOptions = signpostWarningOptions;

    // Notifies on signposts as they appear along a road on a shield to indicate the upcoming directions and destinations, such
    // as cities or road names.
    // Optionally, you can use a feature-configuration to preload the assets as part of a Region.
    _visualNavigator.signpostWarningListener = SignpostWarningListener((SignpostWarning signpostWarning) {
      double distance = signpostWarning.distanceToSignpostsInMeters;
      DistanceType distanceType = signpostWarning.distanceType;

      // Note that DistanceType.reached is not used for Signposts.
      if (distanceType == DistanceType.ahead) {
        print("A Signpost ahead in: "+ distance.toString() + " meters.");
      } else if (distanceType == DistanceType.passed) {
        print("A Signpost just passed.");
      }

      // Multiple signs can appear at the same location.
      for (Signpost signpost in signpostWarning.signposts) {
        String svgImageContent = signpost.svgImageContent;
        print("Signpost SVG data: " + svgImageContent);
        // The resolution-independent SVG data can now be used in an application to visualize the image.
        // Use a SVG library of your choice for this.
      }
    });

    JunctionViewWarningOptions junctionViewWarningOptions = new JunctionViewWarningOptions();
    junctionViewWarningOptions.aspectRatio = AspectRatio.aspectRatio3X4;
    junctionViewWarningOptions.darkTheme = false;
    _visualNavigator.junctionViewWarningOptions = junctionViewWarningOptions;

    // Notifies on complex junction views for which a 3D visualization is available as a static image to help orientate the driver.
    // The event matches the notification for complex junctions, see JunctionViewLaneAssistance.
    // Note that the SVG data for junction view is composed out of several 3D elements such as trees, a horizon and the actual junction
    // geometry. Approx. size per image is 15 MB. In the future, we we reduce the level of realism to reduce the size of the assets.
    // Optionally, you can use a feature-configuration to preload the assets as part of a Region.
    _visualNavigator.junctionViewWarningListener =  JunctionViewWarningListener((JunctionViewWarning junctionViewWarning) {
      double distance = junctionViewWarning.distanceToJunctionViewInMeters;
      DistanceType distanceType = junctionViewWarning.distanceType;

      // Note that DistanceType.reached is not used for junction views.
      if (distanceType == DistanceType.ahead) {
        print("A JunctionView ahead in: "+ distance.toString() + " meters.");
      } else if (distanceType == DistanceType.passed) {
        print("A JunctionView just passed.");
      }

      String svgImageContent = junctionViewWarning.junctionView.svgImageContent;
      print("JunctionView SVG data: " + svgImageContent);
      // The resolution-independent SVG data can now be used in an application to visualize the image.
      // Use a SVG library of your choice for this.
    });
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

      laneNumber++;
    }
  }

  void setupSpeedWarnings() {
    SpeedLimitOffset speedLimitOffset = SpeedLimitOffset.withDefaults();
    speedLimitOffset.lowSpeedOffsetInMetersPerSecond = 2;
    speedLimitOffset.highSpeedOffsetInMetersPerSecond = 4;
    speedLimitOffset.highSpeedBoundaryInMetersPerSecond = 25;

    _visualNavigator.speedWarningOptions = SpeedWarningOptions(speedLimitOffset);
  }

  void setupVoiceTextMessages() {
    LanguageCode ttsLanguageCode =
        getLanguageCodeForDevice(VisualNavigator.getAvailableLanguagesForManeuverNotifications());
    _visualNavigator.maneuverNotificationOptions = ManeuverNotificationOptions(ttsLanguageCode, UnitSystem.metric);

    print("LanguageCode for maneuver notifications: $ttsLanguageCode.");
  }

  LanguageCode getLanguageCodeForDevice(List<LanguageCode> supportedVoiceSkins) {
    final Locale localeForCurrenDevice = window.locales.first;

    // Determine supported voice skins from HERE SDK.
    LanguageCode languageCodeForCurrenDevice = LanguageCodeConverter.getLanguageCode(localeForCurrenDevice);
    if (!supportedVoiceSkins.contains(languageCodeForCurrenDevice)) {
      print("No voice skins available for $languageCodeForCurrenDevice, falling back to enUs.");
      languageCodeForCurrenDevice = LanguageCode.enUs;
    }

    return languageCodeForCurrenDevice;
  }

  double? _getCurrentSpeedLimit(SpeedLimit speedLimit) {
    // Note that all speedLimit properties can be null if no data is available.

    // The regular speed limit if available. In case of unbounded speed limit, the value is zero.
    print("speedLimitInMetersPerSecond: " + speedLimit.speedLimitInMetersPerSecond.toString());

    // A conditional school zone speed limit as indicated on the local road signs.
    print("schoolZoneSpeedLimitInMetersPerSecond: " + speedLimit.schoolZoneSpeedLimitInMetersPerSecond.toString());

    // A conditional time-dependent speed limit as indicated on the local road signs.
    // It is in effect considering the current local time provided by the device's clock.
    print(
        "timeDependentSpeedLimitInMetersPerSecond: " + speedLimit.timeDependentSpeedLimitInMetersPerSecond.toString());

    // A conditional non-legal speed limit that recommends a lower speed,
    // for example, due to bad road conditions.
    print("advisorySpeedLimitInMetersPerSecond: " + speedLimit.advisorySpeedLimitInMetersPerSecond.toString());

    // A weather-dependent speed limit as indicated on the local road signs.
    // The HERE SDK cannot detect the current weather condition, so a driver must decide
    // based on the situation if this speed limit applies.
    print("fogSpeedLimitInMetersPerSecond: " + speedLimit.fogSpeedLimitInMetersPerSecond.toString());
    print("rainSpeedLimitInMetersPerSecond: " + speedLimit.rainSpeedLimitInMetersPerSecond.toString());
    print("snowSpeedLimitInMetersPerSecond: " + speedLimit.snowSpeedLimitInMetersPerSecond.toString());

    // For convenience, this returns the effective (lowest) speed limit between
    // - speedLimitInMetersPerSecond
    // - schoolZoneSpeedLimitInMetersPerSecond
    // - timeDependentSpeedLimitInMetersPerSecond
    return speedLimit.effectiveSpeedLimitInMetersPerSecond();
  }
}
