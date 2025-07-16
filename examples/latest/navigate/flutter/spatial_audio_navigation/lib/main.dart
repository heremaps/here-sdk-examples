/*
 * Copyright (C) 2019-2025 HERE Europe B.V.
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:here_sdk/core.dart' as HERE;
import 'package:here_sdk/core.engine.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/navigation.dart' as HERE;
import 'package:here_sdk/routing.dart' as HERE;

void main() async {
  // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
  await _initializeHERESDK();

  // Ensure that all widgets, including MyApp, have a MaterialLocalizations object available.
  runApp(MaterialApp(home: MyApp()));
}

Future<void> _initializeHERESDK() async {
  // Needs to be called before accessing SDKOptions to load necessary libraries.
  HERE.SdkContext.init(HERE.IsolateOrigin.main);

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

class _MyAppState extends State<MyApp> {
  static const methodChannel = MethodChannel('com.here.sdk.example/spatialAudioExample');
  late HERE.SpatialAudioCuePanning spatialAudioCuePanning;
  late final AppLifecycleListener _appLifecycleListener;
  HereMapController? _hereMapController;

  HERE.RoutingEngine? _routingEngine;
  HERE.VisualNavigator? _visualNavigator;
  HERE.LocationSimulator? _locationSimulator;

  _MyAppState() {
    // Receives calls whenever the native synthesization has been completed
    methodChannel.setMethodCallHandler(platformCallHandler);
  }

  Future<bool> _handleBackPress() async {
    // Handle the back press.
    _visualNavigator?.stopRendering();
    _locationSimulator?.stop();

    // Return true to allow the back press.
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: _handleBackPress,
        child: Scaffold(
          appBar: AppBar(
            title: Text('Spatial Navigation Example'),
          ),
          body: Stack(
            children: [
              HereMap(onMapCreated: _onMapCreated),
            ],
          ),
        ));
  }

  void _onMapCreated(HereMapController hereMapController) {
    _hereMapController = hereMapController;
    _hereMapController!.mapScene.loadSceneForMapScheme(MapScheme.normalDay, (MapError? error) {
      if (error != null) {
        print('Map scene not loaded. MapError: ${error.toString()}');
        return;
      }

      const double distanceToEarthInMeters = 8000;
      MapMeasure mapMeasureZoom = MapMeasure(MapMeasureKind.distanceInMeters, distanceToEarthInMeters);
      _hereMapController!.camera.lookAtPointWithMeasure(HERE.GeoCoordinates(52.520798, 13.409408), mapMeasureZoom);

      _startGuidanceExample();
    });
  }

  _startGuidanceExample() {
    _showDialog(
        "Spatial Audio Navigation", "This app routes to the HERE office in Berlin. See logs for guidance information.");

    // We start by calculating a car route.
    _calculateRoute();
  }

  _calculateRoute() {
    try {
      _routingEngine = HERE.RoutingEngine();
    } on InstantiationException {
      throw Exception('Initialization of RoutingEngine failed.');
    }

    HERE.Waypoint startWaypoint = HERE.Waypoint(HERE.GeoCoordinates(52.520798, 13.409408));
    HERE.Waypoint destinationWaypoint = HERE.Waypoint(HERE.GeoCoordinates(52.530905, 13.385007));

    _routingEngine!.calculateCarRoute([startWaypoint, destinationWaypoint], HERE.CarOptions(),
        (HERE.RoutingError? routingError, List<HERE.Route>? routeList) async {
      if (routingError == null) {
        // When error is null, it is guaranteed that the routeList is not empty.
        HERE.Route _calculatedRoute = routeList!.first;
        _startGuidance(_calculatedRoute);
      } else {
        final error = routingError.toString();
        print('Error while calculating a route: $error');
      }
    });
  }

  _startGuidance(HERE.Route route) {
    try {
      // Without a route set, this starts tracking mode.
      _visualNavigator = HERE.VisualNavigator();
    } on InstantiationException {
      throw Exception("Initialization of VisualNavigator failed.");
    }

    // This enables a navigation view including a rendered navigation arrow.
    _visualNavigator!.startRendering(_hereMapController!);

    // Event text options can be used for enabling the trigger for spatial audio details.
    HERE.EventTextOptions eventTextOptions = HERE.EventTextOptions();
    eventTextOptions.enableSpatialAudio = true;

    _visualNavigator!.eventTextOptions = eventTextOptions;

    _visualNavigator!.eventTextListener = HERE.EventTextListener((eventText) {
      String maneuverText = eventText.text;
      print("SpatialManeuverNotification: $maneuverText");
      if (eventText.spatialNotificationDetails != null) {
        synthesizeSpatialAudioCueAndPlay(eventText);
      }
    });

    // Set a route to follow. This leaves tracking mode.
    _visualNavigator!.route = route;

    // VisualNavigator acts as LocationListener to receive location updates directly from a location provider.
    // Any progress along the route is a result of getting a new location fed into the VisualNavigator.
    _setupLocationSource(_visualNavigator!, route);
  }

  _setupLocationSource(HERE.LocationListener locationListener, HERE.Route route) {
    try {
      // Provides fake GPS signals based on the route geometry.
      _locationSimulator = HERE.LocationSimulator.withRoute(route, HERE.LocationSimulatorOptions());
    } on InstantiationException {
      throw Exception("Initialization of LocationSimulator failed.");
    }

    _locationSimulator!.listener = locationListener;
    _locationSimulator!.start();
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
    HERE.SdkContext.release();
    _appLifecycleListener.dispose();
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
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future synthesizeSpatialAudioCueAndPlay(HERE.EventText eventText) async {
    this.spatialAudioCuePanning =
        eventText.spatialNotificationDetails!.audioCuePanning;
    await methodChannel.invokeMethod('synthesizeAudioCueAndPlay', {
      'audioCue': eventText.text,
      'initialAzimuth':
          eventText.spatialNotificationDetails!.initialAzimuthInDegrees
    });
  }

  Future notifyAzimuth(HERE.SpatialTrajectoryData spatialTrajectoryData) async {
    await methodChannel.invokeMethod('azimuthNotification', {
      'azimuth': spatialTrajectoryData.azimuthInDegrees,
      'completedTrajectory': spatialTrajectoryData.completedSpatialTrajectory
    });
  }

  // Receive callbacks from native platform
  Future platformCallHandler(MethodCall call) async {
    switch (call.method) {
      // Case called when synthesization of an audio cue has been completed
      case "onSynthesizatorDone":
        // Use the length obtained platform based in order to improve the audio cue duration estimation.
        final lengthMs = call.arguments as int;
        Duration duration = new Duration(milliseconds: lengthMs);
        HERE.CustomPanningData customPanningData =
            new HERE.CustomPanningData(duration, null, null);
        spatialAudioCuePanning.startAngularPanning(customPanningData,
            (spatialTrajectoryData) {
          notifyAzimuth(spatialTrajectoryData);
        });
        // audioCuePanning.startPanning(customPanningData);
        break;
    }
  }
}
