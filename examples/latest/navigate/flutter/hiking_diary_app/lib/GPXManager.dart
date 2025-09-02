/*
 * Copyright (C) 2023-2025 HERE Europe B.V.
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

import 'package:flutter/services.dart'; // For platform channels.
import 'package:here_sdk/core.dart';
import 'package:here_sdk/navigation.dart';
import 'package:hiking_diary_app/positioning/HEREPositioningSimulator.dart';

// A class to manage a GPXDocument containing multiple GPX tracks.
class GPXManager {
  // Define the method channel to interact with native code to get the path to writeable storage.
  // For this example, we use the documents directory on iOS and the app's internal storage on Android.
  // See also ios/Runner/AppDelegate.swift and android/app/src/main/java/.../MainActivity.java
  // Alternatively, use a plugin such as path_provider.
  static const methodChannel = MethodChannel('com.example.filepath');

  GPXDocument _gpxDocument = GPXDocument.withTracks([]);
  String _gpxFilePath = "";
  // Needed only when you want to play back to loaded GPX trace.
  HerePositioningSimulator locationSimulator = HerePositioningSimulator();

  // Creates the manager and loads a stored GPXDocument, if any.
  // gpxDocumentFileName example: "myGPXFile.gpx"
  GPXManager(String gpxDocumentFileName) {
    _initialize(gpxDocumentFileName);
  }

  Future<void> _initialize(String gpxDocumentFileName) async {
    await _specifyFullFilePathPerPlatform(gpxDocumentFileName);
    GPXDocument? loadedGPXDocument = await loadGPXDocument();
    if (loadedGPXDocument != null) {
      _gpxDocument = loadedGPXDocument;
    }
  }

  // Specify the full path (including filename) from the platform (iOS or Android) via method channel.
  Future<void> _specifyFullFilePathPerPlatform(String fileName) async {
    _gpxFilePath = fileName;
    try {
      final String? fullPath = await methodChannel.invokeMethod('getFilePath', {'fileName': fileName});
      if (fullPath != null) {
        _gpxFilePath = fullPath;
      } else {
        print('Failed to get file path.');
      }
    } on PlatformException catch (e) {
      print("Failed to get file path: '${e.message}'.");
    }
  }

  Future<GPXDocument?> loadGPXDocument() async {
    try {
      GPXDocument gpxDocument = GPXDocument(_gpxFilePath, GPXOptions());
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
    List<GPXTrack> gpxTracks = _gpxDocument.tracks;
    gpxTracks.removeAt(index);

    // Replace the existing document with the updated tracks list.
    _gpxDocument = GPXDocument.withTracks(gpxTracks);

    return _gpxDocument.save(_gpxFilePath);
  }

  List<GeoCoordinates> getGeoCoordinatesList(GPXTrack track) {
    List<Location> locations = track.getLocations();
    List<GeoCoordinates> geoCoordinatesList = [];
    for (Location location in locations) {
      geoCoordinatesList.add(location.coordinates);
    }
    return geoCoordinatesList;
  }

  List<GPXTrack> getGPXTracks() {
    return _gpxDocument.tracks;
  }

  GPXTrack? getGPXTrack(int index) {
    if (_gpxDocument.tracks.isEmpty) {
      return null;
    }

    if (index < 0 || index > _gpxDocument.tracks.length - 1) {
      return null;
    }

    return _gpxDocument.tracks[index];
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

    _gpxDocument.addTrack(gpxTrack);

    return _gpxDocument.save(_gpxFilePath);
  }

  void startGPXTrackPlayback(LocationListener locationListener, GPXTrack gpxTrack) {
    locationSimulator.startLocating(locationListener, gpxTrack);
  }

  void stopGPXTrackPlayback() {
    locationSimulator.stopLocating();
  }
}
