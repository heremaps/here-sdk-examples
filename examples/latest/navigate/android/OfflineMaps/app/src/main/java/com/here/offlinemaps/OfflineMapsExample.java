/*
 * Copyright (C) 2019-2022 HERE Europe B.V.
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

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import com.google.android.material.snackbar.Snackbar;
import android.util.Log;

import com.here.sdk.core.GeoBox;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.LanguageCode;
import com.here.sdk.core.engine.SDKNativeEngine;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.maploader.CheckMapUpdateCallback;
import com.here.sdk.maploader.DownloadRegionsStatusListener;
import com.here.sdk.maploader.DownloadableRegionsCallback;
import com.here.sdk.maploader.MapDownloader;
import com.here.sdk.maploader.MapDownloaderTask;
import com.here.sdk.maploader.MapLoaderError;
import com.here.sdk.maploader.MapUpdateAvailability;
import com.here.sdk.maploader.MapUpdateProgressListener;
import com.here.sdk.maploader.MapUpdateTask;
import com.here.sdk.maploader.MapUpdater;
import com.here.sdk.maploader.PersistentMapRepairError;
import com.here.sdk.maploader.PersistentMapStatus;
import com.here.sdk.maploader.Region;
import com.here.sdk.maploader.RegionId;
import com.here.sdk.maploader.RepairPersistentMapCallback;
import com.here.sdk.mapview.MapCamera;
import com.here.sdk.mapview.MapView;
import com.here.sdk.search.OfflineSearchEngine;
import com.here.sdk.search.Place;
import com.here.sdk.search.SearchCallback;
import com.here.sdk.search.SearchError;
import com.here.sdk.search.SearchOptions;
import com.here.sdk.search.TextQuery;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class OfflineMapsExample {

    private final MapView mapView;
    private MapDownloader mapDownloader;
    private MapUpdater mapUpdater;
    private OfflineSearchEngine offlineSearchEngine;
    private List<Region> downloadableRegions = new ArrayList<>();
    private final List<MapDownloaderTask> mapDownloaderTasks = new ArrayList<>();
    private Snackbar snackbar;

    public OfflineMapsExample(MapView mapView) {

        // Configure the map.
        MapCamera camera = mapView.getCamera();
        double distanceInMeters = 1000 * 7;
        camera.lookAt(new GeoCoordinates(52.530932, 13.384915), distanceInMeters);

        this.mapView = mapView;

        SDKNativeEngine sdkNativeEngine = SDKNativeEngine.getSharedInstance();

        if (sdkNativeEngine == null) {
            throw new RuntimeException("SDKNativeEngine not initialized.");
        }

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

        mapDownloader = MapDownloader.fromEngine(sdkNativeEngine);
        mapUpdater = MapUpdater.fromEngine(sdkNativeEngine);

        try {
            // Adding offline search engine to show that we can search on downloaded regions.
            // Note that the engine cannot be used while a map update is in progress and an error will be indicated.
            offlineSearchEngine = new OfflineSearchEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of OfflineSearchEngine failed: " + e.error.name());
        }

        // Note that the default storage path can be adapted when creating a new SDKNativeEngine.
        String storagePath = sdkNativeEngine.getOptions().cachePath;
        Log.d("",  "StoragePath: " + storagePath);

        String info = "This example allows to download the region Switzerland.";
        snackbar = Snackbar.make(mapView, info, Snackbar.LENGTH_INDEFINITE);
        snackbar.show();

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

        // Checks the status of already downloaded map data and eventually repairs it.
        // Important: For production-ready apps, it is recommended to not do such operations silently in
        // the background and instead inform the user.
        checkInstallationStatus();
    }

    public void onDownloadListClicked() {
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
                                ", ID: "+ childRegion.regionId.id +
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
        // Find region for Switzerland using the German name as identifier.
        // Note that we requested the list of regions in German above.
        String swizNameInGerman = "Schweiz";
        Region region = findRegion(swizNameInGerman);

        if (region == null ) {
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

        TextQuery textQuery = new TextQuery("restaurants", bbox);

        SearchOptions searchOptions = new SearchOptions();
        searchOptions.languageCode = LanguageCode.EN_US;
        searchOptions.maxItems = 30;

        offlineSearchEngine.search(textQuery, searchOptions, new SearchCallback() {
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
        mapUpdater.checkMapUpdate(new CheckMapUpdateCallback() {
            @Override
            public void onCompleted(@Nullable MapLoaderError mapLoaderError, @Nullable MapUpdateAvailability mapUpdateAvailability) {
                if (mapLoaderError != null) {
                    Log.e("MapUpdateCheck", "Error: " + mapLoaderError.name());
                    return;
                }

                if (mapUpdateAvailability == MapUpdateAvailability.AVAILABLE) {
                    Log.d("MapUpdateCheck", "One or more map updates are available.");
                    performMapUpdate();
                    return;
                }

                Log.d("MapUpdateCheck", "No map update available. Latest versions are already installed.");
            }
        });
    }

    // Downloads and installs map updates for any of the already downloaded regions.
    // Note that this example only shows how to download one region.
    private void performMapUpdate() {
        // This method conveniently updates all installed regions if an update is available.
        // Optionally, you can use the MapUpdateTask to pause / resume or cancel the update.
        MapUpdateTask mapUpdateTask = mapUpdater.performMapUpdate(new MapUpdateProgressListener() {
            @Override
            public void onProgress(@NonNull RegionId regionId, int percentage) {
                Log.d("MapUpdate", "Downloading and installing a map update. Progress for " + regionId.id + ": " + percentage);
            }

            @Override
            public void onPause(@Nullable MapLoaderError mapLoaderError) {
                if (mapLoaderError == null) {
                    String message = "The map update was paused by the user calling mapUpdateTask.pause().";
                    Log.e("MapUpdate", message);
                } else {
                    String message = "Map update onPause error. The task tried to often to retry the update: " + mapLoaderError;
                    Log.d("MapUpdate", message);
                }
            }

            @Override
            public void onResume() {
                String message = "A previously paused map update has been resumed.";
                Log.d("MapUpdate", message);
            }

            @Override
            public void onComplete(@Nullable MapLoaderError mapLoaderError) {
                if (mapLoaderError != null) {
                    String message = "Map update completion error: " + mapLoaderError;
                    Log.d("MapUpdate", message);
                    return;
                }

                String message = "One or more map update has been successfully installed.";
                Log.d("MapUpdate", message);
            }
        });
    }

    private void checkInstallationStatus() {
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

                    Log.d("RepairPersistentMap", "Repair operation failed: " + persistentMapRepairError.name());
                }
            });
        }
    }
}
