/*
 * Copyright (C) 2020-2021 HERE Europe B.V.
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

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:here_sdk/consent.dart' show ConsentEngine, ConsentUserReply;
import 'package:here_sdk/core.dart';
import 'package:here_sdk/location.dart';
import 'package:here_sdk/mapview.dart';
import 'package:permission_handler/permission_handler.dart';

import 'main.dart';

class PositioningExample extends State<MyApp>
    with WidgetsBindingObserver
    implements LocationListener, LocationStatusListener {
  static const String _notAvailable = "--";
  static const double _spacing = 8;
  static const double _padding = 20;
  static const double _labelWidth = 100;
  static const double _labelHeight = 20;
  static const double _cameraDistanceInMeters = 400;
  static final GeoCoordinates _defaultGeoCoordinates = GeoCoordinates(52.530932, 13.384915);

  final LocationEngine _locationEngine = LocationEngine();
  final ConsentEngine _consentEngine = ConsentEngine();

  HereMapController? _hereMapController;
  LocationIndicator? _locationIndicator;
  Location? _location;
  LocationEngineStatus? _status;

  // When using HERE Positioning in your app, it is required to request and to show the user's consent decision.
  // In addition, users must be able to change their consent decision at any time.
  // Note that this is only needed when running on Android devices.
  static const String _consentGranted = 'Positioning consent: You have granted consent to the data collection.';
  static const String _consentDenied = 'Positioning consent: You have denied consent to the data collection.';
  String _consentState = 'Pending ...';

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
      _stopLocating();
    } else if (state == AppLifecycleState.resumed) {
      _startLocating();
    }
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
                    multiLineButton(_consentState, _requestConsent),
                  ],
                ),
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

  Future<void> _ensureUserConsentRequested() async {
    // Check if user consent has been handled.
    if (_consentEngine.userConsentState == ConsentUserReply.notHandled) {
      // Show dialog.
      await _consentEngine.requestUserConsent(context);
    }

    _updateConsentInfo();
    _startLocating();
  }

  Future<void> _requestConsent() async {
    if (Platform.isAndroid) {
      await _consentEngine.requestUserConsent(context);
      _updateConsentInfo();
    }
  }

  // Update the button's text showing the current consent decision of the user.
  void _updateConsentInfo() {
    if (Platform.isIOS) {
      setState(() {
        _consentState = 'Info: On iOS no consent is required as on iOS no data is collected.';
      });
      return;
    }

    if (_consentEngine.userConsentState == ConsentUserReply.granted) {
      setState(() {
        _consentState = _consentGranted;
      });
    } else {
      setState(() {
        _consentState = _consentDenied;
      });
    }
  }

  void _requestPermissions() {
    Permission.location.request().then((status) {
      if (status != PermissionStatus.granted) {
        print("Location permission is needed for this example.");
        Navigator.pop(context);
      } else if (Platform.isAndroid) {
        Permission.activityRecognition.request().then((_) => _ensureUserConsentRequested());
      } else {
        // A user consent request is not required on iOS.
        _updateConsentInfo();
        _startLocating();
      }
    });
  }

  void _onMapCreated(HereMapController hereMapController) {
    _requestPermissions();
    _hereMapController = hereMapController;
    hereMapController.mapScene.loadSceneForMapScheme(MapScheme.normalDay, (MapError? error) {
      if (error != null) {
        print("Map scene not loaded. MapError: " + error.toString());
        Navigator.pop(context);
      }
    });
  }

  void _startLocating() {
    Location? location = _locationEngine.lastKnownLocation;

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

    _locationEngine.addLocationListener(this);
    _locationEngine.addLocationStatusListener(this);
    _locationEngine.startWithLocationAccuracy(LocationAccuracy.bestAvailable);
  }

  void _stopLocating() {
    _locationEngine.removeLocationStatusListener(this);
    _locationEngine.removeLocationListener(this);
    _locationEngine.stop();
  }

  void _addMyLocationToMap(Location myLocation) {
    if (_locationIndicator != null) {
      _hereMapController?.removeLifecycleListener(_locationIndicator!);
    }
    // Set-up location indicator.
    _locationIndicator = LocationIndicator();
    _locationIndicator?.locationIndicatorStyle = LocationIndicatorIndicatorStyle.pedestrian;
    _locationIndicator?.updateLocation(myLocation);
    _hereMapController?.addLifecycleListener(_locationIndicator!);
    // Point camera at given location.
    _hereMapController?.camera.lookAtPointWithDistance(
      myLocation.coordinates,
      _cameraDistanceInMeters,
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
    _locationIndicator?.updateLocation(myLocation);
    // Point camera at given location.
    _hereMapController?.camera.lookAtPoint(myLocation.coordinates);
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
  void release() {
    // Nothing to do here.
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
          primary: Colors.lightBlueAccent,
          onPrimary: Colors.white,
        ),
        onPressed: () => callbackFunction(),
        child: Container(width: 250, child: Text(buttonLabel, style: TextStyle(fontSize: 15))),
      ),
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
    return '${_location?.timestampSinceBootInMilliseconds?.toStringAsFixed(1) ?? _notAvailable}' + ' ms';
  }
}
