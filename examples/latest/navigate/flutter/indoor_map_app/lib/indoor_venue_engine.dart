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

/// Wraps the HERE SDK [VenueEngine] lifecycle, creates all required listeners,
/// and wires up the [VenueTapController].
/// Also provides a callback for authentication errors, and exposes a future that
/// completes when venue engine initialization is complete (successfully or not).
class IndoorVenueEngine {
  IndoorVenueEngine({
    required HereMapController mapController,
    required VenueDataProviderInterface providerInterface,
    required IndoorRoutingDataProviderInterface routingDataProviderInterface,
    required this.onAuthErrorCallback,
  }) {
    _hereMapController = mapController;
    _providerInterface = providerInterface;
    _routingDataProviderInterface = routingDataProviderInterface;
  }

  final void Function(String reason)? onAuthErrorCallback;

  VenueEngine? venueEngine;
  late VenueDataProviderInterface _providerInterface;
  late IndoorRoutingDataProviderInterface _routingDataProviderInterface;
  late VenueService venueService;
  late VenueMap venueMap;
  late VenueServiceListener _venueServiceListener;
  late VenueInfoListListener _venueInfoListListener;
  late VenueMapListener _venueMapListener;
  late VenueSelectionListener _venueSelectionListener;
  VenueTapController? venueTapController;
  late VenueTapListenerImpl tapListener;
  late HereMapController _hereMapController;
  final Completer<void> _venueEngineInitialized = Completer<void>();

  Future<void> get venueEngineInitCompleted => _venueEngineInitialized.future;

  void createVenueEngine() {
    debugPrint('createVenueEngine called');
    venueEngine = VenueEngine(_onVenueEngineCreated);
  }

  void dispose() {
    venueService.removeServiceListener(_venueServiceListener);
    venueMap.removeVenueInfoListListener(_venueInfoListListener);
    venueService.removeVenueMapListener(_venueMapListener);
    venueMap.removeVenueSelectionListener(_venueSelectionListener);
    venueTapController?.removeListener();
    venueTapController = null;
    venueEngine?.destroy();
  }

  void _onAuthCallback(AuthenticationError? error, AuthenticationData? data) {
    debugPrint('Venue Engine auth callback hit.');
    if (error != null) {
      String reason;
      switch (error) {
        case AuthenticationError.invalidParameter:
          reason = 'Invalid parameter received';
          break;
        case AuthenticationError.authenticationFailed:
          reason = 'Authentication failed. Check your credentials.';
          break;
        case AuthenticationError.noConnection:
          reason = 'No network connection';
          break;
        case AuthenticationError.operationAfterDispose:
          reason = 'Operation invoked after SDK engine was disposed';
          break;
        default:
          reason = 'Unknown authentication error';
          break;
      }
      debugPrint('Failed to authenticate the venue engine: $reason');
      onAuthErrorCallback?.call(reason);
    }
    if (!_venueEngineInitialized.isCompleted) {
      _venueEngineInitialized.complete();
    }
  }

  void _onVenueEngineCreated() {
    debugPrint('Venue Engine created.');
    venueService = venueEngine!.venueService;
    venueMap = venueEngine!.venueMap;

    _venueServiceListener = VenueServiceListenerImpl(venueEngine: venueEngine!, providerInterface: _providerInterface);
    _venueInfoListListener = VenueInfoListListenerImpl(providerInterface: _providerInterface);
    _venueMapListener = VenueMapListenerImpl(
      hereMapController: _hereMapController,
      providerInterface: _providerInterface,
    );
    _venueSelectionListener = VenueSelectionListenerImpl(
      hereMapController: _hereMapController,
      providerInterface: _providerInterface,
    );

    venueService.addServiceListener(_venueServiceListener);
    venueMap.addVenueInfoListListener(_venueInfoListListener);
    venueService.addVenueMapListener(_venueMapListener);
    venueMap.addVenueSelectionListener(_venueSelectionListener);

    venueTapController = VenueTapController(
      venueMap: venueMap,
      hereMapController: _hereMapController,
      venueDataProviderInterface: _providerInterface,
      routingDataProviderInterface: _routingDataProviderInterface,
    );
    tapListener = VenueTapListenerImpl(venueTapController, _routingDataProviderInterface);
    _hereMapController.gestures.tapListener = tapListener;

    venueService.loadTopologies();
    venueEngine?.start(_onAuthCallback);
  }

  VenueEngine? getEngine() => venueEngine;
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
      final GeoCoordinates venueCenter = selectedVenue.venueModel.center;
      final MapMeasure mapMeasure = MapMeasure(MapMeasureKind.distanceInMeters, 500);
      hereMapController?.camera.lookAtPointWithMeasure(venueCenter, mapMeasure);
      providerInterface.onSelectedVenueChanged(deselectedVenue, selectedVenue);
    } else {
      debugPrint('onSelectedVenueChanged: Venue ${deselectedVenue?.venueModel.identifier} removed.');
    }
  }
}

/// Tap listener.  Redirects to routing when the routing menu is active.
class VenueTapListenerImpl implements TapListener {
  VenueTapListenerImpl(
    VenueTapController? tapController,
    IndoorRoutingDataProviderInterface routingDataProviderInterface,
  ) {
    _tapController = tapController;
    _routingDataProviderInterface = routingDataProviderInterface;
  }

  VenueTapController? _tapController;
  late IndoorRoutingDataProviderInterface _routingDataProviderInterface;

  @override
  void onTap(Point2D origin) {
    if (_routingDataProviderInterface.isRoutingMainMenuUIActiveOnMap()) {
      _routingDataProviderInterface.onTap(origin);
    } else {
      _tapController?.onTap(origin);
    }
  }
}
