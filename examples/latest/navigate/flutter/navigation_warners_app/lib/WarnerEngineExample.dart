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
import 'package:here_sdk/mapdata.dart';
import 'package:here_sdk/routing.dart';
import 'package:here_sdk/warner.dart';
import 'SpeedBumpWarningProvider.dart';

/// This class shows how to use the unified WarnerEngine to receive all navigation warnings
/// through a single [WarningListener]. The WarnerEngine is obtained from the [VisualNavigator]
/// and provides a centralized way to configure warning options, set notification distances,
/// and handle all warning events.
class WarnerEngineExample {
  late WarnerEngine _warnerEngine;
  bool _isSetUp = false;
  final _speedBumpWarningProvider = SpeedBumpWarningProvider();

  /// Sets up the WarnerEngine obtained from the given [VisualNavigator].
  /// The WarnerEngine provides a unified approach to handle navigation warnings:
  /// Instead of registering individual listeners for each warning type on the VisualNavigator,
  /// you register a single [WarningListener] on the WarnerEngine and use the [WarningsRegistry]
  /// to look up detailed warning information by the Warning's id and type.
  void setupWarnerEngine(VisualNavigator visualNavigator) {
    // Get the WarnerEngine from the VisualNavigator.
    // The engine is already pre-configured and internally connected to the navigator.
    _warnerEngine = visualNavigator.warnerEngine;

    // Configure all warning options in one place.
    _configureWarningOptions();

    // Configure notification distances for specific warning types.
    _configureNotificationDistances();

    // Register custom warning providers before enabling warnings.
    _registerCustomProvider();

    // Required: setEnabledWarnings() must be called to receive any warnings at all.
    // Without this call, no warnings will be delivered to the WarningListener.
    // Pass the list of WarningType values you want to receive.
    _configureEnabledWarnings();

    // Register a single WarningListener to receive all warning events.
    _warnerEngine.addWarningListener(WarningListener((List<WarningUpdate> warnings, WarningsRegistry warningsRegistry) {
      // Each WarningUpdate contains a warning (with warningType and id), a warningStatus, and optional distances.
      // Use the WarningsRegistry to look up the detailed typed warning object.
      for (WarningUpdate warningUpdate in warnings) {
        _handleWarning(warningUpdate, warningsRegistry);
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

  /// Registers custom warning providers with the WarnerEngine before enabling warnings.
  void _registerCustomProvider() {
    SegmentDataLoaderOptions segmentDataLoaderOptions = SegmentDataLoaderOptions();
    // Load per-segment "special speed situations" so the provider can detect speed bumps.
    segmentDataLoaderOptions.loadSpecialSpeedSituations = true;
    _warnerEngine.addCustomWarningProvider(
        CustomWarningProvider(
          () => _speedBumpWarningProvider.getCustomWarningType(),
          (SegmentData currentSegment, SegmentData? previousSegment) =>
              _speedBumpWarningProvider.getWarnings(currentSegment, previousSegment),
        ),
        segmentDataLoaderOptions);

    // Configure notification distances for custom speed bump warnings.
    // These determine how far ahead (in meters) the AHEAD warning fires, based on current speed.
    WarningNotificationDistances customDistances = _warnerEngine
        .getCustomWarningNotificationDistances(SpeedBumpWarningProvider.speedBumpWarningId);
    customDistances.slowSpeedDistanceInMeters = 500;
    customDistances.regularSpeedDistanceInMeters = 750;
    customDistances.fastSpeedDistanceInMeters = 1500;
    _warnerEngine.setCustomWarningNotificationDistances(
        SpeedBumpWarningProvider.speedBumpWarningId, customDistances);
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
      WarningType.laneDecrease,
      WarningType.custom
    ];
    _warnerEngine.setEnabledWarnings(enabledWarnings);
  }

  /// Dispatches each [WarningUpdate] to the appropriate handler based on its warningType.
  /// The WarningUpdate carries the Warning (with id and warningType) and the warningStatus.
  /// Use the [WarningsRegistry] to retrieve the full typed warning with all details.
  void _handleWarning(WarningUpdate warningUpdate, WarningsRegistry warningsRegistry) {
    switch (warningUpdate.warning.warningType) {
      case WarningType.safetyCamera:
        _handleSafetyCameraWarning(warningUpdate, warningsRegistry);
        break;
      case WarningType.truckRestriction:
        _handleTruckRestrictionWarning(warningUpdate, warningsRegistry);
        break;
      case WarningType.roadSign:
        _handleRoadSignWarning(warningUpdate, warningsRegistry);
        break;
      case WarningType.schoolZone:
        _handleSchoolZoneWarning(warningUpdate, warningsRegistry);
        break;
      case WarningType.borderCrossing:
        _handleBorderCrossingWarning(warningUpdate, warningsRegistry);
        break;
      case WarningType.dangerZone:
        _handleDangerZoneWarning(warningUpdate, warningsRegistry);
        break;
      case WarningType.lowSpeedZone:
        _handleLowSpeedZoneWarning(warningUpdate, warningsRegistry);
        break;
      case WarningType.realisticView:
        _handleRealisticViewWarning(warningUpdate, warningsRegistry);
        break;
      case WarningType.tollStop:
        _handleTollStopWarning(warningUpdate, warningsRegistry);
        break;
      case WarningType.trafficMerge:
        _handleTrafficMergeWarning(warningUpdate, warningsRegistry);
        break;
      case WarningType.custom:
        _handleCustomWarning(warningUpdate, warningsRegistry);
        break;
      default:
        print("Unhandled warning type: ${warningUpdate.warning.warningType}, warning status: ${warningUpdate.warningStatus}");
        break;
    }
  }

  /// Handles safety camera warnings.
  /// Safety cameras include speed cameras, red light cameras, and similar monitoring installations.
  void _handleSafetyCameraWarning(WarningUpdate warningUpdate, WarningsRegistry warningsRegistry) {
    SafetyCameraWarning? safetyCameraWarning = warningsRegistry.getSafetyCameraWarning(warningUpdate.warning);
    if (safetyCameraWarning == null) {
      print("SafetyCameraWarning: No detailed data available.");
      return;
    }

    if (warningUpdate.warningStatus == WarningStatus.ahead) {
      // The start indicates the SafetyCamera spot.
      print("SafetyCameraWarning ${safetyCameraWarning.type.name} ahead in: "
          "${warningUpdate.distanceTillStartInMeters} meters"
          ", speed limit = ${safetyCameraWarning.speedLimitInMetersPerSecond} m/s.");
    } else if (warningUpdate.warningStatus == WarningStatus.passed) {
      print("SafetyCameraWarning ${safetyCameraWarning.type.name} passed.");
    } else if (warningUpdate.warningStatus == WarningStatus.reached) {
      print("SafetyCameraWarning ${safetyCameraWarning.type.name} reached.");
    }
  }

  /// Handles truck restriction warnings.
  /// These alert truck drivers to upcoming road restrictions such as bridges with limited height
  /// or roads with weight limits that may prevent passage.
  /// This event notifies on truck restrictions in general,
  /// so it will also deliver events when the transport type was set to a non-truck transport type.
  /// The given restrictions are based on the HERE database of the road network ahead.
  void _handleTruckRestrictionWarning(WarningUpdate warningUpdate, WarningsRegistry warningsRegistry) {
    TruckRestrictionWarning? truckRestrictionWarning = warningsRegistry.getTruckRestrictionWarning(warningUpdate.warning);
    if (truckRestrictionWarning == null) {
      print("TruckRestrictionWarning: No detailed data available.");
      return;
    }

    if (warningUpdate.warningStatus == WarningStatus.ahead) {
      // The start indicates where the truck restriction becomes effective.
      print("TruckRestrictionWarning ahead in: ${warningUpdate.distanceTillStartInMeters} meters.");
      if (truckRestrictionWarning.timeRule != null && !truckRestrictionWarning.timeRule!.appliesTo(DateTime.now())) {
        print("Note that this truck restriction warning currently does not apply.");
      }
    } else if (warningUpdate.warningStatus == WarningStatus.reached) {
      print("A truck restriction has been reached.");
    } else if (warningUpdate.warningStatus == WarningStatus.passed) {
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
  void _handleRoadSignWarning(WarningUpdate warningUpdate, WarningsRegistry warningsRegistry) {
    RoadSignWarning? roadSignWarning = warningsRegistry.getRoadSignWarning(warningUpdate.warning);
    if (roadSignWarning == null) {
      print("RoadSignWarning: No detailed data available.");
      return;
    }

    if (warningUpdate.warningStatus == WarningStatus.ahead) {
      // The start indicates the RoadSign spot.
      print("RoadSignWarning of type: ${roadSignWarning.type.name} ahead in (m): ${warningUpdate.distanceTillStartInMeters}");
    } else if (warningUpdate.warningStatus == WarningStatus.passed) {
      print("RoadSignWarning of type: ${roadSignWarning.type.name} just passed.");
    }

    if (roadSignWarning.signValue != null) {
      print("Road sign text: ${roadSignWarning.signValue!.text}");
    }
  }

  /// Handles school zone warnings.
  /// School zones indicate areas near schools where speed limits are lower.
  void _handleSchoolZoneWarning(WarningUpdate warningUpdate, WarningsRegistry warningsRegistry) {
    SchoolZoneWarning? schoolZoneWarning = warningsRegistry.getSchoolZoneWarning(warningUpdate.warning);
    if (schoolZoneWarning == null) {
      print("SchoolZoneWarning: No detailed data available.");
      return;
    }

    if (warningUpdate.warningStatus == WarningStatus.ahead) {
      // The start indicates where the school zone begins.
      print("SchoolZoneWarning ahead in: ${warningUpdate.distanceTillStartInMeters} meters.");
      print("Speed limit for this school zone: ${schoolZoneWarning.speedLimitInMetersPerSecond} m/s.");
      if (schoolZoneWarning.timeRule != null && !schoolZoneWarning.timeRule!.appliesTo(DateTime.now())) {
        print("Note that this school zone warning currently does not apply.");
      }
    } else if (warningUpdate.warningStatus == WarningStatus.reached) {
      print("A school zone has been reached.");
    } else if (warningUpdate.warningStatus == WarningStatus.passed) {
      print("A school zone has been passed.");
    }
  }

  /// Handles border crossing warnings.
  /// Notifies when country or state borders are approached, along with general speed limits
  /// that apply in the destination country or state.
  void _handleBorderCrossingWarning(WarningUpdate warningUpdate, WarningsRegistry warningsRegistry) {
    BorderCrossingWarning? borderCrossingWarning = warningsRegistry.getBorderCrossingWarning(warningUpdate.warning);
    if (borderCrossingWarning == null) {
      print("BorderCrossingWarning: No detailed data available.");
      return;
    }

    if (warningUpdate.warningStatus == WarningStatus.ahead) {
      // The start indicates the border crossing spot.
      print("BorderCrossing ahead in: ${warningUpdate.distanceTillStartInMeters} meters.");
      print("BorderCrossing type: ${borderCrossingWarning.type.name}");
      print("BorderCrossing country code: ${borderCrossingWarning.administrativeRules.countryCode.name}");

      if (borderCrossingWarning.administrativeRules.stateCode != null) {
        print("BorderCrossing state code: ${borderCrossingWarning.administrativeRules.stateCode}");
      }

      var speedLimits = borderCrossingWarning.administrativeRules.speedLimits;
      print("BorderCrossing: Speed limit in cities (m/s): ${speedLimits.maxSpeedUrbanInMetersPerSecond}");
      print("BorderCrossing: Speed limit outside cities (m/s): ${speedLimits.maxSpeedRuralInMetersPerSecond}");
      print("BorderCrossing: Speed limit on highways (m/s): ${speedLimits.maxSpeedHighwaysInMetersPerSecond}");
    } else if (warningUpdate.warningStatus == WarningStatus.passed) {
      print("A border crossing has been passed.");
    }
  }

  /// Handles danger zone warnings.
  /// Danger zones refer to areas where there is an increased risk of traffic incidents.
  /// Note that danger zones are only available in selected countries, such as France.
  void _handleDangerZoneWarning(WarningUpdate warningUpdate, WarningsRegistry warningsRegistry) {
    DangerZoneWarning? dangerZoneWarning = warningsRegistry.getDangerZoneWarning(warningUpdate.warning);
    if (dangerZoneWarning == null) {
      print("DangerZoneWarning: No detailed data available.");
      return;
    }

    if (warningUpdate.warningStatus == WarningStatus.ahead) {
      // The start indicates where the danger zone begins.
      print("DangerZone ahead in: ${warningUpdate.distanceTillStartInMeters} meters.");
      print("isZoneStart: ${dangerZoneWarning.isZoneStart}");
    } else if (warningUpdate.warningStatus == WarningStatus.reached) {
      print("A danger zone has been reached. isZoneStart: ${dangerZoneWarning.isZoneStart}");
    } else if (warningUpdate.warningStatus == WarningStatus.passed) {
      print("A danger zone has been passed.");
    }
  }

  /// Handles low speed zone warnings.
  /// Low speed zones indicate areas where the speed limit is particularly low.
  void _handleLowSpeedZoneWarning(WarningUpdate warningUpdate, WarningsRegistry warningsRegistry) {
    LowSpeedZoneWarning? lowSpeedZoneWarning = warningsRegistry.getLowSpeedZoneWarning(warningUpdate.warning);
    if (lowSpeedZoneWarning == null) {
      print("LowSpeedZoneWarning: No detailed data available.");
      return;
    }

    if (warningUpdate.warningStatus == WarningStatus.ahead) {
      // The start indicates where the low speed zone begins.
      print("LowSpeedZone ahead in: ${warningUpdate.distanceTillStartInMeters} meters.");
      print("Speed limit in low speed zone (m/s): ${lowSpeedZoneWarning.speedLimitInMetersPerSecond}");
    } else if (warningUpdate.warningStatus == WarningStatus.reached) {
      print("A low speed zone has been reached.");
      print("Speed limit in low speed zone (m/s): ${lowSpeedZoneWarning.speedLimitInMetersPerSecond}");
    } else if (warningUpdate.warningStatus == WarningStatus.passed) {
      print("A low speed zone has been passed.");
    }
  }

  /// Handles realistic view warnings.
  /// Realistic views provide 3D junction views and signpost images as SVG data to help
  /// the driver orientate at complex junctions.
  void _handleRealisticViewWarning(WarningUpdate warningUpdate, WarningsRegistry warningsRegistry) {
    RealisticViewWarning? realisticViewWarning = warningsRegistry.getRealisticViewWarning(warningUpdate.warning);
    if (realisticViewWarning == null) {
      print("RealisticViewWarning: No detailed data available.");
      return;
    }

    // The start indicates the RealisticView spot.
    double distance = warningUpdate.distanceTillStartInMeters ?? 0.0;

    if (warningUpdate.warningStatus == WarningStatus.ahead) {
      print("RealisticView ahead in: $distance meters.");
    } else if (warningUpdate.warningStatus == WarningStatus.passed) {
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
  void _handleTollStopWarning(WarningUpdate warningUpdate, WarningsRegistry warningsRegistry) {
    TollStop? tollStop = warningsRegistry.getTollStopWarning(warningUpdate.warning);
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
  void _handleTrafficMergeWarning(WarningUpdate warningUpdate, WarningsRegistry warningsRegistry) {
    TrafficMergeWarning? trafficMergeWarning = warningsRegistry.getTrafficMergeWarning(warningUpdate.warning);
    if (trafficMergeWarning == null) {
      print("TrafficMergeWarning: No detailed data available.");
      return;
    }

    if (warningUpdate.warningStatus == WarningStatus.ahead) {
      // The start indicates the traffic merge spot.
      print("TrafficMerge: ${trafficMergeWarning.roadType.name} ahead in: "
          "${warningUpdate.distanceTillStartInMeters} meters"
          ", merging from the ${trafficMergeWarning.side.name} side"
          ", with lanes = ${trafficMergeWarning.laneCount}");
    } else if (warningUpdate.warningStatus == WarningStatus.passed) {
      print("TrafficMerge: ${trafficMergeWarning.roadType.name} passed.");
    }
  }

  /// Handles custom warnings delivered by the WarnerEngine.
  /// Decode the CustomWarning from the WarningsRegistry and check its customWarningType.
  void _handleCustomWarning(WarningUpdate warningUpdate, WarningsRegistry warningsRegistry) {
    CustomWarning? customWarning = warningsRegistry.getCustomWarning(warningUpdate.warning);
    if (customWarning == null) {
      print("CustomWarning: No detailed data available.");
      return;
    }
    if (customWarning.customWarningType == SpeedBumpWarningProvider.speedBumpWarningId) {
      String? segRef = _speedBumpWarningProvider.getSegmentReference(customWarning);
      // The WarnerEngine provides warningStatus (ahead/passed) based on startOffsetInMeters.
      String status = warningUpdate.warningStatus == WarningStatus.ahead ? "ahead" : "passed";
      print("Speed bump $status. segmentRef=$segRef");
    } else {
      print("Unsupported custom warning type: ${customWarning.customWarningType}");
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
