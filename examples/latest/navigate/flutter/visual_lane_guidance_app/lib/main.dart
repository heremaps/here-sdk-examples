/*
 * Copyright (C) 2025-2026 HERE Europe B.V.
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
import 'package:here_sdk/core.engine.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/core.dart';
import 'package:permission_handler/permission_handler.dart';

import 'VisualLaneGuidanceExample.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
  await _initializeHERESDK();
  runApp(const MaterialApp(home: VisualLaneGuidanceApp()));
}

Future<void> _initializeHERESDK() async {
  // Needs to be called before accessing SDKOptions to load necessary libraries.
  SdkContext.init(IsolateOrigin.main);
  // Set your credentials for the HERE SDK. Note that this app requires the Navigate license
  // and a separate license to enable visual lane guidance.
  const accessKeyId = 'YOUR_ACCESS_KEY_ID';
  const accessKeySecret = 'YOUR_ACCESS_KEY_SECRET';
  final authenticationMode = AuthenticationMode.withKeySecret(accessKeyId, accessKeySecret);
  final options = SDKOptions.withAuthenticationMode(authenticationMode);

  try {
    await SDKNativeEngine.makeSharedInstance(options);
  } on InstantiationException {
    throw Exception('Failed to initialize the HERE SDK.');
  }
}

class VisualLaneGuidanceApp extends StatefulWidget {
  const VisualLaneGuidanceApp({super.key});

  @override
  State<VisualLaneGuidanceApp> createState() => _VisualLaneGuidanceAppState();
}

class _VisualLaneGuidanceAppState extends State<VisualLaneGuidanceApp> {
  VisualLaneGuidanceExample? _example;
  HereMapController? _mapController;
  late final AppLifecycleListener _appLifecycleListener;
  bool _isHereSdkDisposed = false;
  MapScheme _currentMapScheme = MapScheme.clusterDay;
  _MenuAction _selectedMenuAction = _MenuAction.menu;
  _SettingsAction _selectedSettingsAction = _SettingsAction.settings;
  String _status = 'Camera: not initialized | Map scheme: CLUSTER DAY | Route: not selected';

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HERE SDK - Visual Lane Guidance Example')),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            HereMap(onMapCreated: _onMapCreated),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: _themedDropdown<_MenuAction>(
                          value: _selectedMenuAction,
                          items: const [
                            DropdownMenuItem(value: _MenuAction.menu, child: Text('MENU')),
                            DropdownMenuItem(value: _MenuAction.calculateChicago, child: Text('Calculate route in Chicago')),
                            DropdownMenuItem(value: _MenuAction.calculateBerlin, child: Text('Calculate route in Berlin')),
                            DropdownMenuItem(value: _MenuAction.startGuidance, child: Text('Start guidance')),
                            DropdownMenuItem(value: _MenuAction.stopGuidance, child: Text('Stop guidance')),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _selectedMenuAction = value;
                            });
                            switch (value) {
                              case _MenuAction.calculateChicago:
                                _calculateChicagoRoute();
                                break;
                              case _MenuAction.calculateBerlin:
                                _calculateBerlinRoute();
                                break;
                              case _MenuAction.startGuidance:
                                _startGuidance();
                                break;
                              case _MenuAction.stopGuidance:
                                _stopGuidance();
                                break;
                              case _MenuAction.menu:
                                break;
                            }
                            setState(() => _selectedMenuAction = _MenuAction.menu);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _themedDropdown<_SettingsAction>(
                          value: _selectedSettingsAction,
                          items: const [
                            DropdownMenuItem(value: _SettingsAction.settings, child: Text('SETTINGS')),
                            DropdownMenuItem(value: _SettingsAction.transitionCamera, child: Text('Use Transition camera behavior')),
                            DropdownMenuItem(value: _SettingsAction.automotiveCamera, child: Text('Use Automotive camera behavior')),
                            DropdownMenuItem(value: _SettingsAction.normalDay, child: Text('Use NORMAL DAY map scheme')),
                            DropdownMenuItem(value: _SettingsAction.clusterDay, child: Text('Use CLUSTER DAY map scheme')),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _selectedSettingsAction = value;
                            });
                            switch (value) {
                              case _SettingsAction.transitionCamera:
                                _useTransitionCamera();
                                break;
                              case _SettingsAction.automotiveCamera:
                                _useAutomotiveCamera();
                                break;
                              case _SettingsAction.normalDay:
                                _setMapScheme(MapScheme.normalDay);
                                break;
                              case _SettingsAction.clusterDay:
                                _setMapScheme(MapScheme.clusterDay);
                                break;
                              case _SettingsAction.settings:
                                break;
                            }
                            setState(() => _selectedSettingsAction = _SettingsAction.settings);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                _statusCard(_status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _themedDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          selectedItemBuilder: (context) {
            return items
                .map((item) => Align(
                      alignment: Alignment.centerLeft,
                      child: DefaultTextStyle(
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        child: item.child,
                      ),
                    ))
                .toList();
          },
          onChanged: onChanged,
          isExpanded: true,
          dropdownColor: Colors.white,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          style: const TextStyle(color: Colors.black, fontSize: 16),
        ),
      ),
    );
  }

  Widget _statusCard(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Text(message, style: const TextStyle(fontSize: 15, color: Colors.white)),
      ),
      color: Colors.blue,
      margin: const EdgeInsets.only(left: 8, right: 8, top: 8),
    );
  }

  Future<void> _onMapCreated(HereMapController hereMapController) async {
    _mapController = hereMapController;
    if (!await _requestPermissions()) {
      if (mounted) {
        _showDialog('Error', 'Please enable location service and grant required permissions.');
      }
      return;
    }

    _loadMapScene();
  }

  // Requests runtime permissions required for route simulation and navigation rendering.
  Future<bool> _requestPermissions() async {
    if (!await Permission.location.serviceStatus.isEnabled) {
      return false;
    }
    if (!await Permission.location.request().isGranted) {
      return false;
    }
    if (Platform.isAndroid) {
      await Permission.activityRecognition.request();
    }
    return true;
  }

  // Loads the map scene and initializes the example once the map is ready.
  void _loadMapScene() {
    final controller = _mapController;
    if (controller == null) return;

    // Load a scene from the HERE SDK to render the map with a map scheme and selected map features.
    controller.mapScene.loadSceneForMapScheme(_currentMapScheme, (MapError? error) async {
      if (error != null) {
        _showDialog('Map load error', error.toString());
        return;
      }

      if (_example == null) {
        const double distanceInMeters = 1000 * 10;
        final mapMeasureZoom = MapMeasure(MapMeasureKind.distanceInMeters, distanceInMeters);
        controller.camera.lookAtPointWithMeasure(
          GeoCoordinates(37.53931, -122.05891),
          mapMeasureZoom,
        );

        _example = VisualLaneGuidanceExample(controller, _showDialog);
        await _example!.initialize();
      }

      _updateStatus();
    });
  }

  void _calculateChicagoRoute() {
    _example?.calculateChicagoRoute();
    _updateStatus();
  }

  void _calculateBerlinRoute() {
    _example?.calculateBerlinRoute();
    _updateStatus();
  }

  void _startGuidance() {
    _example?.startGuidance();
    _updateStatus();
  }

  void _stopGuidance() {
    _example?.stopGuidance();
    _updateStatus();
  }

  void _useTransitionCamera() {
    _example?.useTransitionCameraBehavior();
    _updateStatus();
  }

  void _useAutomotiveCamera() {
    _example?.useAutomotiveCameraBehavior();
    _updateStatus();
  }

  void _setMapScheme(MapScheme scheme) {
    _currentMapScheme = scheme;
    _loadMapScene();
    _updateStatus();
  }

  void _updateStatus() {
    final example = _example;
    if (example == null) {
      setState(() {
        _status = 'Camera: not initialized | Map scheme: ${_mapSchemeLabel(_currentMapScheme)} | Route: not selected';
      });
      return;
    }

    setState(() {
      _status = 'Camera: ${example.cameraStatus} | Map scheme: ${_mapSchemeLabel(_currentMapScheme)} | Route: ${_routeLabel(example.selectedRoute)}';
    });
  }

  String _mapSchemeLabel(MapScheme scheme) {
    if (scheme == MapScheme.normalDay) return 'NORMAL DAY';
    if (scheme == MapScheme.clusterDay) return 'CLUSTER DAY';
    return scheme.toString();
  }

  String _routeLabel(RouteSelection selection) {
    switch (selection) {
      case RouteSelection.chicago:
        return 'Chicago';
      case RouteSelection.berlin:
        return 'Berlin';
      case RouteSelection.none:
        return 'not selected';
    }
  }

  void _showDialog(String title, String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: ListBody(children: <Widget>[Text(message)])),
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

  @override
  void dispose() {
    _example?.dispose();
    _disposeHERESDK();
    super.dispose();
  }

  void _disposeHERESDK() async {
    if (_isHereSdkDisposed) {
      return;
    }
    _isHereSdkDisposed = true;

    // Free HERE SDK resources before the application shuts down.
    await SDKNativeEngine.sharedInstance?.dispose();
    SdkContext.release();
    _appLifecycleListener.dispose();
  }
}

enum _MenuAction {
  menu,
  calculateChicago,
  calculateBerlin,
  startGuidance,
  stopGuidance,
}

enum _SettingsAction {
  settings,
  transitionCamera,
  automotiveCamera,
  normalDay,
  clusterDay,
}
