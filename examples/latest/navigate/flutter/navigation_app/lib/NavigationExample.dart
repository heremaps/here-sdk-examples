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

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/location.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/navigation.dart';
import 'package:here_sdk/routing.dart' as HERE;

import 'HEREPositioningProvider.dart';
import 'HEREPositioningSimulator.dart';
import 'LanguageCodeConverter.dart';

// Shows how to start and stop turn-by-turn navigation along a route.
class NavigationExample {
  HereMapController _hereMapController;
  VisualNavigator _visualNavigator;
  HEREPositioningSimulator _locationSimulationProvider;
  HEREPositioningProvider _herePositioningProvider;
  int _previousManeuverIndex = -1;

  NavigationExample(HereMapController hereMapController) {
    _hereMapController = hereMapController;

    try {
      _visualNavigator = VisualNavigator();
    } on InstantiationException {
      throw Exception("Initialization of VisualNavigator failed.");
    }

    // This enables a navigation view including a rendered navigation arrow.
    _visualNavigator.startRendering(_hereMapController);

    // For easy testing, this location provider simulates location events along a route.
    // You can use HERE positioning to feed real locations, see the "Positioning"-section in
    // our Developer's Guide for an example.
    _locationSimulationProvider = HEREPositioningSimulator();

    // Access the device's GPS sensor and other data.
    _herePositioningProvider = HEREPositioningProvider();
    _herePositioningProvider.startLocating(_visualNavigator, LocationAccuracy.navigation);

    setupListeners();
  }

  Location getLastKnownLocation() {
    return _herePositioningProvider.getLastKnownLocation();
  }

  void startNavigationSimulation(HERE.Route route) {
    _prepareNavigation(route);

    // Stop in case it was started before.
    _herePositioningProvider.stop();

    // Simulates location events based on the given route.
    // The navigator is set as listener to receive location updates.
    _locationSimulationProvider.startLocating(route, _visualNavigator);
  }

  void startNavigation(HERE.Route route) {
    _prepareNavigation(route);

    // Stop in case it was started before.
    _locationSimulationProvider.stop();

    // Access the device's GPS sensor and other data.
    // The navigator is set as listener to receive location updates.
    _herePositioningProvider.startLocating(_visualNavigator, LocationAccuracy.navigation);
  }

  void _prepareNavigation(HERE.Route route) {
    setupSpeedWarnings();
    setupVoiceTextMessages();

    // Set the route to follow.
    _visualNavigator.route = route;
  }

  void setTracking(bool isTracking) {
    if (isTracking) {
      _visualNavigator.cameraMode = CameraTrackingMode.enabled;
    } else {
      _visualNavigator.cameraMode = CameraTrackingMode.disabled;
    }
  }

  // Starts tracking the device's location using HERE Positioning.
  void stopNavigation() {
    // Stop in case it was started before.
    _locationSimulationProvider.stop();

    // Leaves navigation and enables tracking mode. The camera may optionally follow, see toggleTracking().
    _visualNavigator.route = null;
    _herePositioningProvider.startLocating(_visualNavigator, LocationAccuracy.navigation);

    // Optionally, you can stop rendering, ie. to remove the current location marker.
    //_visualNavigator.stopRendering();
  }

  void stopRendering() {
    // It is recommended to stop rendering before leaving the app.
    _visualNavigator.stopRendering();
  }

  void setupListeners() {
    // Notifies on the progress along the route including maneuver instructions.
    // These maneuver instructions can be used to compose a visual representation of the next maneuver actions.
    _visualNavigator.routeProgressListener =
        RouteProgressListener.fromLambdas(lambda_onRouteProgressUpdated: (RouteProgress routeProgress) {
      List<SectionProgress> sectionProgressList = routeProgress.sectionProgress;
      // sectionProgressList is guaranteed to be non-empty.
      SectionProgress lastSectionProgress = sectionProgressList.elementAt(sectionProgressList.length - 1);
      print('Distance to destination in meters: ' + lastSectionProgress.remainingDistanceInMeters.toString());
      print('Traffic delay ahead in seconds: ' + lastSectionProgress.trafficDelayInSeconds.toString());

      // Contains the progress for the next maneuver ahead and the next-next maneuvers, if any.
      List<ManeuverProgress> nextManeuverList = routeProgress.maneuverProgress;

      ManeuverProgress nextManeuverProgress = nextManeuverList.first;
      if (nextManeuverProgress == null) {
        print('No next maneuver available.');
        return;
      }

      int nextManeuverIndex = nextManeuverProgress.maneuverIndex;
      HERE.Maneuver nextManeuver = _visualNavigator.getManeuver(nextManeuverIndex);
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

    // Notifies on the current map-matched location and other useful information while driving or walking.
    // The map-matched location is used to update the map view.
    _visualNavigator.navigableLocationListener = NavigableLocationListener.fromLambdas(
        lambda_onNavigableLocationUpdated: (NavigableLocation currentNavigableLocation) {
      MapMatchedLocation mapMatchedLocation = currentNavigableLocation.mapMatchedLocation;
      if (mapMatchedLocation == null) {
        print('This new location could not be map-matched. Are you off-road?');
        return;
      }

      var speed = currentNavigableLocation.originalLocation.speedInMetersPerSecond;
      var accuracy = currentNavigableLocation.originalLocation.speedAccuracyInMetersPerSecond;
      print("Driving speed (m/s): $speed plus/minus an accuracy of: $accuracy");
    });

    // Notifies when the destination of the route is reached.
    _visualNavigator.destinationReachedListener =
        DestinationReachedListener.fromLambdas(lambda_onDestinationReached: () {
      print('Destination reached. Stopping turn-by-turn navigation.');
      stopNavigation();
    });

    // Notifies when a waypoint on the route is reached.
    _visualNavigator.milestoneReachedListener =
        MilestoneReachedListener.fromLambdas(lambda_onMilestoneReached: (Milestone milestone) {
      if (milestone.waypointIndex != null) {
        print('A user-defined waypoint was reached, index of waypoint: ' + milestone.waypointIndex.toString());
        print('Original coordinates: ' + milestone.originalCoordinates.toString());
      } else {
        // For example, when transport mode changes due to a ferry.
        print('A system defined waypoint was reached at ' + milestone.mapMatchedCoordinates.toString());
      }
    });

    // Notifies on the current speed limit valid on the current road.
    _visualNavigator.speedLimitListener =
        SpeedLimitListener.fromLambdas(lambda_onSpeedLimitUpdated: (SpeedLimit speedLimit) {
      double currentSpeedLimit = _getCurrentSpeedLimit(speedLimit);

      if (currentSpeedLimit == null) {
        print("Warning: Speed limits unkown, data could not be retrieved.");
      } else if (currentSpeedLimit == 0) {
        print("No speed limits on this road! Drive as fast as you feel safe ...");
      } else {
        print("Current speed limit (m/s): $currentSpeedLimit");
      }
    });

    // Notifies when the current speed limit is exceeded.
    _visualNavigator.speedWarningListener =
        SpeedWarningListener.fromLambdas(lambda_onSpeedWarningStatusChanged: (SpeedWarningStatus speedWarningStatus) {
      if (speedWarningStatus == SpeedWarningStatus.speedLimitExceeded) {
        // Driver is faster than current speed limit (plus an optional offset, see setupSpeedWarnings()).
        // Play a click sound to indicate this to the driver.
        // As Flutter itself does not provide support for sounds,
        // alternatively use a 3rd party plugin to play an alert sound of your choice.
        // Note that this may not include temporary special speed limits, see SpeedLimitDelegate.
        SystemSound.play(SystemSoundType.click);
        print('Speed limit exceeded.');
      }

      if (speedWarningStatus == SpeedWarningStatus.speedLimitRestored) {
        print('Driver is again slower than current speed limit (plus an optional offset.)');
      }
    });

    // Notifies on a possible deviation from the route.
    // When deviation is too large, an app may decide to recalculate the route from current location to destination.
    _visualNavigator.routeDeviationListener =
        RouteDeviationListener.fromLambdas(lambda_onRouteDeviation: (RouteDeviation routeDeviation) {
      HERE.Route route = _visualNavigator.route;
      if (route == null) {
        // May happen in rare cases when route was set to null inbetween.
        return;
      }

      // Get current geographic coordinates.
      MapMatchedLocation currentMapMatchedLocation = routeDeviation.currentLocation.mapMatchedLocation;
      GeoCoordinates currentGeoCoordinates = currentMapMatchedLocation == null
          ? routeDeviation.currentLocation.originalLocation.coordinates
          : currentMapMatchedLocation.coordinates;

      // Get last geographic coordinates on route.
      GeoCoordinates lastGeoCoordinatesOnRoute;
      if (routeDeviation.lastLocationOnRoute != null) {
        MapMatchedLocation lastMapMatchedLocationOnRoute = routeDeviation.lastLocationOnRoute.mapMatchedLocation;
        lastGeoCoordinatesOnRoute = lastMapMatchedLocationOnRoute == null
            ? routeDeviation.lastLocationOnRoute.originalLocation.coordinates
            : lastMapMatchedLocationOnRoute.coordinates;
      } else {
        print('User was never following the route. So, we take the start of the route instead.');
        lastGeoCoordinatesOnRoute = route.sections.first.departurePlace.originalCoordinates;
      }

      int distanceInMeters = currentGeoCoordinates.distanceTo(lastGeoCoordinatesOnRoute) as int;
      print('RouteDeviation in meters is ' + distanceInMeters.toString());
    });

    // Notifies on voice maneuver messages.
    _visualNavigator.maneuverNotificationListener =
        ManeuverNotificationListener.fromLambdas(lambda_onManeuverNotification: (String voiceText) {
      // Flutter itself does not provide a text-to-speech engine. Use one of the available TTS plugins to speak
      // the voiceText message.
      print('Voice guidance text: $voiceText');
    });
  }

  void setupSpeedWarnings() {
    double lowSpeedOffsetInMetersPerSecond = 2;
    double highSpeedOffsetInMetersPerSecond = 4;
    double highSpeedBoundaryInMetersPerSecond = 25;
    SpeedLimitOffset speedLimitOffset = SpeedLimitOffset(
      lowSpeedOffsetInMetersPerSecond,
      highSpeedOffsetInMetersPerSecond,
      highSpeedBoundaryInMetersPerSecond,
    );

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

  double _getCurrentSpeedLimit(SpeedLimit speedLimit) {
    // If available, it is recommended to show this value as speed limit to the user.
    // Note that the SpeedWarningStatus only warns when speedLimit.speedLimitInMetersPerSecond is exceeded.
    double specialSpeedLimit = getSpecialSpeedLimit(speedLimit.specialSpeedSituations);
    if (specialSpeedLimit != null) {
      return specialSpeedLimit;
    }

    // If no special speed limit is available, show the standard speed limit.
    return speedLimit.speedLimitInMetersPerSecond;
  }

  // An example implementation that will retrieve the slowest speed limit, including advisory speed limits and
  // weather-dependent speed limits that may or may not be valid due to the actual weather condition while driving.
  double getSpecialSpeedLimit(List<SpecialSpeedSituation> specialSpeedSituations) {
    double specialSpeedLimit;

    // Iterates through the list of applicable special speed limits, if available.
    for (SpecialSpeedSituation specialSpeedSituation in specialSpeedSituations) {
      // Check if a time restriction is available and if it is currently active.
      bool timeRestrictionisPresent = false;
      bool timeRestrictionisActive = false;
      for (TimeDomain timeDomain in specialSpeedSituation.appliesDuring) {
        timeRestrictionisPresent = true;
        if (timeDomain.isActive(DateTime.now())) {
          timeRestrictionisActive = true;
        }
      }

      if (timeRestrictionisPresent && !timeRestrictionisActive) {
        // We are not interested in currently inactive special speed limits.
        continue;
      }

      if (specialSpeedSituation.type == SpecialSpeedSituationType.advisorySpeed) {
        print("Contains an advisory speed limit. For safety reasons it is recommended to respect it.");
      }

      if (specialSpeedSituation.type == SpecialSpeedSituationType.rain ||
          specialSpeedSituation.type == SpecialSpeedSituationType.snow ||
          specialSpeedSituation.type == SpecialSpeedSituationType.fog) {
        // The HERE SDK cannot detect the current weather condition, so a driver must decide
        // based on the situation if this speed limit applies.
        // Note: For this example we respect weather related speed limits, even if not applicable
        // due to the current weather condition.
        print("Attention: This road has weather dependent speed limits!");
      }

      double newSpecialSpeedLimit = specialSpeedSituation.specialSpeedLimitInMetersPerSecond;
      print("Found special speed limit: $newSpecialSpeedLimit" + " m/s, type: $specialSpeedSituation.type");

      if (specialSpeedLimit != null && specialSpeedLimit > newSpecialSpeedLimit) {
        // For this example, we are only interested in the slowest special speed limit value,
        // regardless if it is legal, advisory or bound to conditions that may require the decision
        // of the driver.
        specialSpeedLimit = newSpecialSpeedLimit;
      }
    }

    print("Slowest special speed limit (m/s): $specialSpeedLimit");
    return specialSpeedLimit;
  }
}
