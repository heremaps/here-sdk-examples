/*
 * Copyright (C) 2025 HERE Europe B.V.
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
import 'package:here_sdk/core.engine.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/mapview.dart';
import 'CustomPointTileSourceExample.dart';
import 'CustomRasterTileSourceExample.dart';
import 'CustomLineTileSourceExample.dart';

void main() async {
  // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
  await _initializeHERESDK();

  runApp(
    MaterialApp(
      home: MyApp(),
    ),
  );
}

Future<void> _initializeHERESDK() async {
  // Needs to be called before accessing SDKOptions to load necessary libraries.
  SdkContext.init(IsolateOrigin.main);

  // Set your credentials for the HERE SDK.
  String accessKeyId = "YOUR_ACCESS_KEY_ID";
  String accessKeySecret = "YOUR_ACCESS_KEY_SECRET";
  AuthenticationMode authenticationMode =
      AuthenticationMode.withKeySecret(accessKeyId, accessKeySecret);
  SDKOptions sdkOptions = SDKOptions.withAuthenticationMode(authenticationMode);

  try {
    await SDKNativeEngine.makeSharedInstance(sdkOptions);
  } on InstantiationException {
    throw Exception("Failed to initialize the HERE SDK.");
  }
}

class MyApp extends StatefulWidget {
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  CustomPointTileSourceExample? _customPointTileSourceExample;
  CustomRasterTileSourceExample? _customRasterTileSourceExample;
  CustomLineTileSourceExample? _customLineTileSourceExample;
  late final AppLifecycleListener _listener;
  String _selectedTileSource = "point";

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Custom Tile Source Example'),
        ),
        body: Stack(
          children: [
            HereMap(onMapCreated: _onMapCreated),
            Align(
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _radioButton("Point tile", "point"),
                      _radioButton("Raster tile", "raster"),
                      _radioButton("Line tile", "line"),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      button('Enable', _enableButtonClicked),
                      button('Disable', _disableButtonClicked),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onMapCreated(HereMapController hereMapController) {
    hereMapController.mapScene.loadSceneForMapScheme(MapScheme.normalDay,
        (MapError? error) {
      if (error == null) {
        _customPointTileSourceExample =
            CustomPointTileSourceExample(hereMapController);
        _customRasterTileSourceExample =
            CustomRasterTileSourceExample(hereMapController);
        _customLineTileSourceExample =
            CustomLineTileSourceExample(hereMapController);

        _customRasterTileSourceExample?.setup();
      } else {
        print("Map scene not loaded. MapError: " + error.toString());
      }
    });
  }

  void _enableButtonClicked() {
    if (_selectedTileSource == "point") {
      _customPointTileSourceExample?.enableButtonClicked();
    } else if (_selectedTileSource == "raster") {
      _customRasterTileSourceExample?.enableButtonClicked();
    } else {
      _customLineTileSourceExample?.enableButtonClicked();
    }
  }

  void _disableButtonClicked() {
    if (_selectedTileSource == "point") {
      _customPointTileSourceExample?.disableButtonClicked();
    } else if (_selectedTileSource == "raster") {
      _customRasterTileSourceExample?.disableButtonClicked();
    } else {
      _customLineTileSourceExample?.disableButtonClicked();
    }
  }

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onDetach: () =>
          // Sometimes Flutter may not reliably call dispose(),
          // therefore it is recommended to dispose the HERE SDK
          // also when the AppLifecycleListener is detached.
          // See more details: https://github.com/flutter/flutter/issues/40940
          {print('AppLifecycleListener detached.'), _disposeHERESDK()},
    );
  }

  @override
  void dispose() {
    _disposeHERESDK();
    super.dispose();
  }

  void _disposeHERESDK() async {
    _customPointTileSourceExample?.onDestroy();
    _customRasterTileSourceExample?.onDestroy();
    _customLineTileSourceExample?.onDestroy();
    await SDKNativeEngine.sharedInstance?.dispose();
    SdkContext.release();
    _listener.dispose();
  }

  Row _radioButton(String title, String value) {
    return Row(
      children: [
        Radio<String>(
          value: value,
          groupValue: _selectedTileSource,
          onChanged: (value) {
            setState(() {
              _selectedTileSource = value!;
            });
          },
        ),
        Text(title, style: TextStyle(color: Colors.black)),
      ],
    );
  }

  Align button(String buttonLabel, Function callbackFunction) {
    return Align(
      alignment: Alignment.topCenter,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.lightBlueAccent,
        ),
        onPressed: () => callbackFunction(),
        child: Text(buttonLabel, style: TextStyle(fontSize: 20)),
      ),
    );
  }
}
