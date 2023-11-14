/*
 * Copyright (C) 2023 HERE Europe B.V.
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
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/mapview.dart';

// A class to visualize the incoming raw location signals on the map during a trip.
class HerePositioningVisualizer {
  late HereMapController mapView;
  LocationIndicator locationIndicator = new LocationIndicator();
  List<MapPolygon> mapCircles = [];
  MapPolyline? mapPolyline;
  List<GeoCoordinates> geoCoordinatesList = [];
  final double accuracyRadiusThresholdInMeters = 10.0;

  HerePositioningVisualizer(HereMapController hereMap) {
    this.mapView = hereMap;
    _setupMyLocationIndicator();
  }

  void updateLocationIndicator(Location location) {
    locationIndicator.updateLocation(location);
  }

  void renderUnfilteredLocationSignals(Location location) {
    print("Received accuracy " + location.horizontalAccuracyInMeters.toString());

    // Black means that no accuracy information is available.
    Color fillColor = Colors.black;
    if (location.horizontalAccuracyInMeters != null) {
      double accuracy = location.horizontalAccuracyInMeters!;
      if (accuracy < accuracyRadiusThresholdInMeters / 2) {
        // Green means that we have very good accuracy.
        fillColor = Colors.green;
      } else if (accuracy <= accuracyRadiusThresholdInMeters) {
        // Orange means that we have acceptable accuracy.
        fillColor = Colors.orange;
      } else {
        // Red means, the accuracy is quite bad, ie > 50 m.
        // The location will be ignored for our hiking diary.
        fillColor = Colors.red;
      }
    }

    _addLocationCircle(location.coordinates, 1, fillColor);
    _updateMapPolyline(location);
  }

  void clearMap() {
    if (mapPolyline != null) {
      mapView.mapScene.removeMapPolyline(mapPolyline!);
      mapPolyline = null;
    }
    for (MapPolygon circle in mapCircles) {
      mapView.mapScene.removeMapPolygon(circle);
    }

    geoCoordinatesList.clear();
  }

  void _setupMyLocationIndicator() {
    locationIndicator.isAccuracyVisualized = true;
    locationIndicator.locationIndicatorStyle = LocationIndicatorIndicatorStyle.pedestrian;
    locationIndicator.enable(mapView);
  }

  void _addLocationCircle(GeoCoordinates center, double radiusInMeters, Color fillColor) {
    GeoCircle geoCircle = GeoCircle(center, radiusInMeters);
    GeoPolygon geoPolygon = GeoPolygon.withGeoCircle(geoCircle);
    MapPolygon mapPolygon = MapPolygon(geoPolygon, fillColor);
    mapView.mapScene.addMapPolygon(mapPolygon);
    mapCircles.add(mapPolygon);

    if (mapCircles.length > 150) {
      // Drawing too many items on the map view may slow down rendering, so we remove the oldest circle.
      mapView.mapScene.removeMapPolygon(mapCircles.first);
      mapCircles.remove(0);
    }
  }

  void _addMapPolyline(GeoPolyline geoPolyline) {
    double widthInPixels = 5.0;
    Color polylineColor = const Color.fromARGB(0, 56, 54, 63);
    try {
      mapPolyline = MapPolyline.withRepresentation(
          geoPolyline,
          MapPolylineSolidRepresentation(
              MapMeasureDependentRenderSize.withSingleSize(RenderSizeUnit.densityIndependentPixels, widthInPixels),
              polylineColor,
              LineCap.round));
    } on MapPolylineRepresentationInstantiationException catch (e) {
      print("MapPolylineRepresentation Exception:" + e.error.name);
      return;
    } on MapMeasureDependentRenderSizeInstantiationException catch (e) {
      print("MapMeasureDependentRenderSize Exception:" + e.error.name);
      return;
    }
    mapView.mapScene.addMapPolyline(mapPolyline!);
  }

  void _updateMapPolyline(Location location) {
    geoCoordinatesList.add(location.coordinates);

    if (geoCoordinatesList.length < 2) {
      return;
    }
    // We are sure that the number of vertices is greater than 1 (see above), so it will not crash.
    GeoPolyline geoPolyline;
    try {
      geoPolyline = new GeoPolyline(geoCoordinatesList);
    } on InstantiationException catch (e) {
      print("Error:" + e.error.name);
      return;
    }

    // Add polyline to the map, if the instance is null.
    if (mapPolyline == null) {
      _addMapPolyline(geoPolyline);
      return;
    }

    // Update the polyline shape that connects the raw location signals.
    mapPolyline!.geometry = geoPolyline;
  }
}
