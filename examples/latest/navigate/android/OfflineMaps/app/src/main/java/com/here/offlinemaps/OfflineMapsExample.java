/*
 * Copyright (C) 2019-2025 HERE Europe B.V.
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

package com.here.offlinemaps;

import android.app.AlertDialog;
import android.content.Context;
import android.os.Bundle;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.google.android.material.snackbar.Snackbar;
import com.here.sdk.core.GeoBox;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.GeoPolygon;
import com.here.sdk.core.LanguageCode;
import com.here.sdk.core.Point2D;
import com.here.sdk.core.engine.AuthenticationMode;
import com.here.sdk.core.engine.LayerConfiguration;
import com.here.sdk.core.engine.SDKBuildInformation;
import com.here.sdk.core.engine.SDKNativeEngine;
import com.here.sdk.core.engine.SDKOptions;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.maploader.CatalogUpdateInfo;
import com.here.sdk.maploader.CatalogUpdateProgressListener;
import com.here.sdk.maploader.CatalogUpdateTask;
import com.here.sdk.maploader.CatalogsUpdateInfoCallback;
import com.here.sdk.maploader.DownloadRegionsStatusListener;
import com.here.sdk.maploader.DownloadableRegionsCallback;
import com.here.sdk.maploader.MapDownloader;
import com.here.sdk.maploader.MapDownloaderConstructionCallback;
import com.here.sdk.maploader.MapDownloaderTask;
import com.here.sdk.maploader.MapLoaderError;
import com.here.sdk.maploader.MapLoaderException;
import com.here.sdk.maploader.MapUpdateProgressListener;
import com.here.sdk.maploader.MapUpdater;
import com.here.sdk.maploader.MapUpdaterConstructionCallback;
import com.here.sdk.maploader.MapVersionHandle;
import com.here.sdk.maploader.PersistentMapRepairError;
import com.here.sdk.maploader.PersistentMapStatus;
import com.here.sdk.maploader.Region;
import com.here.sdk.maploader.RegionId;
import com.here.sdk.maploader.RepairPersistentMapCallback;
import com.here.sdk.maploader.SDKCache;
import com.here.sdk.maploader.SDKCacheCallback;
import com.here.sdk.mapview.MapCamera;
import com.here.sdk.mapview.MapError;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapScene;
import com.here.sdk.mapview.MapScheme;
import com.here.sdk.mapview.MapView;
import com.here.sdk.search.OfflineSearchEngine;
import com.here.sdk.search.OfflineSearchIndex;
import com.here.sdk.search.OfflineSearchIndexListener;
import com.here.sdk.search.Place;
import com.here.sdk.search.SearchCallback;
import com.here.sdk.search.SearchError;
import com.here.sdk.search.SearchOptions;
import com.here.sdk.search.TextQuery;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class OfflineMapsExample {

    private final Context context;
    private final MapView mapView;
    @Nullable
    private MapDownloader mapDownloader;
    @Nullable
    private MapUpdater mapUpdater;
    private OfflineSearchEngine offlineSearchEngine;
    private List<Region> downloadableRegions = new ArrayList<>();
    private final List<MapDownloaderTask> mapDownloaderTasks = new ArrayList<>();
    private final Snackbar snackbar;
    private final String TAG = OfflineMapsExample.class.getSimpleName();
    private boolean offlineSearchLayerEnabled = true;
    private boolean switchOffline = false;
    private OfflineSearchIndex.Options offlineSearchIndexOptions;
    private OfflineSearchIndexListener offlineSearchIndexListener;


    public OfflineMapsExample(MapView mapView, Context context) {
        this.context = context;

        // Configure the map.
        this.mapView = mapView;
        repositionCamera();

        try {
            // Adding offline search engine to show that we can search on downloaded regions.
            // Note that the engine cannot be used while a map update is in progress and an error will be indicated.
            offlineSearchEngine = new OfflineSearchEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of OfflineSearchEngine failed: " + e.error.name());
        }

        SDKNativeEngine sdkNativeEngine = SDKNativeEngine.getSharedInstance();
        if (sdkNativeEngine == null) {
            throw new RuntimeException("SDKNativeEngine not initialized.");
        }

        // Note that the default storage path can be adapted when creating a new SDKNativeEngine.
        String storagePath = sdkNativeEngine.getOptions().cachePath;
        Log.d("", "StoragePath: " + storagePath);

        // In case you want to set a custom path for cache and map data, you can replace the
        // above initializtion of SDKNativeEngine with the code below using SDKOptions:

        /*
            try {
                SDKOptions options = new SDKOptions(
                    "<ACCESS-KEY-ID>",
                    "<ACCESS-KEY-SECRET>",
                    "<custom-cache-path>",
                    <Size-in-bytes>,
                    "<custon-map-path>"
                );
                SDKNativeEngine sdkNativeEngine = new SDKNativeEngine(options);
            } catch (InstantiationErrorException e) {
                e.printStackTrace();
            } catch (Exception ex){
                throw new RuntimeException("SDKNativeEngine not initialized.");
            }
            SDKNativeEngine.setSharedInstance(sdkNativeEngine);

            // By default, <custom-cache-path> where the application stores cache data is located on
            // the internal storage at:
            //          /data/user/0/<APP-PACKAGE-NAME>/
            // where App-Package-Name is as specificed in the manifest file, e.g. "com.here.offlinemaps".
            // This path does not require additional permissions.
            //
            // Similarly, you can use a location on external SD card storage using a path as shown below:
            //          /storage/<SD-CARD-NAME>/Android/data/<APP-PACKAGE-NAME>
            // Here, <SD-CARD-NAME> is the name of the mounted SD card and it is unique for each
            // Android device. It is up to the user to determine this path for the target device.
            // You can use Android's API call to Context.getExternalFilesDir(), but that does not
            // always provide the path to external storage.
         */
        initMapDownloader(sdkNativeEngine);
        initMapUpdater(sdkNativeEngine);
        // Enable indexing to improve the search experience.
        enableOfflineSearchIndexing(sdkNativeEngine);

        String info = "This example allows to download the region Switzerland.";
        snackbar = Snackbar.make(mapView, info, Snackbar.LENGTH_INDEFINITE);
        snackbar.show();
    }

    public void onDownloadListClicked() {
        if (mapDownloader == null) {
            String message = "MapDownloader instance not ready. Try again.";
            snackbar.setText(message).show();
            return;
        }

        // Download a list of Region items that will tell us what map regions are available for later download.
        mapDownloader.getDownloadableRegions(LanguageCode.DE_DE, new DownloadableRegionsCallback() {
            @Override
            public void onCompleted(@Nullable MapLoaderError mapLoaderError, @Nullable List<Region> list) {
                if (mapLoaderError != null) {
                    String message = "Downloadable regions error: " + mapLoaderError;
                    snackbar.setText(message).show();
                    return;
                }

                // If error is null, it is guaranteed that the list will not be null.
                downloadableRegions = list;

                for (Region region : downloadableRegions) {
                    Log.d("RegionsCallback", region.name);
                    List<Region> childRegions = region.childRegions;
                    if (childRegions == null) {
                        continue;
                    }

                    // Note that this code ignores to list the children of the children (and so on).
                    for (Region childRegion : childRegions) {
                        long sizeOnDiskInMB = childRegion.sizeOnDiskInBytes / (1024 * 1024);
                        String logMessage = "Child region: " + childRegion.name +
                                ", ID: " + childRegion.regionId.id +
                                ", Size: " + sizeOnDiskInMB + " MB";
                        Log.d("RegionsCallback", logMessage);
                    }
                }

                String message = "Found " + downloadableRegions.size() +
                        " continents with various countries. See log for details.";
                snackbar.setText(message).show();
            }
        });
    }

    public void onDownloadMapClicked() {
        if (mapDownloader == null) {
            String message = "MapDownloader instance not ready. Try again.";
            snackbar.setText(message).show();
            return;
        }

        // Find region for Switzerland using the German name as identifier.
        // Note that we requested the list of regions in German above.
        String swizNameInGerman = "Schweiz";
        Region region = findRegion(swizNameInGerman);

        if (region == null) {
            String message = "Error: The Swiz region was not found. Click 'Regions' first.";
            snackbar.setText(message).show();
            return;
        }

        // For this example we only download one country.
        List<RegionId> regionIDs = Collections.singletonList(region.regionId);
        MapDownloaderTask mapDownloaderTask = mapDownloader.downloadRegions(regionIDs,
                new DownloadRegionsStatusListener() {
                    @Override
                    public void onDownloadRegionsComplete(@Nullable MapLoaderError mapLoaderError, @Nullable List<RegionId> list) {
                        if (mapLoaderError != null) {
                            String message = "Download regions completion error: " + mapLoaderError;
                            snackbar.setText(message).show();
                            return;
                        }

                        // If error is null, it is guaranteed that the list will not be null.
                        // For this example we downloaded only one hardcoded region.
                        String message = "Completed 100% for Switzerland! ID: " + list.get(0).id;
                        snackbar.setText(message).show();
                    }

                    @Override
                    public void onProgress(@NonNull RegionId regionId, int percentage) {
                        String message = "Download for Switzerland. ID: " + regionId.id +
                                ". Progress: " + percentage + "%.";
                        snackbar.setText(message).show();
                    }

                    @Override
                    public void onPause(@Nullable MapLoaderError mapLoaderError) {
                        if (mapLoaderError == null) {
                            String message = "The download was paused by the user calling mapDownloaderTask.pause().";
                            snackbar.setText(message).show();
                        } else {
                            String message = "Download regions onPause error. The task tried to often to retry the download: " + mapLoaderError;
                            snackbar.setText(message).show();
                        }
                    }

                    @Override
                    public void onResume() {
                        String message = "A previously paused download has been resumed.";
                        snackbar.setText(message).show();
                    }
                });

        mapDownloaderTasks.add(mapDownloaderTask);
    }

    // Finds a region in the downloaded region list.
    // Note that we ignore children of children (and so on).
    private Region findRegion(String localizedRegionName) {
        Region downloadableRegion = null;
        for (Region region : downloadableRegions) {
            if (region.name.equals(localizedRegionName)) {
                downloadableRegion = region;
                break;
            }
            List<Region> childRegions = region.childRegions;
            if (childRegions == null) {
                continue;
            }
            for (Region childRegion : childRegions) {
                if (childRegion.name.equals(localizedRegionName)) {
                    downloadableRegion = childRegion;
                    break;
                }
            }
        }

        return downloadableRegion;
    }

    public void onCancelMapDownloadClicked() {
        for (MapDownloaderTask mapDownloaderTask : mapDownloaderTasks) {
            mapDownloaderTask.cancel();
        }
        String message = "Cancelled " + mapDownloaderTasks.size() + " download tasks in list.";
        snackbar.setText(message).show();
        mapDownloaderTasks.clear();
    }

    public void toggleOfflineMode() {
        switchOffline = !switchOffline;
        if (switchOffline) {
            SDKNativeEngine.getSharedInstance().setOfflineMode(true);
            snackbar.setText("The app is radio-silence.").show();
        } else {
            SDKNativeEngine.getSharedInstance().setOfflineMode(false);
            snackbar.setText("The app is allowed to go online.").show();
        }
    }

    // A test call that shows that, for example, search is possible on downloaded regions.
    // For this make sure you have successfully downloaded a region, device is offline and
    // the viewport shows a part of the region. Note: We need the OfflineSearchEngine, as
    // the SearchEngine will only search online using HERE backend services.
    // Keep in mind that the OfflineSearchEngine can also search on cached map data.
    public void onSearchPlaceClicked() {
        GeoBox bbox = mapView.getCamera().getBoundingBox();
        if (bbox == null) {
            snackbar.setText("Invalid bounding box.").show();
            return;
        }

        TextQuery.Area queryArea = new TextQuery.Area(bbox);
        TextQuery textQuery = new TextQuery("restaurants", queryArea);

        SearchOptions searchOptions = new SearchOptions();
        searchOptions.languageCode = LanguageCode.EN_US;
        searchOptions.maxItems = 30;

        offlineSearchEngine.searchByText(textQuery, searchOptions, new SearchCallback() {
            @Override
            public void onSearchCompleted(@Nullable SearchError searchError, @Nullable List<Place> list) {
                if (searchError != null) {
                    String message = "Search Error: " + searchError;
                    snackbar.setText(message).show();
                    return;
                }

                // If error is null, it is guaranteed that the items will not be null.
                String message = "Test search found " + list.size() + " results. See log for details.";
                snackbar.setText(message).show();

                // Log search results.
                for (Place place : list) {
                    Log.d("Search", place.getTitle() + ", " + place.getAddress().addressText);
                }
            }
        });
    }

    private void checkForMapUpdates() {
        if (mapUpdater == null) {
            String message = "MapUpdater instance not ready. Try again.";
            snackbar.setText(message).show();
            return;
        }

        mapUpdater.retrieveCatalogsUpdateInfo(new CatalogsUpdateInfoCallback() {
            @Override
            public void apply(@Nullable MapLoaderError mapLoaderError, @Nullable List<CatalogUpdateInfo> catalogList) {
                if (mapLoaderError != null) {
                    Log.e("CatalogUpdateCheck", "Error: " + mapLoaderError.name());
                    return;
                }

                // When error is null, then the list is guaranteed to be not null.
                if (catalogList.isEmpty()) {
                    Log.d("CatalogUpdateCheck", "No map updates are available.");
                }

                logCurrentMapVersion();

                // Usually, only one global catalog is available that contains regions for the whole world.
                // For some regions like Japan only a base map is available, by default.
                // If your company has an agreement with HERE to use a detailed Japan map, then in this case you
                // can install and use a second catalog that references the detailed Japan map data.
                // All map data is part of downloadable regions. A catalog contains references to the
                // available regions. The map data for a region may differ based on the catalog that is used
                // or on the version that is downloaded and installed.
                for (CatalogUpdateInfo catalogUpdateInfo : catalogList) {
                    Log.d("CatalogUpdateCheck", "Catalog name:" + catalogUpdateInfo.installedCatalog.catalogIdentifier.hrn);
                    Log.d("CatalogUpdateCheck", "Installed map version:" + catalogUpdateInfo.installedCatalog.catalogIdentifier.version);
                    Log.d("CatalogUpdateCheck", "Latest available map version:" + catalogUpdateInfo.latestVersion);
                    performMapUpdate(catalogUpdateInfo);
                }
            }
        });
    }

    // Downloads and installs map updates for any of the already downloaded regions.
    // Note that this example only shows how to download one region.
    private void performMapUpdate(CatalogUpdateInfo catalogUpdateInfo) {
        if (mapUpdater == null) {
            String message = "MapUpdater instance not ready. Try again.";
            snackbar.setText(message).show();
            return;
        }

        // This method conveniently updates all installed regions for a catalog if an update is available.
        // Optionally, you can use the CatalogUpdateTask to pause / resume or cancel the update.
        CatalogUpdateTask task = mapUpdater.updateCatalog(catalogUpdateInfo, new CatalogUpdateProgressListener() {
            @Override
            public void onProgress(@NonNull RegionId regionId, int percentage) {
                Log.d("CatalogUpdate", "Downloading and installing a map update. Progress for " + regionId.id + ": " + percentage);
            }

            @Override
            public void onPause(@Nullable MapLoaderError mapLoaderError) {
                if (mapLoaderError == null) {
                    String message = "The map update was paused by the user calling catalogUpdateTask.pause().";
                    Log.e("CatalogUpdate", message);
                } else {
                    String message = "Map update onPause error. The task tried to often to retry the update: " + mapLoaderError;
                    Log.d("CatalogUpdate", message);
                }
            }

            @Override
            public void onResume() {
                String message = "A previously paused map update has been resumed.";
                Log.d("CatalogUpdate", message);
            }

            @Override
            public void onComplete(@Nullable MapLoaderError mapLoaderError) {
                if (mapLoaderError != null) {
                    String message = "Map update completion error: " + mapLoaderError;
                    Log.d("CatalogUpdate", message);
                    return;
                }

                String message = "One or more map update has been successfully installed.";
                Log.d("CatalogUpdate", message);
                logCurrentMapVersion();

                // It is recommend to call now also `getDownloadableRegions()` to update
                // the internal catalog data that is needed to download, update or delete
                // existing `Region` data. It is required to do this at least once
                // before doing a new download, update or delete operation.
            }
        });
    }

    // It is recommended to perform feature update after feature configuration changes.
    // This will delete cached map data and subsequently update it. Also, the downloaded regions will be updated to reflect the changes.
    // Note: Calling performFeatureUpdate() will do nothing when there is no region installed.
    private void performFeatureUpdate() {
        Log.d(TAG, "Map feature update called");
        mapUpdater.performFeatureUpdate(new MapUpdateProgressListener() {
            @Override
            public void onProgress(@NonNull RegionId regionId, int i) {
                Log.d(TAG, "Map feature update progress for " + regionId.toString() + " " + i);
            }

            @Override
            public void onPause(@Nullable MapLoaderError mapLoaderError) {
                Log.d(TAG, "Map feature update progress paused: " + mapLoaderError.name());
            }

            @Override
            public void onComplete(@Nullable MapLoaderError mapLoaderError) {
                if (mapLoaderError == null) {
                    Log.d(TAG, "Map feature update progress completed: ");
                } else {
                    Log.d(TAG, "Map feature update progress error: " + mapLoaderError.name());
                }
            }

            @Override
            public void onResume() {
                Log.d(TAG, "Map feature update progress resumed.");
            }
        });
    }


    private void checkInstallationStatus() {
        if (mapDownloader == null) {
            String message = "MapDownloader instance not ready. Try again.";
            snackbar.setText(message).show();
            return;
        }

        // Note that this value will not change during the lifetime of an app.
        PersistentMapStatus persistentMapStatus = mapDownloader.getInitialPersistentMapStatus();
        if (persistentMapStatus != PersistentMapStatus.OK) {
            // Something went wrong after the app was closed the last time. It seems the offline map data is
            // corrupted. This can eventually happen, when an ongoing map download was interrupted due to a crash.
            Log.d("PersistentMapStatus", "The persistent map data seems to be corrupted. Trying to repair.");

            // Let's try to repair.
            mapDownloader.repairPersistentMap(new RepairPersistentMapCallback() {
                @Override
                public void onCompleted(@Nullable PersistentMapRepairError persistentMapRepairError) {
                    if (persistentMapRepairError == null) {
                        Log.d("RepairPersistentMap", "Repair operation completed successfully!");
                        return;
                    }

                    // In this case, check the PersistentMapStatus and the recommended
                    // healing option listed in the API Reference. For example, if the status
                    // is PENDING_UPDATE, it cannot be repaired, but instead an update
                    // should be executed. It is recommended to inform your users to
                    // perform the recommended action.
                    Log.d("RepairPersistentMap", "Repair operation failed: " + persistentMapRepairError.name());
                }
            });
        }
    }

    public void toggleLayerConfiguration(String accessKeyID, String accessKeySecret, Context context, Bundle savedInstanceState) {
        // Cached map data persists until the Least Recently Used (LRU) eviction policy is triggered.
        // After modifying the "FeatureConfiguration" calling performFeatureUpdate()
        // will also clear the cache if at least one region has been installed.
        // This app allows the user to install one region for testing purposes.
        // In order to simplify testing when no region has been installed, we
        // explicitly clear the cache.
        // If the cache is not cleared, the HERE SDK will look for cached data, for example,
        // when using the OfflineSearchEngine.
        try {
            AuthenticationMode authenticationMode = AuthenticationMode.withKeySecret(accessKeyID, accessKeySecret);
            SDKOptions options = new SDKOptions(authenticationMode);
            // Toggle the layer configuration.
            offlineSearchLayerEnabled = !offlineSearchLayerEnabled;
            // LayerConfiguration can only be updated before HERE SDK initialization.
            if (offlineSearchLayerEnabled) {
                options.layerConfiguration = getLayerConfigurationWithOfflineSearch();
                snackbar.setText("Enabled minimal layer configuration with OFFLINE_SEARCH layer.");
            } else {
                options.layerConfiguration = getLayerConfigurationWithoutOfflineSearch();
                snackbar.setText("Enabled minimal layer configuration without OFFLINE_SEARCH layer.");
            }
            // Invoking makeSharedInstance will invalidate any existing references to the previous instance of SDKNativeEngine.
            SDKNativeEngine.makeSharedInstance(context, options);
            // Update the current MapView instance to recreate the rendering surface that was invalidated by the invocation of makeSharedInstance.
            updateMapView(savedInstanceState);
            // Reinitialize the map updater and perform feature update to "normalize" the new layer configuration.
            initMapUpdaterAndPerformFeatureUpdate(SDKNativeEngine.getSharedInstance());
            // Reinitialize the map downloader using the new instance of SDKNativeEngine.
            initMapDownloader(SDKNativeEngine.getSharedInstance());
            offlineSearchEngine = new OfflineSearchEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("ReInitialization of HERE SDK failed: " + e.error.name());
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void updateMapView(Bundle savedInstanceState) {
        // Needs to be called after recreation of SDKNativeEngine, even when savedInstanceState is null.
        // Otherwise, the map view will keep using the previous SDKNativeEngine instance.
        mapView.onCreate(savedInstanceState);
        // Since mapview.onCreate() results in a new rendering surface, the map scene must be reloaded to ensure proper rendering.
        mapView.getMapScene().loadScene(MapScheme.NORMAL_DAY, new MapScene.LoadSceneCallback() {
            @Override
            public void onLoadScene(@Nullable MapError mapError) {
                if (mapError == null) {
                    Log.d(TAG, "onLoadScene Succeeded.");
                    repositionCamera();
                } else {
                    Log.d(TAG, "onLoadScene failed: " + mapError.toString());
                }
            }
        });
    }

    private void initMapUpdater(SDKNativeEngine sdkNativeEngine) {
        MapUpdater.fromEngineAsync(sdkNativeEngine, new MapUpdaterConstructionCallback() {
            @Override
            public void onMapUpdaterConstructe(@NonNull MapUpdater mapUpdater) {
                OfflineMapsExample.this.mapUpdater = mapUpdater;
                performUpdateChecks();
            }
        });
    }

    private void initMapUpdaterAndPerformFeatureUpdate(SDKNativeEngine sdkNativeEngine) {
        MapUpdater.fromEngineAsync(sdkNativeEngine, new MapUpdaterConstructionCallback() {
            @Override
            public void onMapUpdaterConstructe(@NonNull MapUpdater mapUpdater) {
                OfflineMapsExample.this.mapUpdater = mapUpdater;
                // Checks and updates in cases of map feature configuration changes.
                performFeatureUpdate();
            }
        });
    }

    private void performUpdateChecks() {
        logHERESDKVersion();
        logCurrentMapVersion();

        // Checks if map updates are available for any of the already downloaded maps.
        // If a new map download is started via MapDownloader during an update process,
        // a NOT_READY error is indicated.
        // Note that this example only shows how to download one region.
        // Important: For production-ready apps, it is recommended to ask users whether
        // it's okay for them to update now and to give an indication when the process has completed.
        // - Since all regions are updated in one rush, a large amount of data may be downloaded.
        // - By default, the update process should not be done while an app runs in background as then the
        // download can be interrupted by the OS.
        checkForMapUpdates();

    }

    private void initMapDownloader(SDKNativeEngine sdkNativeEngine) {
        MapDownloader.fromEngineAsync(sdkNativeEngine, new MapDownloaderConstructionCallback() {
            @Override
            public void onMapDownloaderConstructedCompleted(@NonNull MapDownloader mapDownloader) {
                OfflineMapsExample.this.mapDownloader = mapDownloader;

                // Checks the status of already downloaded map data and eventually repairs it.
                // Important: For production-ready apps, it is recommended to not do such operations silently in
                // the background and instead inform the user.
                checkInstallationStatus();
            }
        });
    }

    // With this layer configuration we enable only the listed layers.
    // All the other layers including the default layers will be disabled.
    public static LayerConfiguration getLayerConfigurationWithOfflineSearch() {
        ArrayList<LayerConfiguration.Feature> features = new ArrayList<>();
        features.add(LayerConfiguration.Feature.DETAIL_RENDERING);
        features.add(LayerConfiguration.Feature.RENDERING);
        features.add(LayerConfiguration.Feature.OFFLINE_SEARCH);
        LayerConfiguration layerConfiguration = new LayerConfiguration();
        layerConfiguration.enabledFeatures = features;
        return layerConfiguration;
    }

    // Here we disable the OFFLINE_SEARCH layer to show what happens when we search offline:
    // When the layer is enabled then the OfflineSearchEngine can find results in the cached map data or installed regions.
    // When the layer is disabled, the OfflineSearchEngine will yield either no results or very few limited results.
    private LayerConfiguration getLayerConfigurationWithoutOfflineSearch() {
        ArrayList<LayerConfiguration.Feature> features = new ArrayList<>();
        features.add(LayerConfiguration.Feature.DETAIL_RENDERING);
        features.add(LayerConfiguration.Feature.RENDERING);
        LayerConfiguration layerConfiguration = new LayerConfiguration();
        layerConfiguration.enabledFeatures = features;
        return layerConfiguration;
    }

    private void logHERESDKVersion() {
        Log.d("HERE SDK version: ", SDKBuildInformation.sdkVersion().versionName);
    }

    private void logCurrentMapVersion() {
        if (mapUpdater == null) {
            String message = "MapUpdater instance not ready. Try again.";
            snackbar.setText(message).show();
            return;
        }

        try {
            MapVersionHandle mapVersionHandle = mapUpdater.getCurrentMapVersion();
            // Version string my look like "47.47,47.47".
            Log.d("Installed map version: ", mapVersionHandle.stringRepresentation(","));
        } catch (MapLoaderException e) {
            MapLoaderError mapLoaderError = e.error;
            Log.e("MapLoaderError", "Fetching current map version failed: " + mapLoaderError.toString());
        }
    }

    // Download the rectangular area that is currently visible in the viewport.
    // It is possible to call this method in parallel to download multiple areas in parallel.
    public void onDownloadAreaClicked() {
        showDialog("Note", "Downloading the area that is currently visible in the viewport.");
        GeoPolygon polygonArea = new GeoPolygon(getMapViewGeoBox());

        mapDownloader.downloadArea(polygonArea, new DownloadRegionsStatusListener() {
            @Override
            public void onDownloadRegionsComplete(@Nullable MapLoaderError mapLoaderError, @Nullable List<RegionId> list) {
                if (mapLoaderError != null) {
                    String message = "Download area completion error: " + mapLoaderError;
                    snackbar.setText(message).show();
                    return;
                }

                // If error is null, it is guaranteed that the regions will not be null.
                // When downloading an area, only a single unique ID will be provided.
                // Note: It is recommended to store this ID with a human readable name,
                // as this will make it easier to delete the downloaded area in the future by calling
                // mapDownloader.deleteRegions(...). The ID itself is accessible from InstalledRegions.
                // For simplicity, this is not shown here.
                String message = "Completed 100% for area! ID: " + list.get(0).id;
                snackbar.setText(message).show();
                Log.d(TAG, message);
            }

            @Override
            public void onProgress(@NonNull RegionId regionId, int percentage) {
                // Note that this ID is uniquely created and can be to delete the area in the future.
                String message = "Download for area ID: " + regionId.id +
                        ". Progress: " + percentage + "%.";
                snackbar.setText(message).show();
            }

            @Override
            public void onPause(@Nullable MapLoaderError mapLoaderError) {
                if (mapLoaderError == null) {
                    String message = "The download area was paused by the user calling mapDownloaderTask.pause().";
                    snackbar.setText(message).show();
                } else {
                    String message = "Download area onPause error. The task tried to often to retry the download: " + mapLoaderError;
                    snackbar.setText(message).show();
                }
            }

            @Override
            public void onResume() {
                String message = "A previously paused area download has been resumed.";
                snackbar.setText(message).show();
            }
        });
    }

    private GeoBox getMapViewGeoBox() {
        int mapViewWidthInPixels = mapView.getWidth();
        int mapViewHeightInPixels = mapView.getHeight();
        Point2D bottomLeftPoint2D = new Point2D(0, mapViewHeightInPixels);
        Point2D topRightPoint2D = new Point2D(mapViewWidthInPixels, 0);

        GeoCoordinates southWestCorner = mapView.viewToGeoCoordinates(bottomLeftPoint2D);
        GeoCoordinates northEastCorner = mapView.viewToGeoCoordinates(topRightPoint2D);

        if (southWestCorner == null || northEastCorner == null) {
            throw new RuntimeException("GeoBox creation failed, corners are null.");
        }

        // Note: This algorithm assumes an unrotated map view.
        return new GeoBox(southWestCorner, northEastCorner);
    }

    // Cached map data will not be removed until the least recently used (LRU) strategy is applied.
    // Therefore, we can manually clear the cache to remove any outdated entries.
    public void clearCache() {
        SDKCache.fromEngine(SDKNativeEngine.getSharedInstance()).clearCache(new SDKCacheCallback() {
            @Override
            public void onCompleted(@Nullable MapLoaderError mapLoaderError) {
                if (mapLoaderError != null) {
                    snackbar.setText("Cache clear error " + mapLoaderError.name());
                } else {
                    snackbar.setText("Cache clear succeeded.");
                }
            }
        });
    }

    private void repositionCamera(){
        MapCamera camera = mapView.getCamera();
        double distanceInMeters = 1000 * 7;
        MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE, distanceInMeters);
        camera.lookAt(new GeoCoordinates(46.94843, 7.44046), mapMeasureZoom);
    }

    private void showDialog(String title, String message) {
        AlertDialog.Builder builder =
                new AlertDialog.Builder(context);
        builder.setTitle(title);
        builder.setMessage(message);
        builder.show();
    }

    private void enableOfflineSearchIndexing(SDKNativeEngine sdkNativeEngine) {
        offlineSearchIndexOptions = new OfflineSearchIndex.Options();
        offlineSearchIndexOptions.enabled = true;

        offlineSearchIndexListener = new OfflineSearchIndexListener() {
            @Override
            public void onStarted(@NonNull OfflineSearchIndex.Operation operation) {
                Log.d("OfflineSearchIndexListener", "Indexing started. Operation: " + operation);
                snackbar.setText("Indexing started: " + operation).show();
            }

            @Override
            public void onProgress(int percentage) {
                Log.d("OfflineSearchIndexListener", "Indexing progress: " + percentage + "%");
                snackbar.setText("Indexing progress: " + percentage + "%").show();
            }

            @Override
            public void onComplete(@Nullable OfflineSearchIndex.Error error) {
                if (error == null) {
                    Log.d("OfflineSearchIndexListener", "Indexing completed successfully.");
                    snackbar.setText("Indexing completed successfully.").show();
                } else {
                    Log.e("OfflineSearchIndexListener", "Indexing failed: " + error.name());
                    snackbar.setText("Indexing failed: " + error.name()).show();
                }
            }
        };

        offlineSearchEngine.setIndexOptions(sdkNativeEngine, offlineSearchIndexOptions, offlineSearchIndexListener);
    }
}
