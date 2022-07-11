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

import heresdk
import UIKit

class CustomRasterLayersExample {

    private let viewController: UIViewController
    private let mapView: MapView
    private var rasterMapLayerTonerStyle: MapLayer!
    private var rasterDataSourceTonerStyle: RasterDataSource!

    init(viewController: UIViewController, mapView: MapView) {
        self.viewController = viewController
        self.mapView = mapView

        let camera = mapView.camera
        let distanceInMeters = MapMeasure(kind: .distance, value: 60 * 1000)
        camera.lookAt(point: GeoCoordinates(latitude: 52.518043, longitude: 13.405991),
                      zoom: distanceInMeters)

        let dataSourceName = "myRasterDataSourceTonerStyle"
        rasterDataSourceTonerStyle = createRasterDataSource(dataSourceName: dataSourceName)
        rasterMapLayerTonerStyle = createMapLayer(dataSourceName: dataSourceName)

        // We want to start with the default map style.
        rasterMapLayerTonerStyle.setEnabled(false)
        
        // Add a POI marker
        addPOIMapMarker(geoCoordinates: GeoCoordinates(latitude: 52.530932, longitude: 13.384915))
    }

    func onEnableButtonClicked() {
        rasterMapLayerTonerStyle.setEnabled(true)
    }

    func onDisableButtonClicked() {
        rasterMapLayerTonerStyle.setEnabled(false)
    }

    // Note: Map tile data source by Stamen Design (http://stamen.com),
    // under CC BY 3.0 (http://creativecommons.org/licenses/by/3.0).
    // Data by OpenStreetMap, under ODbL (http://www.openstreetmap.org/copyright):
    // For more details, check: http://maps.stamen.com/#watercolor/12/37.7706/-122.3782.
    private func createRasterDataSource(dataSourceName: String) -> RasterDataSource {
        // The URL template that is used to download tiles from the device or a backend data source.
        let templateUrl = "https://stamen-tiles.a.ssl.fastly.net/toner/{z}/{x}/{y}.png"
        // The storage levels available for this data source. Supported range [0, 31].
        let storageLevels: [Int32] = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
        var rasterProviderConfig = RasterDataSourceConfiguration.Provider(templateUrl: templateUrl,
                                                                          tilingScheme: TilingScheme.quadTreeMercator,
                                                                          storageLevels: storageLevels)

        // If you want to add transparent layers then set this to true.
        rasterProviderConfig.hasAlphaChannel = false
        
        // Raster tiles are stored in a separate cache on the device.
        let path = "cache/raster/toner"
        let maxDiskSizeInBytes: Int64 = 1024 * 1024 * 32
        let cacheConfig = RasterDataSourceConfiguration.Cache(path: path,
                                                              diskSize: maxDiskSizeInBytes)

        // Note that this will make the raster source already known to the passed map view.
        return RasterDataSource(context: mapView.mapContext,
                                configuration: RasterDataSourceConfiguration(name: dataSourceName,
                                                                             provider: rasterProviderConfig,
                                                                             cache: cacheConfig))
    }

    private func createMapLayer(dataSourceName: String) -> MapLayer {
        // The layer should be rendered on top of other layers except the labels layer so that we don't overlap raster layer over POI markers.
        let priority = MapLayerPriorityBuilder().renderedLast().renderedBeforeLayer(named: "labels").build()
        // And it should be visible for all zoom levels.
        let range = MapLayerVisibilityRange(minimumZoomLevel: 0, maximumZoomLevel: 22 + 1)

        let mapLayer: MapLayer

        do {
            // Build and add the layer to the map.
            try mapLayer = MapLayerBuilder()
                .forMap(mapView.hereMap) // mandatory parameter
                .withName(dataSourceName + "Layer") // mandatory parameter
                .withDataSource(named: dataSourceName,
                                contentType: MapContentType.rasterImage)
                .withPriority(priority)
                .withVisibilityRange(range)
                .build()
            return mapLayer
        } catch let InstantiationException {
            fatalError("MapLayer creation failed Cause: \(InstantiationException)")
        }
    }
    
    private func addPOIMapMarker(geoCoordinates: GeoCoordinates) {
        guard
            let image = UIImage(named: "poi.png"),
            let imageData = image.pngData() else {
                print("Error: Image not found.")
                return
        }

        // The bottom, middle position should point to the location.
        // By default, the anchor point is set to 0.5, 0.5.
        let anchorPoint = Anchor2D(horizontal: 0.5, vertical: 1)
        let mapMarker = MapMarker(at: geoCoordinates,
                                  image: MapImage(pixelData: imageData,
                                                  imageFormat: ImageFormat.png),
                                  anchor: anchorPoint)

        mapView.mapScene.addMapMarker(mapMarker)
    }
}
