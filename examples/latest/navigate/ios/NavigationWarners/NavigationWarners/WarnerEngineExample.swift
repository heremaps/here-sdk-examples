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

import heresdk
import Foundation

// This class shows how to use the unified WarnerEngine to receive all navigation warnings
// through a single WarningDelegate, instead of setting individual per-type delegates on the
// VisualNavigator. The WarnerEngine is obtained from the VisualNavigator and provides a centralized
// way to configure warning options, set notification distances, and handle all warning events.
//
// For comparison, see the NavigationWarners class which uses per-type delegates directly.
//
// Note: This is a beta release of this feature, so there could be a few bugs and unexpected
// behaviors. Related APIs may change for new releases without a deprecation process.
class WarnerEngineExample: WarningDelegate {

    private var warnerEngine: WarnerEngine!
    private var warningsRegistry: WarningsRegistry!

    // Sets up the WarnerEngine obtained from the given VisualNavigator.
    // The WarnerEngine provides a unified approach to handle navigation warnings:
    // Instead of registering individual delegates for each warning type on the VisualNavigator,
    // you register a single WarningDelegate on the WarnerEngine and use the WarningsRegistry
    // to look up detailed warning information by the Warning's id and type.
    func setupWarnerEngine(_ visualNavigator: VisualNavigator) {
        // Get the WarnerEngine from the VisualNavigator.
        // The engine is already pre-configured and internally connected to the navigator.
        warnerEngine = visualNavigator.warnerEngine

        // The WarningsRegistry stores detailed warning metadata for each warning type.
        // Use it to look up full warning details (e.g., SafetyCameraWarning, TruckRestrictionWarning)
        // from the generic Warning object received in the WarningDelegate.
        warningsRegistry = warnerEngine.getWarningsRegistry()

        // Configure all warning options in one place.
        configureWarningOptions()

        // Configure notification distances for specific warning types.
        configureNotificationDistances()

        // Required: setEnabledWarnings() must be called to receive any warnings at all.
        // Without this call, no warnings will be delivered to the WarningDelegate.
        // Pass the list of WarningType values you want to receive.
        configureEnabledWarnings()

        // Register a single WarningDelegate to receive all warning events.
        warnerEngine.addWarningDelegate(_: self)

        print("WarnerEngine setup complete. Listening for unified warning events.")
    }

    // Conform to WarningDelegate.
    // Called whenever the WarnerEngine detects new warnings.
    func onWarnings(warnings: [Warning]) {
        // Each Warning in the list contains a warningType, distanceType, and a unique id.
        // Use the WarningsRegistry to look up the detailed typed warning object.
        for warning in warnings {
            handleWarning(warning)
        }
    }

    // Configures all warning options through the WarnerEngine's WarningOptions.
    // This replaces the individual set...Options() calls on the VisualNavigator.
    private func configureWarningOptions() {
        // Get the current warning options from the WarnerEngine.
        var warningOptions = warnerEngine.warningOptions

        // Configure safety camera warning options.
        var safetyCameraWarningOptions = SafetyCameraWarningOptions()
        // Enable text notifications for safety camera warnings, that can be used with TTS engines.
        safetyCameraWarningOptions.enableTextNotification = true
        warningOptions.safetyCameraWarningOptions = safetyCameraWarningOptions

        // Configure road sign warning options.
        var roadSignWarningOptions = RoadSignWarningOptions()
        // Set a filter to get only road signs relevant for TRUCKS and HEAVY_TRUCKS.
        roadSignWarningOptions.vehicleTypesFilter = [.trucks, .heavyTrucks]
        warningOptions.roadSignWarningOptions = roadSignWarningOptions

        // Configure school zone warning options.
        var schoolZoneWarningOptions = SchoolZoneWarningOptions()
        schoolZoneWarningOptions.filterOutInactiveTimeDependentWarnings = true
        schoolZoneWarningOptions.warningDistanceInMeters = 150
        warningOptions.schoolZoneWarningOptions = schoolZoneWarningOptions

        // Configure border crossing warning options.
        var borderCrossingWarningOptions = BorderCrossingWarningOptions()
        // If set to true, all the state border crossing notifications will not be given.
        borderCrossingWarningOptions.filterOutStateBorderWarnings = true
        warningOptions.borderCrossingWarningOptions = borderCrossingWarningOptions

        // Configure realistic view warning options.
        var realisticViewWarningOptions = RealisticViewWarningOptions()
        realisticViewWarningOptions.aspectRatio = .aspectRatio3X4
        realisticViewWarningOptions.darkTheme = false
        warningOptions.realisticViewWarningOptions = realisticViewWarningOptions

        // Apply all warning options at once.
        warnerEngine.warningOptions = warningOptions
    }

    // Configures notification distances for specific warning types through the WarnerEngine.
    // This replaces the individual setWarningNotificationDistances() calls on the VisualNavigator.
    private func configureNotificationDistances() {
        // Configure custom notification distances for road sign warnings.
        var roadSignDistances = warnerEngine.getWarningNotificationDistances(warningType: .roadSign)
        // The distance in meters for emitting warnings when the speed limit or current speed is fast. Defaults to 1500.
        roadSignDistances.fastSpeedDistanceInMeters = 1600
        // The distance in meters for emitting warnings when the speed limit or current speed is regular. Defaults to 750.
        roadSignDistances.regularSpeedDistanceInMeters = 800
        // The distance in meters for emitting warnings when the speed limit or current speed is slow. Defaults to 500.
        roadSignDistances.slowSpeedDistanceInMeters = 600
        _ = warnerEngine.setWarningNotificationDistances(warningType: .roadSign, warningNotificationDistances: roadSignDistances)
    }

    // Required: setEnabledWarnings() must be called to receive any warnings at all.
    // Without this call, no warnings will be delivered, regardless of a registered WarningDelegate.
    // Only the warning types in the list below will be delivered. Remove a type to suppress it.
    private func configureEnabledWarnings() {
        let enabledWarnings: [WarningType] = [
            .safetyCamera,
            .truckRestriction,
            .roadSign,
            .schoolZone,
            .realisticView,
            .borderCrossing,
            .dangerZone,
            .railwayCrossing,
            .lowSpeedZone,
            .trafficMerge,
            .tollStop,
            .laneDecrease
        ]
        warnerEngine.setEnabledWarnings(warningTypes: enabledWarnings)
    }

    // Dispatches each Warning to the appropriate handler based on its warningType.
    // The Warning object is generic and carries only an id, distanceType, and warningType.
    // Use the WarningsRegistry to retrieve the full typed warning with all details.
    private func handleWarning(_ warning: Warning) {
        switch warning.warningType {
        case .safetyCamera:
            handleSafetyCameraWarning(warning)
        case .truckRestriction:
            handleTruckRestrictionWarning(warning)
        case .roadSign:
            handleRoadSignWarning(warning)
        case .schoolZone:
            handleSchoolZoneWarning(warning)
        case .borderCrossing:
            handleBorderCrossingWarning(warning)
        case .dangerZone:
            handleDangerZoneWarning(warning)
        case .lowSpeedZone:
            handleLowSpeedZoneWarning(warning)
        case .realisticView:
            handleRealisticViewWarning(warning)
        case .tollStop:
            handleTollStopWarning(warning)
        case .trafficMerge:
            handleTrafficMergeWarning(warning)
        default:
            print("Unhandled warning type: \(warning.warningType), distance type: \(warning.distanceType)")
        }
    }

    // Handles safety camera warnings.
    // Safety cameras include speed cameras, red light cameras, and similar monitoring installations.
    private func handleSafetyCameraWarning(_ warning: Warning) {
        guard let safetyCameraWarning = warningsRegistry.getSafetyCameraWarning(warning: warning) else {
            print("SafetyCameraWarning: No detailed data available.")
            return
        }

        switch warning.distanceType {
        case .ahead:
            print("SafetyCameraWarning \(safetyCameraWarning.type) ahead in: " +
                  "\(safetyCameraWarning.distanceToCameraInMeters) meters" +
                  ", speed limit = \(safetyCameraWarning.speedLimitInMetersPerSecond) m/s.")
        case .passed:
            print("SafetyCameraWarning \(safetyCameraWarning.type) passed.")
        case .reached:
            print("SafetyCameraWarning \(safetyCameraWarning.type) reached.")
        }
    }

    // Handles truck restriction warnings.
    // These alert truck drivers to upcoming road restrictions such as bridges with limited height
    // or roads with weight limits that may prevent passage.
    private func handleTruckRestrictionWarning(_ warning: Warning) {
        guard let truckRestrictionWarning = warningsRegistry.getTruckRestrictionWarning(warning: warning) else {
            print("TruckRestrictionWarning: No detailed data available.")
            return
        }

        switch warning.distanceType {
        case .ahead:
            print("TruckRestrictionWarning ahead in: \(truckRestrictionWarning.distanceInMeters) meters.")
            if let timeRule = truckRestrictionWarning.timeRule, !timeRule.appliesTo(dateTime: Date()) {
                print("Note that this truck restriction warning currently does not apply.")
            }
        case .reached:
            print("A truck restriction has been reached.")
        case .passed:
            print("A truck restriction just passed.")
        }

        if let weightRestriction = truckRestrictionWarning.weightRestriction {
            print("TruckRestriction for weight (kg): \(weightRestriction.type): \(weightRestriction.valueInKilograms)")
        } else if let dimensionRestriction = truckRestrictionWarning.dimensionRestriction {
            print("TruckRestriction for dimension: \(dimensionRestriction.type): \(dimensionRestriction.valueInCentimeters)")
        } else {
            print("TruckRestriction: General restriction - no trucks allowed.")
        }
    }

    // Handles road sign warnings.
    // Notifies on road signs as they appear along the road, such as stop signs.
    private func handleRoadSignWarning(_ warning: Warning) {
        guard let roadSignWarning = warningsRegistry.getRoadSignWarning(warning: warning) else {
            print("RoadSignWarning: No detailed data available.")
            return
        }

        switch warning.distanceType {
        case .ahead:
            print("RoadSignWarning of type: \(roadSignWarning.type) ahead in (m): \(roadSignWarning.distanceToRoadSignInMeters)")
        case .passed:
            print("RoadSignWarning of type: \(roadSignWarning.type) just passed.")
        default:
            break
        }

        if let signValue = roadSignWarning.signValue {
            print("Road sign text: \(signValue.text)")
        }
    }

    // Handles school zone warnings.
    // School zones indicate areas near schools where speed limits are lower.
    private func handleSchoolZoneWarning(_ warning: Warning) {
        guard let schoolZoneWarning = warningsRegistry.getSchoolZoneWarning(warning: warning) else {
            print("SchoolZoneWarning: No detailed data available.")
            return
        }

        switch warning.distanceType {
        case .ahead:
            print("SchoolZoneWarning ahead in: \(schoolZoneWarning.distanceToSchoolZoneInMeters) meters.")
            print("Speed limit for this school zone: \(schoolZoneWarning.speedLimitInMetersPerSecond) m/s.")
            if let timeRule = schoolZoneWarning.timeRule, !timeRule.appliesTo(dateTime: Date()) {
                print("Note that this school zone warning currently does not apply.")
            }
        case .reached:
            print("A school zone has been reached.")
        case .passed:
            print("A school zone has been passed.")
        }
    }

    // Handles border crossing warnings.
    // Notifies when country or state borders are approached, along with general speed limits
    // that apply in the destination country or state.
    private func handleBorderCrossingWarning(_ warning: Warning) {
        guard let borderCrossingWarning = warningsRegistry.getBorderCrossingWarning(warning: warning) else {
            print("BorderCrossingWarning: No detailed data available.")
            return
        }

        switch warning.distanceType {
        case .ahead:
            print("BorderCrossing ahead in: \(borderCrossingWarning.distanceToBorderCrossingInMeters) meters.")
            print("BorderCrossing type: \(borderCrossingWarning.type)")
            print("BorderCrossing country code: \(borderCrossingWarning.administrativeRules.countryCode)")

            if let stateCode = borderCrossingWarning.administrativeRules.stateCode {
                print("BorderCrossing state code: \(stateCode)")
            }

            let speedLimits = borderCrossingWarning.administrativeRules.speedLimits
            print("BorderCrossing: Speed limit in cities (m/s): \(speedLimits.maxSpeedUrbanInMetersPerSecond)")
            print("BorderCrossing: Speed limit outside cities (m/s): \(speedLimits.maxSpeedRuralInMetersPerSecond)")
            print("BorderCrossing: Speed limit on highways (m/s): \(speedLimits.maxSpeedHighwaysInMetersPerSecond)")
        case .passed:
            print("A border crossing has been passed.")
        default:
            break
        }
    }

    // Handles danger zone warnings.
    // Danger zones refer to areas where there is an increased risk of traffic incidents.
    // Note that danger zones are only available in selected countries, such as France.
    private func handleDangerZoneWarning(_ warning: Warning) {
        guard let dangerZoneWarning = warningsRegistry.getDangerZoneWarning(warning: warning) else {
            print("DangerZoneWarning: No detailed data available.")
            return
        }

        switch warning.distanceType {
        case .ahead:
            print("DangerZone ahead in: \(dangerZoneWarning.distanceInMeters) meters.")
            print("isZoneStart: \(dangerZoneWarning.isZoneStart)")
        case .reached:
            print("A danger zone has been reached. isZoneStart: \(dangerZoneWarning.isZoneStart)")
        case .passed:
            print("A danger zone has been passed.")
        }
    }

    // Handles low speed zone warnings.
    // Low speed zones indicate areas where the speed limit is particularly low.
    private func handleLowSpeedZoneWarning(_ warning: Warning) {
        guard let lowSpeedZoneWarning = warningsRegistry.getLowSpeedZoneWarning(warning: warning) else {
            print("LowSpeedZoneWarning: No detailed data available.")
            return
        }

        switch warning.distanceType {
        case .ahead:
            print("LowSpeedZone ahead in: \(lowSpeedZoneWarning.distanceToLowSpeedZoneInMeters) meters.")
            print("Speed limit in low speed zone (m/s): \(lowSpeedZoneWarning.speedLimitInMetersPerSecond)")
        case .reached:
            print("A low speed zone has been reached.")
            print("Speed limit in low speed zone (m/s): \(lowSpeedZoneWarning.speedLimitInMetersPerSecond)")
        case .passed:
            print("A low speed zone has been passed.")
        }
    }

    // Handles realistic view warnings.
    // Realistic views provide 3D junction views and signpost images as SVG data to help
    // the driver orientate at complex junctions.
    private func handleRealisticViewWarning(_ warning: Warning) {
        guard let realisticViewWarning = warningsRegistry.getRealisticViewWarning(warning: warning) else {
            print("RealisticViewWarning: No detailed data available.")
            return
        }

        let distance = realisticViewWarning.distanceToRealisticViewInMeters

        switch warning.distanceType {
        case .ahead:
            print("RealisticView ahead in: \(distance) meters.")
        case .passed:
            print("A RealisticView just passed.")
        default:
            break
        }

        guard let realisticView = realisticViewWarning.realisticViewVectorImage else {
            print("No SVG data delivered for this RealisticView.")
            return
        }

        // The resolution-independent SVG data can be used to visualize the junction.
        // Both SVGs contain the same dimensions. The signpost should be shown on top of
        // the junction view.
        print("signpostSvgImage: available")
        print("junctionViewSvgImage: available")
    }

    // Handles toll stop warnings.
    // Notifies on upcoming toll stops including lane details and supported payment methods.
    private func handleTollStopWarning(_ warning: Warning) {
        guard let tollStop = warningsRegistry.getTollStopWarning(warning: warning) else {
            print("TollStopWarning: No detailed data available.")
            return
        }

        for (laneNumber, tollBoothLane) in tollStop.lanes.enumerated() {
            let tollBooth = tollBoothLane.booth
            for collectionMethod in tollBooth.tollCollectionMethods {
                print("TollStop lane \(laneNumber) supports collection via: \(collectionMethod)")
            }
            for paymentMethod in tollBooth.paymentMethods {
                print("TollStop lane \(laneNumber) supports payment via: \(paymentMethod)")
            }
        }
    }

    // Handles traffic merge warnings.
    // Notifies about merging traffic from side roads or ramps to the current road.
    private func handleTrafficMergeWarning(_ warning: Warning) {
        guard let trafficMergeWarning = warningsRegistry.getTrafficMergeWarning(warning: warning) else {
            print("TrafficMergeWarning: No detailed data available.")
            return
        }

        switch warning.distanceType {
        case .ahead:
            print("TrafficMerge: \(trafficMergeWarning.roadType) ahead in: " +
                  "\(trafficMergeWarning.distanceToTrafficMergeInMeters) meters" +
                  ", merging from the \(trafficMergeWarning.side) side" +
                  ", with lanes = \(trafficMergeWarning.laneCount)")
        case .passed:
            print("TrafficMerge: \(trafficMergeWarning.roadType) passed.")
        default:
            break
        }
    }

    // Stops the WarnerEngine and cleans up.
    // Call this method when guidance is stopped. It finalizes all active warnings by marking
    // them as PASSED and notifies the WarningDelegate before clearing the internal state.
    func stopWarnerEngine() {
        warnerEngine?.finalizeGivenWarnings()
        print("WarnerEngine finalized. All active warnings marked as passed.")
    }
}
