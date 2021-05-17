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

class PositioningExample extends State<MyApp> implements LocationListener, LocationStatusListener {
  static const String _notAvailable = "--";
  static const double _spacing = 8;
  static const double _padding = 20;
  static const double _labelWidth = 100;
  static const double _labelHeight = 20;
  static const double _cameraDistanceInMeters = 400;
  static final GeoCoordinates _defaultGeoCoordinates = GeoCoordinates(52.530932, 13.384915);

  final LocationEngine _locationEngine = LocationEngine();
  final ConsentEngine _consentEngine = ConsentEngine();

  HereMapController _hereMapController;
  LocationIndicator _locationIndicator;
  Location _location;
  LocationEngineStatus _status;

  @override
  void initState() {
    super.initState();
    _locationEngine.addLocationListener(this);
    _locationEngine.addLocationStatusListener(this);
  }

  @override
  void dispose() {
    _locationEngine.removeLocationStatusListener(this);
    _locationEngine.removeLocationListener(this);
    _stopLocating();
    super.dispose();
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
                      _location == null ? _notAvailable : _location.timestamp.toString(),
                    ),
                    _buildLabelValue(
                      'SinceBoot:',
                      _getTimestampSinceBootString(),
                    ),
                    const SizedBox(height: _padding),
                    _buildLabelValue(
                      'Status:',
                      _status == null ? _notAvailable : describeEnum(_status),
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

  void _ensureUserConsentRequested() {
    if (_consentEngine.userConsentState == ConsentUserReply.notHandled) {
      _consentEngine.requestUserConsent(context).then((_) => _startLocating());
    } else {
      _startLocating();
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
        _ensureUserConsentRequested();
      }
    });
  }

  void _onMapCreated(HereMapController hereMapController) {
    _requestPermissions();
    _hereMapController = hereMapController;
    hereMapController.mapScene.loadSceneForMapScheme(MapScheme.normalDay, (MapError error) {
      if (error != null) {
        print("Map scene not loaded. MapError: " + error.toString());
        Navigator.pop(context);
      }
    });
  }

  void _startLocating() {
    Location location = _locationEngine.lastKnownLocation;

    if (location != null) {
      print("Last known location: " +
          location.coordinates.latitude.toString() +
          ", " +
          location.coordinates.longitude.toString());
    } else {
      location = Location.withDefaults(_defaultGeoCoordinates, DateTime.now());
    }

    _addMyLocationToMap(location);

    _locationEngine.startWithLocationAccuracy(LocationAccuracy.bestAvailable);
  }

  void _stopLocating() {
    _locationEngine.stop();
  }

  void _addMyLocationToMap(Location myLocation) {
    if (_locationIndicator != null) {
      return;
    }
    // Set-up location indicator.
    _locationIndicator = LocationIndicator();
    _locationIndicator.locationIndicatorStyle = LocationIndicatorIndicatorStyle.pedestrian;
    _locationIndicator.updateLocation(myLocation);
    _hereMapController.addLifecycleListener(_locationIndicator);
    // Point camera at given location.
    _hereMapController.camera.lookAtPointWithDistance(
      myLocation.coordinates,
      _cameraDistanceInMeters,
    );
    // Update state's location.
    setState(() {
      _location = myLocation;
    });
  }

  void _updateMyLocationOnMap(Location myLocation) {
    // Update location indicator's location.
    _locationIndicator.updateLocation(myLocation);
    // Point camera at given location.
    _hereMapController.camera.lookAtPoint(myLocation.coordinates);
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

  String _getCoordinatesString() {
    if (_location == null) {
      return _notAvailable;
    }
    return _location.coordinates.latitude.toStringAsFixed(6) +
        ', ' +
        _location.coordinates.longitude.toStringAsFixed(6);
  }

  String _getHorizontalAccuracyString() {
    if (_location == null || _location.horizontalAccuracyInMeters == null) {
      return _notAvailable;
    }
    return _location.horizontalAccuracyInMeters.toStringAsFixed(1) + ' m';
  }

  String _getVerticalAccuracyString() {
    if (_location == null || _location.verticalAccuracyInMeters == null) {
      return _notAvailable;
    }
    return _location.verticalAccuracyInMeters.toStringAsFixed(1) + ' m';
  }

  String _getBearingString() {
    if (_location == null || _location.bearingInDegrees == null) {
      return _notAvailable;
    }
    return _location.bearingInDegrees.toStringAsFixed(1) + ' °';
  }

  String _getBearingAccuracyString() {
    if (_location == null || _location.bearingAccuracyInDegrees == null) {
      return _notAvailable;
    }
    return _location.bearingAccuracyInDegrees.toStringAsFixed(1) + ' °';
  }

  String _getSpeedString() {
    if (_location == null || _location.speedInMetersPerSecond == null) {
      return _notAvailable;
    }
    return _location.speedInMetersPerSecond.toStringAsFixed(1) + ' m/s';
  }

  String _getSpeedAccuracyString() {
    if (_location == null || _location.speedAccuracyInMetersPerSecond == null) {
      return _notAvailable;
    }
    return _location.speedAccuracyInMetersPerSecond.toStringAsFixed(1) + ' m/s';
  }

  String _getTimestampSinceBootString() {
    if (_location == null || _location.timestampSinceBootInMilliseconds == null) {
      return _notAvailable;
    }
    return _location.timestampSinceBootInMilliseconds.toStringAsFixed(1) + ' ms';
  }
}
