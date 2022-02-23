/*
 * Copyright (C) 2019-2022 HERE Europe B.V.
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
import 'package:here_sdk/consent.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';
import 'package:permission_handler/permission_handler.dart';

import 'AppLogic.dart';

void main() {
  SdkContext.init(IsolateOrigin.main);
  runApp(
    MaterialApp(
      // Enable localizations for the ConsentEngine's dialog widget.
      localizationsDelegates: HereSdkConsentLocalizations.localizationsDelegates,
      supportedLocales: HereSdkConsentLocalizations.supportedLocales,
      home: MyApp(),
    ),
  );
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

  // When using HERE Positioning in your app, it is required to request and to show the user's consent decision.
  // In addition, users must be able to change their consent decision at any time.
  // Note that this is only needed when running on Android devices.
  final ConsentEngine _consentEngine = ConsentEngine();
  String _consentState = "Pending ...";
  String _messageState = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  multiLineButton(_consentState, _requestConsent),
                ],
              ),
              messageStateWidget(_messageState),
            ],
          ),
        ],
      ),
    );
  }

  void _onMapCreated(HereMapController hereMapController) {
    hereMapController.mapScene.loadSceneForMapScheme(MapScheme.normalDay, (MapError? error) async {
      _updateMessageState("Loading MapView ...");
      if (error == null) {
        // 1. Before we start the app we want to ensure that the required permissions are handled.
        if (!await _requestPermissions()) {
          await _showDialog("Error", "Cannot start app: Location service and permissions are needed for this app.");
          // Let the user set the permissions from the system settings as fallback.
          openAppSettings();
          SystemNavigator.pop();
          return;
        }

        // 2. Once permissions are granted, we request the user's consent decision which is required for HERE Positioning.
        if (_consentEngine.userConsentState == ConsentUserReply.notHandled) {
          await _requestConsent();
        } else {
          _updateConsentState();
        }

        // 3. User has granted required permissions and made a consent decision.
        _updateMessageState("MapView loaded");
        _appLogic = AppLogic(hereMapController, _updateMessageState);
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

  Future<void> _requestConsent() async {
    if (!Platform.isIOS) {
      // This shows a localized widget that asks the user if data can be collected or not.
      await _consentEngine.requestUserConsent(context);
    }

    _updateConsentState();
  }

  // Update the button's text showing the current consent decision of the user.
  void _updateConsentState() {
    String stateMessage;
    if (Platform.isIOS) {
      stateMessage = "Info: On iOS no consent is required as on iOS no data is collected.";
    } else if (_consentEngine.userConsentState == ConsentUserReply.granted) {
      stateMessage = "Positioning consent: You have granted consent to the data collection.";
    } else {
      stateMessage = "Positioning consent: You have denied consent to the data collection.";
    }

    setState(() {
      _consentState = stateMessage;
    });
  }

  // Update the button's tracking state and set tracking state to VisualNavigator.
  void _updateTrackingState() {
    setState(() {
      _trackingState = _isTracking ? _trackingOn : _trackingOff;
    });

    _appLogic.setTracking(_isTracking);
  }

  // Update the message text state and show selected log messages.
  void _updateMessageState(String messageState) {
    setState(() {
      _messageState = messageState;
      print(messageState);
    });
  }

  void _startNavigationSimulationButtonClicked() {
    _appLogic.startNavigationSimulation();
  }

  void _startNavigationButtonClicked() {
    _appLogic.startNavigation();
  }

  void toggleTrackingButtonClicked() {
    _isTracking = !_isTracking;
    _updateTrackingState();
  }

  void _stopNavigationButtonClicked() {
    _appLogic.stopNavigation();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _appLogic.detach();
    }
  }

  // A helper method to add a button on top of the HERE map.
  Align button(String buttonLabel, VoidCallback? callbackFunction) {
    return Align(
      alignment: Alignment.topCenter,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          primary: Colors.lightBlueAccent,
          onPrimary: Colors.white,
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
          primary: Colors.lightBlueAccent,
          onPrimary: Colors.white,
        ),
        onPressed: callbackFunction,
        child: Container(
            width: MediaQuery.of(context).size.width  * 0.8,
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
          style: TextStyle(fontSize: 15, color: Colors.white,),
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
