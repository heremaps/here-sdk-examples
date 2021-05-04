/*
 * Copyright (C) 2019-2021 HERE Europe B.V.
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
import android.media.Ringtone;
import android.media.RingtoneManager;
import android.net.Uri;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.google.android.material.snackbar.Snackbar;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.LanguageCode;
import com.here.sdk.core.UnitSystem;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.location.LocationAccuracy;
import com.here.sdk.mapview.MapView;
import com.here.sdk.navigation.CameraTrackingMode;
import com.here.sdk.navigation.DestinationReachedListener;
import com.here.sdk.navigation.Lane;
import com.here.sdk.navigation.LaneAssistance;
import com.here.sdk.navigation.LaneAssistanceListener;
import com.here.sdk.navigation.LaneRecommendationState;
import com.here.sdk.navigation.ManeuverNotificationListener;
import com.here.sdk.navigation.ManeuverNotificationOptions;
import com.here.sdk.navigation.ManeuverProgress;
import com.here.sdk.navigation.MapMatchedLocation;
import com.here.sdk.navigation.Milestone;
import com.here.sdk.navigation.MilestoneReachedListener;
import com.here.sdk.navigation.NavigableLocation;
import com.here.sdk.navigation.NavigableLocationListener;
import com.here.sdk.navigation.RouteDeviation;
import com.here.sdk.navigation.RouteDeviationListener;
import com.here.sdk.navigation.RouteProgress;
import com.here.sdk.navigation.RouteProgressListener;
import com.here.sdk.navigation.SectionProgress;
import com.here.sdk.navigation.SpecialSpeedSituation;
import com.here.sdk.navigation.SpecialSpeedSituationType;
import com.here.sdk.navigation.SpeedLimit;
import com.here.sdk.navigation.SpeedLimitListener;
import com.here.sdk.navigation.SpeedLimitOffset;
import com.here.sdk.navigation.SpeedWarningListener;
import com.here.sdk.navigation.SpeedWarningOptions;
import com.here.sdk.navigation.SpeedWarningStatus;
import com.here.sdk.navigation.TimeDomain;
import com.here.sdk.navigation.VisualNavigator;
import com.here.sdk.routing.Maneuver;
import com.here.sdk.routing.ManeuverAction;
import com.here.sdk.routing.RoadType;
import com.here.sdk.routing.Route;
import com.here.sdk.routing.Section;

import java.util.Date;
import java.util.List;
import java.util.Locale;

// Shows how to start and stop turn-by-turn navigation on a car route.
// By default, tracking mode is enabled. When navigation is stopped, tracking mode is enabled again.
// The preferred device language determines the language for voice notifications used for TTS.
// (Make sure to set language + region in device settings.)
public class NavigationExample {

    private static final String TAG = NavigationExample.class.getName();

    private final Context context;
    private final VisualNavigator visualNavigator;
    private final HEREPositioningProvider herePositioningProvider;
    private final HEREPositioningSimulator herePositioningSimulator;
    private final VoiceAssistant voiceAssistant;
    private final RouteCalculator routeCalculator;
    private int previousManeuverIndex = -1;
    private final Snackbar snackbar;

    public NavigationExample(Context context, MapView mapView) {
        this.context = context;

        // Needed for rerouting, when user leaves route.
        routeCalculator = new RouteCalculator();

        // A class to receive real location events.
        herePositioningProvider = new HEREPositioningProvider();
        // A class to receive simulated location events.
        herePositioningSimulator = new HEREPositioningSimulator();

        try {
            // Without a route set, this starts tracking mode.
            visualNavigator = new VisualNavigator();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of VisualNavigator failed: " + e.error.name());
        }

        // This enables a navigation view including a rendered navigation arrow.
        visualNavigator.startRendering(mapView);

        // A helper class for TTS.
        voiceAssistant = new VoiceAssistant(context);

        setupListeners();

        snackbar = Snackbar.make(mapView, "Initialization completed.", Snackbar.LENGTH_INDEFINITE);
        snackbar.show();
    }

    public void startLocationProvider() {
        // Set navigator as listener to receive locations from HERE Positioning
        // and choose the best accuracy for the tbt navigation use case.
        herePositioningProvider.startLocating(visualNavigator, LocationAccuracy.NAVIGATION);
    }

    private void setupListeners() {

        // Notifies on the progress along the route including maneuver instructions.
        visualNavigator.setRouteProgressListener(new RouteProgressListener() {
            @Override
            public void onRouteProgressUpdated(@NonNull RouteProgress routeProgress) {
                List<SectionProgress> sectionProgressList = routeProgress.sectionProgress;
                // sectionProgressList is guaranteed to be non-empty.
                SectionProgress lastSectionProgress = sectionProgressList.get(sectionProgressList.size() - 1);
                Log.d(TAG, "Distance to destination in meters: " + lastSectionProgress.remainingDistanceInMeters);
                Log.d(TAG, "Traffic delay ahead in seconds: " + lastSectionProgress.trafficDelayInSeconds);

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
                String nextRoadName = nextManeuver.getNextRoadName();
                String road = nextRoadName == null ? nextManeuver.getNextRoadNumber() : nextRoadName;

                // On highways, we want to show the highway number instead of a possible street name,
                // while for inner city and urban areas street names are preferred over road numbers.
                if (nextManeuver.getNextRoadType() == RoadType.HIGHWAY) {
                    road = nextManeuver.getNextRoadNumber() == null ? nextRoadName : nextManeuver.getNextRoadNumber();
                }

                if (action == ManeuverAction.ARRIVE) {
                    // We are approaching the destination, so there's no next road.
                    String currentRoadName = nextManeuver.getRoadName();
                    road = currentRoadName == null ? nextManeuver.getRoadNumber() : currentRoadName;
                }

                if (road == null) {
                    // Happens only in rare cases, when also the fallback is null.
                    road = "unnamed road";
                }

                String logMessage = action.name() + " on " + road +
                        " in " + nextManeuverProgress.remainingDistanceInMeters + " meters.";

                if (previousManeuverIndex != nextManeuverIndex) {
                    snackbar.setText("New maneuver: " + logMessage).show();
                } else {
                    // A maneuver update contains a different distance to reach the next maneuver.
                    snackbar.setText("Maneuver update: " + logMessage).show();
                }

                previousManeuverIndex = nextManeuverIndex;
            }
        });

        // Notifies when the destination of the route is reached.
        visualNavigator.setDestinationReachedListener(new DestinationReachedListener() {
            @Override
            public void onDestinationReached() {
                String message = "Destination reached. Stopping turn-by-turn navigation.";
                snackbar.setText(message).show();
                stopNavigation();
            }
        });

        // Notifies when a waypoint on the route is reached.
        visualNavigator.setMilestoneReachedListener(new MilestoneReachedListener() {
            @Override
            public void onMilestoneReached(@NonNull Milestone milestone) {
                if (milestone.waypointIndex != null) {
                    Log.d(TAG, "A user-defined waypoint was reached, index of waypoint: " + milestone.waypointIndex);
                    Log.d(TAG,"Original coordinates: " + milestone.originalCoordinates);
                } else {
                    // For example, when transport mode changes due to a ferry.
                    Log.d(TAG,"A system defined waypoint was reached at " + milestone.mapMatchedCoordinates);
                }
            }
        });

        // Notifies when the current speed limit is exceeded.
        visualNavigator.setSpeedWarningListener(new SpeedWarningListener() {
            @Override
            public void onSpeedWarningStatusChanged(@NonNull SpeedWarningStatus speedWarningStatus) {
                if (speedWarningStatus == SpeedWarningStatus.SPEED_LIMIT_EXCEEDED) {
                    // Driver is faster than current speed limit (plus an optional offset).
                    // Play a notification sound to alert the driver.
                    // Note that this may not include temporary special speed limits, see SpeedLimitDelegate.
                    Uri ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION);
                    Ringtone ringtone = RingtoneManager.getRingtone(context, ringtoneUri);
                    ringtone.play();
                }

                if (speedWarningStatus == SpeedWarningStatus.SPEED_LIMIT_RESTORED) {
                    Log.d(TAG, "Driver is again slower than current speed limit (plus an optional offset).");
                }
            }
        });

        // Notifies on the current speed limit valid on the current road.
        visualNavigator.setSpeedLimitListener(new SpeedLimitListener() {
            @Override
            public void onSpeedLimitUpdated(@NonNull SpeedLimit speedLimit) {
                Double currentSpeedLimit = getCurrentSpeedLimit(speedLimit);

                if (currentSpeedLimit == null) {
                    Log.d(TAG, "Warning: Speed limits unkown, data could not be retrieved.");
                } else if (currentSpeedLimit == 0) {
                    Log.d(TAG, "No speed limits on this road! Drive as fast as you feel safe ...");
                } else {
                    Log.d(TAG, "Current speed limit (m/s):" + currentSpeedLimit);
                }
            }
        });

        // Notifies on the current map-matched location and other useful information while driving or walking.
        visualNavigator.setNavigableLocationListener(new NavigableLocationListener() {
            @Override
            public void onNavigableLocationUpdated(@NonNull NavigableLocation currentNavigableLocation) {
                MapMatchedLocation mapMatchedLocation = currentNavigableLocation.mapMatchedLocation;
                if (mapMatchedLocation == null) {
                    Log.d(TAG, "The currentNavigableLocation could not be map-matched. Are you off-road?");
                    return;
                }

                Double speed = currentNavigableLocation.originalLocation.speedInMetersPerSecond;
                Double accuracy = currentNavigableLocation.originalLocation.speedAccuracyInMetersPerSecond;
                Log.d(TAG, "Driving speed (m/s): " + speed + "plus/minus an accuracy of: " +accuracy);
            }
        });

        // Notifies on a possible deviation from the route.
        visualNavigator.setRouteDeviationListener(new RouteDeviationListener() {
            @Override
            public void onRouteDeviation(@NonNull RouteDeviation routeDeviation) {
                Route route = visualNavigator.getRoute();
                if (route == null) {
                    // May happen in rare cases when route was set to null inbetween.
                    return;
                }

                // Get current geographic coordinates.
                MapMatchedLocation currentMapMatchedLocation = routeDeviation.currentLocation.mapMatchedLocation;
                GeoCoordinates currentGeoCoordinates = currentMapMatchedLocation == null ?
                        routeDeviation.currentLocation.originalLocation.coordinates : currentMapMatchedLocation.coordinates;

                // Get last geographic coordinates on route.
                GeoCoordinates lastGeoCoordinatesOnRoute;
                if (routeDeviation.lastLocationOnRoute != null) {
                    MapMatchedLocation lastMapMatchedLocationOnRoute = routeDeviation.lastLocationOnRoute.mapMatchedLocation;
                    lastGeoCoordinatesOnRoute = lastMapMatchedLocationOnRoute == null ?
                            routeDeviation.lastLocationOnRoute.originalLocation.coordinates : lastMapMatchedLocationOnRoute.coordinates;
                } else {
                    Log.d(TAG, "User was never following the route. So, we take the start of the route instead.");
                    lastGeoCoordinatesOnRoute = route.getSections().get(0).getDeparturePlace().originalCoordinates;
                }

                int distanceInMeters = (int) currentGeoCoordinates.distanceTo(lastGeoCoordinatesOnRoute);
                Log.d(TAG, "RouteDeviation in meters is " + distanceInMeters);

                // Calculate a new route when deviation is too large. Note that this ignores route alternatives
                // and always takes the first route. Route alternatives are not supported for this example app.
                if (distanceInMeters > 30) {
                    List<Section> sections = route.getSections();
                    GeoCoordinates destinationGeoCoordinates = sections.get(sections.size() - 1).getArrivalPlace().originalCoordinates;
                    routeCalculator.calculateRoute(currentGeoCoordinates, destinationGeoCoordinates, (routingError, routes) -> {
                        if (routingError == null) {
                            visualNavigator.setRoute(routes.get(0));
                            snackbar.setText("Rerouting completed.").show();
                        }
                    });
                }
            }
        });

        // Notifies on voice maneuver messages.
        visualNavigator.setManeuverNotificationListener(new ManeuverNotificationListener() {
            @Override
            public void onManeuverNotification(@NonNull String voiceText) {
                voiceAssistant.speak(voiceText);
            }
        });

        // Notifies which lane(s) lead to the next (next) maneuvers.
        // Note: This feature is in BETA state and thus there can be bugs and unexpected behavior.
        // Related APIs may change for new releases without a deprecation process.
        visualNavigator.setLaneAssistanceListener(new LaneAssistanceListener() {
            @Override
            public void onLaneAssistanceUpdated(@NonNull LaneAssistance laneAssistance) {
                // This lane list is guaranteed to be non-empty.
                List<Lane> lanes = laneAssistance.lanesForNextManeuver;
                logLaneRecommendations(lanes);

                List<Lane> nextLanes = laneAssistance.lanesForNextNextManeuver;
                if (!nextLanes.isEmpty()) {
                    Log.d(TAG, "Attention, the next next maneuver is very close.");
                    Log.d(TAG, "Please take the following lane(s) after the next maneuver: ");
                    logLaneRecommendations(nextLanes);
                }
            }
        });
    }

    private void logLaneRecommendations(List<Lane> lanes) {
        // The lane at index 0 is the leftmost lane adjacent to the middle of the road.
        // The lane at the last index is the rightmost lane.
        // Note: Left-hand countries are not yet supported.
        int laneNumber = 0;
        for (Lane lane : lanes) {
            // This state is only possible if laneAssistance.lanesForNextNextManeuver is not empty.
            // For example, when two lanes go left, this lanes leads only to the next maneuver,
            // but not to the maneuver after the next maneuver, while the highly recommended lane also leads
            // to this next next maneuver.
            if (lane.recommendationState == LaneRecommendationState.RECOMMENDED) {
                Log.d(TAG,"Lane " + laneNumber + " leads to next maneuver, but not to the next next maneuver.");
            }

            // If laneAssistance.lanesForNextNextManeuver is not empty, this lane leads also to the
            // maneuver after the next maneuver.
            if (lane.recommendationState == LaneRecommendationState.HIGHLY_RECOMMENDED) {
                Log.d(TAG,"Lane " + laneNumber + " leads to next maneuver and eventually to the next next maneuver.");
            }

            if (lane.recommendationState == LaneRecommendationState.NOT_RECOMMENDED) {
                Log.d(TAG,"Do not take lane " + laneNumber + " to follow the route.");
            }

            laneNumber++;
        }
    }

    private Double getCurrentSpeedLimit(SpeedLimit speedLimit) {
        // If available, it is recommended to show this value as speed limit to the user.
        // Note that the SpeedWarningStatus only warns when speedLimit.speedLimitInMetersPerSecond is exceeded.
        Double specialSpeedLimit = getSpecialSpeedLimit(speedLimit.specialSpeedSituations);
        if (specialSpeedLimit != null ) {
            return specialSpeedLimit;
        }

        // If no special speed limit is available, show the standard speed limit.
        return speedLimit.speedLimitInMetersPerSecond;
    }

    // An example implementation that will retrieve the slowest speed limit, including advisory speed limits and
    // weather-dependent speed limits that may or may not be valid due to the actual weather condition while driving.
    private Double getSpecialSpeedLimit(List<SpecialSpeedSituation> specialSpeedSituations) {
        Double specialSpeedLimit = null;

        // Iterates through the list of applicable special speed limits, if available.
        for (SpecialSpeedSituation specialSpeedSituation : specialSpeedSituations) {

            // Check if a time restriction is available and if it is currently active.
            boolean timeRestrictionisPresent = false;
            boolean timeRestrictionisActive = false;
            for (TimeDomain timeDomain : specialSpeedSituation.appliesDuring) {
                timeRestrictionisPresent = true;
                if (timeDomain.isActive(new Date())) {
                    timeRestrictionisActive = true;
                }
            }

            if (timeRestrictionisPresent && !timeRestrictionisActive) {
                // We are not interested in currently inactive special speed limits.
                continue;
            }

            if (specialSpeedSituation.type == SpecialSpeedSituationType.ADVISORY_SPEED) {
                Log.d(TAG, "Contains an advisory speed limit. For safety reasons it is recommended to respect it.");
            }

            if (specialSpeedSituation.type == SpecialSpeedSituationType.RAIN ||
                    specialSpeedSituation.type == SpecialSpeedSituationType.SNOW ||
                    specialSpeedSituation.type == SpecialSpeedSituationType.FOG) {
                // The HERE SDK cannot detect the current weather condition, so a driver must decide
                // based on the situation if this speed limit applies.
                // Note: For this example we respect weather related speed limits, even if not applicable
                // due to the current weather condition.
                Log.d(TAG, "Attention: This road has weather dependent speed limits!");
            }

            Double newSpecialSpeedLimit = specialSpeedSituation.specialSpeedLimitInMetersPerSecond;
            Log.d(TAG, "Found special speed limit: " + newSpecialSpeedLimit +
                    " m/s, type: " + specialSpeedSituation.type);

            if (specialSpeedLimit != null && specialSpeedLimit > newSpecialSpeedLimit) {
                // For this example, we are only interested in the slowest special speed limit value,
                // regardless if it is legal, advisory or bound to conditions that may require the decision
                // of the driver.
                specialSpeedLimit = newSpecialSpeedLimit;
            }
        }

        Log.d(TAG, "Slowest special speed limit (m/s): " + specialSpeedLimit);
        return specialSpeedLimit;
    }

    public void startNavigation(Route route, boolean isSimulated) {
        setupSpeedWarnings();
        setupVoiceGuidance();

        // Switches to navigation mode when no route was set before, otherwise navigation mode is kept.
        visualNavigator.setRoute(route);

        if (isSimulated) {
            enableRoutePlayback(route);
            snackbar.setText("Starting simulated navgation.").show();
        } else {
            enableDevicePositioning();
            snackbar.setText("Starting navgation.").show();
        }
    }

    public void stopNavigation() {
        // Switches to tracking mode when a route was set before, otherwise tracking mode is kept.
        // Without a route the navigator will only notify on the current map-matched location
        // including info such as speed and current street name.
        visualNavigator.setRoute(null);
        enableDevicePositioning();
        snackbar.setText("Tracking device's location.").show();
    }

    // Provides simulated location updates based on the given route.
    public void enableRoutePlayback(Route route) {
        herePositioningProvider.stopLocating();
        herePositioningSimulator.startLocating(visualNavigator, route);
    }

    // Provides location updates based on the device's GPS sensor.
    public void enableDevicePositioning() {
        herePositioningSimulator.stopLocating();
        herePositioningProvider.startLocating(visualNavigator, LocationAccuracy.NAVIGATION);
    }

    public void startCameraTracking() {
        visualNavigator.setCameraMode(CameraTrackingMode.ENABLED);
    }

    public void stopCameraTracking() {
        visualNavigator.setCameraMode(CameraTrackingMode.DISABLED);
    }

    @Nullable
    public GeoCoordinates getLastKnownGeoCoordinates() {
        return herePositioningProvider.getLastKnownLocation() == null ? null : herePositioningProvider.getLastKnownLocation().coordinates;
    }

    private void setupSpeedWarnings() {
        double lowSpeedOffsetInMetersPerSecond = 2;
        double highSpeedOffsetInMetersPerSecond = 4;
        double highSpeedBoundaryInMetersPerSecond = 25;
        SpeedLimitOffset speedLimitOffset = new SpeedLimitOffset(
                lowSpeedOffsetInMetersPerSecond, highSpeedOffsetInMetersPerSecond, highSpeedBoundaryInMetersPerSecond);

        visualNavigator.setSpeedWarningOptions(new SpeedWarningOptions(speedLimitOffset));
    }

    private void setupVoiceGuidance() {
        LanguageCode ttsLanguageCode = getLanguageCodeForDevice(VisualNavigator.getAvailableLanguagesForManeuverNotifications());
        visualNavigator.setManeuverNotificationOptions(new ManeuverNotificationOptions(ttsLanguageCode, UnitSystem.METRIC));
        Log.d(TAG, "LanguageCode for maneuver notifications: " + ttsLanguageCode);

        // Set language to our TextToSpeech engine.
        Locale locale = LanguageCodeConverter.getLocale(ttsLanguageCode);
        if (voiceAssistant.setLanguage(locale)) {
            Log.d(TAG, "TextToSpeech engine uses this language: " + locale);
        } else {
            Log.e(TAG, "TextToSpeech engine does not support this language: " + locale);
        }
    }

    // Get the language preferrably used on this device.
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

    public void stopLocating() {
        herePositioningProvider.stopLocating();
    }
}
