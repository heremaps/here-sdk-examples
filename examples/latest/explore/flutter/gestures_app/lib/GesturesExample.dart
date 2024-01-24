/*
 * Copyright (C) 2019-2024 HERE Europe B.V.
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

import 'package:here_sdk/core.dart';
import 'package:here_sdk/gestures.dart';
import 'package:here_sdk/mapview.dart';

// A callback to notify the hosting widget.
typedef ShowDialogFunction = void Function(String title, String message);

class GesturesExample {
  final HereMapController _hereMapController;
  final ShowDialogFunction _showDialog;

  GesturesExample(ShowDialogFunction showDialogCallback, HereMapController hereMapController)
      : _showDialog = showDialogCallback,
        _hereMapController = hereMapController {
    double distanceToEarthInMeters = 8000;
    MapMeasure mapMeasureZoom = MapMeasure(MapMeasureKind.distance, distanceToEarthInMeters);
    _hereMapController.camera.lookAtPointWithMeasure(GeoCoordinates(52.530932, 13.384915), mapMeasureZoom);

    _setTapGestureHandler();
    _setDoubleTapGestureHandler();
    _setTwoFingerTapGestureHandler();
    _setLongPressGestureHandler();

    _showDialog("Gestures Example",
        "Shows Tap, DoubleTap, TwoFingerTap and LongPress gesture handling. " + "See log for details.");
  }

  void _setTapGestureHandler() {
    _hereMapController.gestures.tapListener = TapListener((Point2D touchPoint) {
      var geoCoordinates = _toString(_hereMapController.viewToGeoCoordinates(touchPoint));
      print('Tap at: $geoCoordinates');
    });
  }

  void _setDoubleTapGestureHandler() {
    _hereMapController.gestures.doubleTapListener = DoubleTapListener((Point2D touchPoint) {
      var geoCoordinates = _toString(_hereMapController.viewToGeoCoordinates(touchPoint));
      print('DoubleTap at: $geoCoordinates');
    });
  }

  void _setTwoFingerTapGestureHandler() {
    _hereMapController.gestures.twoFingerTapListener = TwoFingerTapListener((Point2D touchCenterPoint) {
      var geoCoordinates = _toString(_hereMapController.viewToGeoCoordinates(touchCenterPoint));
      print('TwoFingerTap at: $geoCoordinates');
    });
  }

  void _setLongPressGestureHandler() {
    _hereMapController.gestures.longPressListener = LongPressListener((GestureState gestureState, Point2D touchPoint) {
      var geoCoordinates = _toString(_hereMapController.viewToGeoCoordinates(touchPoint));

      if (gestureState == GestureState.begin) {
        print('LongPress detected at: $geoCoordinates');
      }

      if (gestureState == GestureState.update) {
        print('LongPress update at: $geoCoordinates');
      }

      if (gestureState == GestureState.end) {
        print('LongPress finger lifted at: $geoCoordinates');
      }

      if (gestureState == GestureState.cancel) {
          print('Map view lost focus. Maybe a modal dialog is shown or the app is sent to background.');
      }
    });
  }

  String _toString(GeoCoordinates? geoCoordinates) {
    if (geoCoordinates == null) {
      // This can happen, when there is no map view touched, for example, when the screen was tilted and
      // the touch point is on the horizon.
      return "Error: No valid geo coordinates.";
    }

    return geoCoordinates.latitude.toString() + ", " + geoCoordinates.longitude.toString();
  }
}
