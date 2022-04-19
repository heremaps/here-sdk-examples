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

package com.here.camerakeyframetracks.animations;

import android.util.Log;

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
import com.here.sdk.mapview.MapCameraAnimation;
import com.here.sdk.mapview.MapCameraAnimationFactory;
import com.here.sdk.mapview.MapCameraKeyframeTrack;
import com.here.sdk.mapview.MapView;
import com.here.time.Duration;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class CameraKeyframeTracksExample {

    private final MapView mapView;
    private List<MapCameraKeyframeTrack> tracks = new ArrayList<>();

    public CameraKeyframeTracksExample(MapView mapView) {
        this.mapView = mapView;
    }

    public void startTripToNYC() {
        // This animation can be started and replayed. When started, it will always start from globe view.
        List<MapCameraKeyframeTrack> tracks = createTripToNYCAnimation();
        startTripToNYCAnimation(tracks);
    }

    public void stopTripToNYCAnimation() {
        mapView.getCamera().cancelAnimations();
    }

    private List<LocationKeyframeModel> createLocationsForTripToNYC() {
        List<LocationKeyframeModel> locationList = new ArrayList<>();

        Collections.addAll(
                locationList,
                new LocationKeyframeModel(new GeoCoordinates(40.685869754854544, -74.02550202768754), Duration.ofMillis(0)), // Statue of Liberty
                new LocationKeyframeModel(new GeoCoordinates(40.69051652745291, -74.04455943649657), Duration.ofMillis(5000)), // Statue of Liberty
                new LocationKeyframeModel(new GeoCoordinates(40.69051652745291, -74.04455943649657), Duration.ofMillis(7000)), // Statue of Liberty
                new LocationKeyframeModel(new GeoCoordinates(40.69051652745291, -74.04455943649657), Duration.ofMillis(9000)), // Statue of Liberty
                new LocationKeyframeModel(new GeoCoordinates(40.690266839135, -74.01237515471776), Duration.ofMillis(5000)), // Governor Island
                new LocationKeyframeModel(new GeoCoordinates(40.7116777285189, -74.01248494562448), Duration.ofMillis(6000)), // World Trade Center
                new LocationKeyframeModel(new GeoCoordinates(40.71083291395444, -74.01226399217569), Duration.ofMillis(6000)), // World Trade Center
                new LocationKeyframeModel(new GeoCoordinates(40.719259512385506, -74.01171007254635), Duration.ofMillis(5000)), // Manhattan College
                new LocationKeyframeModel(new GeoCoordinates(40.73603959180013, -73.98968489844603), Duration.ofMillis(6000)), // Union Square
                new LocationKeyframeModel(new GeoCoordinates(40.741732824650214, -73.98825255774022), Duration.ofMillis(5000)), // Flatiron
                new LocationKeyframeModel(new GeoCoordinates(40.74870637098952, -73.98515306630678), Duration.ofMillis(6000)), // Empire State Building
                new LocationKeyframeModel(new GeoCoordinates(40.742693509776856, -73.95937093336781), Duration.ofMillis(3000)), // Queens Midtown
                new LocationKeyframeModel(new GeoCoordinates(40.75065611103842, -73.96053139022635), Duration.ofMillis(4000)), // Roosevelt Island
                new LocationKeyframeModel(new GeoCoordinates(40.756823163883794, -73.95461519921352), Duration.ofMillis(4000)), // Queens Bridge
                new LocationKeyframeModel(new GeoCoordinates(40.763573707276784, -73.94571562970638), Duration.ofMillis(4000)), // Roosevelt Bridge
                new LocationKeyframeModel(new GeoCoordinates(40.773052036400294, -73.94027981305442), Duration.ofMillis(3000)), // Roosevelt Lighthouse
                new LocationKeyframeModel(new GeoCoordinates(40.78270548734745, -73.92189566092568), Duration.ofMillis(3000)), // Hell gate Bridge
                new LocationKeyframeModel(new GeoCoordinates(40.78406704306872, -73.91746017917936), Duration.ofMillis(2000)), // Ralph Park
                new LocationKeyframeModel(new GeoCoordinates(40.768075472169045, -73.97446921306035), Duration.ofMillis(2000)), // Wollman Rink
                new LocationKeyframeModel(new GeoCoordinates(40.78255966255712, -73.9586425508515), Duration.ofMillis(3000)), // Solomon Museum
                new LocationKeyframeModel(new GeoCoordinates(40.80253970834194, -73.93156255568137), Duration.ofMillis(3000)), // Vintage Autobody
                new LocationKeyframeModel(new GeoCoordinates(40.79780371121212, -73.92238900253808), Duration.ofMillis(4000)), // Robert Kennedy Bridge
                new LocationKeyframeModel(new GeoCoordinates(40.80771345637072, -73.93250541322794), Duration.ofMillis(3000)), // Third Avenue Bridge
                new LocationKeyframeModel(new GeoCoordinates(40.820213148574766, -73.94930111845413), Duration.ofMillis(3000)), // City College NYC
                new LocationKeyframeModel(new GeoCoordinates(40.84692287418771, -73.92803657908391), Duration.ofMillis(1500)), // Washington Bridge
                new LocationKeyframeModel(new GeoCoordinates(40.85851487236918, -73.91388539084845), Duration.ofMillis(2000)), // Hall of Fame for Americans
                new LocationKeyframeModel(new GeoCoordinates(40.87784894879347, -73.92238697760786), Duration.ofMillis(2000)), // Henry Hudson Bridge
                new LocationKeyframeModel(new GeoCoordinates(40.881034859141806, -73.920040015101), Duration.ofMillis(1500)), // Henry Hudson Park
                new LocationKeyframeModel(new GeoCoordinates(41.067415618493946, -73.86134115274218), Duration.ofMillis(1500)) // Transfiguration Church
        );

        return locationList;
    }

    private List<OrientationKeyframeModel> createOrientationsForTripToNYC() {
        List<OrientationKeyframeModel> orientationList = new ArrayList<>();

        Collections.addAll(
                orientationList,
                new OrientationKeyframeModel(new GeoOrientation(30, 60), Duration.ofMillis(0)),
                new OrientationKeyframeModel(new GeoOrientation(-40, 80), Duration.ofMillis(6000)),
                new OrientationKeyframeModel(new GeoOrientation(30, 70), Duration.ofMillis(6000)),
                new OrientationKeyframeModel(new GeoOrientation(70, 30), Duration.ofMillis(4000)),
                new OrientationKeyframeModel(new GeoOrientation(-30, 70), Duration.ofMillis(5000)),
                new OrientationKeyframeModel(new GeoOrientation(30, 70), Duration.ofMillis(5000)),
                new OrientationKeyframeModel(new GeoOrientation(40, 70), Duration.ofMillis(5000)),
                new OrientationKeyframeModel(new GeoOrientation(80, 40), Duration.ofMillis(5000)),
                new OrientationKeyframeModel(new GeoOrientation(30, 70), Duration.ofMillis(5000))
        );

        return orientationList;
    }

    private List<ScalarKeyframeModel> createScalarsForTripToNYC() {
        List<ScalarKeyframeModel> scalarList = new ArrayList<>();

        scalarList.add(new ScalarKeyframeModel(80000000.0, Duration.ofMillis(0)));
        scalarList.add(new ScalarKeyframeModel(8000000.0, Duration.ofMillis(4000)));
        scalarList.add(new ScalarKeyframeModel(500.0, Duration.ofMillis(5000)));

        return scalarList;
    }

    private List<MapCameraKeyframeTrack> createTripToNYCAnimation() {
        // A list of location key frames for moving the map camera from one geo coordinate to another.
        List<GeoCoordinatesKeyframe> locationKeyframesList = new ArrayList<>();
        List<LocationKeyframeModel> locationList = createLocationsForTripToNYC();

        for (LocationKeyframeModel locationKeyframeModel: locationList) {
            locationKeyframesList.add(new GeoCoordinatesKeyframe(locationKeyframeModel.geoCoordinates , locationKeyframeModel.duration));
        }

        // A list of geo orientation keyframes for changing the map camera orientation.
        List<GeoOrientationKeyframe> orientationKeyframeList = new ArrayList<>();
        List<OrientationKeyframeModel> orientationList = createOrientationsForTripToNYC();

        for (OrientationKeyframeModel orientationKeyframeModel: orientationList) {
            orientationKeyframeList.add(new GeoOrientationKeyframe(orientationKeyframeModel.geoOrientation , orientationKeyframeModel.duration));
        }

        // A list of scalar key frames for changing the map camera distance from the earth.
        List<ScalarKeyframe> scalarKeyframesList = new ArrayList<>();
        List<ScalarKeyframeModel> scalarList = createScalarsForTripToNYC();

        for (ScalarKeyframeModel scalarKeyframeModel: scalarList) {
            scalarKeyframesList.add(new ScalarKeyframe(scalarKeyframeModel.scalar, scalarKeyframeModel.duration));
        }

        try {
            // Creating a track to add different kinds of animations to the MapCameraKeyframeTrack.
            tracks = new ArrayList<>();
            tracks.add(MapCameraKeyframeTrack.lookAtDistance(scalarKeyframesList, EasingFunction.LINEAR, KeyframeInterpolationMode.LINEAR));
            tracks.add(MapCameraKeyframeTrack.lookAtTarget(locationKeyframesList, EasingFunction.LINEAR, KeyframeInterpolationMode.LINEAR));
            tracks.add(MapCameraKeyframeTrack.lookAtOrientation(orientationKeyframeList, EasingFunction.LINEAR, KeyframeInterpolationMode.LINEAR));
        } catch (MapCameraKeyframeTrack.InstantiationException e) {
            // Throws an error if keyframes is empty or duration of keyframes are invalid.
            Log.e("KeyframeTrackTag", e.toString());
        }

        return tracks;
    }

    private void startTripToNYCAnimation(List<MapCameraKeyframeTrack> tracks) {
        try {
            mapView.getCamera().startAnimation(MapCameraAnimationFactory.createAnimation(tracks));
        } catch (MapCameraAnimation.InstantiationException e) {
            Log.e("KeyframeAnimationTag", e.error.name());
        }
    }
}
