/*
 * Copyright (C) 2023-2025 HERE Europe B.V.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
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
import 'package:hiking_diary_app/HikingApp.dart';
import 'package:hiking_diary_app/menu/MenuScreen.dart';
import 'package:permission_handler/permission_handler.dart';

import 'MessageNotifier.dart';
import 'positioning/HEREPositioningTermsAndPrivacyHelper.dart';

void main() async {
  // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
  await _initializeHERESDK();

  runApp(
    MaterialApp(
      home: MyApp(messageNotifier: MessageNotifier()),
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
  final MessageNotifier messageNotifier;

  MyApp({required this.messageNotifier});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _mapLayerSwitch = false;
  HikingApp? hikingApp;
  late final AppLifecycleListener _listener;
  bool _isLocationPermissionGranted = false;
  HereMapController? _hereMapController;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onDetach: () =>
      // Sometimes Flutter may not reliably call dispose(),
      // therefore it is recommended to dispose the HERE SDK
      // also when the AppLifecycleListener is detached.
      // See more details: https://github.com/flutter/flutter/issues/40940
      { print('AppLifecycleListener detached.'), _disposeHERESDK() },
    );

    WidgetsBinding.instance.addObserver(this);
    widget.messageNotifier.addListener(_update);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.messageNotifier.removeListener(_update);
    _disposeHERESDK();
    super.dispose();
  }

  void _disposeHERESDK() async {
    if (hikingApp != null) {
      hikingApp!.onDestroyOutdoorRasterLayer();
    }

    // Free HERE SDK resources before the application shuts down.
    await SDKNativeEngine.sharedInstance?.dispose();
    SdkContext.release();
    _listener.dispose();
  }

  // Triggers a rebuild of the widget.
  void _update() {
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(Icons.menu),
              onPressed: () {
                if (hikingApp != null &&
                    hikingApp!.gpxManager.getGPXTracks().isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MenuScreen(
                        entryKeys: hikingApp!.getMenuEntryKeys(),
                        entryTexts: hikingApp!.getMenuEntryDescriptions(),
                        onSelected: (index) {
                          hikingApp!.loadDiaryEntry(index);
                          Navigator.pop(context);
                          print('Selected entry index: $index');
                        },
                        onDeleted: (index) {
                          hikingApp!.deleteDiaryEntry(index);
                          print('Deleted entry index: $index');
                        },
                      ),
                    ),
                  );
                } else {
                  if (hikingApp != null) {
                    hikingApp!.setMessage("No hiking diary entries saved yet.");
                  }
                }
              }, // Add your logic here.
            ),
            Text('HikingDiary App'),
            Switch(
              value: _mapLayerSwitch,
              onChanged: (bool value) {
                setState(() {
                  _mapLayerSwitch = value;
                  if (hikingApp != null && _isLocationPermissionGranted) {
                    if (_mapLayerSwitch) {
                      _disableMapFeatures();
                      hikingApp!.enableOutdoorRasterLayer();
                    } else {
                      _enableMapFeatures();
                      hikingApp!.disableOutdoorRasterLayer();
                    }
                  }
                });
              },
              activeColor: Colors.lightBlueAccent,
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Center(
            child: HereMap(onMapCreated: _onMapCreated),
          ),
          _isLocationPermissionGranted
              ? Positioned(
                  top: 8.0,
                  left: 0.0,
                  right: 0.0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: _onStartHikeButtonPressed,
                        child: Text('Start'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromRGBO(0, 155, 155, 1),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _onStopHikeButtonPressed,
                        child: Text('Stop'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromRGBO(0, 155, 155, 1),
                        ),
                      ),
                    ],
                  ),
                )
              : Container(),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: EdgeInsets.only(
                  bottom: MediaQuery.of(context).size.height * 0.05),
              width: MediaQuery.of(context).size.width * 0.6,
              height: MediaQuery.of(context).size.height * 0.085,
              decoration: BoxDecoration(
                color: Color.fromRGBO(0, 145, 145, 1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  widget.messageNotifier.message,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onMapCreated(HereMapController hereMapController) {
    _hereMapController = hereMapController;

    // Load the map scene using a map scheme to render the map with.
    hereMapController.mapScene.loadSceneForMapScheme(MapScheme.topoDay,
        (MapError? error) async {
      _updateMessageState("Loading MapView ...");
      if (error == null) {
        // 1. We request the user's agreement to use HERE Positioning.
        // Note that this is not required for iOS.
        if (Platform.isAndroid) {
          // Shows an example of how to present application terms and a privacy policy dialog as
          // required by legal requirements when using HERE Positioning.
          // See the Positioning section in our Developer Guide for more details.
          final termsAndPrivacyHelper = HEREPositioningTermsAndPrivacyHelper(context);
          await termsAndPrivacyHelper.showAppTermsAndPrivacyPolicyDialogIfNeeded();
        }

        // 2. Ensure that the required permissions are handled.
        if (!await _requestPermissions()) {
          await _showDialog("Error",
              "Cannot start app: Location service and permissions are needed for this app.");
          // Let the user set the permissions from the system settings as fallback.
          openAppSettings();
          SystemNavigator.pop();
          return;
        }

        // 3. User has granted required permissions.
        _updateMessageState("MapView loaded");

        String message =
            "For this example app, an outdoor layer from thunderforest.com is used. " +
                "Without setting a valid API key, these raster tiles will show a watermark (terms of usage: https://www.thunderforest.com/terms/)." +
                "\n Attribution for the outdoor layer: \n Maps © www.thunderforest.com, \n Data © www.osm.org/copyright.";

        _showDialog("Note", message);

        hikingApp =
            HikingApp(hereMapController, widget.messageNotifier);
        _enableMapFeatures();

        setState(() {
          _isLocationPermissionGranted = true;
        });
      } else {
        print("Map scene not loaded. MapError: " + error.toString());
      }
    });
  }

  // Enhance the scene with map features suitable for hiking trips.
  void _enableMapFeatures() {
    _hereMapController?.mapScene
        .enableFeatures({MapFeatures.terrain: MapFeatureModes.terrain3d});
    _hereMapController?.mapScene
        .enableFeatures({MapFeatures.contours: MapFeatureModes.contoursAll});
    _hereMapController?.mapScene.enableFeatures({
      MapFeatures.buildingFootprints: MapFeatureModes.buildingFootprintsAll
    });
    _hereMapController?.mapScene.enableFeatures(
        {MapFeatures.extrudedBuildings: MapFeatureModes.extrudedBuildingsAll});
    _hereMapController?.mapScene.enableFeatures(
        {MapFeatures.landmarks: MapFeatureModes.landmarksTextured});
    _hereMapController?.mapScene.enableFeatures(
        {MapFeatures.ambientOcclusion: MapFeatureModes.ambientOcclusionAll});
  }

  // When a custom raster outdoor layer is shown, we do not need to load hidden map features to save bandwidth.
  void _disableMapFeatures() {
    _hereMapController?.mapScene.disableFeatures([
      MapFeatures.terrain, MapFeatures.contours, MapFeatures.buildingFootprints,
      MapFeatures.extrudedBuildings, MapFeatures.landmarks, MapFeatures.ambientOcclusion]);
  }

  // Request permissions with the permission_handler plugin. Set the required permissions here:
  // Android: hiking_diary_app/android/app/src/main/AndroidManifest.xml
  // iOS: hiking_diary_app/ios/Runner/Info.plist
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

  void _onStartHikeButtonPressed() {
    if (hikingApp != null) {
      hikingApp!.onStartHikingButtonClicked();
    }
  }

  void _onStopHikeButtonPressed() {
    if (hikingApp != null) {
      hikingApp!.onStopHikingButtonClicked();
    }
  }

  // A helper method to add a multiline button on top of the HERE map.
  Align multiLineButton(String buttonLabel, VoidCallback? callbackFunction) {
    return Align(
      alignment: Alignment.topCenter,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.lightBlueAccent,
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

  // Update the message text state and show selected log messages.
  void _updateMessageState(String messageState) {
    setState(() {
      print(messageState);
    });
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
