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

package com.here.navigationwarners;

import android.util.Log;

import androidx.annotation.NonNull;

import com.here.sdk.mapdata.SegmentDataLoaderOptions;
import com.here.sdk.navigation.AspectRatio;
import com.here.sdk.navigation.BorderCrossingWarning;
import com.here.sdk.navigation.BorderCrossingWarningOptions;
import com.here.sdk.navigation.DangerZoneWarning;
import com.here.sdk.navigation.DimensionRestrictionType;
import com.here.sdk.navigation.LowSpeedZoneWarning;
import com.here.sdk.navigation.RealisticViewWarning;
import com.here.sdk.navigation.RealisticViewWarningOptions;
import com.here.sdk.navigation.RealisticViewVectorImage;
import com.here.sdk.navigation.RoadSignType;
import com.here.sdk.navigation.RoadSignVehicleType;
import com.here.sdk.navigation.RoadSignWarning;
import com.here.sdk.navigation.RoadSignWarningOptions;
import com.here.sdk.navigation.SafetyCameraWarning;
import com.here.sdk.navigation.SafetyCameraWarningOptions;
import com.here.sdk.navigation.SchoolZoneWarning;
import com.here.sdk.navigation.SchoolZoneWarningOptions;
import com.here.sdk.navigation.TollBoothLane;
import com.here.sdk.navigation.TollBooth;
import com.here.sdk.navigation.TollCollectionMethod;
import com.here.sdk.navigation.TollStop;
import com.here.sdk.navigation.TrafficMergeWarning;
import com.here.sdk.navigation.TruckRestrictionWarning;
import com.here.sdk.navigation.VisualNavigator;
import com.here.sdk.navigation.WarningNotificationDistances;
import com.here.sdk.navigation.WarningType;
import com.here.sdk.navigation.WeightRestrictionType;
import com.here.sdk.routing.PaymentMethod;
import com.here.sdk.transport.GeneralVehicleSpeedLimits;
import com.here.sdk.warner.CustomWarning;
import com.here.sdk.warner.WarnerEngine;
import com.here.sdk.warner.WarningListener;
import com.here.sdk.warner.WarningOptions;
import com.here.sdk.warner.WarningsRegistry;
import com.here.sdk.warner.Warning;
import com.here.sdk.warner.WarningStatus;
import com.here.sdk.warner.WarningUpdate;

import java.util.Arrays;
import java.util.Date;
import java.util.List;

// This class shows how to use the unified WarnerEngine to receive all navigation warnings
// through a single WarningListener. The WarnerEngine is obtained from the VisualNavigator and
// provides a centralized way to configure warning options, set notification distances, and
// handle all warning events.
public class WarnerEngineExample {
    private static final String TAG = WarnerEngineExample.class.getName();

    private WarnerEngine warnerEngine;
    private final SpeedBumpWarningProvider speedBumpWarningProvider = new SpeedBumpWarningProvider();

    // Sets up the WarnerEngine obtained from the given VisualNavigator.
    // The WarnerEngine provides a unified approach to handle navigation warnings:
    // Instead of registering individual listeners for each warning type on the VisualNavigator,
    // you register a single WarningListener on the WarnerEngine and use the WarningsRegistry
    // to look up detailed warning information by the Warning's id and type.
    public void setupWarnerEngine(VisualNavigator visualNavigator) {
        // Get the WarnerEngine from the VisualNavigator.
        // The engine is already pre-configured and internally connected to the navigator.
        warnerEngine = visualNavigator.getWarnerEngine();

        // Configure all warning options in one place.
        configureWarningOptions();

        // Configure notification distances for specific warning types.
        configureNotificationDistances();

        // Register custom warning providers before enabling warnings.
        registerCustomProvider();

        // Required: setEnabledWarnings() must be called to receive any warnings at all.
        // Without this call, no warnings will be delivered to the WarningListener.
        // Pass the list of WarningType values you want to receive.
        configureEnabledWarnings();

        // Register a single WarningListener to receive all warning events.
        warnerEngine.addWarningListener(new WarningListener() {
            @Override
            public void onWarnings(@NonNull List<WarningUpdate> warnings, @NonNull WarningsRegistry warningsRegistry) {
                // Each WarningUpdate contains a warning (with warningType and id), a warningStatus, and optional distances.
                // Use the WarningsRegistry to look up the detailed typed warning object.
                for (WarningUpdate warningUpdate : warnings) {
                    handleWarning(warningUpdate, warningsRegistry);
                }
            }
        });

        Log.d(TAG, "WarnerEngine setup complete. Listening for unified warning events.");
    }

    // Registers custom warning providers with the WarnerEngine before enabling warnings.
    private void registerCustomProvider() {
        SegmentDataLoaderOptions segmentDataLoaderOptions = new SegmentDataLoaderOptions();
        // Load per-segment "special speed situations" (e.g. speed-bump presence and offsets) so the provider can detect and compute distances.
        segmentDataLoaderOptions.loadSpecialSpeedSituations = true;
        warnerEngine.addCustomWarningProvider(speedBumpWarningProvider, segmentDataLoaderOptions);
    }

    // Configures all warning options through the WarnerEngine's WarningOptions.
    // This replaces the individual set...Options() calls on the VisualNavigator.
    private void configureWarningOptions() {
        // Get the current warning options from the WarnerEngine.
        WarningOptions warningOptions = warnerEngine.getWarningOptions();

        // Configure safety camera warning options.
        SafetyCameraWarningOptions safetyCameraWarningOptions = new SafetyCameraWarningOptions();
        // Enable text notifications for safety camera warnings, that can be used with TTS engines.
        safetyCameraWarningOptions.enableTextNotification = true;
        warningOptions.safetyCameraWarningOptions = safetyCameraWarningOptions;

        // Configure road sign warning options.
        RoadSignWarningOptions roadSignWarningOptions = new RoadSignWarningOptions();
        // Set a filter to get only road signs relevant for TRUCKS and HEAVY_TRUCKS.
        roadSignWarningOptions.vehicleTypesFilter = Arrays.asList(RoadSignVehicleType.TRUCKS, RoadSignVehicleType.HEAVY_TRUCKS);
        warningOptions.roadSignWarningOptions = roadSignWarningOptions;

        // Configure school zone warning options.
        SchoolZoneWarningOptions schoolZoneWarningOptions = new SchoolZoneWarningOptions();
        schoolZoneWarningOptions.filterOutInactiveTimeDependentWarnings = true;
        schoolZoneWarningOptions.warningDistanceInMeters = 150;
        warningOptions.schoolZoneWarningOptions = schoolZoneWarningOptions;

        // Configure border crossing warning options.
        BorderCrossingWarningOptions borderCrossingWarningOptions = new BorderCrossingWarningOptions();
        // If set to true, all the state border crossing notifications will not be given.
        borderCrossingWarningOptions.filterOutStateBorderWarnings = true;
        warningOptions.borderCrossingWarningOptions = borderCrossingWarningOptions;

        // Configure realistic view warning options.
        RealisticViewWarningOptions realisticViewWarningOptions = new RealisticViewWarningOptions();
        realisticViewWarningOptions.aspectRatio = AspectRatio.ASPECT_RATIO_3_X_4;
        realisticViewWarningOptions.darkTheme = false;
        warningOptions.realisticViewWarningOptions = realisticViewWarningOptions;

        // Apply all warning options at once.
        warnerEngine.setWarningOptions(warningOptions);
    }

    // Required: setEnabledWarnings() must be called to receive any warnings at all.
    // Without this call, no warnings will be delivered, regardless of a registered WarningListener.
    // Only the warning types in the list below will be delivered. Remove a type to suppress it.
    private void configureEnabledWarnings() {
        List<WarningType> enabledWarnings = Arrays.asList(
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
                WarningType.LANE_DECREASE,
                WarningType.CUSTOM
        );
        warnerEngine.setEnabledWarnings(enabledWarnings);
    }

    // Configures notification distances for specific warning types through the WarnerEngine.
    private void configureNotificationDistances() {
        // Configure custom notification distances for road sign warnings.
        WarningNotificationDistances roadSignDistances = warnerEngine.getWarningNotificationDistances(WarningType.ROAD_SIGN);
        // The distance in meters for emitting warnings when the speed limit or current speed is fast. Defaults to 1500.
        roadSignDistances.fastSpeedDistanceInMeters = 1600;
        // The distance in meters for emitting warnings when the speed limit or current speed is regular. Defaults to 750.
        roadSignDistances.regularSpeedDistanceInMeters = 800;
        // The distance in meters for emitting warnings when the speed limit or current speed is slow. Defaults to 500.
        roadSignDistances.slowSpeedDistanceInMeters = 600;
        warnerEngine.setWarningNotificationDistances(WarningType.ROAD_SIGN, roadSignDistances);
    }

    // Dispatches each WarningUpdate to the appropriate handler based on its warningType.
    // The WarningUpdate carries the Warning (with id and warningType) and the warningStatus.
    // Use the WarningsRegistry to retrieve the full typed warning with all details.
    private void handleWarning(WarningUpdate warningUpdate, WarningsRegistry warningsRegistry) {
        switch (warningUpdate.warning.warningType) {
            case SAFETY_CAMERA:
                handleSafetyCameraWarning(warningUpdate, warningsRegistry);
                break;
            case TRUCK_RESTRICTION:
                handleTruckRestrictionWarning(warningUpdate, warningsRegistry);
                break;
            case ROAD_SIGN:
                handleRoadSignWarning(warningUpdate, warningsRegistry);
                break;
            case SCHOOL_ZONE:
                handleSchoolZoneWarning(warningUpdate, warningsRegistry);
                break;
            case BORDER_CROSSING:
                handleBorderCrossingWarning(warningUpdate, warningsRegistry);
                break;
            case DANGER_ZONE:
                handleDangerZoneWarning(warningUpdate, warningsRegistry);
                break;
            case LOW_SPEED_ZONE:
                handleLowSpeedZoneWarning(warningUpdate, warningsRegistry);
                break;
            case REALISTIC_VIEW:
                handleRealisticViewWarning(warningUpdate, warningsRegistry);
                break;
            case TOLL_STOP:
                handleTollStopWarning(warningUpdate, warningsRegistry);
                break;
            case TRAFFIC_MERGE:
                handleTrafficMergeWarning(warningUpdate, warningsRegistry);
                break;
            case CUSTOM:
                handleCustomWarning(warningUpdate, warningsRegistry);
                break;
            default:
                Log.d(TAG, "Unhandled warning type: " + warningUpdate.warning.warningType.name()
                        + ", warning status: " + warningUpdate.warningStatus.name());
                break;
        }
    }

    // Handles safety camera warnings.
    // Safety cameras include speed cameras, red light cameras, and similar monitoring installations.
    private void handleSafetyCameraWarning(WarningUpdate warningUpdate, WarningsRegistry warningsRegistry) {
        SafetyCameraWarning safetyCameraWarning = warningsRegistry.getSafetyCameraWarning(warningUpdate.warning);
        if (safetyCameraWarning == null) {
            Log.d(TAG, "SafetyCameraWarning: No detailed data available.");
            return;
        }

        if (warningUpdate.warningStatus == WarningStatus.AHEAD) {
            // The start indicates the SafetyCamera spot.
            Log.d(TAG, "SafetyCameraWarning " + safetyCameraWarning.type.name()
                    + " ahead in: " + warningUpdate.distanceTillStartInMeters + " meters"
                    + ", speed limit = " + safetyCameraWarning.speedLimitInMetersPerSecond + " m/s.");
        } else if (warningUpdate.warningStatus == WarningStatus.PASSED) {
            Log.d(TAG, "SafetyCameraWarning " + safetyCameraWarning.type.name() + " passed.");
        } else if (warningUpdate.warningStatus == WarningStatus.REACHED) {
            Log.d(TAG, "SafetyCameraWarning " + safetyCameraWarning.type.name() + " reached.");
        }
    }

    // Handles truck restriction warnings.
    // These alert truck drivers to upcoming road restrictions such as bridges with limited height
    // or roads with weight limits that may prevent passage.
    // This event notifies on truck restrictions in general,
    // so it will also deliver events when the transport type was set to a non-truck transport type.
    // The given restrictions are based on the HERE database of the road network ahead.
    private void handleTruckRestrictionWarning(WarningUpdate warningUpdate, WarningsRegistry warningsRegistry) {
        TruckRestrictionWarning truckRestrictionWarning = warningsRegistry.getTruckRestrictionWarning(warningUpdate.warning);
        if (truckRestrictionWarning == null) {
            Log.d(TAG, "TruckRestrictionWarning: No detailed data available.");
            return;
        }

        if (warningUpdate.warningStatus == WarningStatus.AHEAD) {
            // The start indicates where the truck restriction becomes effective.
            Log.d(TAG, "TruckRestrictionWarning ahead in: " + warningUpdate.distanceTillStartInMeters + " meters.");
            if (truckRestrictionWarning.timeRule != null && !truckRestrictionWarning.timeRule.appliesTo(new Date())) {
                Log.d(TAG, "Note that this truck restriction warning currently does not apply.");
            }
        } else if (warningUpdate.warningStatus == WarningStatus.REACHED) {
            Log.d(TAG, "A truck restriction has been reached.");
        } else if (warningUpdate.warningStatus == WarningStatus.PASSED) {
            Log.d(TAG, "A truck restriction just passed.");
        }

        if (truckRestrictionWarning.weightRestriction != null) {
            WeightRestrictionType type = truckRestrictionWarning.weightRestriction.type;
            int value = truckRestrictionWarning.weightRestriction.valueInKilograms;
            Log.d(TAG, "TruckRestriction for weight (kg): " + type.name() + ": " + value);
        } else if (truckRestrictionWarning.dimensionRestriction != null) {
            DimensionRestrictionType type = truckRestrictionWarning.dimensionRestriction.type;
            int value = truckRestrictionWarning.dimensionRestriction.valueInCentimeters;
            Log.d(TAG, "TruckRestriction for dimension: " + type.name() + ": " + value);
        } else {
            Log.d(TAG, "TruckRestriction: General restriction - no trucks allowed.");
        }
    }

    // Handles road sign warnings.
    // Notifies on road signs as they appear along the road, such as stop signs.
    private void handleRoadSignWarning(WarningUpdate warningUpdate, WarningsRegistry warningsRegistry) {
        RoadSignWarning roadSignWarning = warningsRegistry.getRoadSignWarning(warningUpdate.warning);
        if (roadSignWarning == null) {
            Log.d(TAG, "RoadSignWarning: No detailed data available.");
            return;
        }

        RoadSignType roadSignType = roadSignWarning.type;
        if (warningUpdate.warningStatus == WarningStatus.AHEAD) {
            // The start indicates the RoadSign spot.
            Log.d(TAG, "RoadSignWarning of type: " + roadSignType.name()
                    + " ahead in (m): " + warningUpdate.distanceTillStartInMeters);
        } else if (warningUpdate.warningStatus == WarningStatus.PASSED) {
            Log.d(TAG, "RoadSignWarning of type: " + roadSignType.name() + " just passed.");
        }

        if (roadSignWarning.signValue != null) {
            Log.d(TAG, "Road sign text: " + roadSignWarning.signValue.text);
        }
    }

    // Handles school zone warnings.
    // School zones indicate areas near schools where speed limits are lower.
    private void handleSchoolZoneWarning(WarningUpdate warningUpdate, WarningsRegistry warningsRegistry) {
        SchoolZoneWarning schoolZoneWarning = warningsRegistry.getSchoolZoneWarning(warningUpdate.warning);
        if (schoolZoneWarning == null) {
            Log.d(TAG, "SchoolZoneWarning: No detailed data available.");
            return;
        }

        if (warningUpdate.warningStatus == WarningStatus.AHEAD) {
            // The start indicates where the school zone begins.
            Log.d(TAG, "SchoolZoneWarning ahead in: " + warningUpdate.distanceTillStartInMeters + " meters.");
            Log.d(TAG, "Speed limit for this school zone: " + schoolZoneWarning.speedLimitInMetersPerSecond + " m/s.");
            if (schoolZoneWarning.timeRule != null && !schoolZoneWarning.timeRule.appliesTo(new Date())) {
                Log.d(TAG, "Note that this school zone warning currently does not apply.");
            }
        } else if (warningUpdate.warningStatus == WarningStatus.REACHED) {
            Log.d(TAG, "A school zone has been reached.");
        } else if (warningUpdate.warningStatus == WarningStatus.PASSED) {
            Log.d(TAG, "A school zone has been passed.");
        }
    }

    // Handles border crossing warnings.
    // Notifies when country or state borders are approached, along with general speed limits
    // that apply in the destination country or state.
    private void handleBorderCrossingWarning(WarningUpdate warningUpdate, WarningsRegistry warningsRegistry) {
        BorderCrossingWarning borderCrossingWarning = warningsRegistry.getBorderCrossingWarning(warningUpdate.warning);
        if (borderCrossingWarning == null) {
            Log.d(TAG, "BorderCrossingWarning: No detailed data available.");
            return;
        }

        if (warningUpdate.warningStatus == WarningStatus.AHEAD) {
            // The start indicates the border crossing spot.
            Log.d(TAG, "BorderCrossing ahead in: " + warningUpdate.distanceTillStartInMeters + " meters.");
            Log.d(TAG, "BorderCrossing type: " + borderCrossingWarning.type.name());
            Log.d(TAG, "BorderCrossing country code: " + borderCrossingWarning.administrativeRules.countryCode.name());

            if (borderCrossingWarning.administrativeRules.stateCode != null) {
                Log.d(TAG, "BorderCrossing state code: " + borderCrossingWarning.administrativeRules.stateCode);
            }

            GeneralVehicleSpeedLimits speedLimits = borderCrossingWarning.administrativeRules.speedLimits;
            Log.d(TAG, "BorderCrossing: Speed limit in cities (m/s): " + speedLimits.maxSpeedUrbanInMetersPerSecond);
            Log.d(TAG, "BorderCrossing: Speed limit outside cities (m/s): " + speedLimits.maxSpeedRuralInMetersPerSecond);
            Log.d(TAG, "BorderCrossing: Speed limit on highways (m/s): " + speedLimits.maxSpeedHighwaysInMetersPerSecond);
        } else if (warningUpdate.warningStatus == WarningStatus.PASSED) {
            Log.d(TAG, "A border crossing has been passed.");
        }
    }

    // Handles danger zone warnings.
    // Danger zones refer to areas where there is an increased risk of traffic incidents.
    // Note that danger zones are only available in selected countries, such as France.
    private void handleDangerZoneWarning(WarningUpdate warningUpdate, WarningsRegistry warningsRegistry) {
        DangerZoneWarning dangerZoneWarning = warningsRegistry.getDangerZoneWarning(warningUpdate.warning);
        if (dangerZoneWarning == null) {
            Log.d(TAG, "DangerZoneWarning: No detailed data available.");
            return;
        }

        if (warningUpdate.warningStatus == WarningStatus.AHEAD) {
            // The start indicates where the danger zone begins.
            Log.d(TAG, "DangerZone ahead in: " + warningUpdate.distanceTillStartInMeters + " meters.");
            Log.d(TAG, "isZoneStart: " + dangerZoneWarning.isZoneStart);
        } else if (warningUpdate.warningStatus == WarningStatus.REACHED) {
            Log.d(TAG, "A danger zone has been reached. isZoneStart: " + dangerZoneWarning.isZoneStart);
        } else if (warningUpdate.warningStatus == WarningStatus.PASSED) {
            Log.d(TAG, "A danger zone has been passed.");
        }
    }

    // Handles low speed zone warnings.
    // Low speed zones indicate areas where the speed limit is particularly low.
    private void handleLowSpeedZoneWarning(WarningUpdate warningUpdate, WarningsRegistry warningsRegistry) {
        LowSpeedZoneWarning lowSpeedZoneWarning = warningsRegistry.getLowSpeedZoneWarning(warningUpdate.warning);
        if (lowSpeedZoneWarning == null) {
            Log.d(TAG, "LowSpeedZoneWarning: No detailed data available.");
            return;
        }

        if (warningUpdate.warningStatus == WarningStatus.AHEAD) {
            // The start indicates where the low speed zone begins.
            Log.d(TAG, "LowSpeedZone ahead in: " + warningUpdate.distanceTillStartInMeters + " meters.");
            Log.d(TAG, "Speed limit in low speed zone (m/s): " + lowSpeedZoneWarning.speedLimitInMetersPerSecond);
        } else if (warningUpdate.warningStatus == WarningStatus.REACHED) {
            Log.d(TAG, "A low speed zone has been reached.");
            Log.d(TAG, "Speed limit in low speed zone (m/s): " + lowSpeedZoneWarning.speedLimitInMetersPerSecond);
        } else if (warningUpdate.warningStatus == WarningStatus.PASSED) {
            Log.d(TAG, "A low speed zone has been passed.");
        }
    }

    // Handles realistic view warnings.
    // Realistic views provide 3D junction views and signpost images as SVG data to help
    // the driver orientate at complex junctions.
    private void handleRealisticViewWarning(WarningUpdate warningUpdate, WarningsRegistry warningsRegistry) {
        RealisticViewWarning realisticViewWarning = warningsRegistry.getRealisticViewWarning(warningUpdate.warning);
        if (realisticViewWarning == null) {
            Log.d(TAG, "RealisticViewWarning: No detailed data available.");
            return;
        }

        // The start indicates the RealisticView spot.
        double distance = warningUpdate.distanceTillStartInMeters;

        if (warningUpdate.warningStatus == WarningStatus.AHEAD) {
            Log.d(TAG, "RealisticView ahead in: " + distance + " meters.");
        } else if (warningUpdate.warningStatus == WarningStatus.PASSED) {
            Log.d(TAG, "A RealisticView just passed.");
        }

        RealisticViewVectorImage realisticView = realisticViewWarning.realisticViewVectorImage;
        if (realisticView == null) {
            Log.d(TAG, "No SVG data delivered for this RealisticView.");
            return;
        }

        // The resolution-independent SVG data can be used to visualize the junction.
        // Both SVGs contain the same dimensions. The signpost should be shown on top of
        // the junction view.
        String signpostSvgImageContent = realisticView.signpostSvgImageContent;
        String junctionViewSvgImageContent = realisticView.junctionViewSvgImageContent;
        Log.d(TAG, "signpostSvgImage: " + (signpostSvgImageContent != null ? "available" : "null"));
        Log.d(TAG, "junctionViewSvgImage: " + (junctionViewSvgImageContent != null ? "available" : "null"));
    }

    // Handles toll stop warnings.
    // Notifies on upcoming toll stops including lane details and supported payment methods.
    private void handleTollStopWarning(WarningUpdate warningUpdate, WarningsRegistry warningsRegistry) {
        TollStop tollStop = warningsRegistry.getTollStopWarning(warningUpdate.warning);
        if (tollStop == null) {
            Log.d(TAG, "TollStopWarning: No detailed data available.");
            return;
        }

        List<TollBoothLane> lanes = tollStop.lanes;
        int laneNumber = 0;
        for (TollBoothLane tollBoothLane : lanes) {
            TollBooth tollBooth = tollBoothLane.booth;
            for (TollCollectionMethod collectionMethod : tollBooth.tollCollectionMethods) {
                Log.d(TAG, "TollStop lane " + laneNumber + " supports collection via: " + collectionMethod.name());
            }
            for (PaymentMethod paymentMethod : tollBooth.paymentMethods) {
                Log.d(TAG, "TollStop lane " + laneNumber + " supports payment via: " + paymentMethod.name());
            }
            laneNumber++;
        }
    }

    // Handles traffic merge warnings.
    // Notifies about merging traffic from side roads or ramps to the current road.
    private void handleTrafficMergeWarning(WarningUpdate warningUpdate, WarningsRegistry warningsRegistry) {
        TrafficMergeWarning trafficMergeWarning = warningsRegistry.getTrafficMergeWarning(warningUpdate.warning);
        if (trafficMergeWarning == null) {
            Log.d(TAG, "TrafficMergeWarning: No detailed data available.");
            return;
        }

        if (warningUpdate.warningStatus == WarningStatus.AHEAD) {
            // The start indicates the traffic merge spot.
            Log.d(TAG, "TrafficMerge: " + trafficMergeWarning.roadType.name()
                    + " ahead in: " + warningUpdate.distanceTillStartInMeters + " meters"
                    + ", merging from the " + trafficMergeWarning.side.name() + " side"
                    + ", with lanes = " + trafficMergeWarning.laneCount);
        } else if (warningUpdate.warningStatus == WarningStatus.PASSED) {
            Log.d(TAG, "TrafficMerge: " + trafficMergeWarning.roadType.name() + " passed.");
        }
    }

    // Handles custom speed bumps warnings provided by the SpeedBumpWarningProvider.
    private void handleCustomWarning(WarningUpdate warningUpdate, WarningsRegistry warningsRegistry) {
        CustomWarning customWarning = warningsRegistry.getCustomWarning(warningUpdate.warning);
        if (customWarning == null) {
            Log.d(TAG, "CustomWarning: No detailed data available.");
            return;
        }
        if (customWarning.customWarningType == SpeedBumpWarningProvider.SPEED_BUMP_WARNING_ID) {
            String segRef = speedBumpWarningProvider.getSegmentReference(customWarning);
            Log.d(TAG, "Speed bump " + (warningUpdate.warningStatus == WarningStatus.AHEAD ? "ahead" : "passed")
                    + ". segmentRef=" + segRef);
        } else {
            Log.d(TAG, "Unsupported custom warning type: " + customWarning.customWarningType);
        }
    }

    // Stops the WarnerEngine and cleans up.
    // Call this method when guidance is stopped. It finalizes all active warnings by marking
    // them as PASSED and notifies the WarningListener before clearing the internal state.
    public void stopWarnerEngine() {
        if (warnerEngine != null) {
            warnerEngine.finalizeGivenWarnings();
            Log.d(TAG, "WarnerEngine finalized. All active warnings marked as passed.");
        }
    }
}
