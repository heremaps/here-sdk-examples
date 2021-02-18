/*
 * Copyright (C) 2019-2021 HERE Europe B.V.
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

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/navigation.dart';
import 'package:here_sdk/routing.dart' as HERE;

import 'LocationProviderImplementation.dart';

// Shows how to start and stop turn-by-turn navigation along a route.
class NavigationExample {
  HereMapController _hereMapController;
  VisualNavigator _visualNavigator;
  LocationProviderImplementation _locationProvider;
  int _previousManeuverIndex = -1;

  NavigationExample(HereMapController hereMapController) {
    _hereMapController = hereMapController;

    try {
      _visualNavigator = VisualNavigator.make();
    } on InstantiationException {
      throw Exception("Initialization of VisualNavigator failed.");
    }

    // This enables a navigation view including a rendered navigation arrow.
    _visualNavigator.startRendering(_hereMapController);

    // For easy testing, this location provider simulates location events along a route.
    // You can use HERE positioning to feed real locations, see the positioning_app for an example.
    _locationProvider = new LocationProviderImplementation();

    setupListeners();
  }

  void startNavigation(HERE.Route route) {
    setupSpeedWarnings();
    setupVoiceTextMessages();

    // Set the route to follow.
    _visualNavigator.route = route;

    // Simulates location events based on the given route.
    // The navigator is set as listener to receive location updates.
    _locationProvider.enableRoutePlayback(route, _visualNavigator);
  }

  void stopNavigation() {
    // This can be used to enable tracking mode (when valid locations are provided).
    // However, below we just stop the location provider, so no new locations will be forwarded to the navigator.
    _visualNavigator.route = null;
    _locationProvider.stop();

    // Optionally, you can stop rendering, ie. to remove the current location marker.
    //_visualNavigator.stopRendering();
  }

  void setupListeners() {
    // Notifies on the current map-matched location and other useful information while driving or walking.
    // The map-matched location is used to update the map view.
    _visualNavigator.navigableLocationListener =
        NavigableLocationListener.fromLambdas(lambda_onNavigableLocationUpdated:
            (NavigableLocation currentNavigableLocation) {
      MapMatchedLocation mapMatchedLocation =
          currentNavigableLocation.mapMatchedLocation;
      if (mapMatchedLocation == null) {
        print('This new location could not be map-matched. Are you off-road?');
        return;
      }

      print('Current street: ' + currentNavigableLocation.streetName);

      // Get speed limits for drivers.
      if (currentNavigableLocation.speedLimitInMetersPerSecond == null) {
        print('Warning: Speed limits unkown, data could not be retrieved.');
      } else if (currentNavigableLocation.speedLimitInMetersPerSecond == 0) {
        print(
            'No speed limits on this road! Drive as fast as you feel safe ...');
      } else {
        print('Current speed limit (m/s): ' +
            currentNavigableLocation.speedLimitInMetersPerSecond.toString());
      }
    });

    // Notifies on the progress along the route including maneuver instructions.
    // These maneuver instructions can be used to compose a visual representation of the next maneuver actions.
    _visualNavigator.routeProgressListener = RouteProgressListener.fromLambdas(
        lambda_onRouteProgressUpdated: (RouteProgress routeProgress) {
      List<SectionProgress> sectionProgressList = routeProgress.sectionProgress;
      // sectionProgressList is guaranteed to be non-empty.
      SectionProgress lastSectionProgress =
          sectionProgressList.elementAt(sectionProgressList.length - 1);
      print('Distance to destination in meters: ' +
          lastSectionProgress.remainingDistanceInMeters.toString());
      print('Traffic delay ahead in seconds: ' +
          lastSectionProgress.trafficDelayInSeconds.toString());

      // Contains the progress for the next maneuver ahead and the next-next maneuvers, if any.
      List<ManeuverProgress> nextManeuverList = routeProgress.maneuverProgress;

      ManeuverProgress nextManeuverProgress = nextManeuverList.first;
      if (nextManeuverProgress == null) {
        print('No next maneuver available.');
        return;
      }

      int nextManeuverIndex = nextManeuverProgress.maneuverIndex;
      HERE.Maneuver nextManeuver =
          _visualNavigator.getManeuver(nextManeuverIndex);
      if (nextManeuver == null) {
        // Should never happen as we retrieved the next maneuver progress above.
        return;
      }

      HERE.ManeuverAction action = nextManeuver.action;
      String nextRoadName = nextManeuver.nextRoadName;
      String road = nextRoadName ?? nextManeuver.nextRoadNumber;

      if (action == HERE.ManeuverAction.arrive) {
        // We are approaching the destination, so there's no next road.
        String currentRoadName = nextManeuver.roadName;
        road = currentRoadName ?? nextManeuver.roadNumber;
      }

      // Happens only in rare cases, when also the fallback is null.
      road ??= 'unnamed road';

      String logMessage = describeEnum(action) +
          ' on ' +
          road +
          ' in ' +
          nextManeuverProgress.remainingDistanceInMeters.toString() +
          ' meters.';

      if (_previousManeuverIndex != nextManeuverIndex) {
        print('New maneuver: $logMessage');
      } else {
        // A maneuver update contains a different distance to reach the next maneuver.
        print('Maneuver update: $logMessage');
      }

      _previousManeuverIndex = nextManeuverIndex;
    });

    // Notifies when the destination of the route is reached.
    _visualNavigator.destinationReachedListener =
        DestinationReachedListener.fromLambdas(lambda_onDestinationReached: () {
      print('Destination reached. Stopping turn-by-turn navigation.');
      stopNavigation();
    });

    // Notifies when a waypoint on the route is reached.
    _visualNavigator.milestoneReachedListener =
        MilestoneReachedListener.fromLambdas(
            lambda_onMilestoneReached: (Milestone milestone) {
      if (milestone.waypointIndex != null) {
        print('A user-defined waypoint was reached, index of waypoint: ' +
            milestone.waypointIndex.toString());
        print('Original coordinates: ' +
            milestone.originalCoordinates.toString());
      } else {
        // For example, when transport mode changes due to a ferry.
        print('A system defined waypoint was reached at ' +
            milestone.mapMatchedCoordinates.toString());
      }
    });

    // Notifies when the current speed limit is exceeded.
    _visualNavigator.speedWarningListener = SpeedWarningListener.fromLambdas(
        lambda_onSpeedWarningStatusChanged:
            (SpeedWarningStatus speedWarningStatus) {
      if (speedWarningStatus == SpeedWarningStatus.speedLimitExceeded) {
        // Driver is faster than current speed limit (plus an optional offset, see setupSpeedWarnings()).
        // Play a click sound to indicate this to the driver.
        // As Flutter itself does not provide support for sounds,
        // alternatively use a 3rd party plugin to play an alert sound of your choice.
        SystemSound.play(SystemSoundType.click);
        print('Speed limit exceeded.');
      }

      if (speedWarningStatus == SpeedWarningStatus.speedLimitRestored) {
        print(
            'Driver is again slower than current speed limit (plus an optional offset.)');
      }
    });

    // Notifies on a possible deviation from the route.
    // When deviation is too large, an app may decide to recalculate the route from current location to destination.
    _visualNavigator.routeDeviationListener =
        RouteDeviationListener.fromLambdas(
            lambda_onRouteDeviation: (RouteDeviation routeDeviation) {
      HERE.Route route = _visualNavigator.route;
      if (route == null) {
        // May happen in rare cases when route was set to null inbetween.
        return;
      }

      // Get current geographic coordinates.
      MapMatchedLocation currentMapMatchedLocation =
          routeDeviation.currentLocation.mapMatchedLocation;
      GeoCoordinates currentGeoCoordinates = currentMapMatchedLocation == null
          ? routeDeviation.currentLocation.originalLocation.coordinates
          : currentMapMatchedLocation.coordinates;

      // Get last geographic coordinates on route.
      GeoCoordinates lastGeoCoordinatesOnRoute;
      if (routeDeviation.lastLocationOnRoute != null) {
        MapMatchedLocation lastMapMatchedLocationOnRoute =
            routeDeviation.lastLocationOnRoute.mapMatchedLocation;
        lastGeoCoordinatesOnRoute = lastMapMatchedLocationOnRoute == null
            ? routeDeviation.lastLocationOnRoute.originalLocation.coordinates
            : lastMapMatchedLocationOnRoute.coordinates;
      } else {
        print(
            'User was never following the route. So, we take the start of the route instead.');
        lastGeoCoordinatesOnRoute =
            route.sections.first.departurePlace.originalCoordinates;
      }

      int distanceInMeters =
          currentGeoCoordinates.distanceTo(lastGeoCoordinatesOnRoute) as int;
      print('RouteDeviation in meters is ' + distanceInMeters.toString());
    });

    // Notifies on voice maneuver messages.
    _visualNavigator.maneuverNotificationListener =
        ManeuverNotificationListener.fromLambdas(
            lambda_onManeuverNotification: (String voiceText) {
      // Flutter itself does not provide a text-to-speech engine. Use one of the available TTS plugins to speak
      // the voiceText message.
      print('Voice guidance text: $voiceText');
    });
  }

  void setupSpeedWarnings() {
    double lowSpeedOffsetInMetersPerSecond = 2;
    double highSpeedOffsetInMetersPerSecond = 4;
    double highSpeedBoundaryInMetersPerSecond = 25;
    SpeedLimitOffset speedLimitOffset = new SpeedLimitOffset(
      lowSpeedOffsetInMetersPerSecond,
      highSpeedOffsetInMetersPerSecond,
      highSpeedBoundaryInMetersPerSecond,
    );

    _visualNavigator.speedWarningOptions =
        SpeedWarningOptions(speedLimitOffset);
  }

  void setupVoiceTextMessages() {
    LanguageCode languageCode = LanguageCode.enUs;
    List<LanguageCode> supportedVoiceSkins =
        VisualNavigator.getAvailableLanguagesForManeuverNotifications();
    if (supportedVoiceSkins.contains(languageCode)) {
      _visualNavigator.maneuverNotificationOptions =
          ManeuverNotificationOptions(languageCode, UnitSystem.metric);
    } else {
      print('Warning: Requested voice skin is not supported.');
    }
  }
}
