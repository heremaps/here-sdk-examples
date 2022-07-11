/*
 * Copyright (C) 2019-2022 HERE Europe B.V.
 *
 * Licensed under the Apache License, Version 2.0 (the "License")
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

import 'dart:core';

import 'package:camera_keyframe_tracks_app/models/LocationKeyframeModel.dart';
import 'package:camera_keyframe_tracks_app/models/OrientationKeyframeModel.dart';
import 'package:camera_keyframe_tracks_app/models/ScalarKeyframeModel.dart';
import 'package:here_sdk/animation.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';

class CameraKeyframeTracksExample {
  final HereMapController _hereMapController;
  List<MapCameraKeyframeTrack> _tracks = [];

  CameraKeyframeTracksExample(HereMapController hereMapController) : _hereMapController = hereMapController;

  void startTripToNYC() {
    // This animation can be started and replayed. When started, it will always start from globe view.
    List<MapCameraKeyframeTrack> tracks = _createTripToNYCAnimation();
    _startTripToNYCAnimation(tracks);
  }

  void stopTripToNYCAnimation() {
    _hereMapController.camera.cancelAnimations();
  }

  List<LocationKeyframeModel> _createLocationsForTripToNYC() {
    List<LocationKeyframeModel> locationList = [];

    locationList.addAll([
      LocationKeyframeModel(GeoCoordinates(40.685869754854544, -74.02550202768754), const Duration(milliseconds: 0)), // Statue of Liberty
      LocationKeyframeModel(GeoCoordinates(40.69051652745291, -74.04455943649657), const Duration(milliseconds: 5000)), // Statue of Liberty
      LocationKeyframeModel(GeoCoordinates(40.69051652745291, -74.04455943649657), const Duration(milliseconds: 7000)), // Statue of Liberty
      LocationKeyframeModel(GeoCoordinates(40.69051652745291, -74.04455943649657), const Duration(milliseconds: 9000)), // Statue of Liberty
      LocationKeyframeModel(GeoCoordinates(40.690266839135, -74.01237515471776), const Duration(milliseconds: 5000)), // Governor Island
      LocationKeyframeModel(GeoCoordinates(40.7116777285189, -74.01248494562448), const Duration(milliseconds: 6000)), // World Trade Center
      LocationKeyframeModel(GeoCoordinates(40.71083291395444, -74.01226399217569), const Duration(milliseconds: 6000)), // World Trade Center
      LocationKeyframeModel(GeoCoordinates(40.719259512385506, -74.01171007254635), const Duration(milliseconds: 5000)), // Manhattan College
      LocationKeyframeModel(GeoCoordinates(40.73603959180013, -73.98968489844603), const Duration(milliseconds: 6000)), // Union Square
      LocationKeyframeModel(GeoCoordinates(40.741732824650214, -73.98825255774022), const Duration(milliseconds: 5000)), // Flatiron
      LocationKeyframeModel(GeoCoordinates(40.74870637098952, -73.98515306630678), const Duration(milliseconds: 6000)), // Empire State Building
      LocationKeyframeModel(GeoCoordinates(40.742693509776856, -73.95937093336781), const Duration(milliseconds: 3000)), // Queens Midtown
      LocationKeyframeModel(GeoCoordinates(40.75065611103842, -73.96053139022635), const Duration(milliseconds: 4000)), // Roosevelt Island
      LocationKeyframeModel(GeoCoordinates(40.756823163883794, -73.95461519921352), const Duration(milliseconds: 4000)), // Queens Bridge
      LocationKeyframeModel(GeoCoordinates(40.763573707276784, -73.94571562970638), const Duration(milliseconds: 4000)), // Roosevelt Bridge
      LocationKeyframeModel(GeoCoordinates(40.773052036400294, -73.94027981305442), const Duration(milliseconds: 3000)), // Roosevelt Lighthouse
      LocationKeyframeModel(GeoCoordinates(40.78270548734745, -73.92189566092568), const Duration(milliseconds: 3000)), // Hell gate Bridge
      LocationKeyframeModel(GeoCoordinates(40.78406704306872, -73.91746017917936), const Duration(milliseconds: 2000)), // Ralph Park
      LocationKeyframeModel(GeoCoordinates(40.768075472169045, -73.97446921306035), const Duration(milliseconds: 2000)), // Wollman Rink
      LocationKeyframeModel(GeoCoordinates(40.78255966255712, -73.9586425508515), const Duration(milliseconds: 3000)) // Solomon Museum
    ]);

    return locationList;
  }

  List<OrientationKeyframeModel> _createOrientationsForTripToNYC() {
    List<OrientationKeyframeModel> orientationList = [];

    orientationList.addAll([
      OrientationKeyframeModel(GeoOrientation(30, 60), const Duration(milliseconds: 0)),
      OrientationKeyframeModel(GeoOrientation(-40, 80), const Duration(milliseconds: 6000)),
      OrientationKeyframeModel(GeoOrientation(30, 70), const Duration(milliseconds: 6000)),
      OrientationKeyframeModel(GeoOrientation(70, 30), const Duration(milliseconds: 4000)),
      OrientationKeyframeModel(GeoOrientation(-30, 70), const Duration(milliseconds: 5000)),
      OrientationKeyframeModel(GeoOrientation(30, 70), const Duration(milliseconds: 5000)),
      OrientationKeyframeModel(GeoOrientation(40, 70), const Duration(milliseconds: 5000)),
      OrientationKeyframeModel(GeoOrientation(80, 40), const Duration(milliseconds: 5000)),
      OrientationKeyframeModel(GeoOrientation(30, 70), const Duration(milliseconds: 5000))
    ]);

    return orientationList;
  }

  List<ScalarKeyframeModel> _createScalarsForTripToNYC() {
    List<ScalarKeyframeModel> scalarList = [];

    scalarList.add(ScalarKeyframeModel(80000000.0, const Duration(milliseconds: 0)));
    scalarList.add(ScalarKeyframeModel(8000000.0, const Duration(milliseconds: 2000)));
    scalarList.add(ScalarKeyframeModel(8000.0, const Duration(milliseconds: 2000)));
    scalarList.add(ScalarKeyframeModel(1000.0, const Duration(milliseconds: 2000)));
    scalarList.add(ScalarKeyframeModel(400.0, const Duration(milliseconds: 3000)));

    return scalarList;
  }

  List<MapCameraKeyframeTrack> _createTripToNYCAnimation() {
    // A list of location key frames for moving the map camera from one geo coordinate to another.
    List<GeoCoordinatesKeyframe> locationKeyframesList = [];
    List<LocationKeyframeModel> locationList = _createLocationsForTripToNYC();

    for (LocationKeyframeModel locationKeyframeModel in locationList) {
      locationKeyframesList
          .add(GeoCoordinatesKeyframe(locationKeyframeModel.geoCoordinates, locationKeyframeModel.duration));
    }

    // A list of geo orientation keyframes for changing the map camera orientation.
    List<GeoOrientationKeyframe> orientationKeyframeList = [];
    List<OrientationKeyframeModel> orientationList = _createOrientationsForTripToNYC();

    for (OrientationKeyframeModel orientationKeyframeModel in orientationList) {
      orientationKeyframeList
          .add(GeoOrientationKeyframe(orientationKeyframeModel.geoOrientation, orientationKeyframeModel.duration));
    }

    // A list of scalar key frames for changing the map camera distance from the earth.
    List<ScalarKeyframe> scalarKeyframesList = [];
    List<ScalarKeyframeModel> scalarList = _createScalarsForTripToNYC();

    for (ScalarKeyframeModel scalarKeyframeModel in scalarList) {
      scalarKeyframesList.add(ScalarKeyframe(scalarKeyframeModel.scalar, scalarKeyframeModel.duration));
    }

    try {
      // Creating a track to add different kinds of animations to the MapCameraKeyframeTrack.
      _tracks = [];
      _tracks.add(MapCameraKeyframeTrack.lookAtDistance(
          scalarKeyframesList, EasingFunction.linear, KeyframeInterpolationMode.linear));
      _tracks.add(MapCameraKeyframeTrack.lookAtTarget(
          locationKeyframesList, EasingFunction.linear, KeyframeInterpolationMode.linear));
      _tracks.add(MapCameraKeyframeTrack.lookAtOrientation(
          orientationKeyframeList, EasingFunction.linear, KeyframeInterpolationMode.linear));
    } on MapCameraKeyframeTrackInstantiationException catch (e) {
      // Throws an error if keyframes is empty or duration of keyframes are invalid.
      print("KeyframeTrackTag: " + e.error.name);
    }

    return _tracks;
  }

  void _startTripToNYCAnimation(List<MapCameraKeyframeTrack> tracks) {
    try {
      _hereMapController.camera.startAnimation(MapCameraAnimationFactory.createAnimationFromKeyframeTracks(tracks));
    } on MapCameraKeyframeTrackInstantiationException catch (e) {
      print("KeyframeAnimationTag: " + e.error.name);
    }
  }
}
