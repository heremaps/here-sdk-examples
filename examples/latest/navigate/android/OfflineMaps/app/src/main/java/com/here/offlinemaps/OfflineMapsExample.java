/*
 * Copyright (C) 2019-2021 HERE Europe B.V.
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

import android.support.annotation.NonNull;
import android.support.annotation.Nullable;
import android.support.design.widget.Snackbar;
import android.util.Log;

import com.here.sdk.core.GeoBox;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.LanguageCode;
import com.here.sdk.core.engine.SDKNativeEngine;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.maploader.DownloadRegionsStatusListener;
import com.here.sdk.maploader.DownloadableRegionsCallback;
import com.here.sdk.maploader.MapDownloader;
import com.here.sdk.maploader.MapDownloaderTask;
import com.here.sdk.maploader.MapLoaderError;
import com.here.sdk.maploader.Region;
import com.here.sdk.maploader.RegionId;
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

        mapDownloader = MapDownloader.fromEngine(sdkNativeEngine);

        try {
            // Adding offline search engine to show that we can search on downloaded regions.
            offlineSearchEngine = new OfflineSearchEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of OfflineSearchEngine failed: " + e.error.name());
        }

        // Note that the default storage path can be adapted when creating a new SDKNativeEngine.
        String storagePath = SDKNativeEngine.getSharedInstance().getOptions().cachePath;
        Log.d("",  "StoragePath: " + storagePath);

        String info = "This example allows to download the region Switzerland.";
        snackbar = Snackbar.make(mapView, info, Snackbar.LENGTH_INDEFINITE);
        snackbar.show();
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
                });

        mapDownloaderTasks.add(mapDownloaderTask);
    }

    // Finds a region in the downloaded region list.
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
        int maxItems = 30;
        SearchOptions searchOptions = new SearchOptions(LanguageCode.EN_US, maxItems);

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
}
