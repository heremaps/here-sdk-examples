/*
 * Copyright (C) 2020-2026 HERE Europe B.V.
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

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:indoor_map_app/indoor_events.dart';
import 'package:indoor_map_app/indoor_routing_data_provider_interface.dart';
import 'package:indoor_map_app/venue_data_provider_interface.dart';
import 'package:indoor_map_app/venue_tap_controller.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/gestures.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/venue.control.dart';
import 'package:here_sdk/venue.dart';
import 'package:here_sdk/venue.data.dart';
import 'package:here_sdk/venue.service.dart';
import 'package:here_sdk/venue.style.dart';

class IndoorVenueEngineState {
  const IndoorVenueEngineState({
    required this.venueEngine,
    required this.venueService,
    required this.venueMap,
    required this.venueTapController,
  });

  final VenueEngine venueEngine;
  final VenueService venueService;
  final VenueMap venueMap;
  final VenueTapController venueTapController;
}

/// Wraps the HERE SDK [VenueEngine] lifecycle, creates all required listeners,
/// and wires up the [VenueTapController].
///
/// Returns a [Future] that completes with [IndoorVenueEngineState] on success
/// or `null` on failure (authentication error, disposal, etc.).
class IndoorVenueEngine {
  IndoorVenueEngine({
    required HereMapController mapController,
    required this.providerInterface,
    required this.routingDataProviderInterface,
    required this.onAuthErrorCallback,
  }) : _hereMapController = mapController;

  final void Function(String reason)? onAuthErrorCallback;
  final HereMapController _hereMapController;
  final VenueDataProviderInterface providerInterface;
  final IndoorRoutingDataProviderInterface routingDataProviderInterface;

  VenueEngine? _venueEngine;
  VenueServiceListener? _venueServiceListener;
  VenueInfoListListener? _venueInfoListListener;
  VenueMapListener? _venueMapListener;
  VenueSelectionListener? _venueSelectionListener;
  VenueTapListenerImpl? _tapListener;
  IndoorVenueEngineState? _currentState;
  final Completer<IndoorVenueEngineState?> _venueEngineInitialized = Completer<IndoorVenueEngineState?>();
  bool _isDisposed = false;

  Future<IndoorVenueEngineState?> get venueEngineInitCompleted => _venueEngineInitialized.future;
  IndoorVenueEngineState? get currentState => _currentState;
  VenueEngine? get venueEngine => _currentState?.venueEngine ?? _venueEngine;
  VenueTapController? get venueTapController => _currentState?.venueTapController;

  Future<IndoorVenueEngineState?> createVenueEngine() {
    if (_isDisposed) {
      return Future<IndoorVenueEngineState?>.value();
    }
    debugPrint('createVenueEngine called');
    _venueEngine = VenueEngine(_onVenueEngineCreated);
    return venueEngineInitCompleted;
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _detachVenueListeners();
    _detachTapListener();
    _currentState?.venueTapController.removeListener();
    _currentState = null;
    _venueEngine?.destroy();
    _venueEngine = null;
    _completeInitialization(null);
  }

  void _onAuthCallback(AuthenticationError? error, AuthenticationData? data) {
    if (_isDisposed) {
      _completeInitialization(null);
      return;
    }
    debugPrint('Venue Engine auth callback hit.');
    if (error != null) {
      final String reason = error.reasonDescription;
      debugPrint('Failed to authenticate the venue engine: $reason');
      onAuthErrorCallback?.call(reason);
      _completeInitialization(null);
      debugPrint('Venue Engine creation completed with error.');
      return;
    }

    if (!_venueEngineInitialized.isCompleted) {
      _completeInitialization(_currentState);
      debugPrint('Venue Engine creation completed.');
    }
  }

  void _onVenueEngineCreated() {
    if (_isDisposed) {
      _venueEngine?.destroy();
      _venueEngine = null;
      _completeInitialization(null);
      return;
    }
    debugPrint('Venue Engine creation started.');
    if (_venueEngine == null) {
      debugPrint('VenueEngine creation failed. VenueEngine is null.');
      _completeInitialization(null);
      return;
    }
    final VenueService venueService = _venueEngine!.venueService;
    final VenueMap venueMap = _venueEngine!.venueMap;

    _venueServiceListener = VenueServiceListenerImpl(venueEngine: _venueEngine!, providerInterface: providerInterface);
    _venueInfoListListener = VenueInfoListListenerImpl(providerInterface: providerInterface);
    _venueMapListener = VenueMapListenerImpl(
      hereMapController: _hereMapController,
      providerInterface: providerInterface,
    );
    _venueSelectionListener = VenueSelectionListenerImpl(
      hereMapController: _hereMapController,
      providerInterface: providerInterface,
    );

    // Add Venue Engine related listeners
    venueService
      ..addServiceListener(_venueServiceListener!)
      ..addVenueMapListener(_venueMapListener!);
    venueMap
      ..addVenueInfoListListener(_venueInfoListListener!)
      ..addVenueSelectionListener(_venueSelectionListener!);

    // Create a venue tap controller for handling all SDK tap related events.
    final VenueTapController venueTapController = VenueTapController(
      venueMap: venueMap,
      hereMapController: _hereMapController,
      venueDataProviderInterface: providerInterface,
      routingDataProviderInterface: routingDataProviderInterface,
    );

    // Tap listener for HereMapController
    _tapListener = VenueTapListenerImpl(
      tapController: venueTapController,
      routingDataProviderInterface: routingDataProviderInterface,
    );
    _hereMapController.gestures.tapListener = _tapListener;

    // Load topologies feature
    venueService.loadTopologies();

    _currentState = IndoorVenueEngineState(
      venueEngine: _venueEngine!,
      venueService: venueService,
      venueMap: venueMap,
      venueTapController: venueTapController,
    );

    // After listeners are added, start the engine.
    _venueEngine?.start(_onAuthCallback);
  }

  void _detachVenueListeners() {
    if (_currentState == null) {
      return;
    }
    final VenueService venueService = _currentState!.venueService;
    final VenueMap venueMap = _currentState!.venueMap;
    if (_venueServiceListener != null) {
      venueService.removeServiceListener(_venueServiceListener!);
    }
    if (_venueMapListener != null) {
      venueService.removeVenueMapListener(_venueMapListener!);
    }
    if (_venueInfoListListener != null) {
      venueMap.removeVenueInfoListListener(_venueInfoListListener!);
    }
    if (_venueSelectionListener != null) {
      venueMap.removeVenueSelectionListener(_venueSelectionListener!);
    }
  }

  void _detachTapListener() {
    if (_tapListener != null && identical(_hereMapController.gestures.tapListener, _tapListener)) {
      _hereMapController.gestures.tapListener = null;
    }
    _tapListener = null;
  }

  void _completeInitialization(IndoorVenueEngineState? state) {
    if (_venueEngineInitialized.isCompleted) {
      return;
    }
    _venueEngineInitialized.complete(state);
  }
}

// ---------------------------------------------------------------------------
// AuthenticationError extension for human-readable descriptions
// ---------------------------------------------------------------------------

extension _AuthenticationErrorExtension on AuthenticationError {
  String get reasonDescription {
    switch (this) {
      case AuthenticationError.invalidParameter:
        return 'Invalid parameter received';
      case AuthenticationError.authenticationFailed:
        return 'Authentication failed. Check your credentials.';
      case AuthenticationError.noConnection:
        return 'No network connection';
      case AuthenticationError.operationAfterDispose:
        return 'Operation invoked after SDK engine was disposed';
    }
  }
}

// ---------------------------------------------------------------------------
// VenueEngine listener implementations
// ---------------------------------------------------------------------------

class VenueServiceListenerImpl implements VenueServiceListener {
  VenueServiceListenerImpl({required this.venueEngine, required this.providerInterface});

  final VenueEngine venueEngine;
  final VenueDataProviderInterface providerInterface;

  @override
  void onInitializationCompleted(VenueServiceInitStatus result) {
    debugPrint('Venue Engine Init Completed: $result');
    if (result == VenueServiceInitStatus.onlineSuccess) {
      venueEngine.venueMap.getVenueInfoListAsyncWithErrors((VenueErrorCode? venueLoadError) {
        final String errorMsg = _errorMessage(venueLoadError);
        debugPrint('VenueService Initialization Failure with error: $errorMsg');
        providerInterface.onVenueInfoListLoadWithError(venueLoadError, errorMsg);
      });
    } else {
      debugPrint('VenueService failed to initialize!');
      providerInterface.onVenueServiceInitializationFailure(result);
    }
  }

  @override
  void onVenueServiceStopped() {}

  static String _errorMessage(VenueErrorCode? code) {
    switch (code) {
      case VenueErrorCode.noNetwork:
        return 'The device has no internet connectivity';
      case VenueErrorCode.noMetaDataFound:
        return 'Meta data not present in platform collection catalog';
      case VenueErrorCode.hrnMissing:
        return 'HRN not provided. Please insert HRN';
      case VenueErrorCode.hrnMismatch:
        return 'HRN does not match with Auth key & secret';
      case VenueErrorCode.noDefaultCollection:
        return 'Default collection missing from platform collection catalog';
      case VenueErrorCode.mapIdNotFound:
        return 'Map ID requested is not part of the default collection';
      case VenueErrorCode.mapDataIncorrect:
        return 'Map data in collection is wrong';
      case VenueErrorCode.internalServerError:
        return 'Internal Server Error';
      case VenueErrorCode.serviceUnavailable:
        return 'Requested service is not available currently. Please try after some time';
      case VenueErrorCode.noMapInCollection:
        return 'No maps available in the collection';
      default:
        return 'Unknown Error encountered';
    }
  }
}

class VenueInfoListListenerImpl implements VenueInfoListListener {
  VenueInfoListListenerImpl({required this.providerInterface});

  final VenueDataProviderInterface providerInterface;

  @override
  void onVenueInfoListLoad(VenueInfoDataList venueInfoList) {
    debugPrint('onVenueInfoListLoad: ${venueInfoList.length} venues.');
    final List<String> ids = <String>[];
    final List<String> names = <String>[];
    for (int i = 0; i < venueInfoList.length; i++) {
      ids.add(venueInfoList[i].venueIdentifier);
      names.add(venueInfoList[i].venueName);
    }
    venueIdList.updatedIdList.value = ids;
    venueNameList.updatedNameList.value = names;
    filteredVenueIdList.updatedIdList.value = ids;
    filteredVenueNameList.updatedNameList.value = names;
    providerInterface.onVenueInfoListLoadSuccess();
  }
}

class VenueMapListenerImpl implements VenueMapListener {
  VenueMapListenerImpl({required this.hereMapController, required this.providerInterface});

  final HereMapController? hereMapController;
  final VenueDataProviderInterface providerInterface;

  @override
  void onGetVenueCompleted(String venueIdentifier, VenueModel? venueModel, bool online, VenueStyle? venueStyle) {
    debugPrint('onGetVenueCompleted venue ID: $venueIdentifier');
    hereMapController?.camera.zoomTo(18);
    providerInterface.onGetVenueCompleted(venueIdentifier, venueModel, online, venueStyle);
  }
}

class VenueSelectionListenerImpl implements VenueSelectionListener {
  VenueSelectionListenerImpl({required this.hereMapController, required this.providerInterface});

  final HereMapController? hereMapController;
  final VenueDataProviderInterface providerInterface;

  @override
  void onSelectedVenueChanged(Venue? deselectedVenue, Venue? selectedVenue) {
    if (selectedVenue != null) {
      debugPrint('onSelectedVenueChanged venue ID: ${selectedVenue.venueModel.identifier}');
      final MapMeasure mapMeasure = MapMeasure(MapMeasureKind.distanceInMeters, 500);
      // Move camera to the selected drawing's centre with zoom to frame the venue.
      hereMapController?.camera.lookAtPointWithMeasure(selectedVenue.selectedDrawing.center, mapMeasure);
      providerInterface.onSelectedVenueChanged(deselectedVenue, selectedVenue);
    } else {
      debugPrint('onSelectedVenueChanged: Venue ${deselectedVenue?.venueModel.identifier} removed.');
    }
  }
}

/// Tap listener. Redirects to routing when the routing menu is active.
class VenueTapListenerImpl implements TapListener {
  VenueTapListenerImpl({
    required VenueTapController? tapController,
    required IndoorRoutingDataProviderInterface routingDataProviderInterface,
  }) : _tapController = tapController,
       _routingDataProviderInterface = routingDataProviderInterface;

  final VenueTapController? _tapController;
  final IndoorRoutingDataProviderInterface _routingDataProviderInterface;

  @override
  void onTap(Point2D origin) {
    if (_routingDataProviderInterface.isRoutingMainMenuUIActiveOnMap()) {
      _routingDataProviderInterface.onTap(origin);
    } else {
      _tapController?.onTap(origin);
    }
  }
}
