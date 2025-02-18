/*
 * Copyright (C) 2020-2025 HERE Europe B.V.
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

import 'dart:io' show Platform, Process;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.engine.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/location.dart';
import 'package:here_sdk/mapview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';


import 'main.dart';

class PositioningExample extends State<MyApp>
    with WidgetsBindingObserver
    implements LocationListener, LocationStatusListener, LocationIssueListener {
  static const String _notAvailable = "--";
  static const double _spacing = 8;
  static const double _padding = 20;
  static const double _labelWidth = 100;
  static const double _labelHeight = 20;
  static const double _cameraDistanceInMeters = 400;
  static final GeoCoordinates _defaultGeoCoordinates = GeoCoordinates(52.530932, 13.384915);
  static final String _prefServiceTerms = "service_terms";

  LocationEngine? _locationEngine;

  HereMapController? _hereMapController;
  LocationIndicator? _locationIndicator;
  Location? _location;
  LocationEngineStatus? _status;
  List<LocationIssueType> _issues = <LocationIssueType>[];
  late final AppLifecycleListener _appLifecycleListener;
  bool? _serviceTermsAccepted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);

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
    WidgetsBinding.instance!.removeObserver(this);
    _disposeHERESDK();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _stopLocating();
    } else if (state == AppLifecycleState.resumed) {
      if (_locationEngine != null) {
        _startLocating();
      }
    }
  }

  void _disposeHERESDK() async {
    // Free HERE SDK resources before the application shuts down.
    await SDKNativeEngine.sharedInstance?.dispose();
    SdkContext.release();
    _appLifecycleListener.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('HERE SDK - Positioning Example'),
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
                    IgnorePointer(
                      child: Padding(
                        padding: const EdgeInsets.all(_spacing),
                        child: Column(
                          children: [
                            _buildLabelValue(
                              'Coordinates:',
                              _getCoordinatesString(),
                            ),
                            _buildLabelValue(
                              'Horz.Accuracy:',
                              _getHorizontalAccuracyString(),
                            ),
                            _buildLabelValue(
                              'Vert.Accuracy:',
                              _getVerticalAccuracyString(),
                            ),
                            _buildLabelValue(
                              'Bearing:',
                              _getBearingString(),
                            ),
                            _buildLabelValue(
                              'Bear.Accuracy:',
                              _getBearingAccuracyString(),
                            ),
                            _buildLabelValue(
                              'Speed:',
                              _getSpeedString(),
                            ),
                            _buildLabelValue(
                              'Speed.Accuracy:',
                              _getSpeedAccuracyString(),
                            ),
                            _buildLabelValue(
                              'Timestamp:',
                              _location?.time.toString() ?? _notAvailable,
                            ),
                            _buildLabelValue(
                              'SinceBoot:',
                              _getTimestampSinceBootString(),
                            ),
                            _buildLabelValue(
                              'Issues:',
                              _issues.map((issue) => issue.toString().split('.').last).join(', '),
                            ),
                            const SizedBox(height: _padding),
                            _buildLabelValue(
                              'Status:',
                              _status == null ? _notAvailable : describeEnum(_status!),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _requestPermissions() async {
    if (!await Permission.location.serviceStatus.isEnabled) {
      return false;
    }

    if (!await Permission.location.request().isGranted) {
      return false;
    }

    // All required permissions granted.
    return true;
  }

  void _onMapCreated(HereMapController hereMapController) {
    _hereMapController = hereMapController;
    hereMapController.mapScene.loadSceneForMapScheme(MapScheme.normalDay, (MapError? error) async {
      if (error == null) {
        if (Platform.isAndroid) {
          await _readPrefs();

          if (_serviceTermsAccepted == null ||
              _serviceTermsAccepted == false) {
            // Shows example of application Terms & Privacy policy dialog as
            // required by Legal Requirements in Development Guide under Positioning
            // section.
            await _showApplicationTermsAndConditionsDialog();
          }
        }

        // Before we start the app we want to ensure that the required permissions are handled.
        if (!await _requestPermissions()) {
          await _showDialog("Error", "Cannot start app: Location service and permissions are needed for this app.");
          // Let the user set the permissions from the system settings as fallback.
          openAppSettings();
          SystemNavigator.pop();
          return;
        }

        try {
          _locationEngine = LocationEngine();
        } on InstantiationException {
          throw ("Initialization of LocationEngine failed.");
        }

        // Once permissions are granted, start locating.
        _startLocating();
      } else {
        print('Map scene not loaded. MapError: ' + error.toString());
      }
    });
  }

  void _startLocating() {
    Location? location = _locationEngine!.lastKnownLocation;

    if (location != null) {
      print("Last known location: " +
          location.coordinates.latitude.toString() +
          ", " +
          location.coordinates.longitude.toString());
    } else {
      location = Location.withCoordinates(_defaultGeoCoordinates);
      location.time = DateTime.now();
    }

    _addMyLocationToMap(location);

    // Enable background updates on iOS.
    _locationEngine!.setBackgroundLocationAllowed(true);
    _locationEngine!.setBackgroundLocationIndicatorVisible(true);

    // Set delegates and start location engine.
    _locationEngine!.addLocationListener(this);
    _locationEngine!.addLocationStatusListener(this);
    _locationEngine!.addLocationIssueListener(this);
    if (Platform.isAndroid) {
      _locationEngine!.confirmHEREPrivacyNoticeInclusion();
    }
    _locationEngine!.startWithLocationAccuracy(LocationAccuracy.bestAvailable);
  }

  void _stopLocating() {
    _locationEngine!.removeLocationIssueListener(this);
    _locationEngine!.removeLocationStatusListener(this);
    _locationEngine!.removeLocationListener(this);
    _locationEngine!.stop();
  }

  void _addMyLocationToMap(Location myLocation) {
    if (_locationIndicator != null) {
      return;
    }
    // Set-up location indicator.
    _locationIndicator = LocationIndicator();
    // Enable a halo to indicate the horizontal accuracy.
    _locationIndicator!.isAccuracyVisualized = true;
    _locationIndicator!.locationIndicatorStyle = LocationIndicatorIndicatorStyle.pedestrian;
    _locationIndicator!.updateLocation(myLocation);
    _locationIndicator!.enable(_hereMapController!);

    // Point camera at given location.
    MapMeasure mapMeasureZoom = MapMeasure(MapMeasureKind.distanceInMeters, _cameraDistanceInMeters);
    _hereMapController!.camera.lookAtPointWithMeasure(
      myLocation.coordinates,
      mapMeasureZoom,
    );

    // Update state's location.
    setState(() {
      _location = myLocation;
    });
  }

  void _updateMyLocationOnMap(Location myLocation) {
    if (_locationIndicator == null) {
      return;
    }

    // Update location indicator's location.
    _locationIndicator!.updateLocation(myLocation);
    // Point camera at given location.
    _hereMapController!.camera.lookAtPoint(myLocation.coordinates);
    // Update state's location.
    setState(() {
      _location = myLocation;
    });
  }

  @override
  onFeaturesNotAvailable(List<LocationFeature> features) {
    for (var feature in features) {
      print("Feature not available: " + feature.toString());
    }
  }

  @override
  void onLocationUpdated(Location location) {
    print("Location update: " +
        location.coordinates.latitude.toString() +
        ", " +
        location.coordinates.longitude.toString());
    _updateMyLocationOnMap(location);
  }

  @override
  void onStatusChanged(LocationEngineStatus locationEngineStatus) {
    setState(() {
      _status = locationEngineStatus;
    });
  }

  @override
  void onLocationIssueChanged(List<LocationIssueType> issues) {
    setState(() => _issues = issues);
  }

  Widget _buildLabelValue(String text, String value) {
    return Row(
      children: <Widget>[
        _createLabel(text),
        const SizedBox(width: _padding),
        _createValue(value),
      ],
    );
  }

  Widget _createLabel(String text) {
    return SizedBox(
      width: _labelWidth,
      height: _labelHeight,
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _createValue(String text) {
    return SizedBox(height: _labelHeight, child: Text(text));
  }

  // A helper method to add a multiline button on top of the HERE map.
  Align multiLineButton(String buttonLabel, Function callbackFunction) {
    return Align(
      alignment: Alignment.topCenter,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.lightBlueAccent,
          foregroundColor: Colors.white,
        ),
        onPressed: () => callbackFunction(),
        child: Container(width: 250, child: Text(buttonLabel, style: TextStyle(fontSize: 15))),
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

  String _getCoordinatesString() {
    if (_location == null) {
      return _notAvailable;
    }
    return _location!.coordinates.latitude.toStringAsFixed(6) +
        ', ' +
        _location!.coordinates.longitude.toStringAsFixed(6);
  }

  String _getHorizontalAccuracyString() {
    return '${_location?.horizontalAccuracyInMeters?.toStringAsFixed(1) ?? _notAvailable}' + ' m';
  }

  String _getVerticalAccuracyString() {
    return '${_location?.verticalAccuracyInMeters?.toStringAsFixed(1) ?? _notAvailable}' + ' m';
  }

  String _getBearingString() {
    return '${_location?.bearingInDegrees?.toStringAsFixed(1) ?? _notAvailable}' + ' °';
  }

  String _getBearingAccuracyString() {
    return '${_location?.bearingAccuracyInDegrees?.toStringAsFixed(1) ?? _notAvailable}' + ' °';
  }

  String _getSpeedString() {
    return '${_location?.speedInMetersPerSecond?.toStringAsFixed(1) ?? _notAvailable}' + ' m/s';
  }

  String _getSpeedAccuracyString() {
    return '${_location?.speedAccuracyInMetersPerSecond?.toStringAsFixed(1) ?? _notAvailable}' + ' m/s';
  }

  String _getTimestampSinceBootString() {
    return '${_location?.timestampSinceBoot?.toString() ?? _notAvailable}' + ' ms';
  }

  // A helper method to show terms and conditions dialog.
  Future<void> _showApplicationTermsAndConditionsDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        content: GestureDetector(
          onTap: () async {
            await _showPrivacyPolicyDialog();
            Navigator.of(context).pop();
          },
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(text: "You need to agree to the Service Terms and ", style: TextStyle(backgroundColor: Colors.white, color: Colors.black, fontSize: 18)),
                  TextSpan(text: "Privacy Policy", style: TextStyle(backgroundColor: Colors.white, color: Colors.blue, fontSize: 18, decoration: TextDecoration.underline)),
                  TextSpan(text: " to use this app.", style: TextStyle(backgroundColor: Colors.white, color: Colors.black, fontSize: 18)),
                ],
              ),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            style: TextButton.styleFrom(
              textStyle: Theme.of(context).textTheme.labelLarge,
            ),
            child: const Text('Agree'),
            onPressed: () {
              _serviceTermsAccepted = true;
              _savePrefs();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  // A helper method to show terms and conditions dialog.
  Future<void> _showPrivacyPolicyDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        content: GestureDetector(
            onTap: () {
              _launchUrl("https://legal.here.com/here-network-positioning-via-sdk");
            },
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: RichText(
                  text: TextSpan(
                      children: [
                        TextSpan(text: "Your privacy when using this application.\n\n", style: TextStyle(backgroundColor: Colors.white, color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                        TextSpan(text: "(In this Privacy Policy example, the following paragraph demonstrates one way to inform app users about data collection. All other potential privacy-related aspects are intentionally omitted from this example.)\n\n", style: TextStyle(backgroundColor: Colors.white, color: Colors.black, fontSize: 18)),
                        TextSpan(text: "This application uses location services provided by HERE Technologies. To maintain, improve and provide these services, HERE Technologies from time to time gathers characteristics information about the near-by network signals. For more information, please see the HERE Privacy Notice at ", style: TextStyle(backgroundColor: Colors.white, color: Colors.black, fontSize: 18)),
                        TextSpan(text: "https://legal.here.com/here-network-positioning-via-sdk", style: TextStyle(backgroundColor: Colors.white, color: Colors.blue, fontSize: 18, decoration: TextDecoration.underline)),
                        TextSpan(text: ".", style: TextStyle(backgroundColor: Colors.white, color: Colors.black, fontSize: 18)),
                      ],
                  ),
                ),
              ),
            ),
        ),
        actions: <Widget>[
          TextButton(
            style: TextButton.styleFrom(
              textStyle: Theme.of(context).textTheme.labelLarge,
            ),
            child: const Text('Agree'),
            onPressed: () {
              _serviceTermsAccepted = true;
              _savePrefs();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _savePrefs() async {
      SharedPreferences preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_prefServiceTerms, _serviceTermsAccepted!);
  }

  Future<void> _readPrefs() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    setState(() {
      _serviceTermsAccepted = preferences.getBool(_prefServiceTerms);
    });
  }

  void _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!uri.hasScheme) return; // Prevent invalid URLs

    try {
      const platform = MethodChannel('com.here.sdk.examples.positioning_app');
      await platform.invokeMethod('openWebLink', url);
    } catch (e) {
      print("Could not open the URL: $e");
    }
  }
}
