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

import 'MapViewPinsExample.dart';

void main() {
  SdkContext.init(IsolateOrigin.main);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MapViewPinsExample _mapViewPinsExample;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('HERE SDK - MapViewPins Example'),
        ),
        body: Stack(
          children: [
            HereMap(onMapCreated: _onMapCreated),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                button('Default', _addDefaultMapViewPinButtonClicked),
                button('Anchored', _addAnchoredMapViewPinButtonClicked),
                button('Clear', _clearMapButtonClicked),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onMapCreated(HereMapController hereMapController) {
    hereMapController.mapScene.loadSceneForMapScheme(MapScheme.normalDay, (MapError error) {
      if (error == null) {
        _mapViewPinsExample = MapViewPinsExample(hereMapController);
      } else {
        print("Map scene not loaded. MapError: " + error.toString());
      }
    });
  }

  void _addDefaultMapViewPinButtonClicked() {
    _mapViewPinsExample.addDefaultMapViewPinButtonClicked();
  }

  void _addAnchoredMapViewPinButtonClicked() {
    _mapViewPinsExample.addAnchoredMapViewPinButtonClicked();
  }

  void _clearMapButtonClicked() {
    _mapViewPinsExample.clearMap();
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
