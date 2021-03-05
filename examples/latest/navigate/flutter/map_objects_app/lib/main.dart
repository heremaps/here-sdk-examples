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
import 'package:here_sdk/mapview.dart';

import 'MapObjectsExample.dart';

void main() {
  SdkContext.init(IsolateOrigin.main);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MapObjectsExample _mapObjectsExample;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('HERE SDK - Map Objects Example'),
        ),
        body: Stack(
          children: [
            HereMap(onMapCreated: _onMapCreated),
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    button('Polyline', _addPolylineButtonClicked),
                    button('Arrow', _addArrowButtonClicked),
                    button('Polygon', _addPolygonButtonClicked),
                    button('Circle', _addCircleButtonClicked),
                  ],
                ),
                button('Clear', _clearMapButtonClicked),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onMapCreated(HereMapController hereMapController) {
    hereMapController.mapScene.loadSceneForMapScheme(MapScheme.normalDay,
        (MapError error) {
      if (error == null) {
        _mapObjectsExample = MapObjectsExample(hereMapController);
      } else {
        print("Map scene not loaded. MapError: " + error.toString());
      }
    });
  }

  void _addPolylineButtonClicked() {
    _mapObjectsExample.showMapPolyline();
  }

  void _addArrowButtonClicked() {
    _mapObjectsExample.showMapArrow();
  }

  void _addPolygonButtonClicked() {
    _mapObjectsExample.showMapPolygon();
  }

  void _addCircleButtonClicked() {
    _mapObjectsExample.showMapCircle();
  }

  void _clearMapButtonClicked() {
    _mapObjectsExample.clearMapButtonClicked();
  }

  // A helper method to add a button on top of the HERE map.
  Align button(String buttonLabel, Function callbackFunction) {
    return Align(
      alignment: Alignment.topCenter,
      child: RaisedButton(
        color: Colors.lightBlueAccent,
        textColor: Colors.white,
        onPressed: () => callbackFunction(),
        child: Text(buttonLabel, style: TextStyle(fontSize: 20)),
      ),
    );
  }
}
