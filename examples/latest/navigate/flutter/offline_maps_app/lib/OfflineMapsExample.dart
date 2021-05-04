/*
 * Copyright (C) 2019-2021 HERE Europe B.V.
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

import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.engine.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/maploader.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/search.dart';

// A callback to notify the hosting widget.
typedef ShowDialogFunction = void Function(String title, String message);

class OfflineMapsExample {
  HereMapController _hereMapController;
  MapDownloader _mapDownloader;
  OfflineSearchEngine _offlineSearchEngine;
  List<Region> _downloadableRegions = [];
  List<MapDownloaderTask> _mapDownloaderTasks = [];
  ShowDialogFunction _showDialog;

  OfflineMapsExample(Function showDialogCallback, HereMapController hereMapController) {
    _showDialog = showDialogCallback;
    _hereMapController = hereMapController;

    double distanceToEarthInMeters = 7000;
    _hereMapController.camera.lookAtPointWithDistance(GeoCoordinates(52.530932, 13.384915), distanceToEarthInMeters);

    SDKNativeEngine sdkNativeEngine = SDKNativeEngine.sharedInstance;
    if (sdkNativeEngine == null) {
      throw ("SDKNativeEngine not initialized.");
    }

    _mapDownloader = MapDownloader.fromSdkEngine(sdkNativeEngine);

    try {
      // Allows to search on already downloaded or cached map data (added for testing a downloaded region).
      _offlineSearchEngine = OfflineSearchEngine();
    } on InstantiationException {
      throw ("Initialization of OfflineSearchEngine failed.");
    }

    // Note that the default storage path can be adapted when creating a new SDKNativeEngine.
    String storagePath = sdkNativeEngine.options.cachePath;
    _showDialog("This example allows to download the region Switzerland.", "Storage path: $storagePath");
  }

  Future<void> onDownloadListClicked() async {
    print("Downloading the list of available regions.");

    _mapDownloader.getDownloadableRegionsWithLanguageCode(LanguageCode.deDe,
        (MapLoaderError mapLoaderError, List<Region> list) {
      if (mapLoaderError != null) {
        _showDialog("Error", "Downloadable regions error: $mapLoaderError");
        return;
      }

      // If error is null, it is guaranteed that the list will not be null.
      _downloadableRegions = list;

      for (Region region in _downloadableRegions) {
        print("RegionsCallback: " + region.name);
        List<Region> childRegions = region.childRegions;
        if (childRegions == null) {
          continue;
        }

        // Note that this code ignores to list the children of the children (and so on).
        for (Region childRegion in childRegions) {
          var sizeOnDiskInMB = childRegion.sizeOnDiskInBytes / (1024 * 1024);
          String logMessage = "Child region: " +
              childRegion.name +
              ", ID: " +
              childRegion.regionId.id.toString() +
              ", Size: " +
              sizeOnDiskInMB.toString() +
              " MB";
          print("RegionsCallback: " + logMessage);
        }
      }

      var listLenght = _downloadableRegions.length;
      _showDialog("Contintents found: $listLenght", "Each continent contains various countries. See log for details.");
    });
  }

  Future<void> onDownloadMapClicked() async {
    _showDialog("Downloading one region", "See log for progress.");

    // Find region for Switzerland using the German name as identifier.
    // Note that we requested the list of regions in German above.
    String swizNameInGerman = "Schweiz";
    Region region = _findRegion(swizNameInGerman);

    if (region == null) {
      _showDialog("Error", "Error: The Swiz region was not found. Click 'Get Regions' first.");
      return;
    }

    // For this example we download only one country.
    List<RegionId> regionIDs = [region.regionId];

    MapDownloaderTask mapDownloaderTask = _mapDownloader.downloadRegions(
        regionIDs,
        new DownloadRegionsStatusListener.fromLambdas(
            lambda_onDownloadRegionsComplete: (MapLoaderError mapLoaderError, List<RegionId> list) {
          // Handle events from onDownloadRegionsComplete().
          if (mapLoaderError != null) {
            _showDialog("Error", "Download regions completion error: $mapLoaderError");
            return;
          }

          // If error is null, it is guaranteed that the list will not be null.
          // For this example we downloaded only one hardcoded region.
          String message = "Download Regions Status: Completed 100% for Switzerland! ID: " + list.first.id.toString();
          print(message);
        }, lambda_onProgress: (RegionId regionId, int percentage) {
          // Handle events from onProgress().
          String message =
              "Download of Switzerland. ID: " + regionId.id.toString() + ". Progress: " + percentage.toString() + "%.";
          print(message);
        }, lambda_onPause: (MapLoaderError mapLoaderError) {
          if (mapLoaderError == null) {
            _showDialog("Info", "The download was paused by the user calling mapDownloaderTask.pause().");
          } else {
            _showDialog("Error", "Download regions onPause error. The task tried to often to retry the download: $mapLoaderError");
          }
        }, lambda_onResume: () {
          _showDialog("Info", "A previously paused download has been resumed.");
        }));

    _mapDownloaderTasks.add(mapDownloaderTask);
  }

  // Finds a region in the downloaded region list.
  // Note that we ignore children of children (and so on): For example, a country may contain downloadable sub regions.
  // For this example, we just download the country including possible sub regions.
  Region _findRegion(String localizedRegionName) {
    Region downloadableRegion = null;
    for (Region region in _downloadableRegions) {
      if (region.name == localizedRegionName) {
        downloadableRegion = region;
        break;
      }

      List<Region> childRegions = region.childRegions;
      if (childRegions == null) {
        continue;
      }

      for (Region childRegion in childRegions) {
        if (childRegion.name == localizedRegionName) {
          downloadableRegion = childRegion;
          break;
        }
      }
    }

    return downloadableRegion;
  }

  onCancelMapDownloadClicked() {
    for (MapDownloaderTask mapDownloaderTask in _mapDownloaderTasks) {
      mapDownloaderTask.cancel();
    }
    int taskLength = _mapDownloaderTasks.length;
    _showDialog("Note", "Cancelled $taskLength download tasks in list.");
    _mapDownloaderTasks.clear();
  }

  // A test call that shows that, for example, search is possible on downloaded regions.
  // For this make sure you have successfully downloaded a region, device is offline and
  // the viewport shows a part of the region. Note: We need the OfflineSearchEngine, as
  // the SearchEngine will only search online using HERE backend services.
  // Keep in mind that the OfflineSearchEngine can also search on cached map data.
  Future<void> onSearchPlaceClicked() async {
    String queryString = "restaurants";
    GeoBox viewportGeoBox = _getMapViewGeoBox();
    int maxItems = 30;
    SearchOptions searchOptions = SearchOptions(LanguageCode.enUs, maxItems);
    TextQuery query = TextQuery.withBoxArea(queryString, viewportGeoBox);

    _offlineSearchEngine.searchByText(query, searchOptions, (SearchError searchError, List<Place> list) async {
      if (searchError != null) {
        _showDialog("Search", "Error: " + searchError.toString());
        return;
      }

      // If error is null, list is guaranteed to be not empty.
      int listLength = list.length;
      _showDialog("Test search for $queryString", "Results: $listLength. See logs for details.");

      // Log search results.
      for (Place place in list) {
        String title = place.title;
        String address = place.address.addressText;
        print("Search result: $title, $address");
      }
    });
  }

  GeoBox _getMapViewGeoBox() {
    GeoBox geoBox = _hereMapController.camera.boundingBox;
    if (geoBox == null) {
      throw ("GeoBox creation failed, corners are null.");
    }
    return geoBox;
  }
}
