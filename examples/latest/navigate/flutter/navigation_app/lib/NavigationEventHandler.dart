/*
 * Copyright (C) 2019-2025 HERE Europe B.V.
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
import 'package:here_sdk/navigation.dart';
import 'package:here_sdk/routing.dart' as HERE;
import 'package:here_sdk/routing.dart';
import 'package:here_sdk/trafficawarenavigation.dart';
import 'package:navigation_app/RouteCalculator.dart';
import 'package:navigation_app/time_utils.dart';

import 'LanguageCodeConverter.dart';

// This class combines the various events that can be emitted during turn-by-turn navigation.
// Note that this class does not show an exhaustive list of all possible events.
class NavigationEventHandler {
  VisualNavigator _visualNavigator;
  DynamicRoutingEngine _dynamicRoutingEngine;
  MapMatchedLocation? _lastMapMatchedLocation;
  int _previousManeuverIndex = -1;
  int lastTrafficUpdateInMilliseconds = 0;
  final ValueChanged<String> _updateMessageState;
  RouteCalculator _routeCalculator;
  final _timeUtils = TimeUtils();

  NavigationEventHandler(VisualNavigator visualNavigator, DynamicRoutingEngine dynamicRoutingEngine,
      ValueChanged<String> updateMessageState, RouteCalculator routeCalculator)
      : _visualNavigator = visualNavigator,
        _dynamicRoutingEngine = dynamicRoutingEngine,
        _updateMessageState = updateMessageState,
        _routeCalculator = routeCalculator {}

  void setupListeners() {
    _setupSpeedWarnings();
    _setupVoiceTextMessages();
    _setupRealisticViewWarnings();

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
      String logMessage = action.name +
          ' on ' +
          roadName +
          ' in ' +
          nextManeuverProgress.remainingDistanceInMeters.toString() +
          ' meters.';

      String currentETAString = _getETA(routeProgress);

      if (_previousManeuverIndex != nextManeuverIndex) {
        currentETAString = '$currentETAString\nNew maneuver: $logMessage';
      } else {
        // A maneuver update contains a different distance to reach the next maneuver.
        currentETAString = '$currentETAString\nManeuver update: $logMessage';
      }
      _updateMessageState(currentETAString);

      _previousManeuverIndex = nextManeuverIndex;

      if (_lastMapMatchedLocation != null) {
        // Update the route based on the current location of the driver.
        // We periodically want to search for better traffic-optimized routes.
        _dynamicRoutingEngine.updateCurrentLocation(_lastMapMatchedLocation!, routeProgress.sectionIndex);
      }

      updateTrafficOnRoute(routeProgress);
    });

    // Provides lane information for the road a user is currently driving on.
    // It's supported for turn-by-turn navigation and in tracking mode.
    // It does not notify on which lane the user is currently driving on.
    _visualNavigator.currentSituationLaneAssistanceViewListener =
        CurrentSituationLaneAssistanceViewListener((CurrentSituationLaneAssistanceView currentSituationLaneAssistanceView) {
          // A list of lanes on the current road.
          List<CurrentSituationLaneView>  lanesList = currentSituationLaneAssistanceView.lanes;

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

      if (_lastMapMatchedLocation?.isDrivingInTheWrongWay == true) {
        // For two-way streets, this value is always false. This feature is supported in tracking mode and when deviating from a route.
        print("This is a one way road. User is driving against the allowed traffic direction.");
      }

      var speed = currentNavigableLocation.originalLocation.speedInMetersPerSecond;
      var accuracy = currentNavigableLocation.originalLocation.speedAccuracyInMetersPerSecond;
      print("Driving speed (m/s): $speed plus/minus an accuracy of: $accuracy");
    });

    // Notifies when the destination of the route is reached.
    _visualNavigator.destinationReachedListener = DestinationReachedListener(() {
      // Handle results from onDestinationReached().
      _updateMessageState("Destination reached.");
      // Guidance has stopped. Now consider to, for example,
      // switch to tracking mode or stop rendering or locating or do anything else that may
      // be useful to support your app flow.
      // If the DynamicRoutingEngine was started before, consider to stop it now.
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

    // Notifies on school zones ahead.
    _visualNavigator.schoolZoneWarningListener = SchoolZoneWarningListener((List<SchoolZoneWarning> list) {
      // The list is guaranteed to be non-empty.
      for (SchoolZoneWarning schoolZoneWarning in list) {
        if (schoolZoneWarning.distanceType == DistanceType.ahead) {
          print("A school zone ahead in: ${schoolZoneWarning.distanceToSchoolZoneInMeters} meters.");
          // Note that this will be the same speed limit as indicated by SpeedLimitListener, unless
          // already a lower speed limit applies, for example, because of a heavy truck load.
          print("Speed limit restriction for this school zone: ${schoolZoneWarning.speedLimitInMetersPerSecond} m/s.");
          if (schoolZoneWarning.timeRule != null && !schoolZoneWarning.timeRule!.appliesTo(DateTime.now())) {
            // For example, during night sometimes a school zone warning does not apply.
            // If schoolZoneWarning.timeRule is null, the warning applies at anytime.
            print("Note that this school zone warning currently does not apply.");
          }
        } else if (schoolZoneWarning.distanceType == DistanceType.reached) {
          print("A school zone has been reached.");
        } else if (schoolZoneWarning.distanceType == DistanceType.passed) {
          print("A school zone has been passed.");
        }
      }
    });

    SchoolZoneWarningOptions schoolZoneWarningOptions = SchoolZoneWarningOptions();
    schoolZoneWarningOptions.filterOutInactiveTimeDependentWarnings = true;
    schoolZoneWarningOptions.warningDistanceInMeters = 150;
    _visualNavigator.schoolZoneWarningOptions = schoolZoneWarningOptions;

    // Notifies whenever a border is crossed of a country and optionally, by default, also when a state
    // border of a country is crossed.
    _visualNavigator.borderCrossingWarningListener =
        BorderCrossingWarningListener((BorderCrossingWarning borderCrossingWarning) {
      // Since the border crossing warning is given relative to a single location,
      // the DistanceType.reached will never be given for this warning.
      if (borderCrossingWarning.distanceType == DistanceType.ahead) {
        print(
            "BorderCrossing: A border is ahead in: ${borderCrossingWarning.distanceToBorderCrossingInMeters} meters.");
        print("BorderCrossing: Type (such as country or state): ${borderCrossingWarning.type.name}");
        print("BorderCrossing: Country code: ${borderCrossingWarning.countryCode.name}");

        // The state code after the border crossing. It represents the state / province code.
        // It is a 1 to 3 upper-case characters string that follows the ISO 3166-2 standard,
        // but without the preceding country code (e.g., for Texas, the state code will be TX).
        // It will be null for countries without states or countries in which the states have very
        // similar regulations (e.g., for Germany, there will be no state borders).
        if (borderCrossingWarning.stateCode != null) {
          print("BorderCrossing: State code: ${borderCrossingWarning.stateCode}");
        }

        // The general speed limits that apply in the country / state after border crossing.
        var generalVehicleSpeedLimits = borderCrossingWarning.speedLimits;
        print(
            "BorderCrossing: Speed limit in cities (m/s): ${generalVehicleSpeedLimits.maxSpeedUrbanInMetersPerSecond}");
        print(
            "BorderCrossing: Speed limit outside cities (m/s): ${generalVehicleSpeedLimits.maxSpeedRuralInMetersPerSecond}");
        print(
            "BorderCrossing: Speed limit on highways (m/s): ${generalVehicleSpeedLimits.maxSpeedHighwaysInMetersPerSecond}");
      } else if (borderCrossingWarning.distanceType == DistanceType.passed) {
        print("BorderCrossing: A border has been passed.");
      }
    });

    BorderCrossingWarningOptions borderCrossingWarningOptions = BorderCrossingWarningOptions();
    // If set to true, all the state border crossing notifications will not be given.
    // If the value is false, all border crossing notifications will be given for both
    // country borders and state borders. Defaults to false.
    borderCrossingWarningOptions.filterOutStateBorderWarnings = true;
    _visualNavigator.borderCrossingWarningOptions = borderCrossingWarningOptions;

    // Notifies on danger zones.
    // A danger zone refers to areas where there is an increased risk of traffic incidents.
    // These zones are designated to alert drivers to potential hazards and encourage safer driving behaviors.
    // The HERE SDK warns when approaching the danger zone, as well as when leaving such a zone.
    // A danger zone may or may not have one or more speed cameras in it. The exact location of such speed cameras
    // is not provided. Note that danger zones are only available in selected countries, such as France.
    _visualNavigator.dangerZoneWarningListener = DangerZoneWarningListener((DangerZoneWarning dangerZoneWarning) {
      if (dangerZoneWarning.distanceType == DistanceType.ahead) {
        print("A danger zone ahead in: " + dangerZoneWarning.distanceInMeters.toString() + " meters.");
        // isZoneStart indicates if we enter the danger zone from the start.
        // It is false, when the danger zone is entered from a side street.
        // Based on the route path, the HERE SDK anticipates from where the danger zone will be entered.
        // In tracking mode, the most probable path will be used to anticipate from where
        // the danger zone is entered.
        print("isZoneStart: " + dangerZoneWarning.isZoneStart.toString());
      } else if (dangerZoneWarning.distanceType == DistanceType.reached) {
        print("A danger zone has been reached. isZoneStart: " + dangerZoneWarning.isZoneStart.toString());
      } else if (dangerZoneWarning.distanceType == DistanceType.passed) {
        print("A danger zone has been passed.");
      }
    });

    // Notifies on low speed zones ahead - as indicated also on the map when
    // MapFeatures.lowSpeedZones is set.
    _visualNavigator.lowSpeedZoneWarningListener =
        LowSpeedZoneWarningListener((LowSpeedZoneWarning lowSpeedZoneWarning) {
      if (lowSpeedZoneWarning.distanceType == DistanceType.ahead) {
        print(
            "A low speed zone ahead in: " + lowSpeedZoneWarning.distanceToLowSpeedZoneInMeters.toString() + " meters.");
        print("Speed limit in low speed zone (m/s): " + lowSpeedZoneWarning.speedLimitInMetersPerSecond.toString());
      } else if (lowSpeedZoneWarning.distanceType == DistanceType.reached) {
        print("A low speed zone has been reached.");
        print("Speed limit in low speed zone (m/s): " + lowSpeedZoneWarning.speedLimitInMetersPerSecond.toString());
      } else if (lowSpeedZoneWarning.distanceType == DistanceType.passed) {
        print("A low speed zone has been passed.");
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

    // Notifies about merging traffic to the current road.
    _visualNavigator.trafficMergeWarningListener =
        TrafficMergeWarningListener((TrafficMergeWarning trafficMergeWarning) {
      if (trafficMergeWarning.distanceType == DistanceType.ahead) {
        print("There is a merging " +
            trafficMergeWarning.roadType.name +
            " ahead in: " +
            trafficMergeWarning.distanceToTrafficMergeInMeters.toString() +
            "meters, merging from the " +
            trafficMergeWarning.side.name +
            "side, with lanes =" +
            trafficMergeWarning.laneCount.toString());
      } else if (trafficMergeWarning.distanceType == DistanceType.passed) {
        print("A merging " +
            trafficMergeWarning.roadType.name +
            " passed: " +
            trafficMergeWarning.distanceToTrafficMergeInMeters.toString() +
            "meters, merging from the " +
            trafficMergeWarning.side.name +
            "side, with lanes =" +
            trafficMergeWarning.laneCount.toString());
      } else if (trafficMergeWarning.distanceType == DistanceType.reached) {
        // Since the traffic merge warning is given relative to a single position on the route,
        // DistanceType.reached will never be given for this warning.
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

    // Notifies on messages that can be fed into TTS engines to guide the user with audible instructions.
    // The texts can be maneuver instructions or warn on certain obstacles, such as speed cameras.
    _visualNavigator.eventTextListener = EventTextListener((EventText eventText) {
      // Flutter itself does not provide a text-to-speech engine. Use one of the available TTS plugins to speak
      // the eventText message.
      print("Voice guidance text: $eventText");
      // We can optionally retrieve the associated maneuver. The details will be null if the text contains
      // non-maneuver related information, such as for speed camera warnings.
      if (eventText.type == TextNotificationType.maneuver) {
        HERE.Maneuver? maneuver = eventText.maneuverNotificationDetails?.maneuver;
      }
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
    // Get notification distances for road sign alerts from visual navigator.
    WarningNotificationDistances warningNotificationDistances =
        _visualNavigator.getWarningNotificationDistances(WarningType.roadSign);

    // The distance in meters for emitting warnings when the speed limit or current speed is fast. Defaults to 1500.
    warningNotificationDistances.fastSpeedDistanceInMeters = 1600;
    // The distance in meters for emitting warnings when the speed limit or current speed is regular. Defaults to 750.
    warningNotificationDistances.regularSpeedDistanceInMeters = 800;
    // The distance in meters for emitting warnings when the speed limit or current speed is slow. Defaults to 500.
    warningNotificationDistances.slowSpeedDistanceInMeters = 600;

    // Set the warning distances for road signs.
    _visualNavigator.setWarningNotificationDistances(WarningType.roadSign, warningNotificationDistances);

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

    // Notifies on safety camera warnings as they appear along the road.
    _visualNavigator.safetyCameraWarningListener =
        SafetyCameraWarningListener((SafetyCameraWarning safetyCameraWarning) {
      if (safetyCameraWarning.distanceType == DistanceType.ahead) {
        print("Safety camera warning " +
            safetyCameraWarning.type.name +
            " ahead in: " +
            safetyCameraWarning.distanceToCameraInMeters.toString() +
            "with speed limit =" +
            safetyCameraWarning.speedLimitInMetersPerSecond.toString() +
            "m/s");
      } else if (safetyCameraWarning.distanceType == DistanceType.passed) {
        print("Safety camera warning " +
            safetyCameraWarning.type.name +
            " passed: " +
            safetyCameraWarning.distanceToCameraInMeters.toString() +
            "with speed limit =" +
            safetyCameraWarning.speedLimitInMetersPerSecond.toString() +
            "m/s");
      } else if (safetyCameraWarning.distanceType == DistanceType.reached) {
        print("Safety camera warning " +
            safetyCameraWarning.type.name +
            " reached at: " +
            safetyCameraWarning.distanceToCameraInMeters.toString() +
            "with speed limit =" +
            safetyCameraWarning.speedLimitInMetersPerSecond.toString() +
            "m/s");
      }
    });

    // Notifies truck drivers on road restrictions ahead. Called whenever there is a change.
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
          if (truckRestrictionWarning.timeRule != null &&
              !truckRestrictionWarning.timeRule!.appliesTo(DateTime.now())) {
            // For example, during a specific time period of a day, some truck restriction warnings do not apply.
            // If truckRestrictionWarning.timeRule is null, the warning applies at anytime.
            print("Note that this truck restriction warning currently does not apply.");
          }
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
    _visualNavigator.realisticViewWarningListener =
        RealisticViewWarningListener((RealisticViewWarning realisticViewWarning) {
      double distance = realisticViewWarning.distanceToRealisticViewInMeters;
      DistanceType distanceType = realisticViewWarning.distanceType;

      // Note that DistanceType.reached is not used for Signposts and junction views
      // as a junction is identified through a location instead of an area.
      if (distanceType == DistanceType.ahead) {
        print("A RealisticView ahead in: " + distance.toString() + " meters.");
      } else if (distanceType == DistanceType.passed) {
        print("A RealisticView just passed.");
      }

      RealisticViewVectorImage? realisticView = realisticViewWarning.realisticViewVectorImage;
      if (realisticView == null) {
        print("A RealisticView just passed. No SVG content delivered.");
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
      print("signpostSvgImage: " + signpostSvgImageContent);
      print("junctionViewSvgImage: " + junctionViewSvgImageContent);
    });

    // Notifies on upcoming toll stops. Uses the same notification
    // thresholds as other warners and provides events with or without a route to follow.
    _visualNavigator.tollStopWarningListener = TollStopWarningListener((TollStop tollStop) {
      List<TollBoothLane> lanes = tollStop.lanes;

      // The lane at index 0 is the leftmost lane adjacent to the middle of the road.
      // The lane at the last index is the rightmost lane.
      int laneNumber = 0;
      for (TollBoothLane tollBoothLane in lanes) {
        // Log which vehicles types are allowed on this lane that leads to the toll booth.
        _logLaneAccess("ToolBoothLane: ", laneNumber, tollBoothLane.access);
        TollBooth tollBooth = tollBoothLane.booth;
        List<TollCollectionMethod> tollCollectionMethods = tollBooth.tollCollectionMethods;
        List<PaymentMethod> paymentMethods = tollBooth.paymentMethods;
        // The supported collection methods like ticket or automatic / electronic.
        for (TollCollectionMethod collectionMethod in tollCollectionMethods) {
          print("This toll stop supports collection via: " + collectionMethod.name);
        }
        // The supported payment methods like cash or credit card.
        for (PaymentMethod paymentMethod in paymentMethods) {
          print("This toll stop supports payment via: " + paymentMethod.name);
        }
        laneNumber++;
      }
    });
  }

  // Periodically updates the traffic information for the current route.
  // This method checks whether the last traffic update occurred within the specified interval and skips the update if not.
  // Then it calculates the current traffic conditions along the route using the `RoutingEngine`.
  // Lastly, it updates the `VisualNavigator` with the newly calculated `TrafficOnRoute` object,
  // which affects the `RouteProgress` duration without altering the route geometry or distance.
  //
  // Note: This code initiates periodic calls to the HERE Routing backend. Depending on your contract,
  // each call may be charged separately. It is the application's responsibility to decide how and how
  // often this code should be executed.
  void updateTrafficOnRoute(RouteProgress routeProgress) {
    Route? currentRoute = _visualNavigator.route;
    if (currentRoute == null) {
      // Should never happen.
      return;
    }

    // Below, we use 10 minutes. A common range is between 5 and 15 minutes.
    const int trafficUpdateIntervalInMilliseconds = 10 * 60000; // 10 minutes.
    int now = DateTime.now().millisecondsSinceEpoch;
    if ((now - lastTrafficUpdateInMilliseconds) < trafficUpdateIntervalInMilliseconds) {
      return;
    }
    // Store the current time when we update trafficOnRoute.
    lastTrafficUpdateInMilliseconds = now;

    List<SectionProgress> sectionProgressList = routeProgress.sectionProgress;
    SectionProgress lastSectionProgress = sectionProgressList.last;
    int traveledDistanceOnLastSectionInMeters =
        currentRoute.lengthInMeters - lastSectionProgress.remainingDistanceInMeters;
    int lastTraveledSectionIndex = routeProgress.sectionIndex;

    _routeCalculator.calculateTrafficOnRoute(
      currentRoute,
      lastTraveledSectionIndex,
      traveledDistanceOnLastSectionInMeters,
      (RoutingError? routingError, TrafficOnRoute? trafficOnRoute) {
        if (routingError != null) {
          print("CalculateTrafficOnRoute error: ${routingError.name}");
          return;
        }
        // Sets traffic data for the current route, affecting RouteProgress duration in SectionProgress,
        // while preserving route distance and geometry.
        _visualNavigator.trafficOnRoute = trafficOnRoute;
        print("Updated traffic on route.");
      },
    );
  }

  String _getETA(RouteProgress routeProgress) {
    List<SectionProgress> sectionProgressList = routeProgress.sectionProgress;
    // sectionProgressList is guaranteed to be non-empty.
    SectionProgress lastSectionProgress = sectionProgressList.last;

    String currentETAString =
        'ETA: ${_timeUtils.getETAinDeviceTimeZone(lastSectionProgress.remainingDuration.inSeconds)}';

    print('Distance to destination in meters: ${lastSectionProgress.remainingDistanceInMeters}');
    print('Traffic delay ahead in seconds: ${lastSectionProgress.trafficDelay.inSeconds}');
    // Logs current ETA.
    print(currentETAString);

    return currentETAString;
  }

  void _setupSpeedWarnings() {
    SpeedLimitOffset speedLimitOffset = SpeedLimitOffset();
    speedLimitOffset.lowSpeedOffsetInMetersPerSecond = 2;
    speedLimitOffset.highSpeedOffsetInMetersPerSecond = 4;
    speedLimitOffset.highSpeedBoundaryInMetersPerSecond = 25;

    _visualNavigator.speedWarningOptions = SpeedWarningOptions(speedLimitOffset);
  }

  void _setupVoiceTextMessages() {
    LanguageCode ttsLanguageCode =
        getLanguageCodeForDevice(VisualNavigator.getAvailableLanguagesForManeuverNotifications());
    ManeuverNotificationOptions maneuverNotificationOptions = ManeuverNotificationOptions.withDefaults();
    // Set the language in which the notifications will be generated.
    maneuverNotificationOptions.language = ttsLanguageCode;
    // Set the measurement system used for distances.
    maneuverNotificationOptions.unitSystem = UnitSystem.metric;
    _visualNavigator.maneuverNotificationOptions = maneuverNotificationOptions;
    print("LanguageCode for maneuver notifications: $ttsLanguageCode.");
  }

  void _setupRealisticViewWarnings() {
    RealisticViewWarningOptions realisticViewWarningOptions = RealisticViewWarningOptions();
    realisticViewWarningOptions.aspectRatio = AspectRatio.aspectRatio3X4;
    realisticViewWarningOptions.darkTheme = false;
    _visualNavigator.realisticViewWarningOptions = realisticViewWarningOptions;
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
      bool isLaneDirectionOnRoute = _isCurrentSituationLaneViewDirectionOnRoute(currentSituationLaneView, laneDirection);
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

  bool _isCurrentSituationLaneViewDirectionOnRoute(CurrentSituationLaneView currentSituationLaneView, LaneDirection laneDirection) {
    return currentSituationLaneView.directionsOnRoute.contains(laneDirection);
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

  String _getRoadName(Maneuver maneuver) {
    RoadTexts currentRoadTexts = maneuver.roadTexts;
    RoadTexts nextRoadTexts = maneuver.nextRoadTexts;

    String? currentRoadName = currentRoadTexts.names.getDefaultValue();
    String? currentRoadNumber = currentRoadTexts.numbersWithDirection.getDefaultValue();
    String? nextRoadName = nextRoadTexts.names.getDefaultValue();
    String? nextRoadNumber = nextRoadTexts.numbersWithDirection.getDefaultValue();

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
}