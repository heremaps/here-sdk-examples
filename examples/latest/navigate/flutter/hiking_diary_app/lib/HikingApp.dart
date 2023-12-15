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

import 'dart:core';

import 'package:flutter/material.dart';
import 'package:here_sdk/animation.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/location.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/navigation.dart';
import 'package:hiking_diary_app/OutdoorRasterLayer.dart';
import 'package:hiking_diary_app/locationfilter/LocationFilterAbstract.dart';
import 'package:hiking_diary_app/positioning/HEREPositioningProvider.dart';
import 'package:hiking_diary_app/positioning/HEREPositioningVisualizer.dart';

import 'GPXManager.dart';
import 'MessageNotifier.dart';
import 'locationfilter/DistanceAccuracyLocationFilter.dart';

class HikingApp implements LocationListener, LocationStatusListener {
  late HEREPositioningProvider herePositioningProvider;
  late HerePositioningVisualizer positioningVisualizer;
  late GPXManager gpxManager;

  final BuildContext context;
  final HereMapController mapView;
  final MessageNotifier messageNotifier;

  MapPolyline? myPathMapPolyline;
  bool isHiking = false;
  bool isGPXTrackLoaded = false;
  bool moveMapToCurrentLocation = true;
  GPXTrackWriter gpxTrackWriter = GPXTrackWriter();
  OutdoorRasterLayer? outdoorRasterLayer;
  LocationFilterAbstract? locationFilter;

  HikingApp(this.context, this.mapView, this.messageNotifier) {
    herePositioningProvider = HEREPositioningProvider();
    locationFilter = DistanceAccuracyLocationFilter();
    gpxManager = GPXManager("myGPXDocument.gpx", context);
    positioningVisualizer = HerePositioningVisualizer(mapView);
    outdoorRasterLayer = OutdoorRasterLayer(mapView);

    Location? location = herePositioningProvider.getLastKnownLocation();
    if (location != null) {
      mapView.camera.lookAtPoint(location.coordinates);
    }
    herePositioningProvider.startLocating(this, LocationAccuracy.navigation);

    setMessage("** Hiking Diary **");
  }

  @override
  void onFeaturesNotAvailable(List<LocationFeature> features) {}

  @override
  void onStatusChanged(LocationEngineStatus locationEngineStatus) {}

  @override
  void onLocationUpdated(Location location) {
    if (moveMapToCurrentLocation) {
      moveMapToCurrentLocation = false;
      _animateCameraToCurrentLocation(location);
    }

    positioningVisualizer.updateLocationIndicator(location);
    if (isHiking) {
      positioningVisualizer.renderUnfilteredLocationSignals(location);
    }

    if (isHiking && locationFilter!.checkIfLocationCanBeUsed(location)) {
      gpxTrackWriter.onLocationUpdated(location);
      MapPolyline mapPolyline = _updateTravelledPath();
      var distanceTravelled = getLengthOfGeoPolylineInMeters(mapPolyline.geometry);
      setMessage("Hike Distance: " + distanceTravelled.toString() + " m");
    }
  }

  void clearMap() {
    if (myPathMapPolyline != null) {
      mapView.mapScene.removeMapPolyline(myPathMapPolyline!);
      myPathMapPolyline = null;
    }
    positioningVisualizer.clearMap();
  }

  // Load the selected diary entry and show the polyline related to that hike.
  void loadDiaryEntry(int index) {
    if (isHiking) {
      setMessage("Stop hiking first.");
      return;
    }

    isGPXTrackLoaded = true;

    // Load the hiking trip.
    GPXTrack? gpxTrack = gpxManager.getGPXTrack(index);
    if (gpxTrack == null) {
      return;
    }

    List<GeoCoordinates> diaryGeoCoordinatesList = gpxManager.getGeoCoordinatesList(gpxTrack);
    GeoPolyline diaryGeoPolyline;
    int distanceTravelled = 0;

    try {
      diaryGeoPolyline = new GeoPolyline(diaryGeoCoordinatesList);
      distanceTravelled = getLengthOfGeoPolylineInMeters(diaryGeoPolyline);

      _addMapPolyline(diaryGeoPolyline);
      _animateCameraTo(diaryGeoCoordinatesList);
    } on InstantiationException catch (e) {
      print("Error: " + e.error.name);
    }

    setMessage(
        "Diary Entry from: " + gpxTrack.description + "\n" + "Hike Distance: " + distanceTravelled.toString() + " m");
  }

  void deleteDiaryEntry(int index) {
    Future<bool> isSuccess = gpxManager.deleteGPXTrack(index);
    isSuccess.then((value) => setMessage("Deleted entry: " + value.toString()));
  }

  void saveDiaryEntry() {
    // Permanently store the trip on the device.
    Future<bool> result = gpxManager.saveGPXTrack(gpxTrackWriter.track);

    result.then((value) => setMessage("Saved Hike: " + value.toString() + "."));
  }

  void onStartHikingButtonClicked() {
    clearMap();
    isHiking = true;
    moveMapToCurrentLocation = true;
    isGPXTrackLoaded = false;
    setMessage("Start Hike.");
    gpxTrackWriter = new GPXTrackWriter();
  }

  void onStopHikingButtonClicked() {
    clearMap();
    if (isHiking && !isGPXTrackLoaded) {
      saveDiaryEntry();
    } else {
      setMessage("Stopped.");
    }
    isHiking = false;
    moveMapToCurrentLocation = false;
    mapView.camera.cancelAnimations();
  }

  void enableOutdoorRasterLayer() {
    if (outdoorRasterLayer != null) {
      outdoorRasterLayer!.enable();
    }
  }

  void disableOutdoorRasterLayer() {
    if (outdoorRasterLayer != null) {
      outdoorRasterLayer!.disable();
    }
  }

  int getLengthOfGeoPolylineInMeters(GeoPolyline geoPolyline) {
    int length = 0;

    for (int i = 1; i < geoPolyline.vertices.length; i++) {
      length += geoPolyline.vertices.elementAt(i).distanceTo(geoPolyline.vertices.elementAt(i - 1)).toInt();
    }
    return length;
  }

  List<String> getMenuEntryKeys() {
    List<String> entryKeys = [];
    for (GPXTrack track in gpxManager.gpxDocument.tracks) {
      entryKeys.add(track.name);
    }
    return entryKeys;
  }

  List<String> getMenuEntryDescriptions() {
    List<String> entryDescriptions = [];

    for (GPXTrack track in gpxManager.gpxDocument.tracks) {
      entryDescriptions.add("Hike done on: " + track.description);
    }
    return entryDescriptions;
  }

  void setMessage(String message) {
    messageNotifier.updateMessage(message);
  }

  void _addMapPolyline(GeoPolyline geoPolyline) {
    clearMap();
    double widthInPixels = 20.0;
    Color polylineColor = const Color.fromARGB(0, 56, 54, 63);
    MapPolyline myPathMapPolyline;
    try {
      myPathMapPolyline = MapPolyline.withRepresentation(
          geoPolyline,
          MapPolylineSolidRepresentation(
              MapMeasureDependentRenderSize.withSingleSize(RenderSizeUnit.pixels, widthInPixels),
              polylineColor,
              LineCap.round));
      mapView.mapScene.addMapPolyline(myPathMapPolyline!);
    } on MapPolylineRepresentationInstantiationException catch (e) {
      print("MapPolylineRepresentation Exception:" + e.error.name);
      return;
    } on MapMeasureDependentRenderSizeInstantiationException catch (e) {
      print("MapMeasureDependentRenderSize Exception:" + e.error.name);
      return;
    }
  }

  MapPolyline _updateTravelledPath() {
    List<GeoCoordinates> geoCoordinatesList = gpxManager.getGeoCoordinatesList(gpxTrackWriter.track);
    if (geoCoordinatesList.length < 2) {
      return MapPolyline.withRepresentation(
          GeoPolyline([]),
          MapPolylineSolidRepresentation(
              MapMeasureDependentRenderSize.withSingleSize(RenderSizeUnit.pixels, 0),
              Colors.transparent,
              LineCap.round));
    }
    GeoPolyline geoPolyline;
    try {
      geoPolyline = new GeoPolyline(geoCoordinatesList);
      if (myPathMapPolyline == null) {
        _addMapPolyline(geoPolyline);
        return myPathMapPolyline!;
      }
      myPathMapPolyline!.geometry = geoPolyline;
    } on InstantiationErrorCode catch (e) {
      print("Error: " + e.name);
    }

    return myPathMapPolyline!;
  }

  void _animateCameraTo(List<GeoCoordinates> geoCoordinateList) {
    // We want to show the polyline fitting in the map view with an additional padding of 50 pixels.
    Point2D origin = new Point2D(50.0, 50.0);
    Size2D sizeInPixels = new Size2D(mapView.viewportSize.width - 100, mapView.viewportSize.height - 100);
    Rectangle2D mapViewport = new Rectangle2D(origin, sizeInPixels);

    // Untilt and unrotate the map.
    double bearing = 0;
    double tilt = 0;
    GeoOrientationUpdate geoOrientationUpdate = new GeoOrientationUpdate(bearing, tilt);

    // For very short polylines we want to have at least a distance of 100 meters.
    MapMeasure minDistanceInMeters = new MapMeasure(MapMeasureKind.distance, 100);

    MapCameraUpdate mapCameraUpdate =
        MapCameraUpdateFactory.lookAtPoints(geoCoordinateList, mapViewport, geoOrientationUpdate, minDistanceInMeters);

    // Create animation.
    Duration durationInSeconds = Duration(seconds: 3);
    MapCameraAnimation mapCameraAnimation =
        MapCameraAnimationFactory.createAnimationFromUpdateWithEasing(mapCameraUpdate, durationInSeconds, Easing(EasingFunction.inCubic));

    mapView.camera.startAnimation(mapCameraAnimation);
  }

  void _animateCameraToCurrentLocation(Location currentLocation) {
    GeoCoordinatesUpdate geoCoordinatesUpdate = GeoCoordinatesUpdate.fromGeoCoordinates(currentLocation.coordinates);
    Duration durationInSeconds = Duration(seconds: 3);
    MapMeasure distanceInMeters = new MapMeasure(MapMeasureKind.distance, 500);
    MapCameraAnimation animation =
        MapCameraAnimationFactory.flyToWithZoom(geoCoordinatesUpdate, distanceInMeters, 1, durationInSeconds);
    mapView.camera.startAnimation(animation);
  }

  void onDestroyOutdoorRasterLayer() {
    if (outdoorRasterLayer != null) {
      outdoorRasterLayer!.onDestroy();
    }
  }
}
