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

package com.here.navigationwarnerskotlin

import android.util.Log
import com.here.sdk.navigation.AspectRatio
import com.here.sdk.navigation.BorderCrossingWarningOptions
import com.here.sdk.navigation.DistanceType
import com.here.sdk.navigation.RealisticViewWarningOptions
import com.here.sdk.navigation.RoadSignVehicleType
import com.here.sdk.navigation.RoadSignWarningOptions
import com.here.sdk.navigation.SafetyCameraWarningOptions
import com.here.sdk.navigation.SchoolZoneWarningOptions
import com.here.sdk.navigation.VisualNavigator
import com.here.sdk.navigation.WarningType
import com.here.sdk.warner.Warning
import com.here.sdk.warner.WarnerEngine
import com.here.sdk.warner.WarningListener
import com.here.sdk.warner.WarningOptions
import com.here.sdk.warner.WarningsRegistry
import java.util.Date

// This class shows how to use the unified WarnerEngine to receive all navigation warnings
// through a single WarningListener, instead of setting individual per-type listeners on the
// VisualNavigator. The WarnerEngine is obtained from the VisualNavigator and provides a centralized
// way to configure warning options, set notification distances, and handle all warning events.
//
// For comparison, see the NavigationWarnersExample class which uses per-type listeners directly.
//
// Note: This is a beta release of this feature, so there could be a few bugs and unexpected
// behaviors. Related APIs may change for new releases without a deprecation process.
class WarnerEngineExample {

    private lateinit var warnerEngine: WarnerEngine
    private lateinit var warningsRegistry: WarningsRegistry

    // Sets up the WarnerEngine obtained from the given VisualNavigator.
    // The WarnerEngine provides a unified approach to handle navigation warnings:
    // Instead of registering individual listeners for each warning type on the VisualNavigator,
    // you register a single WarningListener on the WarnerEngine and use the WarningsRegistry
    // to look up detailed warning information by the Warning's id and type.
    fun setupWarnerEngine(visualNavigator: VisualNavigator) {
        // Get the WarnerEngine from the VisualNavigator.
        // The engine is already pre-configured and internally connected to the navigator.
        warnerEngine = visualNavigator.warnerEngine

        // The WarningsRegistry stores detailed warning metadata for each warning type.
        // Use it to look up full warning details (e.g., SafetyCameraWarning, TruckRestrictionWarning)
        // from the generic Warning object received in the WarningListener.
        warningsRegistry = warnerEngine.getWarningsRegistry()

        // Configure all warning options in one place.
        configureWarningOptions()

        // Configure notification distances for specific warning types.
        configureNotificationDistances()

        // Required: setEnabledWarnings() must be called to receive any warnings at all.
        // Without this call, no warnings will be delivered to the WarningListener.
        // Pass the list of WarningType values you want to receive.
        configureEnabledWarnings()

        // Register a single WarningListener to receive all warning events.
        warnerEngine.addWarningListener(WarningListener { warnings ->
            // Each Warning in the list contains a warningType, distanceType, and a unique id.
            // Use the WarningsRegistry to look up the detailed typed warning object.
            for (warning in warnings) {
                handleWarning(warning)
            }
        })

        Log.d(TAG, "WarnerEngine setup complete. Listening for unified warning events.")
    }

    // Configures all warning options through the WarnerEngine's WarningOptions.
    // This replaces the individual set...Options() calls on the VisualNavigator.
    private fun configureWarningOptions() {
        // Get the current warning options from the WarnerEngine.
        val warningOptions: WarningOptions = warnerEngine.warningOptions

        // Configure safety camera warning options.
        val safetyCameraWarningOptions = SafetyCameraWarningOptions()
        // Enable text notifications for safety camera warnings, that can be used with TTS engines.
        safetyCameraWarningOptions.enableTextNotification = true
        warningOptions.safetyCameraWarningOptions = safetyCameraWarningOptions

        // Configure road sign warning options.
        val roadSignWarningOptions = RoadSignWarningOptions()
        // Set a filter to get only road signs relevant for TRUCKS and HEAVY_TRUCKS.
        roadSignWarningOptions.vehicleTypesFilter = listOf(RoadSignVehicleType.TRUCKS, RoadSignVehicleType.HEAVY_TRUCKS)
        warningOptions.roadSignWarningOptions = roadSignWarningOptions

        // Configure school zone warning options.
        val schoolZoneWarningOptions = SchoolZoneWarningOptions()
        schoolZoneWarningOptions.filterOutInactiveTimeDependentWarnings = true
        schoolZoneWarningOptions.warningDistanceInMeters = 150
        warningOptions.schoolZoneWarningOptions = schoolZoneWarningOptions

        // Configure border crossing warning options.
        val borderCrossingWarningOptions = BorderCrossingWarningOptions()
        // If set to true, all the state border crossing notifications will not be given.
        borderCrossingWarningOptions.filterOutStateBorderWarnings = true
        warningOptions.borderCrossingWarningOptions = borderCrossingWarningOptions

        // Configure realistic view warning options.
        val realisticViewWarningOptions = RealisticViewWarningOptions()
        realisticViewWarningOptions.aspectRatio = AspectRatio.ASPECT_RATIO_3_X_4
        realisticViewWarningOptions.darkTheme = false
        warningOptions.realisticViewWarningOptions = realisticViewWarningOptions

        // Apply all warning options at once.
        warnerEngine.warningOptions = warningOptions
    }

    // Configures notification distances for specific warning types through the WarnerEngine.
    // This replaces the individual setWarningNotificationDistances() calls on the VisualNavigator.
    private fun configureNotificationDistances() {
        // Configure custom notification distances for road sign warnings.
        val roadSignDistances = warnerEngine.getWarningNotificationDistances(WarningType.ROAD_SIGN)
        // The distance in meters for emitting warnings when the speed limit or current speed is fast. Defaults to 1500.
        roadSignDistances.fastSpeedDistanceInMeters = 1600
        // The distance in meters for emitting warnings when the speed limit or current speed is regular. Defaults to 750.
        roadSignDistances.regularSpeedDistanceInMeters = 800
        // The distance in meters for emitting warnings when the speed limit or current speed is slow. Defaults to 500.
        roadSignDistances.slowSpeedDistanceInMeters = 600
        warnerEngine.setWarningNotificationDistances(WarningType.ROAD_SIGN, roadSignDistances)
    }

    // Required: setEnabledWarnings() must be called to receive any warnings at all.
    // Without this call, no warnings will be delivered, regardless of a registered WarningListener.
    // Only the warning types in the list below will be delivered. Remove a type to suppress it.
    private fun configureEnabledWarnings() {
        val enabledWarnings = listOf(
            WarningType.SAFETY_CAMERA,
            WarningType.TRUCK_RESTRICTION,
            WarningType.ROAD_SIGN,
            WarningType.SCHOOL_ZONE,
            WarningType.REALISTIC_VIEW,
            WarningType.BORDER_CROSSING,
            WarningType.DANGER_ZONE,
            WarningType.RAILWAY_CROSSING,
            WarningType.LOW_SPEED_ZONE,
            WarningType.TRAFFIC_MERGE,
            WarningType.TOLL_STOP,
            WarningType.LANE_DECREASE
        )
        warnerEngine.setEnabledWarnings(enabledWarnings)
    }

    // Dispatches each Warning to the appropriate handler based on its warningType.
    // The Warning object is generic and carries only an id, distanceType, and warningType.
    // Use the WarningsRegistry to retrieve the full typed warning with all details.
    private fun handleWarning(warning: Warning) {
        when (warning.warningType) {
            WarningType.SAFETY_CAMERA -> handleSafetyCameraWarning(warning)
            WarningType.TRUCK_RESTRICTION -> handleTruckRestrictionWarning(warning)
            WarningType.ROAD_SIGN -> handleRoadSignWarning(warning)
            WarningType.SCHOOL_ZONE -> handleSchoolZoneWarning(warning)
            WarningType.BORDER_CROSSING -> handleBorderCrossingWarning(warning)
            WarningType.DANGER_ZONE -> handleDangerZoneWarning(warning)
            WarningType.LOW_SPEED_ZONE -> handleLowSpeedZoneWarning(warning)
            WarningType.REALISTIC_VIEW -> handleRealisticViewWarning(warning)
            WarningType.TOLL_STOP -> handleTollStopWarning(warning)
            WarningType.TRAFFIC_MERGE -> handleTrafficMergeWarning(warning)
            else -> Log.d(TAG, "Unhandled warning type: ${warning.warningType.name}, distance type: ${warning.distanceType.name}")
        }
    }

    // Handles safety camera warnings.
    // Safety cameras include speed cameras, red light cameras, and similar monitoring installations.
    private fun handleSafetyCameraWarning(warning: Warning) {
        val safetyCameraWarning = warningsRegistry.getSafetyCameraWarning(warning) ?: run {
            Log.d(TAG, "SafetyCameraWarning: No detailed data available.")
            return
        }

        when (warning.distanceType) {
            DistanceType.AHEAD -> Log.d(TAG,
                "SafetyCameraWarning ${safetyCameraWarning.type.name} ahead in: " +
                        "${safetyCameraWarning.distanceToCameraInMeters} meters" +
                        ", speed limit = ${safetyCameraWarning.speedLimitInMetersPerSecond} m/s.")
            DistanceType.PASSED -> Log.d(TAG,
                "SafetyCameraWarning ${safetyCameraWarning.type.name} passed.")
            DistanceType.REACHED -> Log.d(TAG,
                "SafetyCameraWarning ${safetyCameraWarning.type.name} reached.")
        }
    }

    // Handles truck restriction warnings.
    // These alert truck drivers to upcoming road restrictions such as bridges with limited height
    // or roads with weight limits that may prevent passage.
    private fun handleTruckRestrictionWarning(warning: Warning) {
        val truckRestrictionWarning = warningsRegistry.getTruckRestrictionWarning(warning) ?: run {
            Log.d(TAG, "TruckRestrictionWarning: No detailed data available.")
            return
        }

        when (warning.distanceType) {
            DistanceType.AHEAD -> {
                Log.d(TAG, "TruckRestrictionWarning ahead in: ${truckRestrictionWarning.distanceInMeters} meters.")
                if (truckRestrictionWarning.timeRule != null && !truckRestrictionWarning.timeRule!!.appliesTo(Date())) {
                    Log.d(TAG, "Note that this truck restriction warning currently does not apply.")
                }
            }
            DistanceType.REACHED -> Log.d(TAG, "A truck restriction has been reached.")
            DistanceType.PASSED -> Log.d(TAG, "A truck restriction just passed.")
        }

        when {
            truckRestrictionWarning.weightRestriction != null -> {
                val type = truckRestrictionWarning.weightRestriction!!.type
                val value = truckRestrictionWarning.weightRestriction!!.valueInKilograms
                Log.d(TAG, "TruckRestriction for weight (kg): ${type.name}: $value")
            }
            truckRestrictionWarning.dimensionRestriction != null -> {
                val type = truckRestrictionWarning.dimensionRestriction!!.type
                val value = truckRestrictionWarning.dimensionRestriction!!.valueInCentimeters
                Log.d(TAG, "TruckRestriction for dimension: ${type.name}: $value")
            }
            else -> Log.d(TAG, "TruckRestriction: General restriction - no trucks allowed.")
        }
    }

    // Handles road sign warnings.
    // Notifies on road signs as they appear along the road, such as stop signs.
    private fun handleRoadSignWarning(warning: Warning) {
        val roadSignWarning = warningsRegistry.getRoadSignWarning(warning) ?: run {
            Log.d(TAG, "RoadSignWarning: No detailed data available.")
            return
        }

        when (warning.distanceType) {
            DistanceType.AHEAD -> Log.d(TAG,
                "RoadSignWarning of type: ${roadSignWarning.type.name} ahead in (m): ${roadSignWarning.distanceToRoadSignInMeters}")
            DistanceType.PASSED -> Log.d(TAG,
                "RoadSignWarning of type: ${roadSignWarning.type.name} just passed.")
            else -> {}
        }

        roadSignWarning.signValue?.let {
            Log.d(TAG, "Road sign text: ${it.text}")
        }
    }

    // Handles school zone warnings.
    // School zones indicate areas near schools where speed limits are lower.
    private fun handleSchoolZoneWarning(warning: Warning) {
        val schoolZoneWarning = warningsRegistry.getSchoolZoneWarning(warning) ?: run {
            Log.d(TAG, "SchoolZoneWarning: No detailed data available.")
            return
        }

        when (warning.distanceType) {
            DistanceType.AHEAD -> {
                Log.d(TAG, "SchoolZoneWarning ahead in: ${schoolZoneWarning.distanceToSchoolZoneInMeters} meters.")
                Log.d(TAG, "Speed limit for this school zone: ${schoolZoneWarning.speedLimitInMetersPerSecond} m/s.")
                if (schoolZoneWarning.timeRule != null && !schoolZoneWarning.timeRule!!.appliesTo(Date())) {
                    Log.d(TAG, "Note that this school zone warning currently does not apply.")
                }
            }
            DistanceType.REACHED -> Log.d(TAG, "A school zone has been reached.")
            DistanceType.PASSED -> Log.d(TAG, "A school zone has been passed.")
        }
    }

    // Handles border crossing warnings.
    // Notifies when country or state borders are approached, along with general speed limits
    // that apply in the destination country or state.
    private fun handleBorderCrossingWarning(warning: Warning) {
        val borderCrossingWarning = warningsRegistry.getBorderCrossingWarning(warning) ?: run {
            Log.d(TAG, "BorderCrossingWarning: No detailed data available.")
            return
        }

        when (warning.distanceType) {
            DistanceType.AHEAD -> {
                Log.d(TAG, "BorderCrossing ahead in: ${borderCrossingWarning.distanceToBorderCrossingInMeters} meters.")
                Log.d(TAG, "BorderCrossing type: ${borderCrossingWarning.type.name}")
                Log.d(TAG, "BorderCrossing country code: ${borderCrossingWarning.administrativeRules.countryCode.name}")

                borderCrossingWarning.administrativeRules.stateCode?.let {
                    Log.d(TAG, "BorderCrossing state code: $it")
                }

                val speedLimits = borderCrossingWarning.administrativeRules.speedLimits
                Log.d(TAG, "BorderCrossing: Speed limit in cities (m/s): ${speedLimits.maxSpeedUrbanInMetersPerSecond}")
                Log.d(TAG, "BorderCrossing: Speed limit outside cities (m/s): ${speedLimits.maxSpeedRuralInMetersPerSecond}")
                Log.d(TAG, "BorderCrossing: Speed limit on highways (m/s): ${speedLimits.maxSpeedHighwaysInMetersPerSecond}")
            }
            DistanceType.PASSED -> Log.d(TAG, "A border crossing has been passed.")
            else -> {}
        }
    }

    // Handles danger zone warnings.
    // Danger zones refer to areas where there is an increased risk of traffic incidents.
    // Note that danger zones are only available in selected countries, such as France.
    private fun handleDangerZoneWarning(warning: Warning) {
        val dangerZoneWarning = warningsRegistry.getDangerZoneWarning(warning) ?: run {
            Log.d(TAG, "DangerZoneWarning: No detailed data available.")
            return
        }

        when (warning.distanceType) {
            DistanceType.AHEAD -> {
                Log.d(TAG, "DangerZone ahead in: ${dangerZoneWarning.distanceInMeters} meters.")
                Log.d(TAG, "isZoneStart: ${dangerZoneWarning.isZoneStart}")
            }
            DistanceType.REACHED -> Log.d(TAG, "A danger zone has been reached. isZoneStart: ${dangerZoneWarning.isZoneStart}")
            DistanceType.PASSED -> Log.d(TAG, "A danger zone has been passed.")
        }
    }

    // Handles low speed zone warnings.
    // Low speed zones indicate areas where the speed limit is particularly low.
    private fun handleLowSpeedZoneWarning(warning: Warning) {
        val lowSpeedZoneWarning = warningsRegistry.getLowSpeedZoneWarning(warning) ?: run {
            Log.d(TAG, "LowSpeedZoneWarning: No detailed data available.")
            return
        }

        when (warning.distanceType) {
            DistanceType.AHEAD -> {
                Log.d(TAG, "LowSpeedZone ahead in: ${lowSpeedZoneWarning.distanceToLowSpeedZoneInMeters} meters.")
                Log.d(TAG, "Speed limit in low speed zone (m/s): ${lowSpeedZoneWarning.speedLimitInMetersPerSecond}")
            }
            DistanceType.REACHED -> {
                Log.d(TAG, "A low speed zone has been reached.")
                Log.d(TAG, "Speed limit in low speed zone (m/s): ${lowSpeedZoneWarning.speedLimitInMetersPerSecond}")
            }
            DistanceType.PASSED -> Log.d(TAG, "A low speed zone has been passed.")
        }
    }

    // Handles realistic view warnings.
    // Realistic views provide 3D junction views and signpost images as SVG data to help
    // the driver orientate at complex junctions.
    private fun handleRealisticViewWarning(warning: Warning) {
        val realisticViewWarning = warningsRegistry.getRealisticViewWarning(warning) ?: run {
            Log.d(TAG, "RealisticViewWarning: No detailed data available.")
            return
        }

        val distance = realisticViewWarning.distanceToRealisticViewInMeters

        when (warning.distanceType) {
            DistanceType.AHEAD -> Log.d(TAG, "RealisticView ahead in: $distance meters.")
            DistanceType.PASSED -> Log.d(TAG, "A RealisticView just passed.")
            else -> {}
        }

        val realisticView = realisticViewWarning.realisticViewVectorImage
        if (realisticView == null) {
            Log.d(TAG, "No SVG data delivered for this RealisticView.")
            return
        }

        // The resolution-independent SVG data can be used to visualize the junction.
        // Both SVGs contain the same dimensions. The signpost should be shown on top of
        // the junction view.
        Log.d(TAG, "signpostSvgImage: available")
        Log.d(TAG, "junctionViewSvgImage: available")
    }

    // Handles toll stop warnings.
    // Notifies on upcoming toll stops including lane details and supported payment methods.
    private fun handleTollStopWarning(warning: Warning) {
        val tollStop = warningsRegistry.getTollStopWarning(warning) ?: run {
            Log.d(TAG, "TollStopWarning: No detailed data available.")
            return
        }

        tollStop.lanes.forEachIndexed { laneNumber, tollBoothLane ->
            val tollBooth = tollBoothLane.booth
            for (collectionMethod in tollBooth.tollCollectionMethods) {
                Log.d(TAG, "TollStop lane $laneNumber supports collection via: ${collectionMethod.name}")
            }
            for (paymentMethod in tollBooth.paymentMethods) {
                Log.d(TAG, "TollStop lane $laneNumber supports payment via: ${paymentMethod.name}")
            }
        }
    }

    // Handles traffic merge warnings.
    // Notifies about merging traffic from side roads or ramps to the current road.
    private fun handleTrafficMergeWarning(warning: Warning) {
        val trafficMergeWarning = warningsRegistry.getTrafficMergeWarning(warning) ?: run {
            Log.d(TAG, "TrafficMergeWarning: No detailed data available.")
            return
        }

        when (warning.distanceType) {
            DistanceType.AHEAD -> Log.d(TAG,
                "TrafficMerge: ${trafficMergeWarning.roadType.name} ahead in: " +
                        "${trafficMergeWarning.distanceToTrafficMergeInMeters} meters" +
                        ", merging from the ${trafficMergeWarning.side.name} side" +
                        ", with lanes = ${trafficMergeWarning.laneCount}")
            DistanceType.PASSED -> Log.d(TAG,
                "TrafficMerge: ${trafficMergeWarning.roadType.name} passed.")
            else -> {}
        }
    }

    // Stops the WarnerEngine and cleans up.
    // Call this method when guidance is stopped. It finalizes all active warnings by marking
    // them as PASSED and notifies the WarningListener before clearing the internal state.
    fun stopWarnerEngine() {
        if (::warnerEngine.isInitialized) {
            warnerEngine.finalizeGivenWarnings()
            Log.d(TAG, "WarnerEngine finalized. All active warnings marked as passed.")
        }
    }

    companion object {
        private val TAG = WarnerEngineExample::class.java.name
    }
}
