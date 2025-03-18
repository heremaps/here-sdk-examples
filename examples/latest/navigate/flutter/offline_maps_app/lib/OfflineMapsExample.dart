/*
 * Copyright (C) 2019-2025 HERE Europe B.V.
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

import 'dart:ffi';

import 'package:flutter/cupertino.dart';
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
  late MapDownloader _mapDownloader;
  late MapUpdater _mapUpdater;
  late OfflineSearchEngine _offlineSearchEngine;
  List<Region> _downloadableRegions = [];
  List<MapDownloaderTask> _mapDownloaderTasks = [];
  ShowDialogFunction _showDialog;
  bool _offlineSearchLayerEnabled = true;

  OfflineMapsExample(ShowDialogFunction showDialogCallback,
      HereMapController hereMapController)
      : _showDialog = showDialogCallback,
        _hereMapController = hereMapController {
    double distanceToEarthInMeters = 7000;
    MapMeasure mapMeasureZoom =
        MapMeasure(MapMeasureKind.distanceInMeters, distanceToEarthInMeters);
    _hereMapController.camera.lookAtPointWithMeasure(
        GeoCoordinates(52.530932, 13.384915), mapMeasureZoom);

    try {
      // Allows to search on already downloaded or cached map data (added for testing a downloaded region).
      // Note that the engine cannot be used while a map update is in progress and an error will be indicated.
      _offlineSearchEngine = OfflineSearchEngine();
    } on InstantiationException {
      throw ("Initialization of OfflineSearchEngine failed.");
    }

    SDKNativeEngine? sdkNativeEngine = SDKNativeEngine.sharedInstance;
    if (sdkNativeEngine == null) {
      throw ("SDKNativeEngine not initialized.");
    }

    MapDownloader.fromSdkEngineAsync(sdkNativeEngine, (mapDownloader) {
      _mapDownloader = mapDownloader;

      // Checks the status of already downloaded map data and eventually repairs it.
      // Important: For production-ready apps, it is recommended to not do such operations silently in
      // the background and instead inform the user.
      _checkInstallationStatus();
    });

    MapUpdater.fromSdkEngineAsync(sdkNativeEngine, (mapUpdater) {
      _mapUpdater = mapUpdater;

      _performUpdateChecks();
    });

    // Note that the default storage path can be adapted when creating a new SDKNativeEngine.
    _showDialog("Note", "This example allows to download the region Switzerland.");

    // This is the default path for caching map data that is not available as installed region.
    String storagePath = sdkNativeEngine.options.cachePath;
    print("Cache storage path: $storagePath");

    // This is the default path for storing map data permanently.
    // The application must have read/write access to this path if updating it.
    String persistentMapStoragePath = sdkNativeEngine.options.persistentMapStoragePath;
    print("Persistent map storage path: $storagePath");
  }

  void _performUpdateChecks() {
    _logCurrentSDKVersion();
    _logCurrentMapVersion();

    // Checks if map updates are available for any of the already downloaded maps.
    // If a new map download is started via MapDownloader during an update process,
    // an NotReady error is indicated.
    // Note that this example only shows how to download one region.
    // Important: For production-ready apps, it is recommended to ask users whether
    // it's okay for them to update now and to give an indication when the process has completed.
    // - Since all regions are updated in one rush, a large amount of data may be downloaded.
    // - By default, the update process should not be done while an app runs in background as then the
    // download can be interrupted by the OS.
    _checkForMapUpdates();
  }

  Future<void> onDownloadListClicked() async {
    if (_mapDownloader == null) {
      _showDialog("Note", "MapDownloader instance not ready. Try again.");
      return;
    }

    print("Downloading the list of available regions.");

    _mapDownloader.getDownloadableRegionsWithLanguageCode(LanguageCode.deDe,
        (MapLoaderError? mapLoaderError, List<Region>? list) {
      if (mapLoaderError != null) {
        _showDialog("Error", "Downloadable regions error: $mapLoaderError");
        return;
      }

      // If error is null, it is guaranteed that the list will not be null.
      _downloadableRegions = list!;

      for (Region region in _downloadableRegions) {
        print("RegionsCallback: " + region.name);
        List<Region>? childRegions = region.childRegions;
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
      _showDialog("Contintents found: $listLenght",
          "Each continent contains various countries. See log for details.");
    });
  }

  Future<void> onDownloadMapClicked() async {
    if (_mapDownloader == null) {
      _showDialog("Note", "MapDownloader instance not ready. Try again.");
      return;
    }

    _showDialog("Downloading one region", "See log for progress.");

    // Find region for Switzerland using the German name as identifier.
    // Note that we requested the list of regions in German above.
    String swizNameInGerman = "Schweiz";
    Region? region = _findRegion(swizNameInGerman);

    if (region == null) {
      _showDialog("Error",
          "Error: The Swiz region was not found. Click 'Get Regions' first.");
      return;
    }

    // For this example we download only one country.
    List<RegionId> regionIDs = [region.regionId];

    MapDownloaderTask mapDownloaderTask = _mapDownloader.downloadRegions(
        regionIDs,
        DownloadRegionsStatusListener(
            (MapLoaderError? mapLoaderError, List<RegionId>? list) {
          // Handle events from onDownloadRegionsComplete().
          if (mapLoaderError != null) {
            _showDialog(
                "Error", "Download regions completion error: $mapLoaderError");
            return;
          }

          // If error is null, it is guaranteed that the list will not be null.
          // For this example we downloaded only one hardcoded region.
          String message =
              "Download Regions Status: Completed 100% for Switzerland! ID: " +
                  list!.first.id.toString();
          print(message);
        }, (RegionId regionId, int percentage) {
          // Handle events from onProgress().
          String message = "Download of Switzerland. ID: " +
              regionId.id.toString() +
              ". Progress: " +
              percentage.toString() +
              "%.";
          print(message);
        }, (MapLoaderError? mapLoaderError) {
          // Handle events from onPause().
          if (mapLoaderError == null) {
            _showDialog("Info",
                "The download was paused by the user calling mapDownloaderTask.pause().");
          } else {
            _showDialog("Error",
                "Download regions onPause error. The task tried to often to retry the download: $mapLoaderError");
          }
        }, () {
          // Hnadle events from onResume().
          _showDialog("Info", "A previously paused download has been resumed.");
        }));

    _mapDownloaderTasks.add(mapDownloaderTask);
  }

  // Finds a region in the downloaded region list.
  // Note that we ignore children of children (and so on): For example, a country may contain downloadable sub regions.
  // For this example, we just download the country including possible sub regions.
  Region? _findRegion(String localizedRegionName) {
    Region? downloadableRegion;
    for (Region region in _downloadableRegions) {
      if (region.name == localizedRegionName) {
        downloadableRegion = region;
        break;
      }

      List<Region>? childRegions = region.childRegions;
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

  // Download the rectangular area that is currently visible in the viewport.
  // It is possible to call this method in parallel to download multiple areas in parallel.
  onDownloadAreaClicked() {
    _showDialog("Note",
        "Downloading the area that is currently visible in the viewport.");

    GeoBox geoBox = _getMapViewGeoBox();
    GeoPolygon polygonArea = GeoPolygon.withGeoBox(geoBox);

    MapDownloaderTask mapDownloaderTask = _mapDownloader.downloadArea(
        polygonArea,
        DownloadRegionsStatusListener(
                (MapLoaderError? mapLoaderError, List<RegionId>? list) {
              // Handle events from onDownloadRegionsComplete().
              if (mapLoaderError != null) {
                _showDialog(
                    "Error", "Download area completion error: $mapLoaderError");
                return;
              }

              // If error is null, it is guaranteed that the regions will not be null.
              // When downloading an area, only a single unique ID will be provided.
              // Note: It is recommended to store this ID with a human readable name,
              // as this will make it easier to delete the downloaded area in the future by calling
              // mapDownloader.deleteRegions(...). The ID itself is accessible from InstalledRegions.
              // For simplicity, this is not shown here.
              String message =
                  "Download area status. Completed 100%! ID: " +
                      list!.first.id.toString();
              print(message);
            }, (RegionId regionId, int percentage) {
          // Handle events from onProgress().
          // Note that this ID is uniquely created and can be used to delete the area in the future.
          String message = "Download of area. ID: " +
              regionId.id.toString() +
              ". Progress: " +
              percentage.toString() +
              "%.";
          print(message);
        }, (MapLoaderError? mapLoaderError) {
          // Handle events from onPause().
          if (mapLoaderError == null) {
            _showDialog("Info",
                "The area download was paused by the user calling mapDownloaderTask.pause().");
          } else {
            _showDialog("Error",
                "Download area onPause error. The task tried to often to retry the download: $mapLoaderError");
          }
        }, () {
          // Handle events from onResume().
          _showDialog("Info", "A previously paused area download has been resumed.");
        }));
  }

  GeoBox _getMapViewGeoBox() {
    MapCamera camera = _hereMapController.camera;
    GeoBox? geoBox = camera.boundingBox;
    if (geoBox == null) {
      print(
          "GeoBox creation failed, corners are null. This can happen when the map is tilted. Falling back to a fixed box.");
      GeoCoordinates southWestCorner = GeoCoordinates(
          camera.state.targetCoordinates.latitude - 0.05,
          camera.state.targetCoordinates.longitude - 0.05);
      GeoCoordinates northEastCorner = GeoCoordinates(
          camera.state.targetCoordinates.latitude + 0.05,
          camera.state.targetCoordinates.longitude + 0.05);
      geoBox = GeoBox(southWestCorner, northEastCorner);
    }

    return geoBox;
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
    GeoBox? viewportGeoBox = _hereMapController.camera.boundingBox;
    if (viewportGeoBox == null) {
      _showDialog("GeoBox creation failed",
          "Is the map tilted or zoomed-out? Note that you cannot pick coordinates from the sky or the space when map is zoomed-out.");
      return;
    }
    TextQueryArea queryArea = TextQueryArea.withBox(viewportGeoBox);
    TextQuery query = TextQuery.withArea(queryString, queryArea);

    SearchOptions searchOptions = SearchOptions();
    searchOptions.languageCode = LanguageCode.enUs;
    searchOptions.maxItems = 30;

    _offlineSearchEngine.searchByText(query, searchOptions,
        (SearchError? searchError, List<Place>? list) async {
      if (searchError != null) {
        _showDialog("Search", "Error: " + searchError.toString());
        return;
      }

      // If error is null, list is guaranteed to be not empty.
      int listLength = list!.length;
      _showDialog("Test search for $queryString",
          "Results: $listLength. See logs for details.");

      // Log search results.
      for (Place place in list) {
        String title = place.title;
        String address = place.address.addressText;
        print("Search result: $title, $address");
      }
    });
  }

  onOnlineButtonClicked() {
    SDKNativeEngine.sharedInstance?.isOfflineMode = false;
    _showDialog("Note", "The app is allowed to go online.");
  }

  onOfflineButtonClicked() {
    SDKNativeEngine.sharedInstance?.isOfflineMode = true;
    _showDialog("Note", "The app is radio-silence.");
  }

  onClearCache(){
    SDKCache.fromSdkEngine(SDKNativeEngine.sharedInstance!).clearAppCache((mapLoaderError){
      if (mapLoaderError != null) {
        _showDialog("Error","Cache clear error $mapLoaderError");
      } else {
        _showDialog("Note","Cache clear succeeded.");
      }
    });
  }

  toggleLayerConfiguration(String accessKeyId, String accessKeySecret,
      void Function() rebuildMapView) async {
    // Cached map data persists until the Least Recently Used (LRU) eviction policy is triggered.
    // After modifying the "FeatureConfiguration" calling performFeatureUpdate()
    // will also clear the cache if at least one region has been installed.
    // This app allows the user to install one region for testing purposes.
    // In order to simplify testing when no region has been installed, we
    // explicitly clear the cache.
    // If the cache is not cleared, the HERE SDK will look for cached data, for example,
    // when using the OfflineSearchEngine.
    // Needs to be called before accessing SDKOptions to load necessary libraries.
    _offlineSearchLayerEnabled = !_offlineSearchLayerEnabled;
    var enabledFeatures = [
      LayerConfigurationFeature.detailRendering,
      LayerConfigurationFeature.rendering
    ];
    if (_offlineSearchLayerEnabled) {
      enabledFeatures.add(LayerConfigurationFeature.offlineSearch);
      _showDialog("Note",
          "Enabled minimal layer configuration with offlineSearch layer.");
    } else {
      _showDialog("Note",
          "Enabled minimal layer configuration without offlineSearch layer.");
    }
    // LayerConfiguration can only be updated before HERE SDK initialization.
    var layerConfiguration = LayerConfiguration(enabledFeatures);

    // Set your credentials for the HERE SDK.
    AuthenticationMode authenticationMode = AuthenticationMode.withKeySecret(accessKeyId, accessKeySecret);
    SDKOptions sdkOptions = SDKOptions.withAuthenticationMode(authenticationMode);
    sdkOptions.layerConfiguration = layerConfiguration;

    // Releases resources used by the SDK.
    SdkContext.release();

    // Needs to be called before accessing SDKOptions to load necessary libraries.
    SdkContext.init(IsolateOrigin.main);

    try {
      // Invoking makeSharedInstance will invalidate any existing references to the previous instance of SDKNativeEngine.
      await SDKNativeEngine.makeSharedInstance(sdkOptions);
    } on InstantiationException {
      throw Exception("Failed to initialize the HERE SDK.");
    }

    rebuildMapView();

    // Reinitialize MapDownloader.
    MapDownloader.fromSdkEngineAsync(SDKNativeEngine.sharedInstance!,
        (mapDownloader) {
      _mapDownloader = mapDownloader;
    });

    // Reinitialize MapUpdater in background to not block the UI thread.
    MapUpdater.fromSdkEngineAsync(SDKNativeEngine.sharedInstance!,
        (mapUpdater) {
      _mapUpdater = mapUpdater;
      _mapUpdater.performFeatureUpdate(
          MapUpdateProgressListener((regionId, percentage) {
        // Handle feature update progress.
        print(
            "FeatureUpdate: Downloading and installing a map feature update. Progress for" +
                regionId.id.toString() +
                ":" +
                percentage.toString());
      }, (error) {
        if (error == null) {
          print(
              "Feature update onPause error. The task tried to often to retry the update: " +
                  error.toString());
        } else {
          print(
              "FeatureUpdate: The map feature update was paused by the user.");
        }
      }, (error) {
        if (error == null) {
          print("Feature update completion error: " + error.toString());
        } else {
          print(
              "FeatureUpdate: One or more map update has been successfully installed.");
        }
      }, () {
        print(
            "FeatureUpdate: A previously paused map feature update has been resumed.");
      }));
    });

    // Reinitialize offline search engine.
    try {
      _offlineSearchEngine = OfflineSearchEngine();
    } on InstantiationException {
      throw ("Initialization of OfflineSearchEngine failed.");
    }
  }

  void _checkForMapUpdates() {
    if (_mapUpdater == null) {
      _showDialog("Note", "MapUpdater instance not ready. Try again.");
      return;
    }

    _mapUpdater.retrieveCatalogsUpdateInfo((mapLoaderError, catalogList) {
      if (mapLoaderError != null) {
        print("CatalogUpdateCheck Error: " + mapLoaderError.toString());
        return;
      }

      // When error is null, then the list is guaranteed to be not null.
      if (catalogList!.isEmpty) {
        print("CatalogUpdateCheck: No map updates are available.");
      }

      _logCurrentMapVersion();

      // Usually, only one global catalog is available that contains regions for the whole world.
      // For some regions like Japan only a base map is available, by default.
      // If your company has an agreement with HERE to use a detailed Japan map, then in this case you
      // can install and use a second catalog that references the detailed Japan map data.
      // All map data is part of downloadable regions. A catalog contains references to the
      // available regions. The map data for a region may differ based on the catalog that is used
      // or on the version that is downloaded and installed.
      for (CatalogUpdateInfo catalogUpdateInfo in catalogList) {
        print("CatalogUpdateCheck - Catalog name:" +
            catalogUpdateInfo.installedCatalog.catalogIdentifier.hrn);
        print("CatalogUpdateCheck - Installed map version:" +
            catalogUpdateInfo.installedCatalog.catalogIdentifier.version
                .toString());
        print("CatalogUpdateCheck - Latest available map version:" +
            catalogUpdateInfo.latestVersion.toString());
        _performMapUpdate(catalogUpdateInfo);
      }
    });
  }

  // Downloads and installs map updates for any of the already downloaded regions.
  // Note that this example only shows how to download one region.
  void _performMapUpdate(CatalogUpdateInfo catalogUpdateInfo) {
    if (_mapUpdater == null) {
      _showDialog("Note", "MapUpdater instance not ready. Try again.");
      return;
    }

    // This method conveniently updates all installed regions if an update is available.
    // Optionally, you can use the CatalogUpdateTask to pause / resume or cancel the update.
    CatalogUpdateTask catalogUpdateTask = _mapUpdater.updateCatalog(
        catalogUpdateInfo,
        CatalogUpdateProgressListener((RegionId regionId, int percentage) {
          // Handle events from onProgress().
          print(
              "CatalogUpdate: Downloading and installing a map update. Progress for ${regionId.id}: $percentage%.");
        }, (MapLoaderError? mapLoaderError) {
          // Handle events from onPause().
          if (mapLoaderError == null) {
            print(
                "CatalogUpdate:  The map update was paused by the user calling catalogUpdateTask.pause().");
          } else {
            print(
                "CatalogUpdate: Map update onPause error. The task tried to often to retry the update: " +
                    mapLoaderError.toString());
          }
        }, (MapLoaderError? mapLoaderError) {
          // Handle events from onComplete().
          if (mapLoaderError != null) {
            print("CatalogUpdate: Map update completion error: " +
                mapLoaderError.toString());
            return;
          }

          print(
              "CatalogUpdate: One or more map update has been successfully installed.");
          _logCurrentMapVersion();

          // It is recommend to call now also `getDownloadableRegions()` to update
          // the internal catalog data that is needed to download, update or delete
          // existing `Region` data. It is required to do this at least once
          // before doing a new download, update or delete operation.
        }, () {
          // Handle events from onResume():
          print(
              "CatalogUpdate: A previously paused map update has been resumed.");
        }));
  }

  _checkInstallationStatus() {
    if (_mapDownloader == null) {
      _showDialog("Note", "MapDownloader instance not ready. Try again.");
      return;
    }

    // Note that this value will not change during the lifetime of an app.
    PersistentMapStatus persistentMapStatus =
        _mapDownloader.getInitialPersistentMapStatus();
    if (persistentMapStatus != PersistentMapStatus.ok) {
      // Something went wrong after the app was closed the last time. It seems the offline map data is
      // corrupted. This can eventually happen, when an ongoing map download was interrupted due to a crash.
      print(
          "PersistentMapStatus: The persistent map data seems to be corrupted. Trying to repair.");

      // Let's try to repair.
      _mapDownloader.repairPersistentMap(
          (PersistentMapRepairError? persistentMapRepairError) {
        if (persistentMapRepairError == null) {
          print(
              "RepairPersistentMap: Repair operation completed successfully!");
          return;
        }

        // In this case, check the PersistentMapStatus and the recommended
        // healing option listed in the API Reference. For example, if the status
        // is "pendingUpdate", it cannot be repaired, but instead an update
        // should be executed. It is recommended to inform your users to
        // perform the recommended action.
        print("RepairPersistentMap: Repair operation failed: " +
            persistentMapRepairError.toString());
      });
    }
  }

  _logCurrentSDKVersion() {
    print("HERE SDK version: " + SDKBuildInformation.sdkVersion().versionName);
  }

  _logCurrentMapVersion() {
    if (_mapUpdater == null) {
      _showDialog("Note", "MapUpdater instance not ready. Try again.");
      return;
    }

    try {
      MapVersionHandle mapVersionHandle = _mapUpdater.getCurrentMapVersion();
      print("Installed map version: " +
          mapVersionHandle.stringRepresentation(","));
    } on MapLoaderExceptionException catch (e) {
      MapLoaderError mapLoaderError = e.error;
      print("MapLoaderError" +
          "Fetching current map version failed: " +
          mapLoaderError.toString());
    }
  }
}
