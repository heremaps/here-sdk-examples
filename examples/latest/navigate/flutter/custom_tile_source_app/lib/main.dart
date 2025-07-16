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

import 'package:custom_tile_source_app/CustomPolygonTileSourceExample.dart';
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
  CustomLineTileSourceExample? _customLineTileSourceExample;
  CustomRasterTileSourceExample? _customRasterTileSourceExample;
  CustomPolygonTileSourceExample? _customPolygonTileSourceExample;
  late final AppLifecycleListener _appLifecycleListener;
  bool _isPointTileChecked = true;
  bool _isLineTileChecked = false;
  bool _isRasterTileChecked = false;
  bool _isPolygonTileChecked = false;

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
              child: Container(
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        _customSwitch("Point tile", _isPointTileChecked),
                        _customSwitch("Raster tile", _isRasterTileChecked),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _customSwitch("Line tile", _isLineTileChecked),
                        _customSwitch("Polygon tile", _isPolygonTileChecked),
                      ],
                    ),
                  ],
                ),
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
        _customPolygonTileSourceExample =
            CustomPolygonTileSourceExample(hereMapController);

        _customRasterTileSourceExample?.setup();
      } else {
        print("Map scene not loaded. MapError: " + error.toString());
      }
    });
  }

  void _enableLayer(String _selectedTileSource) {
    if (_selectedTileSource == "Point tile") {
      _customPointTileSourceExample?.enableLayer();
      _isPointTileChecked = true;
    } else if (_selectedTileSource == "Raster tile") {
      _customRasterTileSourceExample?.enableLayer();
      _isRasterTileChecked = true;
    } else if (_selectedTileSource == "Line tile") {
      _customLineTileSourceExample?.enableLayer();
      _isLineTileChecked = true;
    } else {
      _customPolygonTileSourceExample?.enableLayer();
      _isPolygonTileChecked = true;
    }
  }

  void _disableLayer(String _selectedTileSource) {
    if (_selectedTileSource == "Point tile") {
      _customPointTileSourceExample?.disableLayer();
      _isPointTileChecked = false;
    } else if (_selectedTileSource == "Raster tile") {
      _customRasterTileSourceExample?.disableLayer();
      _isRasterTileChecked = false;
    } else if (_selectedTileSource == "Line tile") {
      _customLineTileSourceExample?.disableLayer();
      _isLineTileChecked = false;
    } else {
      _customPolygonTileSourceExample?.disableLayer();
      _isPolygonTileChecked = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _appLifecycleListener = AppLifecycleListener(
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
    _customPolygonTileSourceExample?.onDestroy();
    await SDKNativeEngine.sharedInstance?.dispose();
    SdkContext.release();
    _appLifecycleListener.dispose();
  }

  Widget _customSwitch(String title, bool isChecked) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(title, style: TextStyle(color: Colors.black)),
          Switch(
            value: isChecked, 
            onChanged: (value) {
              setState(() {
                isChecked ? _disableLayer(title) : _enableLayer(title);
              });
            }
          ),
        ],
      ),
    );
  }
}
