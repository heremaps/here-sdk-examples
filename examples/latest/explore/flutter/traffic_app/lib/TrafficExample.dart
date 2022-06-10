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

import 'dart:ui';

import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/gestures.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/traffic.dart';

// A callback to notify the hosting widget.
typedef ShowDialogFunction = void Function(String title, String message);

class TrafficExample {
  HereMapController _hereMapController;
  ShowDialogFunction _showDialog;
  late TrafficEngine _trafficEngine;

  // Visualizes traffic incidents found with the TrafficEngine.
  List<MapPolyline> _mapPolylineList = [];

  TrafficExample(ShowDialogFunction showDialogCallback, HereMapController hereMapController)
      : _showDialog = showDialogCallback,
        _hereMapController = hereMapController {
    double distanceToEarthInMeters = 10000;
    MapMeasure mapMeasureZoom = MapMeasure(MapMeasureKind.distance, distanceToEarthInMeters);
    _hereMapController.camera.lookAtPointWithMeasure(GeoCoordinates(52.520798, 13.409408), mapMeasureZoom);

    try {
      _trafficEngine = TrafficEngine();
    } on InstantiationException {
      throw ("Initialization of TrafficEngine failed.");
    }

    // Setting a tap handler to pick and search for traffic incidents around the tapped area.
    _setTapGestureHandler();

    _showDialog("Note", "Tap on the map to pick a traffic incident.");
  }

  void enableAll() {
    // Show real-time traffic lines and incidents on the map.
    _enableTrafficVisualization();
  }

  void disableAll() {
    _disableTrafficVisualization();
  }

  void _enableTrafficVisualization() {
    // Once these layers are added to the map, they will be automatically updated while panning the map.
    _hereMapController.mapScene.setLayerVisibility(MapSceneLayers.trafficFlow, VisibilityState.visible);
    // MapSceneLayers.trafficIncidents renders traffic icons and lines to indicate the location of incidents. Note that these are not directly pickable yet.
    _hereMapController.mapScene.setLayerVisibility(MapSceneLayers.trafficIncidents, VisibilityState.visible);
  }

  void _disableTrafficVisualization() {
    _hereMapController.mapScene.setLayerVisibility(MapSceneLayers.trafficFlow, VisibilityState.hidden);
    _hereMapController.mapScene.setLayerVisibility(MapSceneLayers.trafficIncidents, VisibilityState.hidden);

    // This clears only the custom visualization for incidents found with the TrafficEngine.
    _clearTrafficIncidentsMapPolylines();
  }

  void _setTapGestureHandler() {
    _hereMapController.gestures.tapListener = TapListener((Point2D touchPoint) {
      GeoCoordinates? touchGeoCoords = _hereMapController.viewToGeoCoordinates(touchPoint);
      // Can be null when the map was tilted and the sky was tapped.
      if (touchGeoCoords != null) {
        // Pick incidents that are shown in MapSceneLayers.trafficIncidents.
        _pickTrafficIncident(touchPoint);

        // Query for incidents independent of MapSceneLayers.trafficIncidents.
        _queryForIncidents(touchGeoCoords);
      }
    });
  }

  // Traffic incidents can only be picked, when MapScene.Layers.TRAFFIC_INCIDENTS is visible.
  _pickTrafficIncident(Point2D touchPointInPixels) {
    Point2D originInPixels = new Point2D(touchPointInPixels.x, touchPointInPixels.y);
    Size2D sizeInPixels = new Size2D(1, 1);
    Rectangle2D rectangle = new Rectangle2D(originInPixels, sizeInPixels);

    _hereMapController.pickMapContent(rectangle, (pickMapContentResult) {
      if (pickMapContentResult == null) {
        // An error occurred while performing the pick operation.
        return;
      }

      List<PickTrafficIncidentResult> trafficIncidents = pickMapContentResult.trafficIncidents;
      if (trafficIncidents.length == 0) {
        print("No traffic incident found at picked location");
      } else {
        print("Picked at least one incident.");
        PickTrafficIncidentResult firstIncident = trafficIncidents.first;
        _showDialog("Traffic incident picked:", "Type: " + firstIncident.type.name);

        // Find more details by looking up the ID via TrafficEngine.
        _findIncidentByID(firstIncident.originalId);
      }

      // Optionally, look for more map content like embedded POIs.
    });
  }

  _findIncidentByID(String originalId) {
    TrafficIncidentLookupOptions trafficIncidentsLookupOptions = new TrafficIncidentLookupOptions();
    // Optionally, specify a language:
    // the language of the country where the incident occurs is used.
    // trafficIncidentsLookupOptions.languageCode = LanguageCode.EN_US;
    _trafficEngine.lookupIncident(originalId, trafficIncidentsLookupOptions,
        (trafficQueryError, trafficIncident) {
      if (trafficQueryError == null) {
        print("Fetched TrafficIncident from lookup request." + " Description: " + trafficIncident!.description.text);
        _addTrafficIncidentsMapPolyline(trafficIncident.location.polyline);
      } else {
        _showDialog("TrafficLookupError:", trafficQueryError.toString());
      }
    });
  }

  void _addTrafficIncidentsMapPolyline(GeoPolyline geoPolyline) {
    // Show traffic incident as polyline.
    double widthInPixels = 20;
    MapPolyline routeMapPolyline = MapPolyline(geoPolyline, widthInPixels, Color.fromARGB(120, 0, 0, 0));

    _hereMapController.mapScene.addMapPolyline(routeMapPolyline);
    _mapPolylineList.add(routeMapPolyline);
  }

  void _queryForIncidents(GeoCoordinates centerCoords) {
    double radiusInMeters = 1000;
    GeoCircle geoCircle = GeoCircle(centerCoords, radiusInMeters);
    TrafficIncidentsQueryOptions trafficIncidentsQueryOptions = TrafficIncidentsQueryOptions();
    // Optionally, specify a language:
    // the language of the country where the incident occurs is used.
    // trafficIncidentsQueryOptions.languageCode = LanguageCode.enUs;
    _trafficEngine.queryForIncidentsInCircle(geoCircle, trafficIncidentsQueryOptions,
        (TrafficQueryError? trafficQueryError, List<TrafficIncident>? trafficIncidentsList) {
      if (trafficQueryError != null) {
        print("TrafficQueryError: " + trafficQueryError.toString());
        return;
      }

      // If error is null, list is guaranteed to be not empty.
      String trafficMessage = "Found ${trafficIncidentsList!.length} result(s).";
      TrafficIncident? nearestIncident = _getNearestTrafficIncident(centerCoords, trafficIncidentsList);
      if (nearestIncident != null) {
        trafficMessage += " Nearest incident: " + nearestIncident.description.text;
      }
      print("Nearby traffic incidents: " + trafficMessage);

      for (TrafficIncident trafficIncident in trafficIncidentsList) {
        print(trafficIncident.description.text);
        _addTrafficIncidentsMapPolyline(trafficIncident.location.polyline);
      }
    });
  }

  TrafficIncident? _getNearestTrafficIncident(
      GeoCoordinates currentGeoCoords, List<TrafficIncident> trafficIncidentsList) {
    if (trafficIncidentsList.length == 0) {
      return null;
    }

    // By default, traffic incidents results are not sorted by distance.
    double nearestDistance = double.maxFinite;
    TrafficIncident? nearestTrafficIncident;
    for (TrafficIncident trafficIncident in trafficIncidentsList) {
      // In case lengthInMeters == 0 then the polyline consistes of two equal coordinates.
      // It is guaranteed that each incident has a valid polyline.
      for (GeoCoordinates geoCoords in trafficIncident.location.polyline.vertices) {
        double currentDistance = currentGeoCoords.distanceTo(geoCoords);
        if (currentDistance < nearestDistance) {
          nearestDistance = currentDistance;
          nearestTrafficIncident = trafficIncident;
        }
      }
    }

    return nearestTrafficIncident;
  }

  void _clearTrafficIncidentsMapPolylines() {
    for (var mapPolyline in _mapPolylineList) {
      _hereMapController.mapScene.removeMapPolyline(mapPolyline);
    }
    _mapPolylineList.clear();
  }
}
