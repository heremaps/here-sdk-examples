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
import 'package:here_sdk/navigation.dart';
import 'package:hiking_diary_app/positioning/HEREPositioningSimulator.dart';

// A class to manage a GPXDocument containing multiple GPX tracks.
class GPXManager {
  GPXDocument gpxDocument = GPXDocument.withTracks([]);
  String gpxDocumentFileName = "";
  late BuildContext context;
  HerePositioningSimulator locationSimulator = HerePositioningSimulator();

  GPXManager(String gpxDocumentFileName, BuildContext context) {
    this.gpxDocumentFileName = gpxDocumentFileName;
    this.context = context;
    _initialize();
  }

  Future<GPXDocument?> loadGPXDocument(String gpxDocumentFileName) async {
    try {
      GPXDocument gpxDocument = GPXDocument(gpxDocumentFileName, GPXOptions());
      return gpxDocument;
    } catch (e) {
      print("It seems no GPXDocument was stored yet: $e");
      return null;
    }
  }

  String getCurrentDate() {
    DateTime dateTime = DateTime.now();
    String formattedDate =
        "${dateTime.year % 100}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')},${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
    return formattedDate;
  }

  String getName() {
    DateTime dateTime = DateTime.now();
    String formattedDate =
        "${dateTime.year % 100}${dateTime.month.toString().padLeft(2, '0')}${dateTime.day.toString().padLeft(2, '0')}${dateTime.hour.toString().padLeft(2, '0')}${dateTime.minute.toString().padLeft(2, '0')}${dateTime.second.toString().padLeft(2, '0')}";
    return formattedDate;
  }

  Future<bool> deleteGPXTrack(int index) async {
    List<GPXTrack> gpxTracks = gpxDocument.tracks;
    gpxTracks.removeAt(index);

    // Replace the existing document with the updated tracks list.
    gpxDocument = GPXDocument.withTracks(gpxTracks);

    return gpxDocument.save(gpxDocumentFileName);
  }

  List<GeoCoordinates> getGeoCoordinatesList(GPXTrack track) {
    List<Location> locations = track.getLocations();
    List<GeoCoordinates> geoCoordinatesList = [];
    for (Location location in locations) {
      geoCoordinatesList.add(location.coordinates);
    }
    return geoCoordinatesList;
  }

  GPXTrack? getGPXTrack(int index) {
    if (gpxDocument.tracks.isEmpty) {
      return null;
    }

    if (index < 0 || index > gpxDocument.tracks.length - 1) {
      return null;
    }

    return gpxDocument.tracks[index];
  }

  Future<bool> saveGPXTrack(GPXTrack gpxTrack) async {
    if (gpxTrack.getLocations().length < 2) {
      return false;
    }

    if (gpxTrack.name.isEmpty) {
      gpxTrack.name = getName();
    }

    if (gpxTrack.description.isEmpty) {
      gpxTrack.description = getCurrentDate();
    }

    gpxDocument.addTrack(gpxTrack);

    return gpxDocument.save(gpxDocumentFileName);
  }

  void startGPXTrackPlayback(LocationListener locationListener, GPXTrack gpxTrack) {
    locationSimulator.startLocating(locationListener, gpxTrack);
  }

  void stopGPXTrackPlayback() {
    locationSimulator.stopLocating();
  }

  Future<void> _initialize() async {
    GPXDocument? loadedGPXDocument = await loadGPXDocument(gpxDocumentFileName);
    if (loadedGPXDocument != null) {
      gpxDocument = loadedGPXDocument;
    }
  }
}
