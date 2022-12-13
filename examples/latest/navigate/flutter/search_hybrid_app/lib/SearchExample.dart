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

import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/gestures.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/search.dart';

import 'SearchResultMetadata.dart';

// A callback to notify the hosting widget.
typedef ShowDialogFunction = void Function(String title, String message);

class SearchExample {
  HereMapController _hereMapController;
  MapCamera _camera;
  MapImage? _poiMapImage;
  List<MapMarker> _mapMarkerList = [];
  late SearchEngine _onlineSearchEngine;
  late OfflineSearchEngine _offlineSearchEngine;
  bool useOnlineSearchEngine = true;
  ShowDialogFunction _showDialog;

  SearchExample(ShowDialogFunction showDialogCallback, HereMapController hereMapController)
      : _showDialog = showDialogCallback,
        _hereMapController = hereMapController,
        _camera = hereMapController.camera {
    double distanceToEarthInMeters = 5000;
    MapMeasure mapMeasureZoom = MapMeasure(MapMeasureKind.distance, distanceToEarthInMeters);
    _camera.lookAtPointWithMeasure(GeoCoordinates(52.520798, 13.409408), mapMeasureZoom);

    try {
      _onlineSearchEngine = SearchEngine();
    } on InstantiationException {
      throw ("Initialization of SearchEngine failed.");
    }

    try {
      // Allows to search on already downloaded or cached map data.
      _offlineSearchEngine = OfflineSearchEngine();
    } on InstantiationException {
      throw ("Initialization of OfflineSearchEngine failed.");
    }

    _setTapGestureHandler();
    _setLongPressGestureHandler();

    _showDialog("Note", "Long press on the map to get the address for that location with reverse geocoding.");
  }

  Future<void> searchButtonClicked() async {
    // Search for "Pizza" and show the results on the map.
    _searchExample();

    // Search for auto suggestions and log the results to the console.
    _autoSuggestExample();
  }

  Future<void> geocodeAnAddressButtonClicked() async {
    // Search for the location that belongs to an address and show it on the map.
    _geocodeAnAddress();
  }

  void useOnlineSearchEngineButtonClicked() {
    useOnlineSearchEngine = true;

    _showDialog('Switched to SearchEngine', 'Requests will be calculated online.');
  }

  void useOfflineSearchEngineButtonClicked() {
    useOnlineSearchEngine = false;

    // Note that this app does not show how to download offline maps. For this, check the offline_maps_app example.
    _showDialog(
        'Switched to OfflineSearchEngine', 'Requests will be calculated offline on cached or downloaded map data.');
  }

  void _searchExample() {
    String searchTerm = "Pizza";
    print("Searching in viewport for: " + searchTerm);
    _searchInViewport(searchTerm);
  }

  void _geocodeAnAddress() {
    // Set map to expected location.
    GeoCoordinates geoCoordinates = GeoCoordinates(52.53086, 13.38469);
    double distanceToEarthInMeters = 1000 * 5;
    MapMeasure mapMeasureZoom = MapMeasure(MapMeasureKind.distance, distanceToEarthInMeters);
    _camera.lookAtPointWithMeasure(geoCoordinates, mapMeasureZoom);

    String queryString = "Invalidenstraße 116, Berlin";

    print("Finding locations for: $queryString. Tap marker to see the coordinates.");

    _geocodeAddressAtLocation(queryString, geoCoordinates);
  }

  void _setTapGestureHandler() {
    _hereMapController.gestures.tapListener = TapListener((Point2D touchPoint) {
      _pickMapMarker(touchPoint);
    });
  }

  void _setLongPressGestureHandler() {
    _hereMapController.gestures.longPressListener = LongPressListener((GestureState gestureState, Point2D touchPoint) {
      if (gestureState == GestureState.begin) {
        GeoCoordinates? geoCoordinates = _hereMapController.viewToGeoCoordinates(touchPoint);
        if (geoCoordinates == null) {
          return;
        }
        _addPoiMapMarker(geoCoordinates);
        _getAddressForCoordinates(geoCoordinates);
      }
    });
  }

  Future<void> _getAddressForCoordinates(GeoCoordinates geoCoordinates) async {
    SearchOptions reverseGeocodingOptions = SearchOptions();
    reverseGeocodingOptions.languageCode = LanguageCode.enGb;
    reverseGeocodingOptions.maxItems = 1;

    if (useOnlineSearchEngine) {
      _onlineSearchEngine.searchByCoordinates(geoCoordinates, reverseGeocodingOptions,
          (SearchError? searchError, List<Place>? list) async {
        _handleReverseGeocodingResults(searchError, list);
      });
    } else {
      _offlineSearchEngine.searchByCoordinates(geoCoordinates, reverseGeocodingOptions,
          (SearchError? searchError, List<Place>? list) async {
        _handleReverseGeocodingResults(searchError, list);
      });
    }
  }

  // Note that this can be called by the online or offline search engine.
  void _handleReverseGeocodingResults(SearchError? searchError, List<Place>? list) {
    if (searchError != null) {
      _showDialog("Reverse geocoding", "Error: " + searchError.toString());
      return;
    }

    // If error is null, list is guaranteed to be not empty.
    _showDialog("Reverse geocoded address:", list!.first.address.addressText);
  }

  void _pickMapMarker(Point2D touchPoint) {
    double radiusInPixel = 2;
    _hereMapController.pickMapItems(touchPoint, radiusInPixel, (pickMapItemsResult) {
      if (pickMapItemsResult == null) {
        // Pick operation failed.
        return;
      }
      List<MapMarker>? mapMarkerList = pickMapItemsResult.markers;
      if (mapMarkerList.length == 0) {
        print("No map markers found.");
        return;
      }

      MapMarker topmostMapMarker = mapMarkerList.first;
      Metadata? metadata = topmostMapMarker.metadata;
      if (metadata != null) {
        CustomMetadataValue? customMetadataValue = metadata.getCustomValue("key_search_result");
        if (customMetadataValue != null) {
          SearchResultMetadata searchResultMetadata = customMetadataValue as SearchResultMetadata;
          String title = searchResultMetadata.searchResult.title;
          String vicinity = searchResultMetadata.searchResult.address.addressText;
          _showDialog("Picked Search Result", title + ". Vicinity: " + vicinity);
          return;
        }
      }

      double lat = topmostMapMarker.coordinates.latitude;
      double lon = topmostMapMarker.coordinates.longitude;
      _showDialog("Picked Map Marker", "Geographic coordinates: $lat, $lon.");
    });
  }

  Future<void> _searchInViewport(String queryString) async {
    _clearMap();

    GeoBox viewportGeoBox = _getMapViewGeoBox();
    TextQueryArea queryArea = TextQueryArea.withBox(viewportGeoBox);
    TextQuery query = TextQuery.withArea(queryString, queryArea);

    SearchOptions searchOptions = SearchOptions();
    searchOptions.languageCode = LanguageCode.enUs;
    searchOptions.maxItems = 30;

    if (useOnlineSearchEngine) {
      _onlineSearchEngine.searchByText(query, searchOptions, (SearchError? searchError, List<Place>? list) async {
        _handleSearchResults(searchError, list, queryString);
      });
    } else {
      _offlineSearchEngine.searchByText(query, searchOptions, (SearchError? searchError, List<Place>? list) async {
        _handleSearchResults(searchError, list, queryString);
      });
    }
  }

  // Note that this can be called by the online or offline search engine.
  void _handleSearchResults(SearchError? searchError, List<Place>? list, String queryString) {
    if (searchError != null) {
      // Note: When using the OfflineSearchEngine, the HERE SDK searches only on cached map data and
      // search results may not be available for all zoom levels.
      // Please also note that it may take time until the required map data is loaded.
      // Subsequently, the cache is filled when a user pans and zooms the map.
      _showDialog("Search", "Error: " + searchError.toString());
      return;
    }

    // If error is null, list is guaranteed to be not empty.
    int listLength = list!.length;
    _showDialog("Search for $queryString", "Results: $listLength. Tap marker to see details.");

    // Add new marker for each search result on map.
    for (Place searchResult in list) {
      Metadata metadata = Metadata();
      metadata.setCustomValue("key_search_result", SearchResultMetadata(searchResult));
      // Note: getGeoCoordinates() may return null only for Suggestions.
      _addPoiMapMarkerWithMetadata(searchResult.geoCoordinates!, metadata);
    }
  }

  Future<void> _autoSuggestExample() async {
    GeoCoordinates centerGeoCoordinates = _getMapViewCenter();

    SearchOptions searchOptions = SearchOptions();
    searchOptions.languageCode = LanguageCode.enUs;
    searchOptions.maxItems = 5;

    TextQueryArea queryArea = TextQueryArea.withCenter(centerGeoCoordinates);

    if (useOnlineSearchEngine) {
      // Simulate a user typing a search term.
      _onlineSearchEngine.suggest(
          TextQuery.withArea(
              "p", // User typed "p".
              queryArea),
          searchOptions, (SearchError? searchError, List<Suggestion>? list) async {
        _handleSuggestionResults(searchError, list);
      });

      _onlineSearchEngine.suggest(
          TextQuery.withArea(
              "pi", // User typed "pi".
              queryArea),
          searchOptions, (SearchError? searchError, List<Suggestion>? list) async {
        _handleSuggestionResults(searchError, list);
      });

      _onlineSearchEngine.suggest(
          TextQuery.withArea(
              "piz", // User typed "piz".
              queryArea),
          searchOptions, (SearchError? searchError, List<Suggestion>? list) async {
        _handleSuggestionResults(searchError, list);
      });
    } else {
      // Simulate a user typing a search term.
      _offlineSearchEngine.suggest(
          TextQuery.withArea(
              "p", // User typed "p".
              queryArea),
          searchOptions, (SearchError? searchError, List<Suggestion>? list) async {
        _handleSuggestionResults(searchError, list);
      });

      _offlineSearchEngine.suggest(
          TextQuery.withArea(
              "pi", // User typed "pi".
              queryArea),
          searchOptions, (SearchError? searchError, List<Suggestion>? list) async {
        _handleSuggestionResults(searchError, list);
      });

      _offlineSearchEngine.suggest(
          TextQuery.withArea(
              "piz", // User typed "piz".
              queryArea),
          searchOptions, (SearchError? searchError, List<Suggestion>? list) async {
        _handleSuggestionResults(searchError, list);
      });
    }
  }

  void _handleSuggestionResults(SearchError? searchError, List<Suggestion>? list) {
    if (searchError != null) {
      print("Autosuggest Error: " + searchError.toString());
      return;
    }

    // If error is null, list is guaranteed to be not empty.
    int listLength = list!.length;
    print("Autosuggest results: $listLength.");

    for (Suggestion autosuggestResult in list) {
      String addressText = "Not a place.";
      Place? place = autosuggestResult.place;
      if (place != null) {
        addressText = place.address.addressText;
      }

      print("Autosuggest result: " + autosuggestResult.title + " addressText: " + addressText);
    }
  }

  Future<void> _geocodeAddressAtLocation(String queryString, GeoCoordinates geoCoordinates) async {
    _clearMap();

    AddressQuery query = AddressQuery.withAreaCenter(queryString, geoCoordinates);

    SearchOptions geocodingOptions = SearchOptions();
    geocodingOptions.languageCode = LanguageCode.deDe;
    geocodingOptions.maxItems = 30;

    if (useOnlineSearchEngine) {
      _onlineSearchEngine.searchByAddress(query, geocodingOptions, (SearchError? searchError, List<Place>? list) async {
        _handleGeocodingResults(searchError, list, queryString);
      });
    } else {
      _offlineSearchEngine.searchByAddress(query, geocodingOptions,
          (SearchError? searchError, List<Place>? list) async {
        _handleGeocodingResults(searchError, list, queryString);
      });
    }
  }

  // Note that this can be called by the online or offline search engine.
  void _handleGeocodingResults(SearchError? searchError, List<Place>? list, String queryString) {
    if (searchError != null) {
      _showDialog("Geocoding", "Error: " + searchError.toString());
      return;
    }

    String locationDetails = "";

    // If error is null, list is guaranteed to be not empty.
    for (Place geocodingResult in list!) {
      // Note: getGeoCoordinates() may return null only for Suggestions.
      GeoCoordinates geoCoordinates = geocodingResult.geoCoordinates!;
      Address address = geocodingResult.address;
      locationDetails = address.addressText +
          ". GeoCoordinates: " +
          geoCoordinates.latitude.toString() +
          ", " +
          geoCoordinates.longitude.toString();

      print("GeocodingResult: " + locationDetails);
      _addPoiMapMarker(geoCoordinates);
    }

    int itemsCount = list.length;
    _showDialog("Geocoding result for $queryString. Results: $itemsCount", locationDetails);
  }

  Future<MapMarker> _addPoiMapMarker(GeoCoordinates geoCoordinates) async {
    // Reuse existing MapImage for new map markers.
    if (_poiMapImage == null) {
      Uint8List imagePixelData = await _loadFileAsUint8List('poi.png');
      _poiMapImage = MapImage.withPixelDataAndImageFormat(imagePixelData, ImageFormat.png);
    }

    MapMarker mapMarker = MapMarker(geoCoordinates, _poiMapImage!);
    _hereMapController.mapScene.addMapMarker(mapMarker);
    _mapMarkerList.add(mapMarker);

    return mapMarker;
  }

  Future<Uint8List> _loadFileAsUint8List(String fileName) async {
    // The path refers to the assets directory as specified in pubspec.yaml.
    ByteData fileData = await rootBundle.load('assets/' + fileName);
    return Uint8List.view(fileData.buffer);
  }

  Future<void> _addPoiMapMarkerWithMetadata(GeoCoordinates geoCoordinates, Metadata metadata) async {
    MapMarker mapMarker = await _addPoiMapMarker(geoCoordinates);
    mapMarker.metadata = metadata;
  }

  GeoCoordinates _getMapViewCenter() {
    return _camera.state.targetCoordinates;
  }

  GeoBox _getMapViewGeoBox() {
    GeoBox? geoBox = _camera.boundingBox;
    if (geoBox == null) {
      print(
          "GeoBox creation failed, corners are null. This can happen when the map is tilted. Falling back to a fixed box.");
      GeoCoordinates southWestCorner = GeoCoordinates(
          _camera.state.targetCoordinates.latitude - 0.05, _camera.state.targetCoordinates.longitude - 0.05);
      GeoCoordinates northEastCorner = GeoCoordinates(
          _camera.state.targetCoordinates.latitude + 0.05, _camera.state.targetCoordinates.longitude + 0.05);
      geoBox = GeoBox(southWestCorner, northEastCorner);
    }
    return geoBox;
  }

  void _clearMap() {
    _mapMarkerList.forEach((mapMarker) {
      _hereMapController.mapScene.removeMapMarker(mapMarker);
    });
    _mapMarkerList.clear();
  }
}
