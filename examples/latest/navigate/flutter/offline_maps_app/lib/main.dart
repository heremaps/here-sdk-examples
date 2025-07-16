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

import 'OfflineMapsExample.dart';

void main() async {
  String accessKeyId = "YOUR_ACCESS_KEY_ID";
  String accessKeySecret = "YOUR_ACCESS_KEY_SECRET";

  // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
  await _initializeHERESDK(accessKeyId,accessKeySecret);

  // Ensure that all widgets, including MyApp, have a MaterialLocalizations object available.
  runApp(MaterialApp(home: MyApp(accessKeyId: accessKeyId,accessKeySecret: accessKeySecret)));
}

Future<void> _initializeHERESDK(String accessKeyId,String accessKeySecret) async {
  // Needs to be called before accessing SDKOptions to load necessary libraries.
  SdkContext.init(IsolateOrigin.main);

  // Set your credentials for the HERE SDK.

  AuthenticationMode authenticationMode = AuthenticationMode.withKeySecret(accessKeyId, accessKeySecret);
  SDKOptions sdkOptions = SDKOptions.withAuthenticationMode(authenticationMode);

  // With this layer configuration we enable only the listed layers.
  // All the other layers including the default layers will be disabled.
  var enabledFeatures = [LayerConfigurationFeature.detailRendering,LayerConfigurationFeature.rendering,LayerConfigurationFeature.offlineSearch];
  var layerConfiguration = LayerConfiguration(enabledFeatures);
  sdkOptions.layerConfiguration = layerConfiguration;

  try {
    await SDKNativeEngine.makeSharedInstance(sdkOptions);
  } on InstantiationException {
    throw Exception("Failed to initialize the HERE SDK.");
  }
}

class MyApp extends StatefulWidget {
  final String? accessKeyId ;
  final String? accessKeySecret ;

  @override
  _MyAppState createState() => _MyAppState();

  MyApp({Key? key, this.accessKeyId, this.accessKeySecret }) : super(key: key);

}

class _MyAppState extends State<MyApp> {
  OfflineMapsExample? _offlineMapsExample;
  final List<bool> _selectedOfflineMode = <bool>[true];
  final List<bool> _toggleOfflineSearchLayer = <bool>[true];
  final ValueNotifier<bool> mapRebuildNotifier = ValueNotifier(false);
  Key _refreshKey = UniqueKey();
  late final AppLifecycleListener _appLifecycleListener;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _refreshKey,
      appBar: AppBar(
        title: Text('HERE SDK - Offline Maps Example'),
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
                  button('Regions', _regionsButtonClicked),
                  button('Download', _downloadButtonClicked),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  button('Cancel', _cancelButtonClicked),
                  button('Area', _areaButtonClicked),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  button('Test Search', _testButtonClicked),
                  button('Clear Cache', _clearCacheClicked),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  button('Delete Regions', _deleteRegionsClicked),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ToggleButtons(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: Colors.lightBlueAccent,
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          child: Text(
                            _selectedOfflineMode[0]
                                ? 'Offline Mode-OFF'
                                : 'Offline Mode-ON',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18.0,
                            ),
                          ),

                        ),
                      ],
                      onPressed: (int index) {
                        setState(() {
                          _selectedOfflineMode[index] =
                          !_selectedOfflineMode[index];
                        });
                        _toggleOnlineMode();
                      },
                      isSelected: _selectedOfflineMode
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ToggleButtons(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: Colors.lightBlueAccent,
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          child: Text(
                            _toggleOfflineSearchLayer[0]
                                ? 'offlineSearch layer: ON'
                                : 'offlineSearch layer: OFF',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18.0,
                            ),
                          ),
                        ),
                      ],
                      onPressed: (int index) {
                        setState(() {
                          _toggleOfflineSearchLayer[index] =
                          !_toggleOfflineSearchLayer[index];

                        });
                        _toggleConfiguration();
                      },
                      isSelected: _toggleOfflineSearchLayer
                  ),
                ],
              )
            ],
          ),
        ],
      ),
    );
  }

  void _rebuildMap() {
    setState(() {
      // Force rebuild of mapview.
      _refreshKey = UniqueKey();
    });
  }

  void _onMapCreated(HereMapController hereMapController) {
    hereMapController.mapScene.loadSceneForMapScheme(MapScheme.normalDay, (MapError? error) {
      if (error == null) {
        _offlineMapsExample = OfflineMapsExample(_showDialog, hereMapController);
      } else {
        print("Map scene not loaded. MapError: " + error.toString());
      }
    });
  }

  void _regionsButtonClicked() {
    _offlineMapsExample?.onDownloadListClicked();
  }

  void _downloadButtonClicked() {
    _offlineMapsExample?.onDownloadMapClicked();
  }

  void _areaButtonClicked() {
    _offlineMapsExample?.onDownloadAreaClicked();
  }

  void _cancelButtonClicked() {
    _offlineMapsExample?.onCancelMapDownloadClicked();
  }

  void _testButtonClicked() {
    _offlineMapsExample?.onSearchPlaceClicked();
  }

  void _toggleOnlineMode() {
    if(_selectedOfflineMode[0]){
      _offlineMapsExample?.onOnlineButtonClicked();
    }else{
      _offlineMapsExample?.onOfflineButtonClicked();
    }
  }

  void _clearCacheClicked() {
    _offlineMapsExample?.onClearCache();
  }

  void _deleteRegionsClicked() {
    _offlineMapsExample?.deleteDownloadedRegions();
  }

  void _toggleConfiguration() {
    _offlineMapsExample?.toggleLayerConfiguration(widget.accessKeyId!, widget.accessKeySecret!, _rebuildMap);
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
    SdkContext.release();
    _appLifecycleListener.dispose();
  }

  // A helper method to add a button on top of the HERE map.
  Align button(String buttonLabel, Function callbackFunction) {
    return Align(
      alignment: Alignment.topCenter,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.lightBlueAccent,
          foregroundColor: Colors.white,
        ),
        onPressed: () => callbackFunction(),
        child: Text(buttonLabel, style: TextStyle(fontSize: 20)),
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
}
