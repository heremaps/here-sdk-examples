/*
 * Copyright (C) 2019-2022 HERE Europe B.V.
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

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:here_sdk/core.dart';
import 'package:here_sdk/gestures.dart';
import 'package:here_sdk/mapview.dart';

// A callback to notifiy the hosting widget.
typedef ShowDialogFunction = void Function(String title, String message);

class MapItemsExample {
  final HereMapController _hereMapController;
  List<MapMarker> _mapMarkerList = [];
  List<MapMarkerCluster> _mapMarkerClusterList = [];
  List<MapMarker3D> _mapMarker3DList = [];
  List<LocationIndicator> _locationIndicatorList = [];
  MapImage? _poiMapImage;
  MapImage? _photoMapImage;
  MapImage? _circleMapImage;
  MapImage? _blueSquareMapImage;
  MapImage? _greenSquareMapImage;
  final ShowDialogFunction _showDialog;

  MapItemsExample(ShowDialogFunction showDialogCallback, HereMapController hereMapController)
      : _showDialog = showDialogCallback,
        _hereMapController = hereMapController {
    double distanceToEarthInMeters = 8000;
    _hereMapController.camera
        .lookAtPointWithDistance(GeoCoordinates(52.51760485151816, 13.380312380535472), distanceToEarthInMeters);

    // Setting a tap handler to pick markers from map.
    _setTapGestureHandler();

    _showDialog("Note", "You can tap 2D markers.");
  }

  void showAnchoredMapMarkers() {
    _unTiltMap();

    GeoCoordinates geoCoordinates = _createRandomGeoCoordinatesAroundMapCenter();

    // Centered on location. Shown below the POI image to indicate the location.
    // The draw order is determined from what is first added to the map,
    // but since loading images is done async, we can make this explicit by setting
    // a draw order. High numbers are drawn on top of lower numbers.
    _addCircleMapMarker(geoCoordinates, 0);

    // Anchored, pointing to location.
    _addPOIMapMarker(geoCoordinates, 1);
  }

  void showCenteredMapMarkers() {
    _unTiltMap();

    GeoCoordinates geoCoordinates = _createRandomGeoCoordinatesAroundMapCenter();

    // Centered on location.
    _addPhotoMapMarker(geoCoordinates, 0);

    // Centered on location. Shown above the photo marker to indicate the location.
    _addCircleMapMarker(geoCoordinates, 1);
  }

  Future<void> showMapMarkerCluster() async {
    // Reuse existing MapImage for new map markers.
    if (_blueSquareMapImage == null) {
      Uint8List imagePixelData = await _loadFileAsUint8List('assets/blue_square.png');
      _blueSquareMapImage = MapImage.withPixelDataAndImageFormat(imagePixelData, ImageFormat.png);
    }

    MapMarkerCluster mapMarkerCluster = MapMarkerCluster(MapMarkerClusterImageStyle(_blueSquareMapImage!));
    _hereMapController.mapScene.addMapMarkerCluster(mapMarkerCluster);
    _mapMarkerClusterList.add(mapMarkerCluster);

    for (int i = 0; i < 10; i++) {
      mapMarkerCluster.addMapMarker(await _createRandomMapMarkerInViewport());
    }
  }

  Future<MapMarker> _createRandomMapMarkerInViewport() async {
    // Reuse existing MapImage for new map markers.
    if (_greenSquareMapImage == null) {
      Uint8List imagePixelData = await _loadFileAsUint8List('assets/green_square.png');
      _greenSquareMapImage = MapImage.withPixelDataAndImageFormat(imagePixelData, ImageFormat.png);
    }

    MapMarker mapMarker = MapMarker(_createRandomGeoCoordinatesAroundMapCenter(), _greenSquareMapImage!);
    return mapMarker;
  }

  void showLocationIndicatorPedestrian() {
    _unTiltMap();

    GeoCoordinates geoCoordinates = _createRandomGeoCoordinatesAroundMapCenter();

    // Centered on location.
    _addLocationIndicator(geoCoordinates, LocationIndicatorIndicatorStyle.pedestrian);
  }

  void showLocationIndicatorNavigation() {
    _unTiltMap();

    GeoCoordinates geoCoordinates = _createRandomGeoCoordinatesAroundMapCenter();

    // Centered on location.
    _addLocationIndicator(geoCoordinates, LocationIndicatorIndicatorStyle.navigation);
  }

  void showFlatMapMarkers() {
    // Tilt the map for a better 3D effect.
    _tiltMap();

    GeoCoordinates geoCoordinates = _createRandomGeoCoordinatesAroundMapCenter();

    // Adds a flat POI marker that rotates and tilts together with the map.
    _addFlatMarker3D(geoCoordinates);

    // A centered 2D map marker to indicate the exact location.
    // Note that 3D map markers are always drawn on top of 2D map markers.
    _addCircleMapMarker(geoCoordinates, 1);
  }

  void showMapMarkers3D() {
    // Tilt the map for a better 3D effect.
    _tiltMap();

    GeoCoordinates geoCoordinates = _createRandomGeoCoordinatesAroundMapCenter();

    // Adds a textured 3D model.
    // It's origin is centered on the location.
    _addMapMarker3D(geoCoordinates);
  }

  void clearMap() {
    _hereMapController.mapScene.removeMapMarkers(_mapMarkerList);
    _mapMarkerList.clear();

    for (var mapMarker3D in _mapMarker3DList) {
      _hereMapController.mapScene.removeMapMarker3d(mapMarker3D);
    }
    _mapMarker3DList.clear();

    for (var mapMarkerCluster in _mapMarkerClusterList) {
      _hereMapController.mapScene.removeMapMarkerCluster(mapMarkerCluster);
    }
    _mapMarkerClusterList.clear();

    for (var locationIndicator in _locationIndicatorList) {
      _hereMapController.removeLifecycleListener(locationIndicator);
    }
    _locationIndicatorList.clear();
  }

  Future<void> _addPOIMapMarker(GeoCoordinates geoCoordinates, int drawOrder) async {
    // Reuse existing MapImage for new map markers.
    if (_poiMapImage == null) {
      Uint8List imagePixelData = await _loadFileAsUint8List('assets/poi.png');
      _poiMapImage = MapImage.withPixelDataAndImageFormat(imagePixelData, ImageFormat.png);
    }

    // By default, the anchor point is set to 0.5, 0.5 (= centered).
    // Here the bottom, middle position should point to the location.
    Anchor2D anchor2D = Anchor2D.withHorizontalAndVertical(0.5, 1);

    MapMarker mapMarker = MapMarker.withAnchor(geoCoordinates, _poiMapImage!, anchor2D);
    mapMarker.drawOrder = drawOrder;

    Metadata metadata = Metadata();
    metadata.setString("key_poi", "Metadata: This is a POI.");
    mapMarker.metadata = metadata;

    _hereMapController.mapScene.addMapMarker(mapMarker);
    _mapMarkerList.add(mapMarker);
  }

  Future<void> _addPhotoMapMarker(GeoCoordinates geoCoordinates, int drawOrder) async {
    // Reuse existing MapImage for new map markers.
    if (_photoMapImage == null) {
      Uint8List imagePixelData = await _loadFileAsUint8List('assets/here_car.png');
      _photoMapImage = MapImage.withPixelDataAndImageFormat(imagePixelData, ImageFormat.png);
    }

    MapMarker mapMarker = MapMarker(geoCoordinates, _photoMapImage!);
    mapMarker.drawOrder = drawOrder;

    _hereMapController.mapScene.addMapMarker(mapMarker);
    _mapMarkerList.add(mapMarker);
  }

  Future<void> _addCircleMapMarker(GeoCoordinates geoCoordinates, int drawOrder) async {
    // Reuse existing MapImage for new map markers.
    if (_circleMapImage == null) {
      Uint8List imagePixelData = await _loadFileAsUint8List('assets/circle.png');
      _circleMapImage = MapImage.withPixelDataAndImageFormat(imagePixelData, ImageFormat.png);
    }

    MapMarker mapMarker = MapMarker(geoCoordinates, _circleMapImage!);
    mapMarker.drawOrder = drawOrder;

    _hereMapController.mapScene.addMapMarker(mapMarker);
    _mapMarkerList.add(mapMarker);
  }

  void _addLocationIndicator(GeoCoordinates geoCoordinates, LocationIndicatorIndicatorStyle indicatorStyle) {
    LocationIndicator locationIndicator = LocationIndicator();
    locationIndicator.locationIndicatorStyle = indicatorStyle;

    // A LocationIndicator is intended to mark the user's current location,
    // including a bearing direction.
    Location location = Location.withCoordinates(geoCoordinates);
    location.time = DateTime.now();
    location.bearingInDegrees = _getRandom(0, 360);

    locationIndicator.updateLocation(location);

    // A LocationIndicator listens to the lifecycle of the map view,
    // therefore, for example, it will get destroyed when the map view gets destroyed.
    _hereMapController.addLifecycleListener(locationIndicator);
    _locationIndicatorList.add(locationIndicator);
  }

  void _addFlatMarker3D(GeoCoordinates geoCoordinates) {
    // Place the files in the "assets" directory as specified in pubspec.yaml.
    // Adjust file name and path as appropriate for your project.
    // Note: The bottom of the plane is centered on the origin.
    String geometryFilePath = "assets/models/plane.obj";

    // The POI texture is a square, so we can easily wrap it onto the 2 x 2 plane model.
    String textureFilePath = "assets/models/poi_texture.png";

    // Optionally, consider to store the model for reuse (like we showed for MapImages above).
    MapMarker3DModel mapMarker3DModel = MapMarker3DModel.withTextureFilePath(geometryFilePath, textureFilePath);
    MapMarker3D mapMarker3D = MapMarker3D(geoCoordinates, mapMarker3DModel);
    // Scale marker. Note that we used a normalized length of 2 units in 3D space.
    mapMarker3D.scale = 50;

    _hereMapController.mapScene.addMapMarker3d(mapMarker3D);
    _mapMarker3DList.add(mapMarker3D);
  }

  // A location indicator can be switched to a gray state, for example, to indicate a weak GPS signal.
  void toggleActiveStateForLocationIndicator() {
    for (var locationIndicator in _locationIndicatorList) {
      var isActive = locationIndicator.isActive;
      // Toggle between active / inactive state.
      locationIndicator.isActive = !isActive;
    }
  }

  void _addMapMarker3D(GeoCoordinates geoCoordinates) {
    // Place the files in the "assets" directory as specified in pubspec.yaml.
    // Adjust file name and path as appropriate for your project.
    String geometryFilePath = "assets/models/obstacle.obj";
    String textureFilePath = "assets/models/obstacle_texture.png";

    // Optionally, consider to store the model for reuse (like we showed for MapImages above).
    MapMarker3DModel mapMarker3DModel = MapMarker3DModel.withTextureFilePath(geometryFilePath, textureFilePath);
    MapMarker3D mapMarker3D = MapMarker3D(geoCoordinates, mapMarker3DModel);
    mapMarker3D.scale = 6;
    mapMarker3D.isDepthCheckEnabled = true;

    _hereMapController.mapScene.addMapMarker3d(mapMarker3D);
    _mapMarker3DList.add(mapMarker3D);
  }

  Future<Uint8List> _loadFileAsUint8List(String assetPathToFile) async {
    // The path refers to the assets directory as specified in pubspec.yaml.
    ByteData fileData = await rootBundle.load(assetPathToFile);
    return Uint8List.view(fileData.buffer);
  }

  void _setTapGestureHandler() {
    _hereMapController.gestures.tapListener = TapListener((Point2D touchPoint) {
      _pickMapMarker(touchPoint);
    });
  }

  void _pickMapMarker(Point2D touchPoint) {
    double radiusInPixel = 2;
    _hereMapController.pickMapItems(touchPoint, radiusInPixel, (pickMapItemsResult) {
      if (pickMapItemsResult == null) {
        // Pick operation failed.
        return;
      }

      // Note that MapMarker items contained in a cluster are not part of pickMapItemsResult.markers.
      _handlePickedMapMarkerClusters(pickMapItemsResult);

      // Note that 3D map markers can't be picked yet. Only marker, polgon and polyline map items are pickable.
      List<MapMarker> mapMarkerList = pickMapItemsResult.markers;
      int listLength = mapMarkerList.length;
      if (listLength == 0) {
        print("No map markers found.");
        return;
      }

      MapMarker topmostMapMarker = mapMarkerList.first;
      Metadata? metadata = topmostMapMarker.metadata;
      if (metadata != null) {
        String message = metadata.getString("key_poi") ?? "No message found.";

        _showDialog("Map Marker picked", message);
        return;
      }

      _showDialog("Map Marker picked", "No metadata attached.");
    });
  }

  void _handlePickedMapMarkerClusters(PickMapItemsResult pickMapItemsResult) {
    List<MapMarkerClusterGrouping> groupingList = pickMapItemsResult.clusteredMarkers;
    if (groupingList.length == 0) {
      return;
    }

    MapMarkerClusterGrouping topmostGrouping = groupingList.first;
    int clusterSize = topmostGrouping.markers.length;
    if (clusterSize == 0) {
      // This cluster does not contain any MapMarker items.
      return;
    }
    if (clusterSize == 1) {
      _showDialog("Map marker picked", "This MapMarker belongs to a cluster.");
    } else {
      int totalSize = topmostGrouping.parent.markers.length;
      _showDialog(
          "Map marker cluster picked",
          "Number of contained markers in this cluster: $clusterSize." +
              "Total number of markers in this MapMarkerCluster: $totalSize.");
    }
  }

  void _tiltMap() {
    double bearing = _hereMapController.camera.state.orientationAtTarget.bearing;
    double tilt = 60;
    _hereMapController.camera.setOrientationAtTarget(GeoOrientationUpdate(bearing, tilt));
  }

  void _unTiltMap() {
    double bearing = _hereMapController.camera.state.orientationAtTarget.bearing;
    double tilt = 0;
    _hereMapController.camera.setOrientationAtTarget(GeoOrientationUpdate(bearing, tilt));
  }

  GeoCoordinates _createRandomGeoCoordinatesAroundMapCenter() {
    GeoCoordinates? centerGeoCoordinates = _hereMapController.viewToGeoCoordinates(
        Point2D(_hereMapController.viewportSize.width / 2, _hereMapController.viewportSize.height / 2));
    if (centerGeoCoordinates == null) {
      // Should never happen for center coordinates.
      throw Exception("CenterGeoCoordinates are null");
    }
    double lat = centerGeoCoordinates.latitude;
    double lon = centerGeoCoordinates.longitude;
    return GeoCoordinates(_getRandom(lat - 0.02, lat + 0.02), _getRandom(lon - 0.02, lon + 0.02));
  }

  double _getRandom(double min, double max) {
    return min + Random().nextDouble() * (max - min);
  }
}
