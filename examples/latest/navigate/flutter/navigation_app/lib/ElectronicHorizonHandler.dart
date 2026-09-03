/*
 * Copyright (C) 2019-2026 HERE Europe B.V.
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

import 'dart:ui';

import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.engine.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/electronic_horizon.dart';
import 'package:here_sdk/mapdata.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/navigation.dart';
import 'package:here_sdk/routing.dart';
import 'package:here_sdk/transport.dart';

/// A class that handles electronic horizon related operations.
/// This is not required for navigation, but can be used to get information about the road network ahead of the user.
/// For this example, selected retrieved information is logged, such as road signs.
///
/// Usage:
/// 1. Create an instance of this class.
/// 2. Call start(route) to initialize the ElectronicHorizonEngine.
///    Optionally, null can be provided to operate in tracking mode without a route.
/// 3. Call update(mapMatchedLocation) with a map-matched location to update the ElectronicHorizonEngine.
/// 4. Call stop() to stop getting ElectronicHorizonEngine events.
///
/// Note that in this example app we only enable the electronic horizon in car mode while following a route.
///
/// For convenience, the ElectronicHorizonDataLoader wraps a SegmentDataLoader that allows to
/// continuously load required map data segments based on the most preferred path(s) of the ElectronicHorizonEngine.
/// When it does not find cached, prefetched or preloaded region data for a segment,
/// it will asynchronously request the data from the HERE backend services.
/// It is recommended to use a prefetcher to prefetch region data along the route in advance (not shown in this class).
class ElectronicHorizonHandler {
  static const String _logTag = 'ElectronicHorizonHandler';
  // Optional: Using a small offset can help mark/log the side street more clearly for visualization.
  static const double _sideStreetLogOffsetMeters = 20.0;

  final HereMapController _hereMapController;
  ElectronicHorizonEngine? _electronicHorizonEngine;
  late final ElectronicHorizonDataLoader _electronicHorizonDataLoader;
  ElectronicHorizonListener? _electronicHorizonListener;
  ElectronicHorizonDataLoaderStatusListener? _electronicHorizonDataLoaderStatusListener;

  // Keep track of the last electronic horizon to access its segments
  // when data loading is completed.
  ElectronicHorizon? _lastElectronicHorizon;

  // Segment polyline map: maps the segment's OCM local ID to its drawn MapPolyline.
  // This allows individual polylines to be removed when segments leave the horizon.
  final Map<int, MapPolyline> _segmentPolylineMap = {};

  // Controls whether segment polylines are drawn on the map.
  bool _isVisualizationEnabled = false;

  ElectronicHorizonHandler(this._hereMapController) {
    _electronicHorizonListener = _createElectronicHorizonListener();
    _electronicHorizonDataLoaderStatusListener = _createElectronicHorizonDataLoaderStatusListener();

    // Many more options are available, see SegmentDataLoaderOptions in the API Reference.
    SegmentDataLoaderOptions segmentDataLoaderOptions = SegmentDataLoaderOptions();
    segmentDataLoaderOptions.loadRoadSigns = true;
    segmentDataLoaderOptions.loadSpeedLimits = true;
    segmentDataLoaderOptions.loadRoadAttributes = true;
    segmentDataLoaderOptions.loadStreetNamesAndRoadNumbers = true;

    // The cache size defines how many road segments are cached locally. A larger cache size
    // can reduce data usage, but requires more storage memory in the cache.
    // A small cache can replace previously loaded segments too early.
    int segmentDataCacheSize = 1000;

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

  /// Enable or disable the colored segment polyline visualization on the map.
  /// When disabled, all currently drawn polylines are removed from the map immediately.
  void toggleVisualization(bool enabled) {
    _isVisualizationEnabled = enabled;
    if (!enabled) {
      _clearVisualization();
    }
    print('$_logTag: EH visualization ${enabled ? "enabled" : "disabled"}.');
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
      _electronicHorizonEngine = ElectronicHorizonEngine.WithOptionsAndRoutePathEvaluator(
        _getSDKNativeEngine(),
        electronicHorizonOptions,
        transportMode,
        route,
      );
    } on InstantiationException {
      throw Exception('ElectronicHorizonEngine is not initialized.');
    }

    // Remove any existing electronic horizon listeners.
    stop();

    // Create and add new listeners.
    _electronicHorizonListener = _createElectronicHorizonListener();
    _electronicHorizonEngine?.addElectronicHorizonListener(_electronicHorizonListener!);
    _electronicHorizonDataLoaderStatusListener = _createElectronicHorizonDataLoaderStatusListener();
    _electronicHorizonDataLoader.addElectronicHorizonDataLoaderStatusListener(_electronicHorizonDataLoaderStatusListener!);
    print('$_logTag: ElectronicHorizonEngine started.');
  }

  /// Similar like the VisualNavigator, the ElectronicHorizonEngine also needs to be updated with
  /// a location, with the difference that the location must be map-matched. Therefore, the
  /// location provided by the VisualNavigator can be used.
  void update(MapMatchedLocation mapMatchedLocation) {
    if (_electronicHorizonEngine == null) {
      throw StateError('ElectronicHorizonEngine is not initialized. Call start() first.');
    }
    _electronicHorizonEngine!.update(mapMatchedLocation);
    print('$_logTag: ElectronicHorizonUpdate mapMatchedLocation received.');
  }

  /// Create a listener to get notified about electronic horizon updates while a user moves along the road.
  /// This only informs on the available segment IDs and indexes, so that the actual data can be requested
  /// by the ElectronicHorizonDataLoader.
  ElectronicHorizonListener _createElectronicHorizonListener() {
    return ElectronicHorizonListener((ElectronicHorizonErrorCode? errorCode, ElectronicHorizonUpdate? electronicHorizonUpdate) {
      if (errorCode != null) {
        print('$_logTag: ElectronicHorizonUpdate error: ${errorCode.name}');
        return;
      }
      print('$_logTag: ElectronicHorizonUpdate received.');

      // Store last known horizon if present.
      if (electronicHorizonUpdate?.electronicHorizon != null) {
        _lastElectronicHorizon = electronicHorizonUpdate?.electronicHorizon;
      }
      
      // Remove polylines for segments that have left the horizon.
      // Segments are removed when they fall behind trailingDistanceInMeters
      // or when the vehicle passes the decision point for a side path.
      if (electronicHorizonUpdate?.segmentChanges != null) {
        final removedSegmentIds = electronicHorizonUpdate!.segmentChanges!.removedIds;
        for (var segmentId in removedSegmentIds) {
          if (segmentId.ocmSegmentId == null) continue;
          int localId = segmentId.ocmSegmentId!.id.localId;
          MapPolyline? polyline = _segmentPolylineMap.remove(localId);
          if (polyline != null) {
            print('$_logTag: Removing segment polyline - localId=$localId');
            _hereMapController.mapScene.removeMapPolyline(polyline);
          }
        }
      }
      
      // Asynchronously start to load required data for the new segments.
      // Use the ElectronicHorizonDataLoaderStatusListener to get notified when new data is arriving.
      if (electronicHorizonUpdate?.segmentChanges != null) {
        _electronicHorizonDataLoader.loadData(electronicHorizonUpdate!);
      }
    });
  }

  /// Handle newly arriving map data segments provided by the ElectronicHorizonDataLoader.
  /// This listener is called when the data loader's status is updated and segments are ready.
  /// When visualization is enabled, newly loaded segments are drawn as colored polylines on the map.
  ElectronicHorizonDataLoaderStatusListener _createElectronicHorizonDataLoaderStatusListener() {
    return ElectronicHorizonDataLoaderStatusListener((Map<int, ElectronicHorizonDataLoadedStatus> statusMap) {
      print('$_logTag: ElectronicHorizonDataLoaderStatus updated.');

      final lastUpdate = _lastElectronicHorizon;
      if (lastUpdate == null) return;

      final allPaths = lastUpdate.paths;

      statusMap.forEach((int loadedLevel, ElectronicHorizonDataLoadedStatus status) {
        if (status != ElectronicHorizonDataLoadedStatus.fullyLoaded) return;

        // Level 0 = MPP. Process MPP segments for road sign logging.
        if (loadedLevel == 0 && allPaths.isNotEmpty) {
          final mpp = allPaths[0];
          for (var segment in mpp.segments) {
            final directedOCMSegmentId = segment.segmentId.ocmSegmentId;
            if (directedOCMSegmentId == null) continue;
            final result = _electronicHorizonDataLoader.getSegment(directedOCMSegmentId);
            if (result.errorCode == null && result.segmentData != null) {
              _logRoadSigns(result.segmentData!, directedOCMSegmentId);
            }
          }
          return;
        }

        // Wait until first-level side-path data is fully loaded before logging side streets
        // that branch directly from the active route.
        if (loadedLevel == 1) {
          _notifySideStreetInfos(allPaths);
        }

        // For side-path levels (level > 0): walk all path segments and use
        // sidePathIndexes to find paths that branch off at each segment.
        // sidePathIndexes contains indexes into allPaths[], pointing to branching paths.
        // Track processed path indexes to avoid redundant getSegment() calls.
        final processedSidePathIndexes = <int>{};
        for (var path in allPaths) {
          for (var segment in path.segments) {
            for (var sidePathIndex in segment.sidePathIndexes) {
              if (sidePathIndex < 0 || sidePathIndex >= allPaths.length) continue;
              if (!processedSidePathIndexes.add(sidePathIndex)) continue;
              final branchingPath = allPaths[sidePathIndex];

              // Only process branching paths at the loaded level.
              if (branchingPath.level != loadedLevel) continue;

              print('$_logTag: Branching path index: $sidePathIndex, level: ${branchingPath.level}');

              // Draw all segments of this branching path.
              for (var branchSegment in branchingPath.segments) {
                final directedOCMSegmentId = branchSegment.segmentId.ocmSegmentId;
                if (directedOCMSegmentId == null) continue;

                final result = _electronicHorizonDataLoader.getSegment(directedOCMSegmentId);
                if (result.errorCode == null && result.segmentData != null) {
                  final polyline = result.segmentData!.polyline;
                  if (_isVisualizationEnabled && polyline != null) {
                    _drawSegmentPolyline(directedOCMSegmentId.id.localId, polyline, branchingPath.level);
                  }
                }
              }
            }
          }
        }
      });
    });
  }

  // Finds first-level side streets whose parent is the currently followed navigation path.
  void _notifySideStreetInfos(List<ElectronicHorizonPath> allPaths) {
    for (int pathIndex = 0; pathIndex < allPaths.length; pathIndex++) {
      final path = allPaths[pathIndex];
      if (path.level != 1 || path.parentPathIndex == null || path.parentPathIndex != 0) {
        continue;
      }

      final sideStreetInfo = _findSideStreetInfo(path, pathIndex);
      if (sideStreetInfo != null) {
        print('$_logTag: SideStreetName near active route: ${sideStreetInfo.streetName} '
            'at lat/lon: ${sideStreetInfo.coordinateAtOffsetFromSegmentStart.latitude}/'
            '${sideStreetInfo.coordinateAtOffsetFromSegmentStart.longitude}, '
            'pathIndex=${sideStreetInfo.pathIndex}, '
            'segmentLocalId=${sideStreetInfo.segmentLocalId}');
      }
    }
  }

  _SideStreetInfo? _findSideStreetInfo(ElectronicHorizonPath branchingPath, int pathIndex) {
    for (final segment in branchingPath.segments) {
      final directedOCMSegmentId = segment.segmentId.ocmSegmentId;
      if (directedOCMSegmentId == null) continue;

      final result = _electronicHorizonDataLoader.getSegment(directedOCMSegmentId);
      if (result.errorCode != null || result.segmentData == null) continue;

      final segmentData = result.segmentData!;
      final sideStreetName = _getFirstStreetLabel(segmentData);
      if (sideStreetName == null) continue;

      final polyline = segmentData.polyline;
      if (polyline == null) continue;

      final sideStreetCoordinates = polyline.coordinatesAtOffsetInMeters(
        _sideStreetLogOffsetMeters,
        GeoPolylineDirection.fromBeginning,
      );

      return _SideStreetInfo(
        sideStreetName,
        sideStreetCoordinates,
        pathIndex,
        directedOCMSegmentId.id.localId,
      );
    }

    return null;
  }

  // Returns the first non-empty street label (street name or road number).
  String? _getFirstStreetLabel(SegmentData segmentData) {
    final segmentSpans = segmentData.spans;
    if (segmentSpans.isEmpty) return null;

    for (final segmentSpanData in segmentSpans) {
      String? streetName = segmentSpanData.streetNames?.getDefaultValue();
      if (streetName == null || streetName.trim().isEmpty) {
        streetName = segmentSpanData.roadNumbers?.getDefaultValue();
      }
      if (streetName != null && streetName.trim().isNotEmpty) {
        return streetName;
      }
    }

    return null;
  }

  /// Draw a colored MapPolyline for the given road segment and register it in _segmentPolylineMap
  /// so it can be removed when the segment leaves the horizon.
  ///   - MPP (level == 0):        Already rendered as main route
  ///   - Side paths level 1:       Cyan
  ///   - Side paths level 2:       Pink
  ///   - Side paths level 3:       Orange
  ///   - Side paths level 4:       Green
  void _drawSegmentPolyline(int localId, GeoPolyline geoPolyline, int level) {
    // MPP (Most Preferred Path, level == 0) is already rendered as the main route
    // We only draw visual polylines for alternative side-paths (level > 0)
    if (level == 0) {
      print('$_logTag: MPP SEGMENT - localId=$localId (already rendered as main route)');
      return;
    }

    // Skip if a polyline for this segment is already on the map.
    if (_segmentPolylineMap.containsKey(localId)) return;

    Color color;
    String colorName;
    switch (level) {
      case 1:
        color = const Color.fromARGB(255, 0, 255, 255); // Cyan - first side-path level (fully opaque)
        colorName = 'CYAN';
        break;
      case 2:
        color = const Color.fromARGB(217, 255, 51, 204); // Pink/Fuchsia - second side-path level
        colorName = 'PINK';
        break;
      case 3:
        color = const Color.fromARGB(217, 255, 165, 0); // Orange - third side-path level
        colorName = 'ORANGE';
        break;
      case 4:
        color = const Color.fromARGB(217, 0, 255, 0); // Green - fourth side-path level
        colorName = 'GREEN';
        break;
      default:
        return; // Don't draw levels beyond 4
    }

    print('$_logTag: Drawing segment polyline - localId=$localId, level=$level, color=$colorName');

    double widthInPixels = 25;
    MapPolyline mapPolyline;
    try {
      mapPolyline = MapPolyline.withRepresentation(
        geoPolyline,
        MapPolylineSolidRepresentation(
          MapMeasureDependentRenderSize.withSingleSize(RenderSizeUnit.pixels, widthInPixels),
          color,
          LineCap.round,
        ),
      );
    } on MapPolylineRepresentationInstantiationException catch (e) {
      print("$_logTag: MapPolyline instantiation failed: ${e.error.name}");
      return;
    } on MapMeasureDependentRenderSizeInstantiationException catch (e) {
      print("$_logTag: MapMeasureDependentRenderSize failed: ${e.error.name}");
      return;
    }
    _hereMapController.mapScene.addMapPolyline(mapPolyline);
    _segmentPolylineMap[localId] = mapPolyline;
    print('$_logTag: Successfully added polyline to map scene - localId=$localId');
  }

  /// Remove all EH segment polylines from the map.
  void _clearVisualization() {
    for (var polyline in _segmentPolylineMap.values) {
      _hereMapController.mapScene.removeMapPolyline(polyline);
    }
    _segmentPolylineMap.clear();
  }

  /// Log road sign information from a fully loaded segment.
  void _logRoadSigns(SegmentData segmentData, DirectedOCMSegmentId directedOCMSegmentId) {
    List<RoadSign>? roadSigns = segmentData.roadSigns;
    if (roadSigns == null || roadSigns.isEmpty) return;
    final polyline = segmentData.polyline;
    if (polyline == null) return;
    for (RoadSign roadSign in roadSigns) {
      GeoCoordinates roadSignCoordinates = _getGeoCoordinatesFromOffsetInMeters(
          polyline, roadSign.offsetInMeters.toDouble());
      print('$_logTag: RoadSign: type = ${roadSign.roadSignType.name}, '
          'offsetInMeters = ${roadSign.offsetInMeters}, '
          'lat/lon: ${roadSignCoordinates.latitude}/${roadSignCoordinates.longitude}, '
          'segmentId = ${directedOCMSegmentId.id.localId}');
    }
  }

  /// Convert an offset in meters along a GeoPolyline to GeoCoordinates using the HERE SDK's coordinatesAtOffsetInMeters.
  GeoCoordinates _getGeoCoordinatesFromOffsetInMeters(GeoPolyline geoPolyline, double offsetInMeters) {
    return geoPolyline.coordinatesAtOffsetInMeters(offsetInMeters, GeoPolylineDirection.fromBeginning);
  }

  void stop() {
    if (_electronicHorizonEngine == null) {
      return;
    }

    if (_electronicHorizonListener != null) {
      _electronicHorizonEngine!.removeElectronicHorizonListener(_electronicHorizonListener!);
    }
    if (_electronicHorizonDataLoaderStatusListener != null) {
      _electronicHorizonDataLoader.removeElectronicHorizonDataLoaderStatusListener(
          _electronicHorizonDataLoaderStatusListener!);
    }
    _clearVisualization();
    print('$_logTag: ElectronicHorizonEngine stopped.');
  }

  SDKNativeEngine _getSDKNativeEngine() {
    SDKNativeEngine? sdkNativeEngine = SDKNativeEngine.sharedInstance;
    if (sdkNativeEngine == null) {
      throw Exception('SDKNativeEngine is not initialized.');
    }
    return sdkNativeEngine;
  }
}

class _SideStreetInfo {
  final String streetName;
  final GeoCoordinates coordinateAtOffsetFromSegmentStart;
  final int pathIndex;
  final int segmentLocalId;

  _SideStreetInfo(
    this.streetName,
    this.coordinateAtOffsetFromSegmentStart,
    this.pathIndex,
    this.segmentLocalId,
  );
}
