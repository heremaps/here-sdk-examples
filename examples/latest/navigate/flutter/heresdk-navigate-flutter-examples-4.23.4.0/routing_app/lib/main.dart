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

import 'routing_example.dart';

void main() async {
  // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
  await _initializeHERESDK();

  // Ensure that all widgets, including MyApp, have a MaterialLocalizations object available.
  runApp(const MaterialApp(home: MyApp()));
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
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  RoutingExample? _routingExample;
  HereMapController? _hereMapController;
  final List<bool> _selectedTrafficOptimization = <bool>[true];
  late final AppLifecycleListener _appLifecycleListener;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HERE SDK - Routing Example'),
      ),
      body: Stack(
        children: [
          HereMap(onMapCreated: _onMapCreated),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  button('Add Route', _addRouteButtonClicked),
                  button(' Add\nWaypoints', _addWaypointButtonClicked),
                  button('Clear Map', _clearMapButtonClicked),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ToggleButtons(
                      onPressed: (int index) {
                        _toggleTrafficOptimization();
                        setState(() {
                          _selectedTrafficOptimization[index] =
                              !_selectedTrafficOptimization[index];
                        });
                      },
                      isSelected: _selectedTrafficOptimization,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: Colors.lightBlueAccent,
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          child: Text(
                            _selectedTrafficOptimization[0]
                                ? 'Traffic Optimization-On'
                                : 'Traffic Optimization-OFF',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15.0,
                            ),
                          ),
                        ),
                      ]),
                  button('Update traffic \n on route', _updateTrafficOnRoute),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onMapCreated(HereMapController hereMapController) {
    _hereMapController = hereMapController;

    // Load the map scene using a map scheme to render the map with.
    _hereMapController?.mapScene.loadSceneForMapScheme(MapScheme.normalDay,
        (MapError? error) {
      if (error == null) {
        _hereMapController?.mapScene.enableFeatures(
            {MapFeatures.lowSpeedZones: MapFeatureModes.lowSpeedZonesAll});
        _routingExample = RoutingExample(_showDialog, hereMapController);
      } else {
        print("Map scene not loaded. MapError: $error");
      }
    });
  }

  void _toggleTrafficOptimization() {
    _routingExample?.toggleTrafficOptimization();
  }

  void _addRouteButtonClicked() {
    _routingExample?.addRoute();
  }

  void _addWaypointButtonClicked() {
    _routingExample?.addWaypoints();
  }

  void _updateTrafficOnRoute() {
    _routingExample?.onUpdateTrafficOnRouteButtonClick();
  }

  void _clearMapButtonClicked() {
    _routingExample?.clearMap();
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
          foregroundColor: Colors.white,
          backgroundColor: Colors.lightBlueAccent,
        ),
        onPressed: () => callbackFunction(),
        child: Text(buttonLabel, style: const TextStyle(fontSize: 15)),
      ),
    );
  }

  // A helper method to show a dialog.
  Future<void> _showDialog(String title, String message) async {
    return showDialog<void>(
      context: context,
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
              child: const Text('OK'),
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
