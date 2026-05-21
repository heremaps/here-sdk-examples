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

import 'package:here_sdk/navigation.dart';
import 'package:here_sdk/routing.dart';
import 'package:here_sdk/warner.dart';

/// This class shows how to use the unified WarnerEngine to receive all navigation warnings
/// through a single [WarningListener], instead of setting individual per-type listeners on the
/// [VisualNavigator]. The WarnerEngine is obtained from the [VisualNavigator] and provides a
/// centralized way to configure warning options, set notification distances, and handle all
/// warning events.
///
/// For comparison, see the NavigationWarnersExample class which uses per-type listeners directly.
///
/// Note: This is a beta release of this feature, so there could be a few bugs and unexpected
/// behaviors. Related APIs may change for new releases without a deprecation process.
class WarnerEngineExample {
  late WarnerEngine _warnerEngine;
  late WarningsRegistry _warningsRegistry;
  bool _isSetUp = false;

  /// Sets up the WarnerEngine obtained from the given [VisualNavigator].
  /// The WarnerEngine provides a unified approach to handle navigation warnings:
  /// Instead of registering individual listeners for each warning type on the VisualNavigator,
  /// you register a single [WarningListener] on the WarnerEngine and use the [WarningsRegistry]
  /// to look up detailed warning information by the Warning's id and type.
  void setupWarnerEngine(VisualNavigator visualNavigator) {
    // Get the WarnerEngine from the VisualNavigator.
    // The engine is already pre-configured and internally connected to the navigator.
    _warnerEngine = visualNavigator.warnerEngine;

    // The WarningsRegistry stores detailed warning metadata for each warning type.
    // Use it to look up full warning details (e.g., SafetyCameraWarning, TruckRestrictionWarning)
    // from the generic Warning object received in the WarningListener.
    _warningsRegistry = _warnerEngine.getWarningsRegistry();

    // Configure all warning options in one place.
    _configureWarningOptions();

    // Configure notification distances for specific warning types.
    _configureNotificationDistances();

    // Required: setEnabledWarnings() must be called to receive any warnings at all.
    // Without this call, no warnings will be delivered to the WarningListener.
    // Pass the list of WarningType values you want to receive.
    _configureEnabledWarnings();

    // Register a single WarningListener to receive all warning events.
    _warnerEngine.addWarningListener(WarningListener((List<Warning> warnings) {
      // Each Warning in the list contains a warningType, distanceType, and a unique id.
      // Use the WarningsRegistry to look up the detailed typed warning object.
      for (Warning warning in warnings) {
        _handleWarning(warning);
      }
    }));

    _isSetUp = true;
    print("WarnerEngine setup complete. Listening for unified warning events.");
  }

  /// Configures all warning options through the WarnerEngine's [WarningOptions].
  /// This replaces the individual set...Options() calls on the VisualNavigator.
  void _configureWarningOptions() {
    // Get the current warning options from the WarnerEngine.
    WarningOptions warningOptions = _warnerEngine.warningOptions;

    // Configure safety camera warning options.
    SafetyCameraWarningOptions safetyCameraWarningOptions = SafetyCameraWarningOptions();
    // Enable text notifications for safety camera warnings, that can be used with TTS engines.
    safetyCameraWarningOptions.enableTextNotification = true;
    warningOptions.safetyCameraWarningOptions = safetyCameraWarningOptions;

    // Configure road sign warning options.
    RoadSignWarningOptions roadSignWarningOptions = RoadSignWarningOptions();
    // Set a filter to get only road signs relevant for TRUCKS and HEAVY_TRUCKS.
    roadSignWarningOptions.vehicleTypesFilter = [RoadSignVehicleType.trucks, RoadSignVehicleType.heavyTrucks];
    warningOptions.roadSignWarningOptions = roadSignWarningOptions;

    // Configure school zone warning options.
    SchoolZoneWarningOptions schoolZoneWarningOptions = SchoolZoneWarningOptions();
    schoolZoneWarningOptions.filterOutInactiveTimeDependentWarnings = true;
    schoolZoneWarningOptions.warningDistanceInMeters = 150;
    warningOptions.schoolZoneWarningOptions = schoolZoneWarningOptions;

    // Configure border crossing warning options.
    BorderCrossingWarningOptions borderCrossingWarningOptions = BorderCrossingWarningOptions();
    // If set to true, all the state border crossing notifications will not be given.
    borderCrossingWarningOptions.filterOutStateBorderWarnings = true;
    warningOptions.borderCrossingWarningOptions = borderCrossingWarningOptions;

    // Configure realistic view warning options.
    RealisticViewWarningOptions realisticViewWarningOptions = RealisticViewWarningOptions();
    realisticViewWarningOptions.aspectRatio = AspectRatio.aspectRatio3X4;
    realisticViewWarningOptions.darkTheme = false;
    warningOptions.realisticViewWarningOptions = realisticViewWarningOptions;

    // Apply all warning options at once.
    _warnerEngine.warningOptions = warningOptions;
  }

  /// Configures notification distances for specific warning types through the WarnerEngine.
  /// This replaces the individual setWarningNotificationDistances() calls on the VisualNavigator.
  void _configureNotificationDistances() {
    // Configure custom notification distances for road sign warnings.
    WarningNotificationDistances roadSignDistances =
        _warnerEngine.getWarningNotificationDistances(WarningType.roadSign);
    // The distance in meters for emitting warnings when the speed limit or current speed is fast. Defaults to 1500.
    roadSignDistances.fastSpeedDistanceInMeters = 1600;
    // The distance in meters for emitting warnings when the speed limit or current speed is regular. Defaults to 750.
    roadSignDistances.regularSpeedDistanceInMeters = 800;
    // The distance in meters for emitting warnings when the speed limit or current speed is slow. Defaults to 500.
    roadSignDistances.slowSpeedDistanceInMeters = 600;
    _warnerEngine.setWarningNotificationDistances(WarningType.roadSign, roadSignDistances);
  }

  /// Required: setEnabledWarnings() must be called to receive any warnings at all.
  /// Without this call, no warnings will be delivered, regardless of a registered [WarningListener].
  /// Only the warning types in the list below will be delivered. Remove a type to suppress it.
  void _configureEnabledWarnings() {
    List<WarningType> enabledWarnings = [
      WarningType.safetyCamera,
      WarningType.truckRestriction,
      WarningType.roadSign,
      WarningType.schoolZone,
      WarningType.realisticView,
      WarningType.borderCrossing,
      WarningType.dangerZone,
      WarningType.railwayCrossing,
      WarningType.lowSpeedZone,
      WarningType.trafficMerge,
      WarningType.tollStop,
      WarningType.laneDecrease
    ];
    _warnerEngine.setEnabledWarnings(enabledWarnings);
  }

  /// Dispatches each [Warning] to the appropriate handler based on its warningType.
  /// The Warning object is generic and carries only an id, distanceType, and warningType.
  /// Use the [WarningsRegistry] to retrieve the full typed warning with all details.
  void _handleWarning(Warning warning) {
    switch (warning.warningType) {
      case WarningType.safetyCamera:
        _handleSafetyCameraWarning(warning);
        break;
      case WarningType.truckRestriction:
        _handleTruckRestrictionWarning(warning);
        break;
      case WarningType.roadSign:
        _handleRoadSignWarning(warning);
        break;
      case WarningType.schoolZone:
        _handleSchoolZoneWarning(warning);
        break;
      case WarningType.borderCrossing:
        _handleBorderCrossingWarning(warning);
        break;
      case WarningType.dangerZone:
        _handleDangerZoneWarning(warning);
        break;
      case WarningType.lowSpeedZone:
        _handleLowSpeedZoneWarning(warning);
        break;
      case WarningType.realisticView:
        _handleRealisticViewWarning(warning);
        break;
      case WarningType.tollStop:
        _handleTollStopWarning(warning);
        break;
      case WarningType.trafficMerge:
        _handleTrafficMergeWarning(warning);
        break;
      default:
        print("Unhandled warning type: ${warning.warningType}, distance type: ${warning.distanceType}");
        break;
    }
  }

  /// Handles safety camera warnings.
  /// Safety cameras include speed cameras, red light cameras, and similar monitoring installations.
  void _handleSafetyCameraWarning(Warning warning) {
    SafetyCameraWarning? safetyCameraWarning = _warningsRegistry.getSafetyCameraWarning(warning);
    if (safetyCameraWarning == null) {
      print("SafetyCameraWarning: No detailed data available.");
      return;
    }

    if (warning.distanceType == DistanceType.ahead) {
      print("SafetyCameraWarning ${safetyCameraWarning.type.name} ahead in: "
          "${safetyCameraWarning.distanceToCameraInMeters} meters"
          ", speed limit = ${safetyCameraWarning.speedLimitInMetersPerSecond} m/s.");
    } else if (warning.distanceType == DistanceType.passed) {
      print("SafetyCameraWarning ${safetyCameraWarning.type.name} passed.");
    } else if (warning.distanceType == DistanceType.reached) {
      print("SafetyCameraWarning ${safetyCameraWarning.type.name} reached.");
    }
  }

  /// Handles truck restriction warnings.
  /// These alert truck drivers to upcoming road restrictions such as bridges with limited height
  /// or roads with weight limits that may prevent passage.
  void _handleTruckRestrictionWarning(Warning warning) {
    TruckRestrictionWarning? truckRestrictionWarning = _warningsRegistry.getTruckRestrictionWarning(warning);
    if (truckRestrictionWarning == null) {
      print("TruckRestrictionWarning: No detailed data available.");
      return;
    }

    if (warning.distanceType == DistanceType.ahead) {
      print("TruckRestrictionWarning ahead in: ${truckRestrictionWarning.distanceInMeters} meters.");
      if (truckRestrictionWarning.timeRule != null && !truckRestrictionWarning.timeRule!.appliesTo(DateTime.now())) {
        print("Note that this truck restriction warning currently does not apply.");
      }
    } else if (warning.distanceType == DistanceType.reached) {
      print("A truck restriction has been reached.");
    } else if (warning.distanceType == DistanceType.passed) {
      print("A truck restriction just passed.");
    }

    if (truckRestrictionWarning.weightRestriction != null) {
      var type = truckRestrictionWarning.weightRestriction!.type;
      var value = truckRestrictionWarning.weightRestriction!.valueInKilograms;
      print("TruckRestriction for weight (kg): ${type.name}: $value");
    } else if (truckRestrictionWarning.dimensionRestriction != null) {
      var type = truckRestrictionWarning.dimensionRestriction!.type;
      var value = truckRestrictionWarning.dimensionRestriction!.valueInCentimeters;
      print("TruckRestriction for dimension: ${type.name}: $value");
    } else {
      print("TruckRestriction: General restriction - no trucks allowed.");
    }
  }

  /// Handles road sign warnings.
  /// Notifies on road signs as they appear along the road, such as stop signs.
  void _handleRoadSignWarning(Warning warning) {
    RoadSignWarning? roadSignWarning = _warningsRegistry.getRoadSignWarning(warning);
    if (roadSignWarning == null) {
      print("RoadSignWarning: No detailed data available.");
      return;
    }

    if (warning.distanceType == DistanceType.ahead) {
      print("RoadSignWarning of type: ${roadSignWarning.type.name} ahead in (m): ${roadSignWarning.distanceToRoadSignInMeters}");
    } else if (warning.distanceType == DistanceType.passed) {
      print("RoadSignWarning of type: ${roadSignWarning.type.name} just passed.");
    }

    if (roadSignWarning.signValue != null) {
      print("Road sign text: ${roadSignWarning.signValue!.text}");
    }
  }

  /// Handles school zone warnings.
  /// School zones indicate areas near schools where speed limits are lower.
  void _handleSchoolZoneWarning(Warning warning) {
    SchoolZoneWarning? schoolZoneWarning = _warningsRegistry.getSchoolZoneWarning(warning);
    if (schoolZoneWarning == null) {
      print("SchoolZoneWarning: No detailed data available.");
      return;
    }

    if (warning.distanceType == DistanceType.ahead) {
      print("SchoolZoneWarning ahead in: ${schoolZoneWarning.distanceToSchoolZoneInMeters} meters.");
      print("Speed limit for this school zone: ${schoolZoneWarning.speedLimitInMetersPerSecond} m/s.");
      if (schoolZoneWarning.timeRule != null && !schoolZoneWarning.timeRule!.appliesTo(DateTime.now())) {
        print("Note that this school zone warning currently does not apply.");
      }
    } else if (warning.distanceType == DistanceType.reached) {
      print("A school zone has been reached.");
    } else if (warning.distanceType == DistanceType.passed) {
      print("A school zone has been passed.");
    }
  }

  /// Handles border crossing warnings.
  /// Notifies when country or state borders are approached, along with general speed limits
  /// that apply in the destination country or state.
  void _handleBorderCrossingWarning(Warning warning) {
    BorderCrossingWarning? borderCrossingWarning = _warningsRegistry.getBorderCrossingWarning(warning);
    if (borderCrossingWarning == null) {
      print("BorderCrossingWarning: No detailed data available.");
      return;
    }

    if (warning.distanceType == DistanceType.ahead) {
      print("BorderCrossing ahead in: ${borderCrossingWarning.distanceToBorderCrossingInMeters} meters.");
      print("BorderCrossing type: ${borderCrossingWarning.type.name}");
      print("BorderCrossing country code: ${borderCrossingWarning.administrativeRules.countryCode.name}");

      if (borderCrossingWarning.administrativeRules.stateCode != null) {
        print("BorderCrossing state code: ${borderCrossingWarning.administrativeRules.stateCode}");
      }

      var speedLimits = borderCrossingWarning.administrativeRules.speedLimits;
      print("BorderCrossing: Speed limit in cities (m/s): ${speedLimits.maxSpeedUrbanInMetersPerSecond}");
      print("BorderCrossing: Speed limit outside cities (m/s): ${speedLimits.maxSpeedRuralInMetersPerSecond}");
      print("BorderCrossing: Speed limit on highways (m/s): ${speedLimits.maxSpeedHighwaysInMetersPerSecond}");
    } else if (warning.distanceType == DistanceType.passed) {
      print("A border crossing has been passed.");
    }
  }

  /// Handles danger zone warnings.
  /// Danger zones refer to areas where there is an increased risk of traffic incidents.
  /// Note that danger zones are only available in selected countries, such as France.
  void _handleDangerZoneWarning(Warning warning) {
    DangerZoneWarning? dangerZoneWarning = _warningsRegistry.getDangerZoneWarning(warning);
    if (dangerZoneWarning == null) {
      print("DangerZoneWarning: No detailed data available.");
      return;
    }

    if (warning.distanceType == DistanceType.ahead) {
      print("DangerZone ahead in: ${dangerZoneWarning.distanceInMeters} meters.");
      print("isZoneStart: ${dangerZoneWarning.isZoneStart}");
    } else if (warning.distanceType == DistanceType.reached) {
      print("A danger zone has been reached. isZoneStart: ${dangerZoneWarning.isZoneStart}");
    } else if (warning.distanceType == DistanceType.passed) {
      print("A danger zone has been passed.");
    }
  }

  /// Handles low speed zone warnings.
  /// Low speed zones indicate areas where the speed limit is particularly low.
  void _handleLowSpeedZoneWarning(Warning warning) {
    LowSpeedZoneWarning? lowSpeedZoneWarning = _warningsRegistry.getLowSpeedZoneWarning(warning);
    if (lowSpeedZoneWarning == null) {
      print("LowSpeedZoneWarning: No detailed data available.");
      return;
    }

    if (warning.distanceType == DistanceType.ahead) {
      print("LowSpeedZone ahead in: ${lowSpeedZoneWarning.distanceToLowSpeedZoneInMeters} meters.");
      print("Speed limit in low speed zone (m/s): ${lowSpeedZoneWarning.speedLimitInMetersPerSecond}");
    } else if (warning.distanceType == DistanceType.reached) {
      print("A low speed zone has been reached.");
      print("Speed limit in low speed zone (m/s): ${lowSpeedZoneWarning.speedLimitInMetersPerSecond}");
    } else if (warning.distanceType == DistanceType.passed) {
      print("A low speed zone has been passed.");
    }
  }

  /// Handles realistic view warnings.
  /// Realistic views provide 3D junction views and signpost images as SVG data to help
  /// the driver orientate at complex junctions.
  void _handleRealisticViewWarning(Warning warning) {
    RealisticViewWarning? realisticViewWarning = _warningsRegistry.getRealisticViewWarning(warning);
    if (realisticViewWarning == null) {
      print("RealisticViewWarning: No detailed data available.");
      return;
    }

    double distance = realisticViewWarning.distanceToRealisticViewInMeters;

    if (warning.distanceType == DistanceType.ahead) {
      print("RealisticView ahead in: $distance meters.");
    } else if (warning.distanceType == DistanceType.passed) {
      print("A RealisticView just passed.");
    }

    RealisticViewVectorImage? realisticView = realisticViewWarning.realisticViewVectorImage;
    if (realisticView == null) {
      print("No SVG data delivered for this RealisticView.");
      return;
    }

    // The resolution-independent SVG data can be used to visualize the junction.
    // Both SVGs contain the same dimensions. The signpost should be shown on top of
    // the junction view.
    print("signpostSvgImage: available");
    print("junctionViewSvgImage: available");
  }

  /// Handles toll stop warnings.
  /// Notifies on upcoming toll stops including lane details and supported payment methods.
  void _handleTollStopWarning(Warning warning) {
    TollStop? tollStop = _warningsRegistry.getTollStopWarning(warning);
    if (tollStop == null) {
      print("TollStopWarning: No detailed data available.");
      return;
    }

    for (int laneNumber = 0; laneNumber < tollStop.lanes.length; laneNumber++) {
      TollBoothLane tollBoothLane = tollStop.lanes[laneNumber];
      TollBooth tollBooth = tollBoothLane.booth;
      for (TollCollectionMethod collectionMethod in tollBooth.tollCollectionMethods) {
        print("TollStop lane $laneNumber supports collection via: ${collectionMethod.name}");
      }
      for (PaymentMethod paymentMethod in tollBooth.paymentMethods) {
        print("TollStop lane $laneNumber supports payment via: ${paymentMethod.name}");
      }
    }
  }

  /// Handles traffic merge warnings.
  /// Notifies about merging traffic from side roads or ramps to the current road.
  void _handleTrafficMergeWarning(Warning warning) {
    TrafficMergeWarning? trafficMergeWarning = _warningsRegistry.getTrafficMergeWarning(warning);
    if (trafficMergeWarning == null) {
      print("TrafficMergeWarning: No detailed data available.");
      return;
    }

    if (warning.distanceType == DistanceType.ahead) {
      print("TrafficMerge: ${trafficMergeWarning.roadType.name} ahead in: "
          "${trafficMergeWarning.distanceToTrafficMergeInMeters} meters"
          ", merging from the ${trafficMergeWarning.side.name} side"
          ", with lanes = ${trafficMergeWarning.laneCount}");
    } else if (warning.distanceType == DistanceType.passed) {
      print("TrafficMerge: ${trafficMergeWarning.roadType.name} passed.");
    }
  }

  /// Stops the WarnerEngine and cleans up.
  /// Call this method when guidance is stopped. It finalizes all active warnings by marking
  /// them as PASSED and notifies the WarningListener before clearing the internal state.
  void stopWarnerEngine() {
    if (!_isSetUp) return;
    _warnerEngine.finalizeGivenWarnings();
    print("WarnerEngine finalized. All active warnings marked as passed.");
  }
}
