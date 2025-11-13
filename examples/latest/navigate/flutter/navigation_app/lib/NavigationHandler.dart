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
import 'package:here_sdk/routing.dart';
import 'package:here_sdk/routing.dart' as HERE;
import 'package:here_sdk/trafficawarenavigation.dart';
import 'package:navigation_app/RouteCalculator.dart';
import 'package:navigation_app/time_utils.dart';

import 'ElectronicHorizonHandler.dart';
import 'LanguageCodeConverter.dart';

// This class combines the various events that can be emitted during turn-by-turn navigation.
// Note that this class does not show an exhaustive list of all possible events.
class NavigationHandler {
  VisualNavigator _visualNavigator;
  DynamicRoutingEngine _dynamicRoutingEngine;
  ElectronicHorizonHandler _electronicHorizonHandler;
  MapMatchedLocation? _lastMapMatchedLocation;
  int _previousManeuverIndex = -1;
  int lastTrafficUpdateInMilliseconds = 0;
  final ValueChanged<String> _updateMessageState;
  RouteCalculator _routeCalculator;
  final _timeUtils = TimeUtils();

  NavigationHandler(
    VisualNavigator visualNavigator,
    DynamicRoutingEngine dynamicRoutingEngine,
    ElectronicHorizonHandler electronicHorizonHandler,
    ValueChanged<String> updateMessageState,
    RouteCalculator routeCalculator,
  ) : _visualNavigator = visualNavigator,
      _dynamicRoutingEngine = dynamicRoutingEngine,
      _electronicHorizonHandler = electronicHorizonHandler,
      _updateMessageState = updateMessageState,
      _routeCalculator = routeCalculator {}

  void setupListeners() {
    _setupVoiceTextMessages();

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
      String logMessage =
          action.name +
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

        // Update the ElectronicHorizon with the last map-matched location.
        _electronicHorizonHandler.update(_lastMapMatchedLocation!);
      }

      updateTrafficOnRoute(routeProgress);
    });

    // Notifies on the current map-matched location and other useful information while driving or walking.
    // The map-matched location is used to update the map view.
    _visualNavigator.navigableLocationListener = NavigableLocationListener((
      NavigableLocation currentNavigableLocation,
    ) {
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

  void _setupVoiceTextMessages() {
    LanguageCode ttsLanguageCode = getLanguageCodeForDevice(
      VisualNavigator.getAvailableLanguagesForManeuverNotifications(),
    );
    ManeuverNotificationOptions maneuverNotificationOptions = ManeuverNotificationOptions.withDefaults();
    // Set the language in which the notifications will be generated.
    maneuverNotificationOptions.language = ttsLanguageCode;
    // Set the measurement system used for distances.
    maneuverNotificationOptions.unitSystem = UnitSystem.metric;
    _visualNavigator.maneuverNotificationOptions = maneuverNotificationOptions;
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
