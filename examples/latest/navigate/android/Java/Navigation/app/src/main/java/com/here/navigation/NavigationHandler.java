/*
 * Copyright (C) 2019-2025 HERE Europe B.V.
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

package com.here.navigation;

import android.content.Context;
import android.util.Log;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.here.sdk.core.LanguageCode;
import com.here.sdk.core.UnitSystem;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.navigation.EventText;
import com.here.sdk.navigation.EventTextListener;
import com.here.sdk.navigation.ManeuverNotificationOptions;
import com.here.sdk.navigation.ManeuverProgress;
import com.here.sdk.navigation.MapMatchedLocation;
import com.here.sdk.navigation.NavigableLocation;
import com.here.sdk.navigation.NavigableLocationListener;
import com.here.sdk.navigation.RouteProgress;
import com.here.sdk.navigation.RouteProgressListener;
import com.here.sdk.navigation.SectionProgress;
import com.here.sdk.navigation.TextNotificationType;
import com.here.sdk.navigation.VisualNavigator;
import com.here.sdk.routing.CalculateTrafficOnRouteCallback;
import com.here.sdk.routing.Maneuver;
import com.here.sdk.routing.ManeuverAction;
import com.here.sdk.routing.RoadTexts;
import com.here.sdk.routing.Route;
import com.here.sdk.routing.RoutingEngine;
import com.here.sdk.routing.RoutingError;
import com.here.sdk.routing.Section;
import com.here.sdk.routing.Span;
import com.here.sdk.routing.StreetAttributes;
import com.here.sdk.routing.TrafficOnRoute;
import com.here.sdk.trafficawarenavigation.DynamicRoutingEngine;

import java.util.List;
import java.util.Locale;

// This class handles voice navigation along with handling other events such as updating traffic on the route.
// Note that this class does not show an exhaustive list of all possible events.
public class NavigationHandler {
    public enum RoadType {HIGHWAY, RURAL, URBAN}

    private static final String TAG = NavigationHandler.class.getName();

    private final Context context;
    private int previousManeuverIndex = -1;
    private MapMatchedLocation lastMapMatchedLocation;
    private VoiceAssistant voiceAssistant;
    private final TextView messageView;
    private final TimeUtils timeUtils;
    private final RoutingEngine routingEngine;
    private long lastTrafficUpdateInMilliseconds = 0L;

    public NavigationHandler(Context context, TextView messageView) {
        this.context = context;
        this.messageView = messageView;

        timeUtils = new TimeUtils();
        try {
            routingEngine = new RoutingEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of RoutingEngine failed: " + e.error.name());
        }
    }

    // Note that this class does not show all available listeners that can be used for turn-by-turn navigation.
    public void setupListeners(VisualNavigator visualNavigator, DynamicRoutingEngine dynamicRoutingEngine, ElectronicHorizonHandler electronicHorizonHandler) {

        // A helper class for TTS.
        voiceAssistant = new VoiceAssistant(context, new VoiceAssistant.VoiceAssistantListener() {
            @Override
            public void onInitialized() {
                setupVoiceGuidance(visualNavigator);
            }
        });

        // Notifies on the progress along the route including maneuver instructions.
        visualNavigator.setRouteProgressListener(new RouteProgressListener() {
            @Override
            public void onRouteProgressUpdated(@NonNull RouteProgress routeProgress) {

                // Contains the progress for the next maneuver ahead and the next-next maneuvers, if any.
                List<ManeuverProgress> nextManeuverList = routeProgress.maneuverProgress;

                ManeuverProgress nextManeuverProgress = nextManeuverList.get(0);
                if (nextManeuverProgress == null) {
                    Log.d(TAG, "No next maneuver available.");
                    return;
                }

                int nextManeuverIndex = nextManeuverProgress.maneuverIndex;
                Maneuver nextManeuver = visualNavigator.getManeuver(nextManeuverIndex);
                if (nextManeuver == null) {
                    // Should never happen as we retrieved the next maneuver progress above.
                    return;
                }

                ManeuverAction action = nextManeuver.getAction();
                String roadName = getRoadName(nextManeuver, visualNavigator.getRoute());
                String logMessage = action.name() + " on " + roadName +
                        " in " + nextManeuverProgress.remainingDistanceInMeters + " meters.";

                String currentETAString = getETA(routeProgress);

                if (previousManeuverIndex != nextManeuverIndex) {
                    currentETAString = currentETAString + "\nNew maneuver: " + logMessage;
                } else {
                    // A maneuver update contains a different distance to reach the next maneuver.
                    currentETAString = currentETAString + "\nManeuver update: " + logMessage;
                }
                messageView.setText(currentETAString);

                previousManeuverIndex = nextManeuverIndex;

                if (lastMapMatchedLocation != null) {
                    // Update the route based on the current location of the driver.
                    // We periodically want to search for better traffic-optimized routes.
                    dynamicRoutingEngine.updateCurrentLocation(lastMapMatchedLocation, routeProgress.sectionIndex);

                    // Update the ElectronicHorizon with the last map-matched location.
                    electronicHorizonHandler.update(lastMapMatchedLocation);
                }

                updateTrafficOnRoute(routeProgress, visualNavigator);
            }
        });

        // Notifies on the current map-matched location and other useful information while driving or walking.
        visualNavigator.setNavigableLocationListener(new NavigableLocationListener() {
            @Override
            public void onNavigableLocationUpdated(@NonNull NavigableLocation currentNavigableLocation) {
                lastMapMatchedLocation = currentNavigableLocation.mapMatchedLocation;
                if (lastMapMatchedLocation == null) {
                    Log.d(TAG, "The currentNavigableLocation could not be map-matched. Are you off-road?");
                    return;
                }

                if (lastMapMatchedLocation.isDrivingInTheWrongWay) {
                    // For two-way streets, this value is always false. This feature is supported in tracking mode and when deviating from a route.
                    Log.d(TAG, "This is a one way road. User is driving against the allowed traffic direction.");
                }

                Double speed = currentNavigableLocation.originalLocation.speedInMetersPerSecond;
                Double accuracy = currentNavigableLocation.originalLocation.speedAccuracyInMetersPerSecond;
                Log.d(TAG, "Driving speed (m/s): " + speed + "plus/minus an accuracy of: " + accuracy);
            }
        });

        // Notifies on messages that can be fed into TTS engines to guide the user with audible instructions.
        // The texts can be maneuver instructions or warn on certain obstacles, such as speed cameras.
        visualNavigator.setEventTextListener(new EventTextListener() {
            @Override
            public void onEventTextUpdated(@NonNull EventText eventText) {
                // We use the built-in TTS engine to synthesize the localized text as audio.
                voiceAssistant.speak(eventText.text);
                // We can optionally retrieve the associated maneuver. The details will be null if the text contains
                // non-maneuver related information, such as for speed camera warnings.
                if (eventText.type == TextNotificationType.MANEUVER && eventText.maneuverNotificationDetails != null) {
                    Maneuver maneuver = eventText.maneuverNotificationDetails.maneuver;
                }
            }
        });
    }

    private String getETA(RouteProgress routeProgress) {
        List<SectionProgress> sectionProgressList = routeProgress.sectionProgress;
        // sectionProgressList is guaranteed to be non-empty.
        SectionProgress lastSectionProgress = sectionProgressList.get(sectionProgressList.size() - 1);
        String currentETAString = "ETA: " + timeUtils.getETAinDeviceTimeZone((int) lastSectionProgress.remainingDuration.toSeconds());
        Log.d(TAG, "Distance to destination in meters: " + lastSectionProgress.remainingDistanceInMeters);
        Log.d(TAG, "Traffic delay ahead in seconds: " + lastSectionProgress.trafficDelay.getSeconds());
        // Logs current ETA.
        Log.d(TAG, currentETAString);
        return currentETAString;
    }

    private void setupVoiceGuidance(VisualNavigator visualNavigator) {
        LanguageCode ttsLanguageCode = getLanguageCodeForDevice(VisualNavigator.getAvailableLanguagesForManeuverNotifications());
        ManeuverNotificationOptions maneuverNotificationOptions = new ManeuverNotificationOptions();
        // Set the language in which the notifications will be generated.
        maneuverNotificationOptions.language = ttsLanguageCode;
        // Set the measurement system used for distances.
        maneuverNotificationOptions.unitSystem = UnitSystem.METRIC;
        visualNavigator.setManeuverNotificationOptions(maneuverNotificationOptions);
        Log.d(TAG, "LanguageCode for maneuver notifications: " + ttsLanguageCode);

        // Toggle the lane recommendation in the maneuver notifications.
        // The lane recommendation, if enabled, will be given only for the ManeuverNotificationType.DISTANCE notification type.
        maneuverNotificationOptions.enableLaneRecommendation = true;

        // Set language to our TextToSpeech engine.
        Locale locale = LanguageCodeConverter.getLocale(ttsLanguageCode);
        if (voiceAssistant.setLanguage(locale)) {
            Log.d(TAG, "TextToSpeech engine uses this language: " + locale);
        } else {
            Log.e(TAG, "TextToSpeech engine does not support this language: " + locale);
        }
    }

    // Get the language preferably used on this device.
    private LanguageCode getLanguageCodeForDevice(List<LanguageCode> supportedVoiceSkins) {

        // 1. Determine if preferred device language is supported by our TextToSpeech engine.
        Locale localeForCurrenDevice = Locale.getDefault();
        if (!voiceAssistant.isLanguageAvailable(localeForCurrenDevice)) {
            Log.e(TAG, "TextToSpeech engine does not support: " + localeForCurrenDevice + ", falling back to EN_US.");
            localeForCurrenDevice = new Locale("en", "US");
        }

        // 2. Determine supported voice skins from HERE SDK.
        LanguageCode languageCodeForCurrenDevice = LanguageCodeConverter.getLanguageCode(localeForCurrenDevice);
        if (!supportedVoiceSkins.contains(languageCodeForCurrenDevice)) {
            Log.e(TAG, "No voice skins available for " + languageCodeForCurrenDevice + ", falling back to EN_US.");
            languageCodeForCurrenDevice = LanguageCode.EN_US;
        }

        return languageCodeForCurrenDevice;
    }

    private String getRoadName(Maneuver maneuver, Route route) {
        RoadTexts currentRoadTexts = maneuver.getRoadTexts();
        RoadTexts nextRoadTexts = maneuver.getNextRoadTexts();

        String currentRoadName = currentRoadTexts.names.getDefaultValue();
        String currentRoadNumber = currentRoadTexts.numbersWithDirection.getDefaultValue();
        String nextRoadName = nextRoadTexts.names.getDefaultValue();
        String nextRoadNumber = nextRoadTexts.numbersWithDirection.getDefaultValue();

        String roadName = nextRoadName == null ? nextRoadNumber : nextRoadName;

        // On highways, we want to show the highway number instead of a possible road name,
        // while for inner city and urban areas road names are preferred over road numbers.
        if (getRoadType(maneuver, route) == RoadType.HIGHWAY) {
            roadName = nextRoadNumber == null ? nextRoadName : nextRoadNumber;
        }

        if (maneuver.getAction() == ManeuverAction.ARRIVE) {
            // We are approaching the destination, so there's no next road.
            roadName = currentRoadName == null ? currentRoadNumber : currentRoadName;
        }

        if (roadName == null) {
            // Happens only in rare cases, when also the fallback is null.
            roadName = "unnamed road";
        }

        return roadName;
    }

    // Determines the road type for a given maneuver based on street attributes.
    // Return The road type classification (HIGHWAY, URBAN, RURAL, or UNDEFINED).
    private RoadType getRoadType(Maneuver maneuver, Route route) {
        Section sectionOfManeuver = route.getSections().get(maneuver.getSectionIndex());
        List<Span> spansInSection = sectionOfManeuver.getSpans();

        // If attributes list is empty then the road type is rural.
        if(spansInSection.isEmpty()) {
            return RoadType.RURAL;
        }

        Span currentSpan = spansInSection.get(maneuver.getSpanIndex());
        List<StreetAttributes> streetAttributes = currentSpan.getStreetAttributes();

        // If attributes list contains either CONTROLLED_ACCESS_HIGHWAY, or MOTORWAY or RAMP then the road type is highway.
        // Check for highway attributes.
        if (streetAttributes.contains(StreetAttributes.CONTROLLED_ACCESS_HIGHWAY)
                || streetAttributes.contains(StreetAttributes.MOTORWAY)
                || streetAttributes.contains(StreetAttributes.RAMP)) {
            return RoadType.HIGHWAY;
        }

        // If attributes list contains BUILT_UP_AREA then the road type is urban.
        // Check for urban attributes.
        if (streetAttributes.contains(StreetAttributes.BUILT_UP_AREA)) {
            return RoadType.URBAN;
        }

        // If the road type is neither urban nor highway, default to rural for all other cases.
        return RoadType.RURAL;
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
    public void updateTrafficOnRoute(RouteProgress routeProgress, VisualNavigator visualNavigator) {
        Route currentRoute = visualNavigator.getRoute();
        if (currentRoute == null) {
            // Should never happen.
            return;
        }

        // Below, we use 10 minutes. A common range is between 5 and 15 minutes.
        long trafficUpdateIntervalInMilliseconds = 10 * 60000; // 10 minutes.
        long now = System.currentTimeMillis();
        if ((now - lastTrafficUpdateInMilliseconds) < trafficUpdateIntervalInMilliseconds) {
            return;
        }
        // Store the current time when we update trafficOnRoute.
        lastTrafficUpdateInMilliseconds = now;

        List<SectionProgress> sectionProgressList = routeProgress.sectionProgress;
        SectionProgress lastSectionProgress = sectionProgressList.get(sectionProgressList.size() - 1);
        int traveledDistanceOnLastSectionInMeters = currentRoute.getLengthInMeters() - lastSectionProgress.remainingDistanceInMeters;
        int lastTraveledSectionIndex = routeProgress.sectionIndex;

        routingEngine.calculateTrafficOnRoute(currentRoute, lastTraveledSectionIndex, traveledDistanceOnLastSectionInMeters, new CalculateTrafficOnRouteCallback() {
            @Override
            public void onTrafficOnRouteCalculated(@Nullable RoutingError routingError, @Nullable TrafficOnRoute trafficOnRoute) {
                if (routingError != null) {
                    Log.d(TAG, "CalculateTrafficOnRoute error: " + routingError.name());
                    return;
                }

                // Sets traffic data for the current route, affecting RouteProgress duration in SectionProgress,
                // while preserving route distance and geometry.
                visualNavigator.setTrafficOnRoute(trafficOnRoute);
                Log.d(TAG, "Updated traffic on route.");
            }
        });
    }
}
