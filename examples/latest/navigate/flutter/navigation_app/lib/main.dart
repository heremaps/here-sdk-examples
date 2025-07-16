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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.engine.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/mapview.dart';
import 'package:permission_handler/permission_handler.dart';

import 'AppLogic.dart';
import 'HEREPositioningTermsAndPrivacyHelper.dart';

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
  AuthenticationMode authenticationMode = AuthenticationMode.withKeySecret(accessKeyId, accessKeySecret);
  SDKOptions sdkOptions = SDKOptions.withAuthenticationMode(authenticationMode);

  try {
    await SDKNativeEngine.makeSharedInstance(sdkOptions);
  } on InstantiationException {
    throw Exception("Failed to initialize the HERE SDK.");
  }
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late AppLogic _appLogic;
  static const String _trackingOn = "Tracking: ON";
  static const String _trackingOff = "Tracking: OFF";
  String _trackingState = "Pending ...";
  bool _isTracking = true;
  late final AppLifecycleListener _appLifecycleListener;
  String _messageState = "";

  Future<bool> _handleBackPress() async {
    // Handle the back press.
    _appLogic?.detach();

    // Return true to allow the back press.
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBackPress,
      child: Scaffold(
        appBar: AppBar(
          title: Text("HERE SDK - Navigation Example"),
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
                    button("Start Simulation", _startNavigationSimulationButtonClicked),
                    button(_trackingState, toggleTrackingButtonClicked),
                    button("Stop", _stopNavigationButtonClicked),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    button("Start with HERE Positioning", _startNavigationButtonClicked),
                  ],
                ),
                messageStateWidget(_messageState),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onMapCreated(HereMapController hereMapController) {
    hereMapController.mapScene.loadSceneForMapScheme(MapScheme.normalDay, (MapError? error) async {
      _updateMessageState("Loading MapView ...");
      if (error == null) {
        // 1. We request the user's agreement to use HERE Positioning.
        if (Platform.isAndroid) {
          // Shows an example of how to present application terms and a privacy policy dialog as
          // required by legal requirements when using HERE Positioning.
          // See the Positioning section in our Developer Guide for more details.
          final termsAndPrivacyHelper = HEREPositioningTermsAndPrivacyHelper(context);
          await termsAndPrivacyHelper.showAppTermsAndPrivacyPolicyDialogIfNeeded();
        }

        // 2. Ensure that the required permissions are handled.
        if (!await _requestPermissions()) {
          await _showDialog("Error", "Cannot start app: Location service and permissions are needed for this app.");
          // Let the user set the permissions from the system settings as fallback.
          openAppSettings();
          SystemNavigator.pop();
          return;
        }

        // 3. User has granted required permissions and agreed to use HERE Positioning.
        _updateMessageState("MapView loaded");
        _appLogic = AppLogic(hereMapController, _updateMessageState, _showDialog);
        _updateTrackingState();
      } else {
        print("Map scene not loaded. MapError: " + error.toString());
      }
    });
  }

  // Request permissions with the permission_handler plugin. Set the required permissions here:
  // Android: navigation_app/android/app/src/main/AndroidManifest.xml
  // iOS: navigation_app/ios/Runner/Info.plist
  Future<bool> _requestPermissions() async {
    if (!await Permission.location.serviceStatus.isEnabled) {
      return false;
    }

    if (!await Permission.location.request().isGranted) {
      return false;
    }

    if (Platform.isAndroid) {
      // This permission is optionally needed on Android devices >= Q to improve the positioning signal.
      Permission.activityRecognition.request();
    }

    // All required permissions granted.
    return true;
  }

  // Update the button's tracking state and set tracking state to VisualNavigator.
  void _updateTrackingState() {
    setState(() {
      _trackingState = _isTracking ? _trackingOn : _trackingOff;
    });

    if (_appLogic != null) {
      _appLogic.setTracking(_isTracking);
    }
  }

  // Update the message text state and show selected log messages.
  void _updateMessageState(String messageState) {
    setState(() {
      _messageState = messageState;
      print(messageState);
    });
  }

  void _startNavigationSimulationButtonClicked() {
    if (_appLogic != null) {
      _appLogic.startNavigationSimulation();
    }
  }

  void _startNavigationButtonClicked() {
    if (_appLogic != null) {
      _appLogic.startNavigation();
    }
  }

  void toggleTrackingButtonClicked() {
    _isTracking = !_isTracking;
    _updateTrackingState();
  }

  void _stopNavigationButtonClicked() {
    if (_appLogic != null) {
      _appLogic.stopNavigation();
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
      { print('AppLifecycleListener detached.'), _disposeHERESDK() },
    );
  }

  @override
  void dispose() {
    _disposeHERESDK();
    super.dispose();
  }

  void _disposeHERESDK() async {
    WidgetsBinding.instance!.removeObserver(this);

    // Free HERE SDK resources before the application shuts down.
    await SDKNativeEngine.sharedInstance?.dispose();
    SdkContext.release();
    _appLifecycleListener.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached && _appLogic != null) {
      _appLogic.detach();
    }
  }

  // A helper method to add a button on top of the HERE map.
  Align button(String buttonLabel, VoidCallback? callbackFunction) {
    return Align(
      alignment: Alignment.topCenter,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.lightBlueAccent,
          foregroundColor: Colors.white,
        ),
        onPressed: callbackFunction,
        child: Text(buttonLabel, style: TextStyle(fontSize: 15)),
      ),
    );
  }

  // A helper method to add a multiline button on top of the HERE map.
  Align multiLineButton(String buttonLabel, VoidCallback? callbackFunction) {
    return Align(
      alignment: Alignment.topCenter,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.lightBlueAccent,
          foregroundColor: Colors.white,
        ),
        onPressed: callbackFunction,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          padding: EdgeInsets.all(2.0),
          child: Text(
            buttonLabel,
            style: TextStyle(fontSize: 15),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  // A helper method to add a message widget on the top of the HERE map.
  Widget messageStateWidget(String messageState) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: Text(
          messageState,
          style: TextStyle(
            fontSize: 15,
            color: Colors.white,
          ),
        ),
      ),
      color: Colors.blue,
      margin: EdgeInsets.only(left: 12.0, right: 12.0, top: 8.0),
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
              child: Text("OK"),
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
