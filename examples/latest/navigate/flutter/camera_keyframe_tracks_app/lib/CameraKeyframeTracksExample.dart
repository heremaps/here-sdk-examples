/*
 * Copyright (C) 2019-2025 HERE Europe B.V.
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

import 'package:here_sdk/animation.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';

class CameraKeyframeTracksExample {

  static final String _tag = (CameraKeyframeTracksExample).toString();

  final HereMapController _hereMapController;

  CameraKeyframeTracksExample(HereMapController hereMapController) : _hereMapController = hereMapController;

  void startTripToNYC() {
    // This animation can be started and replayed. When started, it will always start from globe view.
    List<MapCameraKeyframeTrack>? mapCameraKeyframeTracks = _createMapCameraKeyframeTracks();

    MapCameraAnimation mapCameraAnimation;

    try {
      mapCameraAnimation = MapCameraAnimationFactory.createAnimationFromKeyframeTracks(mapCameraKeyframeTracks!);
    } on MapCameraKeyframeTrackInstantiationException catch (e) {
    print(_tag + "Error occurred: " + e.error.name);
    return;
    }

    // This animation can be started and replayed. When started, it will always start from the first keyframe.
    _hereMapController.camera.startAnimationWithListener(mapCameraAnimation, AnimationListener((AnimationState animationState) {
      switch (animationState) {
        case AnimationState.started:
          print(_tag + "Animation started.");
          break;
        case AnimationState.cancelled:
          print(_tag + "Animation cancelled.");
          break;
        case AnimationState.completed:
          print(_tag + "Animation finished.");
          break;
      }
    }));
  }

  void stopTripToNYCAnimation() {
    _hereMapController.camera.cancelAnimations();
  }

  List<MapCameraKeyframeTrack>? _createMapCameraKeyframeTracks() {
    MapCameraKeyframeTrack geoCoordinatesMapCameraKeyframeTrack;
    MapCameraKeyframeTrack scalarMapCameraKeyframeTrack;
    MapCameraKeyframeTrack geoOrientationMapCameraKeyframeTrack;

    List<GeoCoordinatesKeyframe> geoCoordinatesKeyframes = _createGeoCoordinatesKeyframes();
    List<ScalarKeyframe> scalarKeyframes = _createScalarKeyframes();
    List<GeoOrientationKeyframe> geoOrientationKeyframes = _createGeoOrientationKeyframes();

    try {
      geoCoordinatesMapCameraKeyframeTrack = MapCameraKeyframeTrack.lookAtTargetWithEasing(geoCoordinatesKeyframes, Easing(EasingFunction.linear), KeyframeInterpolationMode.linear);
      scalarMapCameraKeyframeTrack = MapCameraKeyframeTrack.lookAtDistanceWithEasing(scalarKeyframes, Easing(EasingFunction.linear), KeyframeInterpolationMode.linear);
      geoOrientationMapCameraKeyframeTrack = MapCameraKeyframeTrack.lookAtOrientationWithEasing(geoOrientationKeyframes, Easing(EasingFunction.linear), KeyframeInterpolationMode.linear);
    } on MapCameraKeyframeTrackInstantiationException catch (e) {
    // Throws an error if keyframes are empty or the duration of keyframes is invalid.
    print(_tag + e.toString());
    return null;
    }

    // Add different kinds of animation tracks that can be played back simultaneously.
    // Each track can have a different total duration.
    // The animation completes, when the longest track has been competed.
    List<MapCameraKeyframeTrack> mapCameraKeyframeTracks = [];

    // This changes the camera's location over time.
    mapCameraKeyframeTracks.add(geoCoordinatesMapCameraKeyframeTrack);
    // This changes the camera's distance (= scalar) to earth over time.
    mapCameraKeyframeTracks.add(scalarMapCameraKeyframeTrack);
    // This changes the camera's orientation over time.
    mapCameraKeyframeTracks.add(geoOrientationMapCameraKeyframeTrack);

    return mapCameraKeyframeTracks;
  }

  List<GeoCoordinatesKeyframe> _createGeoCoordinatesKeyframes() {
    List<GeoCoordinatesKeyframe> geoCoordinatesKeyframes = [];

    geoCoordinatesKeyframes.addAll([
      GeoCoordinatesKeyframe(GeoCoordinates(40.685869754854544, -74.02550202768754), const Duration(milliseconds: 0)), // Statue of Liberty
      GeoCoordinatesKeyframe(GeoCoordinates(40.69051652745291, -74.04455943649657), const Duration(milliseconds: 5000)), // Statue of Liberty
      GeoCoordinatesKeyframe(GeoCoordinates(40.69051652745291, -74.04455943649657), const Duration(milliseconds: 7000)), // Statue of Liberty
      GeoCoordinatesKeyframe(GeoCoordinates(40.69051652745291, -74.04455943649657), const Duration(milliseconds: 9000)), // Statue of Liberty
      GeoCoordinatesKeyframe(GeoCoordinates(40.690266839135, -74.01237515471776), const Duration(milliseconds: 5000)), // Governor Island
      GeoCoordinatesKeyframe(GeoCoordinates(40.7116777285189, -74.01248494562448), const Duration(milliseconds: 6000)), // World Trade Center
      GeoCoordinatesKeyframe(GeoCoordinates(40.71083291395444, -74.01226399217569), const Duration(milliseconds: 6000)), // World Trade Center
      GeoCoordinatesKeyframe(GeoCoordinates(40.719259512385506, -74.01171007254635), const Duration(milliseconds: 5000)), // Manhattan College
      GeoCoordinatesKeyframe(GeoCoordinates(40.73603959180013, -73.98968489844603), const Duration(milliseconds: 6000)), // Union Square
      GeoCoordinatesKeyframe(GeoCoordinates(40.741732824650214, -73.98825255774022), const Duration(milliseconds: 5000)), // Flatiron
      GeoCoordinatesKeyframe(GeoCoordinates(40.74870637098952, -73.98515306630678), const Duration(milliseconds: 6000)), // Empire State Building
      GeoCoordinatesKeyframe(GeoCoordinates(40.742693509776856, -73.95937093336781), const Duration(milliseconds: 3000)), // Queens Midtown
      GeoCoordinatesKeyframe(GeoCoordinates(40.75065611103842, -73.96053139022635), const Duration(milliseconds: 4000)), // Roosevelt Island
      GeoCoordinatesKeyframe(GeoCoordinates(40.756823163883794, -73.95461519921352), const Duration(milliseconds: 4000)), // Queens Bridge
      GeoCoordinatesKeyframe(GeoCoordinates(40.763573707276784, -73.94571562970638), const Duration(milliseconds: 4000)), // Roosevelt Bridge
      GeoCoordinatesKeyframe(GeoCoordinates(40.773052036400294, -73.94027981305442), const Duration(milliseconds: 3000)), // Roosevelt Lighthouse
      GeoCoordinatesKeyframe(GeoCoordinates(40.78270548734745, -73.92189566092568), const Duration(milliseconds: 3000)), // Hell gate Bridge
      GeoCoordinatesKeyframe(GeoCoordinates(40.78406704306872, -73.91746017917936), const Duration(milliseconds: 2000)), // Ralph Park
      GeoCoordinatesKeyframe(GeoCoordinates(40.768075472169045, -73.97446921306035), const Duration(milliseconds: 2000)), // Wollman Rink
      GeoCoordinatesKeyframe(GeoCoordinates(40.78255966255712, -73.9586425508515), const Duration(milliseconds: 3000)) // Solomon Museum˝
    ]);

    return geoCoordinatesKeyframes;
  }

  List<ScalarKeyframe> _createScalarKeyframes() {
    List<ScalarKeyframe> scalarKeyframes = [];

    scalarKeyframes.add(ScalarKeyframe(80000000.0, const Duration(milliseconds: 0)));
    scalarKeyframes.add(ScalarKeyframe(8000000.0, const Duration(milliseconds: 2000)));
    scalarKeyframes.add(ScalarKeyframe(8000.0, const Duration(milliseconds: 2000)));
    scalarKeyframes.add(ScalarKeyframe(1000.0, const Duration(milliseconds: 2000)));
    scalarKeyframes.add(ScalarKeyframe(400.0, const Duration(milliseconds: 3000)));

    return scalarKeyframes;
  }

  List<GeoOrientationKeyframe> _createGeoOrientationKeyframes() {
    List<GeoOrientationKeyframe> geoOrientationKeyframe = [];

    geoOrientationKeyframe.addAll([
      GeoOrientationKeyframe(GeoOrientation(30, 60), const Duration(milliseconds: 0)),
      GeoOrientationKeyframe(GeoOrientation(-40, 80), const Duration(milliseconds: 6000)),
      GeoOrientationKeyframe(GeoOrientation(30, 70), const Duration(milliseconds: 6000)),
      GeoOrientationKeyframe(GeoOrientation(70, 30), const Duration(milliseconds: 4000)),
      GeoOrientationKeyframe(GeoOrientation(-30, 70), const Duration(milliseconds: 5000)),
      GeoOrientationKeyframe(GeoOrientation(30, 70), const Duration(milliseconds: 5000)),
      GeoOrientationKeyframe(GeoOrientation(40, 70), const Duration(milliseconds: 5000)),
      GeoOrientationKeyframe(GeoOrientation(80, 40), const Duration(milliseconds: 5000)),
      GeoOrientationKeyframe(GeoOrientation(30, 70), const Duration(milliseconds: 5000))
    ]);

    return geoOrientationKeyframe;
  }
}
