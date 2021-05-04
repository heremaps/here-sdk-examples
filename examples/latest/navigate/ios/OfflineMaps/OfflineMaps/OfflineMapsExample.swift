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

import heresdk
import UIKit

class OfflineMapsExample : DownloadRegionsStatusListener {

    private let mapView: MapView
    private let mapDownloader: MapDownloader
    private let offlineSearchEngine: OfflineSearchEngine
    private var downloadableRegions = [Region]()
    private var mapDownloaderTasks = [MapDownloaderTask]()

    init(mapView: MapView) {
        self.mapView = mapView

        // Configure the map.
        let camera = mapView.camera
        camera.lookAt(point: GeoCoordinates(latitude: 52.530932, longitude: 13.384915),
                      distanceInMeters: 1000 * 7)

        guard let sdkNativeEngine = SDKNativeEngine.sharedInstance else {
            fatalError("SDKNativeEngine not initialized.")
        }

        mapDownloader = MapDownloader.fromEngine(sdkNativeEngine)

        do {
            // Adding offline search engine to show that we can search on downloaded regions.
            try offlineSearchEngine = OfflineSearchEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize OfflineSearchEngine. Cause: \(engineInstantiationError)")
        }

        // Note that the default storage path can be adapted when creating a new SDKNativeEngine.
        let storagePath = sdkNativeEngine.options.cachePath
        showMessage("This example allows to download the region Switzerland. StoragePath: \(storagePath).")
    }

    func onDownloadListClicked() {
        // Download a list of Region items that will tell us what map regions are available for later download.
        _ = mapDownloader.getDownloadableRegions(languageCode: LanguageCode.deDe,
                                                 completion: onDownloadableRegionsCompleted)
    }

    // Completion handler to receive search results.
    func onDownloadableRegionsCompleted(error: MapLoaderError?, regions: [Region]?) {
        if let mapLoaderError = error {
            self.showMessage("Downloadable regions error: \(mapLoaderError)")
            return
        }

        // If error is nil, it is guaranteed that the list will not be nil.
        downloadableRegions = regions!

        for region in downloadableRegions {
            print(region.name)
            guard let childRegions = region.childRegions else {
                continue
            }

            // Note that this code ignores to list the children of the children (and so on).
            for childRegion in childRegions {
                let sizeOnDiskinMB = childRegion.sizeOnDiskInBytes / (1024 * 1024)
                print("Child region: \(childRegion.name), ID: \(childRegion.regionId.id), Size: \(sizeOnDiskinMB) MB")
            }
        }

        self.showMessage("Found \(downloadableRegions.count) continents with various countries. Full list: \(downloadableRegions.description).")
    }

    func onDownloadMapClicked() {
        // Find region for Switzerland using the German name as identifier.
        // Note that we requested the list of regions in German above.
        let swizNameInGerman = "Schweiz"
        let swizRegion = findRegion(localizedRegionName: swizNameInGerman)

        guard let region = swizRegion else {
            showMessage("Error: The Swiz region was not found. Click 'Regions' first to download the list of regions.")
            return
        }

        // For this example we only download one country.
        let regionIDs = [region.regionId]
        let mapDownloaderTask = mapDownloader.downloadRegions(regions: regionIDs,
                                                              statusListener: self)
        mapDownloaderTasks.append(mapDownloaderTask)
    }

    // Conform to the DownloadRegionsStatusListener protocol.
    func onDownloadRegionsComplete(error: MapLoaderError?, regions: [RegionId]?) {
        if let mapLoaderError = error {
            self.showMessage("Download regions completion error: \(mapLoaderError)")
            return
        }

        // If error is nil, it is guaranteed that the list will not be nil.
        // For this example we downloaded only one hardcoded region.
        showMessage("Map download completed 100% for Switzerland! ID: \(String(describing: regions!.first))")
    }

    // Conform to the DownloadRegionsStatusListener protocol.
    func onProgress(region: RegionId, percentage: Int32) {
        showMessage("Map download progress for Switzerland. ID: \(region.id). Progress: \(percentage)%.")
    }

    // Conform to the DownloadRegionsStatusListener protocol.
    func onPause(error: MapLoaderError?) {
        if (error == nil) {
            showMessage("The download was paused by the user calling mapDownloaderTask.pause().")
        } else {
            showMessage("Download regions onPause error. The task tried to often to retry the download: \(error.debugDescription)")
        }
    }

    // Conform to the DownloadRegionsStatusListener protocol.
    func onResume() {
        showMessage("A previously paused download has been resumed.")
    }
    
    // Finds a region in the downloaded region list.
    // Note that we ignore children of children (and so on).
    private func findRegion(localizedRegionName: String) -> Region? {
        var downloadableRegion: Region?
        for region in downloadableRegions {
            if region.name == localizedRegionName {
                downloadableRegion = region
                break
            }
            guard let childRegions = region.childRegions else {
                continue
            }
            for childRegion in childRegions {
                if childRegion.name == localizedRegionName {
                    downloadableRegion = childRegion
                    break
                }
            }
        }

        return downloadableRegion
    }

    func onCancelMapDownloadClicked() {
        for mapDownloaderTask in mapDownloaderTasks {
            mapDownloaderTask.cancel()
        }
        showMessage("Cancelled \(mapDownloaderTasks.count) download tasks in list.")
        mapDownloaderTasks.removeAll()
    }

    // A test call that shows that, for example, search is possible on downloaded regions.
    // For this make sure you have successfully downloaded a region, device is offline and
    // the viewport shows a part of the region. Note: We need the OfflineSearchEngine, as
    // the SearchEngine will only search online using HERE backend services.
    // Keep in mind that the OfflineSearchEngine can also search on cached map data.
    func onSearchPlaceClicked() {
        guard let bbox = mapView.camera.boundingBox else {
            self.showMessage("Invalid bounding box.")
            return
        }

        let textQuery = TextQuery("restaurants", in: bbox)
        let searchOptions = SearchOptions(languageCode: LanguageCode.enUs,
                                          maxItems: 30)
        offlineSearchEngine.search(textQuery: textQuery,
                                   options: searchOptions) { error, places in
            if let searchError = error {
                self.showMessage("Search Error: \(searchError)")
                return
            }

            // If error is nil, it is guaranteed that the items will not be nil.
            self.showMessage("Test search found \(places!.count) results. See log for details.")

            // Log search results.
            for place in places! {
                print("\(place.title), \(place.address.addressText)")
            }
        }
    }

    // A permanent view to show scrollablelog content.
    private var messageTextView = UITextView()
    private func showMessage(_ message: String) {
        messageTextView.text = message
        messageTextView.textColor = .white
        messageTextView.backgroundColor = UIColor(red: 0, green: 144 / 255, blue: 138 / 255, alpha: 1)
        messageTextView.layer.cornerRadius = 8
        messageTextView.isEditable = false
        messageTextView.textAlignment = NSTextAlignment.center
        messageTextView.font = .systemFont(ofSize: 14)
        messageTextView.frame = CGRect(x: 0, y: 0, width: mapView.frame.width * 0.9, height: mapView.frame.height * 0.3)
        messageTextView.center = CGPoint(x: mapView.frame.width * 0.5, y: mapView.frame.height * 0.7)

        UIView.transition(with: mapView, duration: 0.2, options: [.transitionCrossDissolve], animations: {
            self.mapView.addSubview(self.messageTextView)
        })
    }
}
