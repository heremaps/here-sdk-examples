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
package com.here.offlinemapskotlin

import android.app.AlertDialog
import android.content.Context
import android.os.Bundle
import android.util.Log
import com.here.sdk.core.GeoBox
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.core.GeoPolygon
import com.here.sdk.core.LanguageCode
import com.here.sdk.core.Point2D
import com.here.sdk.core.engine.AuthenticationMode
import com.here.sdk.core.engine.LayerConfiguration
import com.here.sdk.core.engine.SDKBuildInformation
import com.here.sdk.core.engine.SDKNativeEngine
import com.here.sdk.core.engine.SDKOptions
import com.here.sdk.core.errors.InstantiationErrorException
import com.here.sdk.maploader.CatalogUpdateInfo
import com.here.sdk.maploader.CatalogUpdateProgressListener
import com.here.sdk.maploader.CatalogsUpdateInfoCallback
import com.here.sdk.maploader.DownloadRegionsStatusListener
import com.here.sdk.maploader.DownloadableRegionsCallback
import com.here.sdk.maploader.InstalledRegion
import com.here.sdk.maploader.MapDownloader
import com.here.sdk.maploader.MapDownloaderConstructionCallback
import com.here.sdk.maploader.MapDownloaderTask
import com.here.sdk.maploader.MapLoaderError
import com.here.sdk.maploader.MapLoaderException
import com.here.sdk.maploader.MapUpdater
import com.here.sdk.maploader.MapUpdaterConstructionCallback
import com.here.sdk.maploader.PersistentMapRepairError
import com.here.sdk.maploader.PersistentMapStatus
import com.here.sdk.maploader.Region
import com.here.sdk.maploader.RegionId
import com.here.sdk.maploader.RepairPersistentMapCallback
import com.here.sdk.maploader.SDKCache
import com.here.sdk.mapview.MapMeasure
import com.here.sdk.mapview.MapScheme
import com.here.sdk.mapview.MapView
import com.here.sdk.search.OfflineSearchEngine
import com.here.sdk.search.OfflineSearchIndex
import com.here.sdk.search.OfflineSearchIndexListener
import com.here.sdk.search.Place
import com.here.sdk.search.SearchCallback
import com.here.sdk.search.SearchError
import com.here.sdk.search.SearchOptions
import com.here.sdk.search.TextQuery
import java.util.stream.Collectors

class OfflineMapsExample(
    private val mapView: MapView,
    private val context: Context,
    private val snackbar: MainActivity.SnackBackCallback
) {
    private lateinit var mapDownloader: MapDownloader
    private lateinit var mapUpdater: MapUpdater
    private var offlineSearchEngine: OfflineSearchEngine
    private var downloadableRegions: List<Region> = arrayListOf()
    private val mapDownloaderTasks: MutableList<MapDownloaderTask> = arrayListOf()
    private val TAG: String = OfflineMapsExample::class.java.simpleName
    private var offlineSearchLayerEnabled = true
    private var switchOffline = false
    private lateinit var offlineSearchIndexOptions: OfflineSearchIndex.Options
    private lateinit var offlineSearchIndexListener: OfflineSearchIndexListener

    init {
        // Configure the map.
        repositionCamera()

        val sdkNativeEngine = SDKNativeEngine.getSharedInstance()
            ?: throw RuntimeException("SDKNativeEngine not initialized.")

        try {
            // Adding offline search engine to show that we can search on downloaded regions.
            // Note that the engine cannot be used while a map update is in progress and an error will be indicated.
            offlineSearchEngine = OfflineSearchEngine()
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("Initialization of OfflineSearchEngine failed: " + e.error.name)
        }

        // This is the default storage path for cached map data that is not available as installed region.
        // Note that the default storage paths can be adapted when creating a new SDKNativeEngine.
        val storagePath = sdkNativeEngine.options.cachePath
        Log.d(TAG, "Cache storagePath: $storagePath")

        // This is the default path for storing downloaded regions.
        // The application must have read/write access to this path if updating it.
        val persistentMapStoragePath = sdkNativeEngine.options.persistentMapStoragePath
        Log.d(TAG, "PersistentMapStoragePath: $persistentMapStoragePath")

        // In case you want to set a custom path for cache and map data, you can replace the
        // above initializtion of SDKNativeEngine with the code below using SDKOptions:

        /*
            try {
                val options = SDKOptions(
                    "<ACCESS-KEY-ID>",
                    "<ACCESS-KEY-SECRET>",
                    "<custom-cache-path>",
                    <Size-in-bytes>,
                    "<custon-map-path>"
                )
                val sdkNativeEngine = SDKNativeEngine(options)
            } catch (e: InstantiationErrorException) {
                e.printStackTrace()
            } catch (ex Exception) {
                throw RuntimeException("SDKNativeEngine not initialized.");
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
        initMapDownloader(sdkNativeEngine)
        initMapUpdater(sdkNativeEngine)

        // Enable indexing to improve the search experience.
        enableOfflineSearchIndexing(sdkNativeEngine)

        val info = "This example allows to download the region Switzerland."
        snackbar.show(info)
    }

    fun onDownloadListClicked() {
        if (!this::mapDownloader.isInitialized) {
            val message = "MapDownloader instance not ready. Try again."
            snackbar.show(message)
            return
        }

        // Download a list of Region items that will tell us what map regions are available for later download.
        mapDownloader.getDownloadableRegions(
            LanguageCode.DE_DE,
            object : DownloadableRegionsCallback {
                override fun onCompleted(
                    mapLoaderError: MapLoaderError?,
                    list: MutableList<Region>?
                ) {
                    if (mapLoaderError != null) {
                        val message = "Downloadable regions error: $mapLoaderError"
                        snackbar.show(message)
                        return
                    }
                    // If error is null, it is guaranteed that the list will not be null.
                    downloadableRegions = list!!

                    for (region in downloadableRegions) {
                        Log.d("RegionsCallback", region.name)
                        val childRegions = region.childRegions ?: continue

                        // Note that this code ignores to list the children of the children (and so on).
                        for (childRegion in childRegions) {
                            val sizeOnDiskInMB = childRegion.sizeOnDiskInBytes / (1024 * 1024)
                            val logMessage = "Child region: " + childRegion.name +
                                    ", ID: " + childRegion.regionId.id +
                                    ", Size: " + sizeOnDiskInMB + " MB"
                            Log.d("RegionsCallback", logMessage)
                        }
                    }

                    val message = "Found ${downloadableRegions.size} continents with various " +
                            "countries. Full list: $downloadableRegions."
                    snackbar.show(message)
                }

            }
        )
    }

    fun onDownloadMapClicked() {
        if (!this::mapDownloader.isInitialized) {
            val message = "MapDownloader instance not ready. Try again."
            snackbar.show(message)
            return
        }

        // Find region for Switzerland using the German name as identifier.
        // Note that we requested the list of regions in German above.
        val swizNameInGerman = "Schweiz"
        val region = findRegion(swizNameInGerman)

        if (region == null) {
            val message = "Error: The Swiz region was not found. Click 'Regions' first."
            snackbar.show(message)
            return
        }

        // For this example we only download one country.
        val regionIDs = listOf(region.regionId)
        val mapDownloaderTask = mapDownloader.downloadRegions(
            regionIDs,
            object : DownloadRegionsStatusListener {
                override fun onDownloadRegionsComplete(
                    mapLoaderError: MapLoaderError?,
                    list: List<RegionId>?
                ) {
                    if (mapLoaderError != null) {
                        val message =
                            "Download regions completion error: $mapLoaderError"
                        snackbar.show(message)
                        return
                    }

                    // If error is null, it is guaranteed that the list will not be null.
                    // For this example we downloaded only one hardcoded region.
                    val message = "Completed 100% for Switzerland! ID: " + list!![0].id
                    snackbar.show(message)
                }

                override fun onProgress(regionId: RegionId, percentage: Int) {
                    val message = "Download for Switzerland. ID: " + regionId.id +
                            ". Progress: " + percentage + "%."
                    snackbar.show(message)
                }

                override fun onPause(mapLoaderError: MapLoaderError?) {
                    if (mapLoaderError == null) {
                        val message =
                            "The download was paused by the user calling mapDownloaderTask.pause()."
                        snackbar.show(message)
                    } else {
                        val message =
                            "Download regions onPause error. The task tried to often to retry the download: $mapLoaderError"
                        snackbar.show(message)
                    }
                }

                override fun onResume() {
                    val message = "A previously paused download has been resumed."
                    snackbar.show(message)
                }
            })

        mapDownloaderTasks.add(mapDownloaderTask)
    }

    // Finds a region in the downloaded region list.
    // Note that we ignore children of children (and so on).
    private fun findRegion(localizedRegionName: String): Region? {
        var downloadableRegion: Region? = null
        for (region in downloadableRegions!!) {
            if (region.name == localizedRegionName) {
                downloadableRegion = region
                break
            }
            val childRegions = region.childRegions ?: continue
            for (childRegion in childRegions) {
                if (childRegion.name == localizedRegionName) {
                    downloadableRegion = childRegion
                    break
                }
            }
        }

        return downloadableRegion
    }

    fun onCancelMapDownloadClicked() {
        for (mapDownloaderTask in mapDownloaderTasks) {
            mapDownloaderTask.cancel()
        }
        val message = "Cancelled " + mapDownloaderTasks.size + " download tasks in list."
        snackbar.show(message)
        mapDownloaderTasks.clear()
    }

    fun toggleOfflineMode() {
        switchOffline = !switchOffline
        if (switchOffline) {
            SDKNativeEngine.getSharedInstance()!!.isOfflineMode = true
            snackbar.show("The app is radio-silence.")
        } else {
            SDKNativeEngine.getSharedInstance()!!.isOfflineMode = false
            snackbar.show("The app is allowed to go online.")
        }
    }

    // A test call that shows that, for example, search is possible on downloaded regions.
    // For this make sure you have successfully downloaded a region, device is offline and
    // the viewport shows a part of the region. Note: We need the OfflineSearchEngine, as
    // the SearchEngine will only search online using HERE backend services.
    // Keep in mind that the OfflineSearchEngine can also search on cached map data.
    fun onSearchPlaceClicked() {
        val bbox = mapView.camera.boundingBox
        if (bbox == null) {
            snackbar.show("Invalid bounding box.")
            return
        }

        val queryArea = TextQuery.Area(bbox)
        val textQuery = TextQuery("restaurants", queryArea)

        val searchOptions = SearchOptions()
        searchOptions.languageCode = LanguageCode.EN_US
        searchOptions.maxItems = 30

        offlineSearchEngine.searchByText(
            textQuery, searchOptions,
            object : SearchCallback {
                override fun onSearchCompleted(
                    searchError: SearchError?,
                    list: MutableList<Place>?
                ) {
                    if (searchError != null) {
                        val message = "Search Error: $searchError"
                        snackbar.show(message)
                        return
                    }
                    // If error is null, it is guaranteed that the items will not be null.
                    val message =
                        "Test search found " + list!!.size + " results. See log for details."
                    snackbar.show(message)

                    // Log search results.
                    for (place in list) {
                        Log.d("Search", place.title + ", " + place.address.addressText)
                    }
                }
            }
        )
    }

    private fun checkForMapUpdates() {
        if (!this::mapUpdater.isInitialized) {
            val message = "MapUpdater instance not ready. Try again."
            snackbar.show(message)
            return
        }

        mapUpdater.retrieveCatalogsUpdateInfo(object : CatalogsUpdateInfoCallback {
            override fun apply(
                mapLoaderError: MapLoaderError?,
                catalogList: MutableList<CatalogUpdateInfo>?
            ) {
                if (mapLoaderError != null) {
                    Log.e("CatalogUpdateCheck", "Error: " + mapLoaderError.name)
                    return
                }

                // When error is null, then the list is guaranteed to be not null.
                if (catalogList!!.isEmpty()) {
                    Log.d("CatalogUpdateCheck", "No map updates are available.")
                }

                logCurrentMapVersion()

                // Usually, only one global catalog is available that contains regions for the whole world.
                // For some regions like Japan only a base map is available, by default.
                // If your company has an agreement with HERE to use a detailed Japan map, then in this case you
                // can install and use a second catalog that references the detailed Japan map data.
                // All map data is part of downloadable regions. A catalog contains references to the
                // available regions. The map data for a region may differ based on the catalog that is used
                // or on the version that is downloaded and installed.
                for (catalogUpdateInfo in catalogList) {
                    Log.d(
                        "CatalogUpdateCheck",
                        "Catalog name:" + catalogUpdateInfo.installedCatalog.catalogIdentifier.hrn
                    )
                    Log.d(
                        "CatalogUpdateCheck",
                        "Installed map version:" + catalogUpdateInfo.installedCatalog.catalogIdentifier.version
                    )
                    Log.d(
                        "CatalogUpdateCheck",
                        "Latest available map version:" + catalogUpdateInfo.latestVersion
                    )
                    performMapUpdate(catalogUpdateInfo)
                }
            }
        })
    }

    // Downloads and installs map updates for any of the already downloaded regions.
    // Note that this example only shows how to download one region.
    private fun performMapUpdate(catalogUpdateInfo: CatalogUpdateInfo) {
        if (!this::mapUpdater.isInitialized) {
            val message = "MapUpdater instance not ready. Try again."
            snackbar.show(message)
            return
        }

        // This method conveniently updates all installed regions for a catalog if an update is available.
        // Optionally, you can use the CatalogUpdateTask to pause / resume or cancel the update.
        val task =
            mapUpdater.updateCatalog(catalogUpdateInfo, object : CatalogUpdateProgressListener {
                override fun onProgress(regionId: RegionId, percentage: Int) {
                    Log.d(
                        "CatalogUpdate",
                        "Downloading and installing a map update. Progress for " + regionId.id + ": " + percentage
                    )
                }

                override fun onPause(mapLoaderError: MapLoaderError?) {
                    if (mapLoaderError == null) {
                        val message =
                            "The map update was paused by the user calling catalogUpdateTask.pause()."
                        Log.e("CatalogUpdate", message)
                    } else {
                        val message =
                            "Map update onPause error. The task tried to often to retry the update: $mapLoaderError"
                        Log.d("CatalogUpdate", message)
                    }
                }

                override fun onResume() {
                    val message = "A previously paused map update has been resumed."
                    Log.d("CatalogUpdate", message)
                }

                override fun onComplete(mapLoaderError: MapLoaderError?) {
                    if (mapLoaderError != null) {
                        val message = "Map update completion error: $mapLoaderError"
                        Log.d("CatalogUpdate", message)
                        return
                    }

                    val message = "One or more map update has been successfully installed."
                    Log.d("CatalogUpdate", message)
                    logCurrentMapVersion()

                    // It is recommend to call now also `getDownloadableRegions()` to update
                    // the internal catalog data that is needed to download, update or delete
                    // existing `Region` data. It is required to do this at least once
                    // before doing a new download, update or delete operation.
                }
            })
    }

    private fun checkInstallationStatus() {
        if (!this::mapDownloader.isInitialized) {
            val message = "MapDownloader instance not ready. Try again."
            snackbar.show(message)
            return
        }

        logInstalledRegions()

        // Note that this value will not change during the lifetime of an app.
        val persistentMapStatus = mapDownloader.initialPersistentMapStatus
        if (persistentMapStatus != PersistentMapStatus.OK) {
            // Something went wrong after the app was closed the last time. It seems the offline map data is
            // corrupted. This can eventually happen, when an ongoing map download was interrupted due to a crash.
            Log.d(
                "PersistentMapStatus",
                "The persistent map data seems to be corrupted. Trying to repair."
            )

            // Let's try to repair.
            mapDownloader.repairPersistentMap(object : RepairPersistentMapCallback {
                override fun onCompleted(persistentMapRepairError: PersistentMapRepairError?) {
                    if (persistentMapRepairError == null) {
                        Log.d("RepairPersistentMap", "Repair operation completed successfully!")
                        return
                    }
                    // In this case, check the PersistentMapStatus and the recommended
                    // healing option listed in the API Reference. For example, if the status
                    // is PENDING_UPDATE, it cannot be repaired, but instead an update
                    // should be executed. It is recommended to inform your users to
                    // perform the recommended action.
                    Log.d(
                        "RepairPersistentMap",
                        "Repair operation failed: " + persistentMapRepairError.name
                    )
                }

            })
        }
    }

    fun toggleLayerConfiguration(
        accessKeyID: String,
        accessKeySecret: String,
        context: Context,
        savedInstanceState: Bundle?
    ) {
        // Cached map data persists until the Least Recently Used (LRU) eviction policy is triggered.
        // After modifying the "FeatureConfiguration", calling performUpdateChecks() will trigger an update to the map data.
        // This will update all previously installed region map data and incomplete downloads which are in pending states.
        // If no regions have been downloaded, this method will update only the map cache.
        // If no updates are available, the MapUpdateProgressListener.onComplete callback will be invoked immediately with a MapLoaderError.
        // Note: This app allows the user to install one region for testing purposes.
        // In order to simplify testing when no region has been installed, we
        // explicitly clear the cache.
        // If the cache is not cleared, the HERE SDK will look for cached data, for example,
        // when using the OfflineSearchEngine.
        try {
            val authenticationMode = AuthenticationMode.withKeySecret(
                accessKeyID, accessKeySecret
            )
            val options = SDKOptions(authenticationMode)

            // Toggle the layer configuration.
            offlineSearchLayerEnabled = !offlineSearchLayerEnabled

            // LayerConfiguration can only be updated before HERE SDK initialization.
            if (offlineSearchLayerEnabled) {
                options.layerConfiguration = layerConfigurationWithOfflineSearch
                snackbar.show("Enabled minimal layer configuration with OFFLINE_SEARCH layer.")
            } else {
                options.layerConfiguration = getLayerConfigurationWithoutOfflineSearch()
                snackbar.show("Enabled minimal layer configuration without OFFLINE_SEARCH layer.")
            }

            // Invoking makeSharedInstance will invalidate any existing references to the previous instance of SDKNativeEngine.
            SDKNativeEngine.makeSharedInstance(context, options)

            // Update the current MapView instance to recreate the rendering surface that was invalidated by the invocation of makeSharedInstance.
            updateMapView(savedInstanceState)

            // Reinitialize the map updater and perform feature update internally to "normalize" the new layer configuration.
            // Normalization, in this context, is the process of aligning the currently downloaded layer group configuration in the map data with the requested one.
            // Layer groups that are not in the requested layer configuration are removed and layer groups that were added to the requested configuration are downloaded.
            initMapUpdater(SDKNativeEngine.getSharedInstance()!!)

            // Reinitialize the map downloader using the new instance of SDKNativeEngine.
            initMapDownloader(SDKNativeEngine.getSharedInstance()!!)
            offlineSearchEngine = OfflineSearchEngine()
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("ReInitialization of HERE SDK failed: " + e.error.name)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun updateMapView(savedInstanceState: Bundle?) {
        // Needs to be called after recreation of SDKNativeEngine, even when savedInstanceState is null.
        // Otherwise, the map view will keep using the previous SDKNativeEngine instance.
        mapView.onCreate(savedInstanceState)

        // Since mapview.onCreate() results in a new rendering surface, the map scene must be reloaded to ensure proper rendering.
        mapView.mapScene.loadScene(
            MapScheme.NORMAL_DAY
        ) { mapError ->
            if (mapError == null) {
                Log.d(TAG, "onLoadScene Succeeded.")
                repositionCamera()
            } else {
                Log.d(TAG, "onLoadScene failed: $mapError")
            }
        }
    }

    private fun initMapUpdater(sdkNativeEngine: SDKNativeEngine) {
        MapUpdater.fromEngineAsync(sdkNativeEngine, object : MapUpdaterConstructionCallback {
            override fun onMapUpdaterConstructe(mapUpdater: MapUpdater) {
                this@OfflineMapsExample.mapUpdater = mapUpdater
                performUpdateChecks()
            }
        })
    }

    private fun performUpdateChecks() {
        logHERESDKVersion()
        logCurrentMapVersion()

        // Checks if map updates are available for any of the already downloaded maps.
        // If a new map download is started via MapDownloader during an update process,
        // a NOT_READY error is indicated.
        // Note that this example only shows how to download one region.
        // Important: For production-ready apps, it is recommended to ask users whether
        // it's okay for them to update now and to give an indication when the process has completed.
        // - Since all regions are updated in one rush, a large amount of data may be downloaded.
        // - By default, the update process should not be done while an app runs in background as then the
        // download can be interrupted by the OS.
        checkForMapUpdates()
    }

    private fun initMapDownloader(sdkNativeEngine: SDKNativeEngine) {
        MapDownloader.fromEngineAsync(sdkNativeEngine, object : MapDownloaderConstructionCallback {
            override fun onMapDownloaderConstructedCompleted(mapDownloader: MapDownloader) {
                this@OfflineMapsExample.mapDownloader = mapDownloader
                // Checks the status of already downloaded map data and eventually repairs it.
                // Important: For production-ready apps, it is recommended to not do such operations silently in
                // the background and instead inform the user.
                checkInstallationStatus()
            }
        })
    }

    // Here we disable the OFFLINE_SEARCH layer to show what happens when we search offline:
    // When the layer is enabled then the OfflineSearchEngine can find results in the cached map data or installed regions.
    // When the layer is disabled, the OfflineSearchEngine will yield either no results or very few limited results.
    // enabledFeatures will enable all layers from the list in the downloaded regions for offline use.
    // implicitlyPrefetchedFeatures will enable all layers from the list for the map cache when panning the map view during online use.
    // If the implicitlyPrefetchedFeatures setting is set to an empty list, no features will be implicitly prefetched.
    private fun getLayerConfigurationWithoutOfflineSearch(): LayerConfiguration {
        val features = ArrayList<LayerConfiguration.Feature>()
        features.add(LayerConfiguration.Feature.DETAIL_RENDERING)
        features.add(LayerConfiguration.Feature.RENDERING)
        val layerConfiguration = LayerConfiguration()
        layerConfiguration.enabledFeatures = features
        layerConfiguration.implicitlyPrefetchedFeatures = features
        return layerConfiguration
    }

    private fun logHERESDKVersion() {
        Log.d("HERE SDK version: ", SDKBuildInformation.sdkVersion().versionName)
    }

    private fun logCurrentMapVersion() {
        if (!this::mapUpdater.isInitialized) {
            val message = "MapUpdater instance not ready. Try again."
            snackbar.show(message)
            return
        }

        try {
            val mapVersionHandle = mapUpdater.currentMapVersion
            // Version string my look like "47.47,47.47".
            Log.d("Installed map version: ", mapVersionHandle.stringRepresentation(","))
        } catch (e: MapLoaderException) {
            val mapLoaderError = e.error
            Log.e(
                "MapLoaderError",
                "Fetching current map version failed: $mapLoaderError"
            )
        }
    }

    // Download the rectangular area that is currently visible in the viewport.
    // It is possible to call this method in parallel to download multiple areas in parallel.
    fun onDownloadAreaClicked() {
        showDialog("Note", "Downloading the area that is currently visible in the viewport.")
        val polygonArea = GeoPolygon(getMapViewGeoBox())

        mapDownloader.downloadArea(polygonArea, object : DownloadRegionsStatusListener {
            override fun onDownloadRegionsComplete(
                mapLoaderError: MapLoaderError?,
                list: List<RegionId>?
            ) {
                if (mapLoaderError != null) {
                    val message = "Download area completion error: $mapLoaderError"
                    snackbar.show(message)
                    return
                }

                // If error is null, it is guaranteed that the regions will not be null.
                // When downloading an area, only a single unique ID will be provided.
                // Note: It is recommended to store this ID with a human readable name,
                // as this will make it easier to delete the downloaded area in the future by calling
                // mapDownloader.deleteRegions(...). The ID itself is accessible from InstalledRegions.
                // This ID is used for future operations like deletion, which simplifies region management.
                val message = "Completed 100% for area! ID: " + list!![0].id
                snackbar.show(message)
                Log.d(TAG, message)
            }

            override fun onProgress(regionId: RegionId, percentage: Int) {
                // Note that this ID is uniquely created and can be to delete the area in the future.
                val message = "Download for area ID: " + regionId.id +
                        ". Progress: " + percentage + "%."
                snackbar.show(message)
            }

            override fun onPause(mapLoaderError: MapLoaderError?) {
                if (mapLoaderError == null) {
                    val message =
                        "The download area was paused by the user calling mapDownloaderTask.pause()."
                    snackbar.show(message)
                } else {
                    val message =
                        "Download area onPause error. The task tried to often to retry the download: $mapLoaderError"
                    snackbar.show(message)
                }
            }

            override fun onResume() {
                val message = "A previously paused area download has been resumed."
                snackbar.show(message)
            }
        })
    }

    private fun getMapViewGeoBox(): GeoBox {
        val mapViewWidthInPixels = mapView.width
        val mapViewHeightInPixels = mapView.height
        val bottomLeftPoint2D = Point2D(0.0, mapViewHeightInPixels.toDouble())
        val topRightPoint2D = Point2D(mapViewWidthInPixels.toDouble(), 0.0)

        val southWestCorner = mapView.viewToGeoCoordinates(bottomLeftPoint2D)
        val northEastCorner = mapView.viewToGeoCoordinates(topRightPoint2D)

        if (southWestCorner == null || northEastCorner == null) {
            throw RuntimeException("GeoBox creation failed, corners are null.")
        }

        // Note: This algorithm assumes an unrotated map view.
        return GeoBox(southWestCorner, northEastCorner)
    }

    // Cached map data will not be removed until the least recently used (LRU) strategy is applied.
    // Therefore, we can manually clear the cache to remove any outdated entries.
    fun clearCache() {
        SDKCache.fromEngine(SDKNativeEngine.getSharedInstance()!!).clearCache { mapLoaderError ->
            if (mapLoaderError != null) {
                snackbar.show("Cache clear error " + mapLoaderError.name)
            } else {
                snackbar.show("Cache clear succeeded.")
            }
        }
    }

    private fun repositionCamera() {
        val camera = mapView.camera
        val distanceInMeters = (1000 * 7).toDouble()
        val mapMeasureZoom = MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, distanceInMeters)
        camera.lookAt(GeoCoordinates(46.94843, 7.44046), mapMeasureZoom)
    }

    private fun showDialog(title: String, message: String) {
        val builder: AlertDialog.Builder = AlertDialog.Builder(context)
        builder.setTitle(title)
        builder.setMessage(message)
        builder.show()
    }

    private fun enableOfflineSearchIndexing(sdkNativeEngine: SDKNativeEngine) {
        offlineSearchIndexOptions = OfflineSearchIndex.Options()
        offlineSearchIndexOptions!!.enabled = true

        offlineSearchIndexListener = object : OfflineSearchIndexListener {
            override fun onStarted(operation: OfflineSearchIndex.Operation) {
                Log.d(
                    "OfflineSearchIndexListener",
                    "Indexing started. Operation: $operation"
                )
                snackbar.show("Indexing started: $operation")
            }

            override fun onProgress(percentage: Int) {
                Log.d("OfflineSearchIndexListener", "Indexing progress: $percentage%")
                snackbar.show("Indexing progress: $percentage%")
            }

            override fun onComplete(error: OfflineSearchIndex.Error?) {
                if (error == null) {
                    Log.d("OfflineSearchIndexListener", "Indexing completed successfully.")
                    snackbar.show("Indexing completed successfully.")
                } else {
                    Log.e("OfflineSearchIndexListener", "Indexing failed: " + error.name)
                    snackbar.show("Indexing failed: " + error.name)
                }
            }
        }

        OfflineSearchEngine.setIndexOptions(
            sdkNativeEngine,
            offlineSearchIndexOptions, offlineSearchIndexListener
        )
    }

    private fun getInstalledRegionList(): List<InstalledRegion> {
        var installedRegionList: List<InstalledRegion> = ArrayList()
        try {
            installedRegionList = mapDownloader.installedRegions
        } catch (e: MapLoaderException) {
            Log.d("Fetching installedRegions failed", e.error.toString())
        }
        return installedRegionList
    }

    fun deleteInstalledRegions() {
        val installedRegionList = getInstalledRegionList()

        // Retrieving the RegionIds from the list of installed regions, which will be used for the deletion process.
        val regionIds = installedRegionList.stream()
            .map { region: InstalledRegion -> region.regionId }
            .collect(Collectors.toList())

        // Asynchronous operation to delete map data for regions specified by a list of RegionId.
        // Deleting a region when there is a pending download returns error MapLoaderError.INTERNAL_ERROR.
        // Also, deleting a region when there is an ongoing download returns error MapLoaderError.NOT_READY
        mapDownloader.deleteRegions(
            regionIds
        ) { mapLoaderError, list -> // When error is null, the list is guaranteed to be not null.
            if (mapLoaderError == null && list != null) {
                for (regionID in list) {
                    Log.d(
                        "deleteRegions",
                        "Successfully deleted region: $regionID"
                    )
                }
                snackbar.show("Successfully deleted regions!")
            } else {
                Log.e(
                    "deleteRegions",
                    "Deleting regions failed:" + mapLoaderError!!.name
                )
                snackbar.show("Deleting regions failed: " + mapLoaderError.name)
            }
        }
    }

    private fun logInstalledRegions() {
        val installedRegionList = getInstalledRegionList()

        for (region in installedRegionList) {
            Log.d("Installed region", "Downloaded region id: " + region.regionId)
            Log.d("Installed region", "sizeOnDiskInBytes: " + region.sizeOnDiskInBytes)
            Log.d("Installed region", "InstalledRegionStatus: " + region.status.toString())
        }

        val occupiedStorageSize = getSizeOfInstalledRegionsInBytes(installedRegionList)
        Log.d("Installed Region", "Total storage size in bytes: $occupiedStorageSize")
    }

    private fun getSizeOfInstalledRegionsInBytes(installedRegionList: List<InstalledRegion>): Long {
        return installedRegionList.stream()
            .mapToLong { region: InstalledRegion -> region.sizeOnDiskInBytes }
            .sum()
    }

    companion object {
        val layerConfigurationWithOfflineSearch: LayerConfiguration
            // With this layer configuration we enable only the listed layers.
            get() {
                val features = ArrayList<LayerConfiguration.Feature>()
                features.add(LayerConfiguration.Feature.DETAIL_RENDERING)
                features.add(LayerConfiguration.Feature.RENDERING)
                features.add(LayerConfiguration.Feature.OFFLINE_SEARCH)
                val layerConfiguration = LayerConfiguration()
                layerConfiguration.enabledFeatures = features
                layerConfiguration.implicitlyPrefetchedFeatures = features
                return layerConfiguration
            }
    }
}
