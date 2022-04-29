/*
 * Copyright (C) 2019-2022 HERE Europe B.V.
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

package com.here.camerakeyframetracks;

import android.util.Log;

import com.here.camerakeyframetracks.helper.RouteCalculator;
import com.here.camerakeyframetracks.models.LocationKeyframeModel;
import com.here.camerakeyframetracks.models.OrientationKeyframeModel;
import com.here.camerakeyframetracks.models.ScalarKeyframeModel;
import com.here.sdk.animation.EasingFunction;
import com.here.sdk.animation.GeoCoordinatesKeyframe;
import com.here.sdk.animation.GeoOrientationKeyframe;
import com.here.sdk.animation.KeyframeInterpolationMode;
import com.here.sdk.animation.ScalarKeyframe;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.GeoOrientation;
import com.here.sdk.core.GeoOrientationUpdate;
import com.here.sdk.core.Point2D;
import com.here.sdk.core.Rectangle2D;
import com.here.sdk.core.Size2D;
import com.here.sdk.mapview.MapCameraAnimation;
import com.here.sdk.mapview.MapCameraAnimationFactory;
import com.here.sdk.mapview.MapCameraKeyframeTrack;
import com.here.sdk.mapview.MapCameraUpdate;
import com.here.sdk.mapview.MapCameraUpdateFactory;
import com.here.sdk.mapview.MapPolyline;
import com.here.sdk.mapview.MapView;
import com.here.sdk.routing.Route;
import com.here.time.Duration;

import java.util.ArrayList;
import java.util.List;

public class RouteAnimationExample {

    private final MapView mapView;
    private final RouteCalculator routeCalculator;

    public RouteAnimationExample(MapView mapView) {
        this.mapView = mapView;

        // Creates a fixed route for testing purposes.
        routeCalculator = new RouteCalculator(mapView);
        routeCalculator.createRoute();
    }

    List<LocationKeyframeModel> createLocationsForRouteAnimation(Route route) {
        List<LocationKeyframeModel> locationList = new ArrayList<>();
        List<GeoCoordinates> geoCoordinatesList = route.getGeometry().vertices;

        locationList.add(new LocationKeyframeModel(new GeoCoordinates(40.71335297425111, -74.01128262379694), Duration.ofMillis(0)));
        locationList.add(new LocationKeyframeModel(route.getBoundingBox().southWestCorner, Duration.ofMillis(500)));

        for (int i = 0; i < geoCoordinatesList.size() - 1; i++) {
            locationList.add(new LocationKeyframeModel(geoCoordinatesList.get(i), Duration.ofMillis(500)));
        }

        locationList.add(new LocationKeyframeModel(new GeoCoordinates(40.72040734322057, -74.01225894785958), Duration.ofMillis(1000)));

        return locationList;
    }

    private List<OrientationKeyframeModel> createOrientationForRouteAnimation() {
        List<OrientationKeyframeModel> orientationList = new ArrayList<>();
        orientationList.add(new OrientationKeyframeModel(new GeoOrientation(30, 60), Duration.ofMillis(0)));
        orientationList.add(new OrientationKeyframeModel(new GeoOrientation(-40, 70), Duration.ofMillis(2000)));
        orientationList.add(new OrientationKeyframeModel(new GeoOrientation(-10, 70), Duration.ofMillis(1000)));
        orientationList.add(new OrientationKeyframeModel(new GeoOrientation(10, 70), Duration.ofMillis(4000)));
        orientationList.add(new OrientationKeyframeModel(new GeoOrientation(10, 70), Duration.ofMillis(4000)));

        return orientationList;
    }

    private List<ScalarKeyframeModel> createScalarForRouteAnimation() {
        List<ScalarKeyframeModel> scalarList = new ArrayList<>();
        scalarList.add(new ScalarKeyframeModel(80000000.0, Duration.ofMillis(0)));
        scalarList.add(new ScalarKeyframeModel(8000000.0, Duration.ofMillis(1000)));
        scalarList.add(new ScalarKeyframeModel(500.0, Duration.ofMillis(3000)));
        scalarList.add(new ScalarKeyframeModel(500.0, Duration.ofMillis(6000)));
        scalarList.add(new ScalarKeyframeModel(100.0, Duration.ofMillis(4000)));

        return scalarList;
    }

    public void animateRoute(Route route) {
        // A list of location key frames for moving the map camera from one geo coordinate to another.
        List<GeoCoordinatesKeyframe> locationKeyframesList = new ArrayList<>();
        List<LocationKeyframeModel> locationList = createLocationsForRouteAnimation(route);

        for (LocationKeyframeModel locationKeyframeModel: locationList) {
            locationKeyframesList.add(new GeoCoordinatesKeyframe(locationKeyframeModel.geoCoordinates , locationKeyframeModel.duration));
        }

        // A list of geo orientation keyframes for changing the map camera orientation.
        List<GeoOrientationKeyframe> orientationKeyframeList = new ArrayList<>();
        List<OrientationKeyframeModel> orientationList = createOrientationForRouteAnimation();

        for (OrientationKeyframeModel orientationKeyframeModel: orientationList) {
            orientationKeyframeList.add(new GeoOrientationKeyframe(orientationKeyframeModel.geoOrientation, orientationKeyframeModel.duration));
        }

        // A list of scalar key frames for changing the map camera distance from the earth.
        List<ScalarKeyframe> scalarKeyframesList = new ArrayList<>();
        List<ScalarKeyframeModel> scalarList = createScalarForRouteAnimation();

        for (ScalarKeyframeModel scalarKeyframeModel: scalarList) {
            scalarKeyframesList.add(new ScalarKeyframe(scalarKeyframeModel.scalar, scalarKeyframeModel.duration));
        }

        try {
            // Creating a track to add different kinds of animations to the MapCameraKeyframeTrack.
            List<MapCameraKeyframeTrack> tracks = new ArrayList<>();
            tracks.add(MapCameraKeyframeTrack.lookAtDistance(scalarKeyframesList, EasingFunction.LINEAR, KeyframeInterpolationMode.LINEAR));
            tracks.add(MapCameraKeyframeTrack.lookAtTarget(locationKeyframesList, EasingFunction.LINEAR, KeyframeInterpolationMode.LINEAR));
            tracks.add(MapCameraKeyframeTrack.lookAtOrientation(orientationKeyframeList, EasingFunction.LINEAR, KeyframeInterpolationMode.LINEAR));

            // All animation tracks being played here.
            startRouteAnimation(tracks);
        } catch (MapCameraKeyframeTrack.InstantiationException e) {
            Log.e("KeyframeTrackTag", e.toString());
        }
    }

    public void startRouteAnimation(List<MapCameraKeyframeTrack> tracks) {
        try {
            mapView.getCamera().startAnimation(MapCameraAnimationFactory.createAnimation(tracks));
        } catch (MapCameraAnimation.InstantiationException e) {
            Log.e("KeyframeAnimationTag", e.toString());
        }
    }

    public void stopRouteAnimation() {
        mapView.getCamera().cancelAnimations();
    }

    public void animateToRoute(Route route) {
        // Untilt and unrotate the map.
        double bearing = 0;
        double tilt = 0;
        // We want to show the route fitting in the map view without any additional padding.
        Point2D origin = new Point2D(0, 0);
        Size2D sizeInPixels = new Size2D(mapView.getWidth(), mapView.getHeight());
        Rectangle2D mapViewport = new Rectangle2D(origin, sizeInPixels);

        // Animate to route.
        MapCameraUpdate update = MapCameraUpdateFactory.lookAt(
                route.getBoundingBox(),
                new GeoOrientationUpdate(bearing, tilt),
                mapViewport);
        MapCameraAnimation animation =
                MapCameraAnimationFactory.createAnimation(update, Duration.ofMillis(3000), EasingFunction.IN_CUBIC);
        mapView.getCamera().startAnimation(animation);
    }
}
