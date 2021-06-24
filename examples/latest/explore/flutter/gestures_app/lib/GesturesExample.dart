/*
 * Copyright (C) 2019-2021 HERE Europe B.V.
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

import 'package:flutter/material.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/gestures.dart';
import 'package:here_sdk/mapview.dart';

class GesturesExample {
  BuildContext _context;
  HereMapController _hereMapController;

  GesturesExample(BuildContext context, HereMapController hereMapController) {
    _context = context;
    _hereMapController = hereMapController;

    double distanceToEarthInMeters = 8000;
    _hereMapController.camera.lookAtPointWithDistance(GeoCoordinates(52.530932, 13.384915), distanceToEarthInMeters);

    _setTapGestureHandler();
    _setDoubleTapGestureHandler();
    _setTwoFingerTapGestureHandler();
    _setLongPressGestureHandler();

    _showDialog("Gestures Example",
        "Shows Tap, DoubleTap, TwoFingerTap and LongPress gesture handling. " + "See log for details.");
  }

  void _setTapGestureHandler() {
    _hereMapController.gestures.tapListener = TapListener.fromLambdas(lambda_onTap: (Point2D touchPoint) {
      var geoCoordinates = _toString(_hereMapController.viewToGeoCoordinates(touchPoint));
      print('Tap at: $geoCoordinates');
    });
  }

  void _setDoubleTapGestureHandler() {
    _hereMapController.gestures.doubleTapListener =
        DoubleTapListener.fromLambdas(lambda_onDoubleTap: (Point2D touchPoint) {
      var geoCoordinates = _toString(_hereMapController.viewToGeoCoordinates(touchPoint));
      print('DoubleTap at: $geoCoordinates');
    });
  }

  void _setTwoFingerTapGestureHandler() {
    _hereMapController.gestures.twoFingerTapListener =
        TwoFingerTapListener.fromLambdas(lambda_onTwoFingerTap: (Point2D touchCenterPoint) {
      var geoCoordinates = _toString(_hereMapController.viewToGeoCoordinates(touchCenterPoint));
      print('TwoFingerTap at: $geoCoordinates');
    });
  }

  void _setLongPressGestureHandler() {
    _hereMapController.gestures.longPressListener =
        LongPressListener.fromLambdas(lambda_onLongPress: (GestureState gestureState, Point2D touchPoint) {
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
    });
  }

  String _toString(GeoCoordinates geoCoordinates) {
    return geoCoordinates.latitude.toString() + ", " + geoCoordinates.longitude.toString();
  }

  Future<void> _showDialog(String title, String message) async {
    return showDialog<void>(
      context: _context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(message),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
