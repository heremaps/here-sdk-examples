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
import android.support.annotation.NonNull;
import android.support.annotation.Nullable;
import android.support.design.widget.Snackbar;
import android.util.Log;

import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.Location;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.mapview.MapCamera;
import com.here.sdk.mapview.MapImage;
import com.here.sdk.mapview.MapImageFactory;
import com.here.sdk.mapview.MapMarker;
import com.here.sdk.mapview.MapView;
import com.here.sdk.navigation.CurrentLocation;
import com.here.sdk.navigation.CurrentLocationListener;
import com.here.sdk.navigation.Navigator;
import com.here.sdk.navigation.RouteDeviation;
import com.here.sdk.navigation.RouteDeviationListener;
import com.here.sdk.navigation.RouteProgress;
import com.here.sdk.navigation.RouteProgressListener;
import com.here.sdk.navigation.SectionProgress;
import com.here.sdk.routing.Maneuver;
import com.here.sdk.routing.ManeuverAction;
import com.here.sdk.routing.Route;

import java.util.List;

import static com.here.navigation.RoutingExample.DEFAULT_DISTANCE_IN_METERS;
import static com.here.navigation.RoutingExample.DEFAULT_MAP_CENTER;

// Shows how to start and stop turn-by-turn navigation.
// By default, tracking mode is enabled. When navigation is stopped, tracking mode is enabled again.
public class NavigationExample {

    private static final String TAG = NavigationExample.class.getName();

    private final Context context;
    private final MapView mapView;
    private final LocationProviderImplementation locationProvider;
    private final Navigator navigator;
    private final MapMarker navigationArrow;
    private final MapMarker trackingArrow;
    private int previousManeuverIndex = -1;

    public NavigationExample(Context context, MapView mapView) {
        this.context = context;
        this.mapView = mapView;

        navigationArrow = createArrow(R.drawable.arrow_blue);
        trackingArrow = createArrow(R.drawable.arrow_green);

        locationProvider = new LocationProviderImplementation(context);
        locationProvider.start();

        try {
            // Without a route set, this starts tracking mode.
            navigator = new Navigator(locationProvider);
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of Navigator failed: " + e.error.name());
        }

        setupListeners();
    }

    private MapMarker createArrow(int resource) {
        MapImage mapImage = MapImageFactory.fromResource(context.getResources(), resource);
        return new MapMarker(DEFAULT_MAP_CENTER, mapImage);
    }

    private void setupListeners() {
        navigator.setRouteProgressListener(new RouteProgressListener() {
            @Override
            public void onRouteProgressUpdated(@NonNull RouteProgress routeProgress) {
                List<SectionProgress> sectionProgressList = routeProgress.sectionProgress;
                // sectionProgressList is guaranteed to be non-empty.
                SectionProgress lastSectionProgress = sectionProgressList.get(sectionProgressList.size() - 1);
                Log.d(TAG, "Distance to destination in meters: " + lastSectionProgress.remainingDistanceInMeters);
                Log.d(TAG, "Traffic delay ahead in seconds: " + lastSectionProgress.trafficDelayInSeconds);

                int maneuverIndex = routeProgress.currentManeuverIndex;
                Maneuver maneuver = navigator.getManeuver(maneuverIndex);

                if (maneuver == null) {
                    Log.d(TAG, "No maneuver available.");
                    return;
                }

                ManeuverAction action = maneuver.getAction();
                String nextRoadName = maneuver.getNextRoadName();
                String road = nextRoadName == null ? maneuver.getNextRoadNumber() : nextRoadName;

                if (action == ManeuverAction.ARRIVE) {
                    // We are approaching the destination, so there's no next road.
                    String roadName = maneuver.getRoadName();
                    road = roadName == null ? maneuver.getRoadNumber() : roadName;
                }

                if (road == null) {
                    // Happens only in rare cases, when also the fallback is null.
                    road = "unnamed road";
                }

                String logMessage = action.name() + " on " + road +
                        " in " + routeProgress.currentManeuverRemainingDistanceInMeters + " meters.";

                if (previousManeuverIndex != maneuverIndex) {
                    // Show only new maneuvers and ignore changes in distance.
                    Snackbar.make(mapView, "New maneuver: " + logMessage, Snackbar.LENGTH_LONG).show();
                }

                previousManeuverIndex = maneuverIndex;
            }
        });

        navigator.setCurrentLocationListener(new CurrentLocationListener() {
            @Override
            public void onCurrentLocationUpdated(CurrentLocation currentLocation) {
                Location mapMatchedLocation = currentLocation.mapMatchedLocation;
                if (mapMatchedLocation == null) {
                    Snackbar.make(mapView,
                            "This new location could not be map-matched. Using raw location.",
                            Snackbar.LENGTH_SHORT).show();
                    updateMapView(currentLocation.rawLocation);
                    return;
                }

                Log.d(TAG, "Current street: " + currentLocation.streetName);
                if (currentLocation.speedLimitInMetersPerSecond == 0) {
                    Log.d(TAG, "No speed limits on this road! Drive as fast as you feel safe ...");
                } else {
                    // Can be null if the data could not be retrieved. In this case the real speed limits are unknown.
                    Log.d(TAG, "Current speed limit (m/s): " + currentLocation.speedLimitInMetersPerSecond);
                }

                updateMapView(mapMatchedLocation);
            }
        });

        navigator.setRouteDeviationListener(new RouteDeviationListener() {
            @Override
            public void onRouteDeviation(@NonNull RouteDeviation routeDeviation) {
                int distanceInMeters = (int) routeDeviation.currentLocation.coordinates.distanceTo(
                        routeDeviation.lastLocationOnRoute.coordinates);
                Log.d(TAG, "RouteDeviation in meters is " + distanceInMeters);
            }
        });
    }

    // Update location and rotation of map. Update location of arrow.
    private void updateMapView(Location currentLocation) {
        MapCamera.OrientationUpdate orientation = new MapCamera.OrientationUpdate();
        if (currentLocation.bearingInDegrees != null) {
            orientation.bearing = currentLocation.bearingInDegrees;
        }

        GeoCoordinates currentGeoCoordinates = currentLocation.coordinates;
        mapView.getCamera().lookAt(currentGeoCoordinates, orientation, DEFAULT_DISTANCE_IN_METERS);
        navigationArrow.setCoordinates(currentGeoCoordinates);
        trackingArrow.setCoordinates(currentGeoCoordinates);
    }

    public void startNavigation(Route route, boolean isSimulated) {
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
        navigator.setRoute(null);
        mapView.getMapScene().removeMapMarker(navigationArrow);
    }

    public void startTracking() {
         // Reset route in case TBT was started before.
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
}
