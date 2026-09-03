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
// through a single WarningDelegate. The WarnerEngine is obtained from the VisualNavigator and
// provides a centralized way to configure warning options, set notification distances, and
// handle all warning events.
class WarnerEngineExample: WarningDelegate {

    private var warnerEngine: WarnerEngine!
    private let speedBumpWarningProvider = SpeedBumpWarningProvider()

    // Sets up the WarnerEngine obtained from the given VisualNavigator.
    // The WarnerEngine provides a unified approach to handle navigation warnings:
    // Instead of registering individual delegates for each warning type on the VisualNavigator,
    // you register a single WarningDelegate on the WarnerEngine and use the WarningsRegistry
    // to look up detailed warning information by the Warning's id and type.
    func setupWarnerEngine(_ visualNavigator: VisualNavigator) {
        // Get the WarnerEngine from the VisualNavigator.
        // The engine is already pre-configured and internally connected to the navigator.
        warnerEngine = visualNavigator.warnerEngine

        // Configure all warning options in one place.
        configureWarningOptions()

        // Configure notification distances for specific warning types.
        configureNotificationDistances()

        // Register custom warning providers before enabling warnings.
        registerCustomProvider()

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
    func onWarnings(warnings: [WarningUpdate], warningsRegistry: WarningsRegistry) {
        // Each WarningUpdate contains a warning (with warningType and id), a warningStatus, and optional distances.
        // Use the WarningsRegistry to look up the detailed typed warning object.
        for warningUpdate in warnings {
            handleWarning(warningUpdate, warningsRegistry: warningsRegistry)
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
    private func configureNotificationDistances() {
        // Configure custom notification distances for road sign warnings.
        var roadSignDistances = warnerEngine.getWarningNotificationDistances(warningType: .roadSign)
        // The distance in meters for emitting warnings when the speed limit or current speed is fast. Defaults to 1500.
        roadSignDistances.fastSpeedDistanceInMeters = 1600
        // The distance in meters for emitting warnings when the speed limit or current speed is regular. Defaults to 750.
        roadSignDistances.regularSpeedDistanceInMeters = 800
        // The distance in meters for emitting warnings when the speed limit or current speed is slow. Defaults to 500.
        roadSignDistances.slowSpeedDistanceInMeters = 600
        warnerEngine.setWarningNotificationDistances(warningType: .roadSign, warningNotificationDistances: roadSignDistances)
    }

    // Registers custom warning providers with the WarnerEngine before enabling warnings.
    private func registerCustomProvider() {
        var segmentDataLoaderOptions = SegmentDataLoaderOptions()
        // Load per-segment "special speed situations" so the provider can detect speed bumps.
        segmentDataLoaderOptions.loadSpecialSpeedSituations = true
        warnerEngine.addCustomWarningProvider(customWarningProvider: speedBumpWarningProvider,
                                              segmentDataLoaderOptions: segmentDataLoaderOptions)

        // Configure notification distances for custom speed bump warnings.
        // These determine how far ahead (in meters) the AHEAD warning fires, based on current speed.
        var customDistances = warnerEngine.getCustomWarningNotificationDistances(
            customWarningType: SpeedBumpWarningProvider.speedBumpWarningID)
        customDistances.slowSpeedDistanceInMeters = 500
        customDistances.regularSpeedDistanceInMeters = 750
        customDistances.fastSpeedDistanceInMeters = 1500
        warnerEngine.setCustomWarningNotificationDistances(
            customWarningType: SpeedBumpWarningProvider.speedBumpWarningID,
            warningNotificationDistances: customDistances)
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
            .laneDecrease,
            .custom
        ]
        warnerEngine.setEnabledWarnings(warningTypes: enabledWarnings)
    }

    // Dispatches each WarningUpdate to the appropriate handler based on its warningType.
    // The WarningUpdate carries the Warning (with id and warningType) and the warningStatus.
    // Use the WarningsRegistry to retrieve the full typed warning with all details.
    private func handleWarning(_ warningUpdate: WarningUpdate, warningsRegistry: WarningsRegistry) {
        switch warningUpdate.warning.warningType {
        case .safetyCamera:
            handleSafetyCameraWarning(warningUpdate, warningsRegistry: warningsRegistry)
        case .truckRestriction:
            handleTruckRestrictionWarning(warningUpdate, warningsRegistry: warningsRegistry)
        case .roadSign:
            handleRoadSignWarning(warningUpdate, warningsRegistry: warningsRegistry)
        case .schoolZone:
            handleSchoolZoneWarning(warningUpdate, warningsRegistry: warningsRegistry)
        case .borderCrossing:
            handleBorderCrossingWarning(warningUpdate, warningsRegistry: warningsRegistry)
        case .dangerZone:
            handleDangerZoneWarning(warningUpdate, warningsRegistry: warningsRegistry)
        case .lowSpeedZone:
            handleLowSpeedZoneWarning(warningUpdate, warningsRegistry: warningsRegistry)
        case .realisticView:
            handleRealisticViewWarning(warningUpdate, warningsRegistry: warningsRegistry)
        case .tollStop:
            handleTollStopWarning(warningUpdate, warningsRegistry: warningsRegistry)
        case .trafficMerge:
            handleTrafficMergeWarning(warningUpdate, warningsRegistry: warningsRegistry)
        case .custom:
            handleCustomWarning(warningUpdate, warningsRegistry: warningsRegistry)
        default:
            print("Unhandled warning type: \(warningUpdate.warning.warningType), warning status: \(warningUpdate.warningStatus)")
        }
    }

    // Handles safety camera warnings.
    // Safety cameras include speed cameras, red light cameras, and similar monitoring installations.
    private func handleSafetyCameraWarning(_ warningUpdate: WarningUpdate, warningsRegistry: WarningsRegistry) {
        guard let safetyCameraWarning = warningsRegistry.getSafetyCameraWarning(warning: warningUpdate.warning) else {
            print("SafetyCameraWarning: No detailed data available.")
            return
        }

        switch warningUpdate.warningStatus {
        case .ahead:
            // The start indicates the SafetyCamera spot.
            print("SafetyCameraWarning \(safetyCameraWarning.type) ahead in: " +
                  "\(warningUpdate.distanceTillStartInMeters) meters" +
                  ", speed limit = \(safetyCameraWarning.speedLimitInMetersPerSecond) m/s.")
        case .passed:
            print("SafetyCameraWarning \(safetyCameraWarning.type) passed.")
        case .reached:
            print("SafetyCameraWarning \(safetyCameraWarning.type) reached.")
        default:
            break
        }
    }

    // Handles truck restriction warnings.
    // These alert truck drivers to upcoming road restrictions such as bridges with limited height
    // or roads with weight limits that may prevent passage.
    // This event notifies on truck restrictions in general,
    // so it will also deliver events when the transport type was set to a non-truck transport type.
    // The given restrictions are based on the HERE database of the road network ahead.
    private func handleTruckRestrictionWarning(_ warningUpdate: WarningUpdate, warningsRegistry: WarningsRegistry) {
        guard let truckRestrictionWarning = warningsRegistry.getTruckRestrictionWarning(warning: warningUpdate.warning) else {
            print("TruckRestrictionWarning: No detailed data available.")
            return
        }

        switch warningUpdate.warningStatus {
        case .ahead:
            // The start indicates where the truck restriction becomes effective.
            print("TruckRestrictionWarning ahead in: \(warningUpdate.distanceTillStartInMeters) meters.")
            if let timeRule = truckRestrictionWarning.timeRule, !timeRule.appliesTo(dateTime: Date()) {
                print("Note that this truck restriction warning currently does not apply.")
            }
        case .reached:
            print("A truck restriction has been reached.")
        case .passed:
            print("A truck restriction just passed.")
        default:
            break
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
    private func handleRoadSignWarning(_ warningUpdate: WarningUpdate, warningsRegistry: WarningsRegistry) {
        guard let roadSignWarning = warningsRegistry.getRoadSignWarning(warning: warningUpdate.warning) else {
            print("RoadSignWarning: No detailed data available.")
            return
        }

        switch warningUpdate.warningStatus {
        case .ahead:
            // The start indicates the RoadSign spot.
            print("RoadSignWarning of type: \(roadSignWarning.type) ahead in (m): \(warningUpdate.distanceTillStartInMeters)")
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
    private func handleSchoolZoneWarning(_ warningUpdate: WarningUpdate, warningsRegistry: WarningsRegistry) {
        guard let schoolZoneWarning = warningsRegistry.getSchoolZoneWarning(warning: warningUpdate.warning) else {
            print("SchoolZoneWarning: No detailed data available.")
            return
        }

        switch warningUpdate.warningStatus {
        case .ahead:
            // The start indicates where the school zone begins.
            print("SchoolZoneWarning ahead in: \(warningUpdate.distanceTillStartInMeters) meters.")
            print("Speed limit for this school zone: \(schoolZoneWarning.speedLimitInMetersPerSecond) m/s.")
            if let timeRule = schoolZoneWarning.timeRule, !timeRule.appliesTo(dateTime: Date()) {
                print("Note that this school zone warning currently does not apply.")
            }
        case .reached:
            print("A school zone has been reached.")
        case .passed:
            print("A school zone has been passed.")
        default:
            break
        }
    }
    // Notifies when country or state borders are approached, along with general speed limits
    // that apply in the destination country or state.
    private func handleBorderCrossingWarning(_ warningUpdate: WarningUpdate, warningsRegistry: WarningsRegistry) {
        guard let borderCrossingWarning = warningsRegistry.getBorderCrossingWarning(warning: warningUpdate.warning) else {
            print("BorderCrossingWarning: No detailed data available.")
            return
        }

        switch warningUpdate.warningStatus {
        case .ahead:
            // The start indicates the border crossing spot.
            print("BorderCrossing ahead in: \(warningUpdate.distanceTillStartInMeters) meters.")
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
    private func handleDangerZoneWarning(_ warningUpdate: WarningUpdate, warningsRegistry: WarningsRegistry) {
        guard let dangerZoneWarning = warningsRegistry.getDangerZoneWarning(warning: warningUpdate.warning) else {
            print("DangerZoneWarning: No detailed data available.")
            return
        }

        switch warningUpdate.warningStatus {
        case .ahead:
            // The start indicates where the danger zone begins.
            print("DangerZone ahead in: \(warningUpdate.distanceTillStartInMeters) meters.")
            print("isZoneStart: \(dangerZoneWarning.isZoneStart)")
        case .reached:
            print("A danger zone has been reached. isZoneStart: \(dangerZoneWarning.isZoneStart)")
        case .passed:
            print("A danger zone has been passed.")
        default:
            break
        }
    }
    // Low speed zones indicate areas where the speed limit is particularly low.
    private func handleLowSpeedZoneWarning(_ warningUpdate: WarningUpdate, warningsRegistry: WarningsRegistry) {
        guard let lowSpeedZoneWarning = warningsRegistry.getLowSpeedZoneWarning(warning: warningUpdate.warning) else {
            print("LowSpeedZoneWarning: No detailed data available.")
            return
        }

        switch warningUpdate.warningStatus {
        case .ahead:
            // The start indicates where the low speed zone begins.
            print("LowSpeedZone ahead in: \(warningUpdate.distanceTillStartInMeters) meters.")
            print("Speed limit in low speed zone (m/s): \(lowSpeedZoneWarning.speedLimitInMetersPerSecond)")
        case .reached:
            print("A low speed zone has been reached.")
            print("Speed limit in low speed zone (m/s): \(lowSpeedZoneWarning.speedLimitInMetersPerSecond)")
        case .passed:
            print("A low speed zone has been passed.")
        default:
            break
        }
    }
    // Realistic views provide 3D junction views and signpost images as SVG data to help
    // the driver orientate at complex junctions.
    private func handleRealisticViewWarning(_ warningUpdate: WarningUpdate, warningsRegistry: WarningsRegistry) {
        guard let realisticViewWarning = warningsRegistry.getRealisticViewWarning(warning: warningUpdate.warning) else {
            print("RealisticViewWarning: No detailed data available.")
            return
        }

        // The start indicates the RealisticView spot.
        let distance = warningUpdate.distanceTillStartInMeters

        switch warningUpdate.warningStatus {
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
    private func handleTollStopWarning(_ warningUpdate: WarningUpdate, warningsRegistry: WarningsRegistry) {
        guard let tollStop = warningsRegistry.getTollStopWarning(warning: warningUpdate.warning) else {
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
    private func handleTrafficMergeWarning(_ warningUpdate: WarningUpdate, warningsRegistry: WarningsRegistry) {
        guard let trafficMergeWarning = warningsRegistry.getTrafficMergeWarning(warning: warningUpdate.warning) else {
            print("TrafficMergeWarning: No detailed data available.")
            return
        }

        switch warningUpdate.warningStatus {
        case .ahead:
            // The start indicates the traffic merge spot.
            print("TrafficMerge: \(trafficMergeWarning.roadType) ahead in: " +
                  "\(warningUpdate.distanceTillStartInMeters) meters" +
                  ", merging from the \(trafficMergeWarning.side) side" +
                  ", with lanes = \(trafficMergeWarning.laneCount)")
        case .passed:
            print("TrafficMerge: \(trafficMergeWarning.roadType) passed.")
        default:
            break
        }
    }

    // Handles custom warnings delivered by the WarnerEngine.
    // Decode the CustomWarning from the WarningsRegistry and check its customWarningType.
    private func handleCustomWarning(_ warningUpdate: WarningUpdate, warningsRegistry: WarningsRegistry) {
        guard let customWarning = warningsRegistry.getCustomWarning(warning: warningUpdate.warning) else {
            print("CustomWarning: No detailed data available.")
            return
        }
        if customWarning.customWarningType == SpeedBumpWarningProvider.speedBumpWarningID {
            let segRef = speedBumpWarningProvider.getSegmentReference(customWarning) ?? "unknown"
            // The WarnerEngine provides warningStatus (ahead/passed) based on startOffsetInMeters.
            let status = warningUpdate.warningStatus == .ahead ? "ahead" : "passed"
            print("Speed bump \(status). segmentRef=\(segRef)")
        } else {
            print("Unsupported custom warning type: \(customWarning.customWarningType)")
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
