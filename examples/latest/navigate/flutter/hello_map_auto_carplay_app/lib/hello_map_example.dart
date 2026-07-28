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

import 'package:flutter/services.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';
import 'package:flutter/foundation.dart';

typedef AndroidAutoScaleListener =
    void Function(double focusX, double focusY, double scaleFactor);

typedef CarPlayConnectionListener = void Function();

enum NativeAndroidCall {
  onMapSurfaceReady('onMapSurfaceReady'),
  onSurfaceDestroyed('onSurfaceDestroyed'),
  onScale('androidAutoOnScale');

  const NativeAndroidCall(this.methodName);
  final String methodName;
}

enum NativeIOSCall {
  onCarPlayConnected('onCarPlayConnected'),
  onCarPlayDisconnected('onCarPlayDisconnected');

  const NativeIOSCall(this.methodName);
  final String methodName;
}

// The map ID used to bridge the native Android Auto [MapSurface] to a Dart [HereMapController].
// This value must match the ID used in [HelloMapAutoScreen] on the native Android side.
const int _androidAutoMapId = 1;

// Demonstrates how to display a HERE SDK map on Android Auto via platform channels.
//
// The phone screen shows a standard [HereMap] widget (handled by [main.dart]).
// This class handles the Android Auto map surface, which is rendered natively via
// [MapSurface] + [MapSurfaceHost] on the Android side and controlled from Dart
// through a [HereMapController] linked by a shared map ID.
class HelloMapExample {
  static const _channel = MethodChannel(
    'com.here.sdk.examples.hello_map_auto_carplay_app/channel',
  );

  final HereMapController _phoneMapController;
  final AndroidAutoScaleListener? onAndroidAutoScale;
  final CarPlayConnectionListener? onCarPlayConnected;
  final CarPlayConnectionListener? onCarPlayDisconnected;
  HereMapController? _androidAutoMapController;

  HelloMapExample(
    this._phoneMapController, {
    this.onAndroidAutoScale,
    this.onCarPlayConnected,
    this.onCarPlayDisconnected,
  }) {
    _setupPhoneMap();
    _setupNativeChannelListener();
  }

  void _setupPhoneMap() {
    const double distanceInMeters = 10 * 1000;
    final mapMeasureZoom = MapMeasure(
      MapMeasureKind.distanceInMeters,
      distanceInMeters,
    );
    _phoneMapController.camera.lookAtPointWithMeasure(
      GeoCoordinates(52.530932, 13.384915),
      mapMeasureZoom,
    );
  }

  void _setupNativeChannelListener() {
    _channel.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case String method
            when method == NativeAndroidCall.onMapSurfaceReady.methodName:
          if (defaultTargetPlatform != TargetPlatform.android) {
            return;
          }
          // The native Android Auto surface is ready. Set up the HereMapController
          // that controls the MapSurface rendered on the Android Auto head unit.
          await _onAndroidAutoMapReady();
          break;
        case String method
            when method == NativeAndroidCall.onSurfaceDestroyed.methodName:
          if (defaultTargetPlatform != TargetPlatform.android) {
            return;
          }
          _onAndroidAutoMapDestroyed();
          break;
        case String method when method == NativeAndroidCall.onScale.methodName:
          if (defaultTargetPlatform != TargetPlatform.android) {
            return;
          }
          _onAndroidAutoScale(call.arguments);
          break;
        case String method
            when method == NativeIOSCall.onCarPlayConnected.methodName:
          if (defaultTargetPlatform != TargetPlatform.iOS) {
            return;
          }
          onCarPlayConnected?.call();
          break;
        case String method
            when method == NativeIOSCall.onCarPlayDisconnected.methodName:
          if (defaultTargetPlatform != TargetPlatform.iOS) {
            return;
          }
          onCarPlayDisconnected?.call();
          break;
        default:
          throw MissingPluginException('Unknown method: ${call.method}');
      }
    });
  }

  void _onAndroidAutoScale(dynamic arguments) {
    if (arguments is! Map) {
      print('HelloMapExample: Invalid androidAutoOnScale payload: $arguments');
      return;
    }

    final focusX = (arguments['focusX'] as num?)?.toDouble();
    final focusY = (arguments['focusY'] as num?)?.toDouble();
    final scaleFactor = (arguments['scaleFactor'] as num?)?.toDouble();

    if (focusX == null || focusY == null || scaleFactor == null) {
      print('HelloMapExample: Missing androidAutoOnScale fields: $arguments');
      return;
    }

    onAndroidAutoScale?.call(focusX, focusY, scaleFactor);
  }

  Future<void> _onAndroidAutoMapReady() async {
    // Create a HereMapController linked to the native MapSurface via the shared map ID.
    // The native side registered the MapSurface with MapSurfaceHost using the same ID.
    final controller = HereMapController(_androidAutoMapId);
    bool success = await controller.initialize((event) {});
    if (!success) {
      print(
        'HelloMapExample: Failed to initialize Android Auto HereMapController.',
      );
      return;
    }

    _androidAutoMapController = controller;

    // Load the map scene for the Android Auto display.
    controller.mapScene.loadSceneForMapScheme(MapScheme.normalDay, (
      MapError? error,
    ) {
      if (error != null) {
        print(
          'HelloMapExample: Map scene not loaded for Android Auto. MapError: ${error.toString()}',
        );
        return;
      }
      _positionAndroidAutoCamera();
      print('HelloMapExample: Android Auto map scene loaded.');
    });
  }

  void _positionAndroidAutoCamera() {
    if (_androidAutoMapController == null) return;
    const double distanceInMeters = 10 * 1000;
    final mapMeasureZoom = MapMeasure(
      MapMeasureKind.distanceInMeters,
      distanceInMeters,
    );
    _androidAutoMapController!.camera.lookAtPointWithMeasure(
      GeoCoordinates(52.530932, 13.384915),
      mapMeasureZoom,
    );
  }

  void _onAndroidAutoMapDestroyed() {
    _androidAutoMapController?.finalize();
    _androidAutoMapController = null;
    print('HelloMapExample: Android Auto map surface destroyed.');
  }
}
