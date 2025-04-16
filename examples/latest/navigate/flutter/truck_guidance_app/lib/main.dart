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
import 'package:truck_guidance_app/speed_view.dart';
import 'package:truck_guidance_app/truck_guidance_example.dart';
import 'package:truck_guidance_app/truck_restriction_view.dart';

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
  AuthenticationMode authenticationMode = AuthenticationMode.withKeySecret(accessKeyId, accessKeySecret);
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

/// The UICallback interface for receiving updates from TruckGuidanceExample.
abstract class UICallback {
  void onTruckSpeedLimit(String speedLimit);
  void onCarSpeedLimit(String speedLimit);
  void onDrivingSpeed(String drivingSpeed);
  void onTruckRestrictionWarning(String description);
  void onHideTruckRestrictionWarning();
}

class MyAppState extends State<MyApp> implements UICallback {
  // UI state for speed views and truck restrictions.
  String _truckSpeedLimit = "n/a";
  String _carSpeedLimit = "n/a";
  String _drivingSpeed = "n/a";
  String _truckRestrictionDescription = "";
  TruckGuidanceExample? _truckGuidanceExample;
  HereMapController? _hereMapController;
  late final AppLifecycleListener _appLifecycleListener;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HERE SDK - Truck Guidance Example'),
      ),
      body: Stack(
        children: [
          HereMap(onMapCreated: _onMapCreated),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _truckGuidanceExample?.onShowRouteButtonClicked();
                      },
                      child: Text("Show Route"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal, // Background color
                        foregroundColor: Colors.white, // Text color
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _truckGuidanceExample?.onStartStopButtonClicked();
                      },
                      child: Text("Start/Stop"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal, // Background color
                        foregroundColor: Colors.white, // Text color
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _truckGuidanceExample?.onClearMapButtonClicked();
                      },
                      child: Text("Clear"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal, // Background color
                        foregroundColor: Colors.white, // Text color
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _truckGuidanceExample?.onTrackingButtonClicked();
                      },
                      child: Text("Tracking on/off"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal, // Background color
                        foregroundColor: Colors.white, // Text color
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _truckGuidanceExample?.onSpeedButtonClicked();
                      },
                      child: Text("Toggle Speed"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal, // Background color
                        foregroundColor: Colors.white, // Text color
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Truck restriction view positioned above the speed views.
          Positioned(
            left: 5,
            bottom: 85, // Adjust based on SpeedView height (here 80dp) and margin.
            child: TruckRestrictionView(
              description: _truckRestrictionDescription,
            ),
          ),
          // UI overlays in the bottom-left corner.
          Positioned(
            left: 12,
            bottom: 5,
            child: Row(
              children: [
                SpeedView(
                  label: "Truck",
                  speed: _truckSpeedLimit,
                  circleColor: Colors.red,
                ),
                const SizedBox(width: 5),
                SpeedView(
                  label: "Car",
                  speed: _carSpeedLimit,
                  circleColor: Colors.red,
                ),
                const SizedBox(width: 5),
                SpeedView(
                  label: "",
                  speed: _drivingSpeed,
                  circleColor: Colors.white,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onMapCreated(HereMapController hereMapController) {
    _hereMapController = hereMapController;

    // Load the map scene using a map scheme to render the map with.
    _hereMapController?.mapScene.loadSceneForMapScheme(MapScheme.normalDay, (MapError? error) {
      if (error == null) {
        _hereMapController?.mapScene.enableFeatures({MapFeatures.lowSpeedZones: MapFeatureModes.lowSpeedZonesAll});
        _truckGuidanceExample = TruckGuidanceExample(_showDialog, hereMapController);
        _truckGuidanceExample!.setUICallback(this);
      } else {
        print("Map scene not loaded. MapError: $error");
      }
    });
  }

  // UICallback implementations.
  @override
  void onCarSpeedLimit(String speedLimit) {
    setState(() {
      _carSpeedLimit = speedLimit;
    });
  }

  @override
  void onDrivingSpeed(String drivingSpeed) {
    setState(() {
      _drivingSpeed = drivingSpeed;
    });
  }

  @override
  void onTruckRestrictionWarning(String description) {
    setState(() {
      _truckRestrictionDescription = description;
    });
  }

  @override
  void onTruckSpeedLimit(String speedLimit) {
    setState(() {
      _truckSpeedLimit = speedLimit;
    });
  }

  @override
  void onHideTruckRestrictionWarning() {
    setState(() {
      _truckRestrictionDescription = "";
    });
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
        child: Text(buttonLabel, style: const TextStyle(fontSize: 20)),
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
