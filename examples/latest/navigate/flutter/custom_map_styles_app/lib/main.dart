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

import 'package:flutter/material.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.engine.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/mapview.dart';

import 'CustomMapStyleExample.dart';

void main() async {
  // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
  await _initializeHERESDK();

  runApp(MyApp());
}

Future<void> _initializeHERESDK() async {
  // Needs to be called before accessing SDKOptions to load necessary libraries.
  SdkContext.init(IsolateOrigin.main);

  // Set your credentials for the HERE SDK.
  String accessKeyId = "YOUR_ACCESS_KEY_ID";
  String accessKeySecret = "YOUR_ACCESS_KEY_SECRET";
  AuthenticationMode authenticationMode = AuthenticationMode.withKeySecret(accessKeyId, accessKeySecret);
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
  CustomMapStyleExample? _customMapStyleExample;
  late final AppLifecycleListener _appLifecycleListener;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('HERE SDK - Custom Styles Example'),
        ),
        body: Stack(
          children: [
            HereMap(onMapCreated: _onMapCreated),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                button('Load', _loadStyleButtonClicked),
                button('Unload', _unloadStyleButtonClicked),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onMapCreated(HereMapController hereMapController) {
    hereMapController.mapScene.loadSceneForMapScheme(MapScheme.normalDay, (MapError? error) {
      if (error == null) {
        _customMapStyleExample = CustomMapStyleExample(hereMapController);
      } else {
        print("Map scene not loaded. MapError: " + error.toString());
      }
    });
  }

  void _loadStyleButtonClicked() {
    _customMapStyleExample?.loadCustomMapStyle();
  }

  void _unloadStyleButtonClicked() {
    _customMapStyleExample?.loadDefaultMapStyle();
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
      { print('AppLifecycleListener detached.'), _disposeHERESDK() },
    );
  }

  @override
  void dispose() {
    _disposeHERESDK();
    super.dispose();
  }

  void _disposeHERESDK() async {
    // Free HERE SDK resources before the application shuts down.
    await SDKNativeEngine.sharedInstance?.dispose();
    SdkContext.release();
    _appLifecycleListener.dispose();
  }

  // A helper method to add a button on top of the HERE map.
  Align button(String buttonLabel, Function callbackFunction) {
    return Align(
      alignment: Alignment.topCenter,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.lightBlueAccent,
          foregroundColor: Colors.white,
        ),
        onPressed: () => callbackFunction(),
        child: Text(buttonLabel, style: TextStyle(fontSize: 20)),
      ),
    );
  }
}
