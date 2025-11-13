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

import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.engine.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/electronic_horizon.dart';
import 'package:here_sdk/mapdata.dart';
import 'package:here_sdk/navigation.dart';
import 'package:here_sdk/routing.dart';
import 'package:here_sdk/transport.dart';

/// A class that handles electronic horizon related operations.
/// This is not required for navigation, but can be used to get information about the road network ahead of the user.
/// For this example, selected retrieved information is logged, such as road signs.
///
/// Usage:
/// 1. Create an instance of this class.
/// 2. Call start(route) to initialize the ElectronicHorizon.
///    Optionally, null can be provided to operate in tracking mode without a route.
/// 3. Call update(mapMatchedLocation) with a map-matched location to update the ElectronicHorizon.
/// 4. Call stop() to stop getting ElectronicHorizon events.
///
/// Note that in this example app we only enable the electronic horizon in car mode while following a route.
///
/// For convenience, the ElectronicHorizonDataLoader wraps a SegmentDataLoader that allows to
/// continuously load required map data segments based on the most preferred path(s) of the ElectronicHorizon.
/// When it does not find cached, prefetched or preloaded region data for a segment,
/// it will asynchronously request the data from the HERE backend services.
/// It is recommended to use a prefetcher to prefetch region data along the route in advance (not shown in this class).
class ElectronicHorizonHandler {
  static const String _logTag = 'ElectronicHorizonHandler';

  ElectronicHorizon? _electronicHorizon;
  late final ElectronicHorizonDataLoader _electronicHorizonDataLoader;
  ElectronicHorizonListener? _electronicHorizonListener;
  ElectronicHorizonDataLoaderStatusListener? _electronicHorizonDataLoaderStatusListener;

  // Keep track of the last requested electronic horizon update to access its segments
  // when data loading is completed.
  ElectronicHorizonUpdate? _lastRequestedElectronicHorizonUpdate;

  ElectronicHorizonHandler() {
    _electronicHorizonListener = _createElectronicHorizonListener();
    _electronicHorizonDataLoaderStatusListener = _createElectronicHorizonDataLoaderStatusListener();

    // Many more options are available, see SegmentDataLoaderOptions in the API Reference.
    SegmentDataLoaderOptions segmentDataLoaderOptions = SegmentDataLoaderOptions();
    segmentDataLoaderOptions.loadRoadSigns = true;
    segmentDataLoaderOptions.loadSpeedLimits = true;
    segmentDataLoaderOptions.loadRoadAttributes = true;

    // The cache size defines how many road segments are cached locally. A larger cache size
    // can reduce data usage, but requires more storage memory in the cache.
    int segmentDataCacheSize = 10;

    try {
      _electronicHorizonDataLoader = ElectronicHorizonDataLoader(
        _getSDKNativeEngine(),
        segmentDataLoaderOptions,
        segmentDataCacheSize,
      );
    } on InstantiationException {
      throw Exception('ElectronicHorizonDataLoader is not initialized.');
    }
  }

  /// Without a route, electronic horizon operates in tracking mode and the most probable path is
  /// estimated based on the current location and previous locations.
  /// With a route, electronic horizon operates in map-matched mode and the route is used
  /// to determine the most probable path. Therefore, the route will determine the main path ahead.
  void start(Route? route) {
    // The first entry of the list is for the most preferred path, the second is for the side paths of the first level,
    // the third is for the side paths of the second level, and so on.
    // Each entry defines how far ahead the path should be provided.
    List<double> lookAheadDistancesInMeters = [1000.0, 500.0, 250.0];
    // Segments will be removed by the HERE SDK once passed and distance to it exceeds the trailingDistanceInMeters.
    double trailingDistanceInMeters = 500;
    ElectronicHorizonOptions electronicHorizonOptions =
    ElectronicHorizonOptions(lookAheadDistancesInMeters, trailingDistanceInMeters);

    TransportMode transportMode = TransportMode.car;

    try {
      _electronicHorizon = ElectronicHorizon.WithOptionsAndRoutePathEvaluator(
        _getSDKNativeEngine(),
        electronicHorizonOptions,
        transportMode,
        route,
      );
    } on InstantiationException {
      throw Exception('ElectronicHorizon is not initialized.');
    }

    // Remove any existing electronic horizon listeners.
    stop();

    // Create and add new listeners.
    _electronicHorizonListener = _createElectronicHorizonListener();
    _electronicHorizon?.addElectronicHorizonListener(_electronicHorizonListener!);
    _electronicHorizonDataLoaderStatusListener = _createElectronicHorizonDataLoaderStatusListener();
    _electronicHorizonDataLoader.addElectronicHorizonDataLoaderStatusListener(_electronicHorizonDataLoaderStatusListener!);
    print('$_logTag: ElectronicHorizon started.');
  }

  /// Similar like the VisualNavigator, the ElectronicHorizon also needs to be updated with
  /// a location, with the difference that the location must be map-matched. Therefore, the
  /// location provided by the VisualNavigator can be used.
  void update(MapMatchedLocation mapMatchedLocation) {
    if (_electronicHorizon == null) {
      throw StateError('ElectronicHorizon is not initialized. Call start() first.');
    }
    _electronicHorizon!.update(mapMatchedLocation);
    print('$_logTag: ElectronicHorizonUpdate mapMatchedLocation received.');
  }

  /// Create a listener to get notified about electronic horizon updates while a user moves along the road.
  /// This only informs on the available segment IDs and indexes, so that the actual data can be requested
  /// by the ElectronicHorizonDataLoader.
  ElectronicHorizonListener _createElectronicHorizonListener() {
    return ElectronicHorizonListener((ElectronicHorizonUpdate electronicHorizonUpdate) {
      print('$_logTag: ElectronicHorizonUpdate received.');
      // Asynchronously start to load required data for the new segments.
      // Use the ElectronicHorizonDataLoaderStatusListener to get notified when new data is arriving.
      _lastRequestedElectronicHorizonUpdate = electronicHorizonUpdate;
      _electronicHorizonDataLoader.loadData(electronicHorizonUpdate);
    });
  }

  /// Handle newly arriving map data segments provided by the ElectronicHorizonDataLoader.
  /// This listener is called when the status of the data loader is updated and new segments have been loaded.
  ElectronicHorizonDataLoaderStatusListener _createElectronicHorizonDataLoaderStatusListener() {
    return ElectronicHorizonDataLoaderStatusListener((Map<int, ElectronicHorizonDataLoadedStatus> statusMap) {
      print('$_logTag: ElectronicHorizonDataLoaderStatus updated.');

      if (_lastRequestedElectronicHorizonUpdate == null) {
        return;
      }

      // Access the segments that were part of the last requested electronic horizon update.
      // These segments were requested to be loaded in the call to electronicHorizonDataLoader.loadData().
      // Internally, the data loader keeps track of which segments were requested for loading and provides them
      // in order - i.e. a call to electronicHorizonDataLoader.loadData() is followed by a call to this listener with the
      // loaded status for the segments that were part of that previous request.
      statusMap.forEach((int level, ElectronicHorizonDataLoadedStatus status) {
        // The integer key represents the level of the most preferred path (0) and side paths (1, 2, ...).
        // For this example, we only look into fully loaded segments of the most preferred path (level 0).
        if (status == ElectronicHorizonDataLoadedStatus.fullyLoaded && level == 0) {
          // Now, we know that all level 0 segments have been fully loaded and we can access their data.
          // Note that addedSegments still contains all levels, so we need to filter for level 0 segments below.
          List<ElectronicHorizonPathSegment> addedSegments = _lastRequestedElectronicHorizonUpdate!.addedSegments;
          for (ElectronicHorizonPathSegment segment in addedSegments) {
            // For any segment you can check the parentPathIndex to determine
            // if it is part of the most preferred path (MPP) or a side path.
            if (segment.parentPathIndex != 0) {
              // Skip side path segments as we only want to log MPP segment data in this example.
              // And we only want to log fully loaded segments.
              continue;
            }

            DirectedOCMSegmentId? directedOCMSegmentId = segment.segmentId.ocmSegmentId;
            if (directedOCMSegmentId == null) {
              continue;
            }

            // Retrieving segment data from the loader is executed synchronous. However, since the data has been
            // already loaded, this is a fast operation.
            ElectronicHorizonDataLoaderResult result =
            _electronicHorizonDataLoader.getSegment(directedOCMSegmentId.id);
            if (result.errorCode == null && result.segmentData != null) {
              SegmentData segmentData = result.segmentData!;
              // Access the data that was requested to be loaded in SegmentDataLoaderOptions.
              // For this example, we just log road signs.
              List<RoadSign>? roadSigns = segmentData.roadSigns;
              if (roadSigns == null || roadSigns.isEmpty) {
                continue;
              }
              for (RoadSign roadSign in roadSigns) {
                GeoCoordinates roadSignCoordinates = _getGeoCoordinatesFromOffsetInMeters(
                    segmentData.polyline, roadSign.offsetInMeters as double);
                print('$_logTag: RoadSign: type = ${roadSign.roadSignType.name}, '
                    'offsetInMeters = ${roadSign.offsetInMeters}, '
                    'lat/lon: ${roadSignCoordinates.latitude}/${roadSignCoordinates.longitude}, '
                    'segmentId = ${directedOCMSegmentId.id.localId}');
              }
            }
          }
        }
      });
    });
  }

  /// Convert an offset in meters along a GeoPolyline to GeoCoordinates using the HERE SDK's coordinatesAtOffsetInMeters.
  GeoCoordinates _getGeoCoordinatesFromOffsetInMeters(GeoPolyline geoPolyline, double offsetInMeters) {
    return geoPolyline.coordinatesAtOffsetInMeters(offsetInMeters, GeoPolylineDirection.fromBeginning);
  }

  void stop() {
    if (_electronicHorizon == null) {
      return;
    }

    if (_electronicHorizonListener != null) {
      _electronicHorizon!.removeElectronicHorizonListener(_electronicHorizonListener!);
    }
    if (_electronicHorizonDataLoaderStatusListener != null) {
      _electronicHorizonDataLoader.removeElectronicHorizonDataLoaderStatusListener(
          _electronicHorizonDataLoaderStatusListener!);
    }
    print('$_logTag: ElectronicHorizon stopped.');
  }

  SDKNativeEngine _getSDKNativeEngine() {
    SDKNativeEngine? sdkNativeEngine = SDKNativeEngine.sharedInstance;
    if (sdkNativeEngine == null) {
      throw Exception('SDKNativeEngine is not initialized.');
    }
    return sdkNativeEngine;
  }
}
