/*
 * Copyright (C) 2019-2020 HERE Europe B.V.
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

import com.google.android.material.snackbar.Snackbar;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.LanguageCode;
import com.here.sdk.core.UnitSystem;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.mapview.MapCamera;
import com.here.sdk.mapview.MapImage;
import com.here.sdk.mapview.MapImageFactory;
import com.here.sdk.mapview.MapMarker;
import com.here.sdk.mapview.MapView;
import com.here.sdk.navigation.DestinationReachedListener;
import com.here.sdk.navigation.ManeuverNotificationListener;
import com.here.sdk.navigation.ManeuverNotificationOptions;
import com.here.sdk.navigation.ManeuverProgress;
import com.here.sdk.navigation.MapMatchedLocation;
import com.here.sdk.navigation.Milestone;
import com.here.sdk.navigation.MilestoneReachedListener;
import com.here.sdk.navigation.NavigableLocation;
import com.here.sdk.navigation.NavigableLocationListener;
import com.here.sdk.navigation.Navigator;
import com.here.sdk.navigation.RouteDeviation;
import com.here.sdk.navigation.RouteDeviationListener;
import com.here.sdk.navigation.RouteProgress;
import com.here.sdk.navigation.RouteProgressListener;
import com.here.sdk.navigation.SectionProgress;
import com.here.sdk.navigation.SpeedLimitOffset;
import com.here.sdk.navigation.SpeedWarningListener;
import com.here.sdk.navigation.SpeedWarningOptions;
import com.here.sdk.navigation.SpeedWarningStatus;
import com.here.sdk.routing.Maneuver;
import com.here.sdk.routing.ManeuverAction;
import com.here.sdk.routing.Route;

import java.util.List;
import java.util.Locale;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import static com.here.navigation.RoutingExample.DEFAULT_DISTANCE_IN_METERS;
import static com.here.navigation.RoutingExample.DEFAULT_MAP_CENTER;

// Shows how to start and stop turn-by-turn navigation.
// By default, tracking mode is enabled. When navigation is stopped, tracking mode is enabled again.
// The preferred device language determines the language for voice notifications used for TTS.
// (Make sure to set language + region in device settings.)
public class NavigationExample {

    private static final String TAG = NavigationExample.class.getName();

    private final Context context;
    private final MapView mapView;
    private final LocationProviderImplementation locationProvider;
    private final Navigator navigator;
    private final MapMarker navigationArrow;
    private final MapMarker trackingArrow;
    private final VoiceAssistant voiceAssistant;
    private int previousManeuverIndex = -1;

    public NavigationExample(Context context, MapView mapView) {
        this.context = context;
        this.mapView = mapView;

        navigationArrow = createArrow(R.drawable.arrow_blue);
        trackingArrow = createArrow(R.drawable.arrow_green);

        try {
            // Without a route set, this starts tracking mode.
            navigator = new Navigator();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of Navigator failed: " + e.error.name());
        }

        locationProvider = new LocationProviderImplementation();
        // Set navigator as listener to receive locations from HERE Positioning or from LocationSimulator.
        locationProvider.setListener(navigator);
        locationProvider.start();

        // A helper class for TTS.
        voiceAssistant = new VoiceAssistant(context);

        setupListeners();
    }

    private MapMarker createArrow(int resource) {
        MapImage mapImage = MapImageFactory.fromResource(context.getResources(), resource);
        return new MapMarker(DEFAULT_MAP_CENTER, mapImage);
    }

    private void setupListeners() {

        // Notifies on the progress along the route including maneuver instructions.
        navigator.setRouteProgressListener(new RouteProgressListener() {
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
                Maneuver nextManeuver = navigator.getManeuver(nextManeuverIndex);
                if (nextManeuver == null) {
                    // Should never happen as we retrieved the next maneuver progress above.
                    return;
                }

                ManeuverAction action = nextManeuver.getAction();
                String nextRoadName = nextManeuver.getNextRoadName();
                String road = nextRoadName == null ? nextManeuver.getNextRoadNumber() : nextRoadName;

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
                    // Show only new maneuvers and ignore changes in distance.
                    Snackbar.make(mapView, "New maneuver: " + logMessage, Snackbar.LENGTH_LONG).show();
                }

                previousManeuverIndex = nextManeuverIndex;
            }
        });

        // Notifies when the destination of the route is reached.
        navigator.setDestinationReachedListener(new DestinationReachedListener() {
            @Override
            public void onDestinationReached() {
                String message = "Destination reached. Stopping turn-by-turn navigation.";
                Snackbar.make(mapView, message, Snackbar.LENGTH_LONG).show();
                stopNavigation();
            }
        });

        // Notifies when a waypoint on the route is reached.
        navigator.setMilestoneReachedListener(new MilestoneReachedListener() {
            @Override
            public void onMilestoneReached(Milestone milestone) {
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
        navigator.setSpeedWarningListener(new SpeedWarningListener() {
            @Override
            public void onSpeedWarningStatusChanged(SpeedWarningStatus speedWarningStatus) {
                if (speedWarningStatus == SpeedWarningStatus.SPEED_LIMIT_EXCEEDED) {
                    // Driver is faster than current speed limit (plus an optional offset).
                    // Play a notification sound to alert the driver.
                    Uri ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION);
                    Ringtone ringtone = RingtoneManager.getRingtone(context, ringtoneUri);
                    ringtone.play();
                }

                if (speedWarningStatus == SpeedWarningStatus.SPEED_LIMIT_RESTORED) {
                    Log.d(TAG, "Driver is again slower than current speed limit (plus an optional offset).");
                }
            }
        });

        // Notifies on the current map-matched location and other useful information while driving or walking.
        navigator.setNavigableLocationListener(new NavigableLocationListener() {
            @Override
            public void onNavigableLocationUpdated(@NonNull NavigableLocation currentNavigableLocation) {
                MapMatchedLocation mapMatchedLocation = currentNavigableLocation.mapMatchedLocation;
                if (mapMatchedLocation == null) {
                    Snackbar.make(mapView,
                            "This new location could not be map-matched. Using raw location.",
                            Snackbar.LENGTH_SHORT).show();
                    updateMapView(currentNavigableLocation.originalLocation.coordinates,
                            currentNavigableLocation.originalLocation.bearingInDegrees);
                    return;
                }

                Log.d(TAG, "Current street: " + currentNavigableLocation.streetName);

                // Get speed limits for drivers.
                if (currentNavigableLocation.speedLimitInMetersPerSecond == null) {
                    Log.d(TAG, "Warning: Speed limits unkown, data could not be retrieved.");
                } else if (currentNavigableLocation.speedLimitInMetersPerSecond == 0) {
                    Log.d(TAG, "No speed limits on this road! Drive as fast as you feel safe ...");
                } else {
                    Log.d(TAG, "Current speed limit (m/s): " + currentNavigableLocation.speedLimitInMetersPerSecond);
                }

                updateMapView(mapMatchedLocation.coordinates, mapMatchedLocation.bearingInDegrees);
            }
        });

        // Notifies on a possible deviation from the route.
        navigator.setRouteDeviationListener(new RouteDeviationListener() {
            @Override
            public void onRouteDeviation(@NonNull RouteDeviation routeDeviation) {
                Route route = navigator.getRoute();
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
                    lastGeoCoordinatesOnRoute = route.getSections().get(0).getDeparture().mapMatchedCoordinates;
                }

                int distanceInMeters = (int) currentGeoCoordinates.distanceTo(lastGeoCoordinatesOnRoute);
                Log.d(TAG, "RouteDeviation in meters is " + distanceInMeters);
            }
        });

        // Notifies on voice maneuver messages.
        navigator.setManeuverNotificationListener(new ManeuverNotificationListener() {
            @Override
            public void onManeuverNotification(@NonNull String voiceText) {
                voiceAssistant.speak(voiceText);
            }
        });
    }

    // Update location and rotation of map. Update location of arrows.
    private void updateMapView(GeoCoordinates currentGeoCoordinates,
                               Double bearingInDegrees) {
        MapCamera.OrientationUpdate orientation = new MapCamera.OrientationUpdate();
        orientation.bearing = bearingInDegrees;
        mapView.getCamera().lookAt(currentGeoCoordinates, orientation, DEFAULT_DISTANCE_IN_METERS);
        navigationArrow.setCoordinates(currentGeoCoordinates);
        trackingArrow.setCoordinates(currentGeoCoordinates);
    }

    public void startNavigation(Route route, boolean isSimulated) {
        setupSpeedWarnings();
        setupVoiceGuidance();

        // Switches to navigation mode when no route was set before, otherwise navigation mode is kept.
        navigator.setRoute(route);

        if (isSimulated) {
            locationProvider.enableRoutePlayback(route);
        } else {
            locationProvider.enableDevicePositioning();
        }

        mapView.getMapScene().addMapMarker(navigationArrow);
        updateArrowLocations();
    }

    public void stopNavigation() {
        // Switches to tracking mode when a route was set before, otherwise tracking mode is kept.
        navigator.setRoute(null);
        mapView.getMapScene().removeMapMarker(navigationArrow);
    }

    public void startTracking() {
        // Reset route in case TBT was started before.
        // Without a route the navigator will only notify on the current map-matched location
        // including info such as speed and current street name.
        navigator.setRoute(null);
        locationProvider.enableDevicePositioning();

        mapView.getMapScene().addMapMarker(trackingArrow);
        updateArrowLocations();
        Snackbar.make(mapView, "Free tracking: Running.", Snackbar.LENGTH_SHORT).show();
    }

    public void stopTracking() {
        mapView.getMapScene().removeMapMarker(trackingArrow);
        Snackbar.make(mapView, "Free tracking: Stopped.", Snackbar.LENGTH_SHORT).show();
    }

    private void updateArrowLocations() {
        GeoCoordinates lastKnownGeoCoordinates = getLastKnownGeoCoordinates();
        if (lastKnownGeoCoordinates != null) {
            navigationArrow.setCoordinates(lastKnownGeoCoordinates);
            trackingArrow.setCoordinates(lastKnownGeoCoordinates);
        } else {
            Log.d(TAG, "Can't update arrows: No location found.");
        }
    }

    @Nullable
    public GeoCoordinates getLastKnownGeoCoordinates() {
        return locationProvider.lastKnownLocation == null ? null : locationProvider.lastKnownLocation.coordinates;
    }

    private void setupSpeedWarnings() {
        double lowSpeedOffsetInMetersPerSecond = 2;
        double highSpeedOffsetInMetersPerSecond = 4;
        double highSpeedBoundaryInMetersPerSecond = 25;
        SpeedLimitOffset speedLimitOffset = new SpeedLimitOffset(
                lowSpeedOffsetInMetersPerSecond, highSpeedOffsetInMetersPerSecond, highSpeedBoundaryInMetersPerSecond);

        navigator.setSpeedWarningOptions(new SpeedWarningOptions(speedLimitOffset));
    }

    private void setupVoiceGuidance() {
        LanguageCode ttsLanguageCode = getLanguageCodeForDevice(navigator.getSupportedLanguagesForManeuverNotifications());
        navigator.setManeuverNotificationOptions(new ManeuverNotificationOptions(ttsLanguageCode, UnitSystem.METRIC));
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
}
