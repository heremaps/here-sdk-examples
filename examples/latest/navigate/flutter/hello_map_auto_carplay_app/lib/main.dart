/*
 * Copyright (C) 2026 HERE Europe B.V.
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
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.engine.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/mapview.dart';

import 'hello_map_example.dart';

const MethodChannel _nativeChannel = MethodChannel(
  'com.here.sdk.examples.hello_map_auto_carplay_app/channel',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Needs to be called before accessing SDKOptions to load necessary libraries.
  SdkContext.init(IsolateOrigin.main);

  // Set your credentials for the HERE SDK.
  String accessKeyId = "YOUR_ACCESS_KEY_ID";
  String accessKeySecret = "YOUR_ACCESS_KEY_SECRET";
  AuthenticationMode authenticationMode = AuthenticationMode.withKeySecret(
    accessKeyId,
    accessKeySecret,
  );
  SDKOptions sdkOptions = SDKOptions.withAuthenticationMode(authenticationMode);

  // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
  // Initialization happens here on the Dart side only - the native side does not initialize the SDK.
  try {
    await SDKNativeEngine.makeSharedInstance(sdkOptions);
  } on InstantiationException {
    throw Exception("Failed to initialize the HERE SDK.");
  }

  await _notifyIOSHereSdkReadyWithRetry();

  // Ensure that all widgets, including MyApp, have a MaterialLocalizations object available.
  runApp(const MaterialApp(home: MyApp()));
}

Future<void> _notifyIOSHereSdkReadyWithRetry() async {
  if (defaultTargetPlatform != TargetPlatform.iOS) {
    return;
  }

  for (int attempt = 0; attempt < 10; attempt++) {
    try {
      await _nativeChannel.invokeMethod('onDartHereSdkReady');
      return;
    } on MissingPluginException {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }

  print('Unable to notify iOS that HERE SDK is ready from Dart.');
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  HelloMapExample? _helloMapExample;
  late final AppLifecycleListener _appLifecycleListener;
  bool _isDisposingHereSdk = false;
  bool _isHereSdkDisposed = false;

  @override
  void initState() {
    super.initState();

    _appLifecycleListener = AppLifecycleListener(
      // Sometimes Flutter may not reliably call dispose(), therefore dispose the
      // HERE SDK on detach as well. Guard flags prevent double-dispose.
      onDetach: () {
        print('AppLifecycleListener detached.');
        unawaited(_disposeHERESDK());
      },
    );
  }

  @override
  void dispose() {
    _appLifecycleListener.dispose();
    unawaited(_disposeHERESDK());
    super.dispose();
  }

  Future<void> _disposeHERESDK() async {
    if (_isHereSdkDisposed || _isDisposingHereSdk) {
      return;
    }
    _isDisposingHereSdk = true;

    // Free HERE SDK resources before the application shuts down.
    try {
      await SDKNativeEngine.sharedInstance?.dispose();
    } finally {
      SdkContext.release();
      _isHereSdkDisposed = true;
      _isDisposingHereSdk = false;
    }
  }

  void _onMapCreated(HereMapController hereMapController) {
    hereMapController.mapScene.loadSceneForMapScheme(MapScheme.normalDay, (
      MapError? error,
    ) {
      if (error == null) {
        _helloMapExample = HelloMapExample(
          hereMapController,
          onAndroidAutoScale: (focusX, focusY, scaleFactor) {
            print(
              'Android Auto onScale: focus=($focusX, $focusY), scaleFactor=$scaleFactor',
            );
          },
          onCarPlayConnected: () {
            print('CarPlay connected.');
          },
          onCarPlayDisconnected: () {
            print('CarPlay disconnected.');
          },
        );
      } else {
        print("Map scene not loaded. MapError: ${error.toString()}");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HERE SDK - Hello Map Auto / CarPlay')),
      body: HereMap(onMapCreated: _onMapCreated),
    );
  }
}
