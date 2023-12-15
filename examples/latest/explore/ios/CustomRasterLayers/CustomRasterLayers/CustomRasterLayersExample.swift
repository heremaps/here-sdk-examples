/*
 * Copyright (C) 2019-2023 HERE Europe B.V.
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

    private let mapView: MapView
    private var rasterMapLayerStyle: MapLayer!
    private var rasterDataSourceStyle: RasterDataSource!

    init(mapView: MapView) {
        self.mapView = mapView

        let camera = mapView.camera
        let distanceInMeters = MapMeasure(kind: .distance, value: 60 * 1000)
        camera.lookAt(point: GeoCoordinates(latitude: 52.518043, longitude: 13.405991),
                      zoom: distanceInMeters)

        let dataSourceName = "myRasterDataSourceStyle"
        rasterDataSourceStyle = createRasterDataSource(dataSourceName: dataSourceName)
        rasterMapLayerStyle = createMapLayer(dataSourceName: dataSourceName)

        // We want to start with the default map style.
        rasterMapLayerStyle.setEnabled(false)
        
        // Add a POI marker
        addPOIMapMarker(geoCoordinates: GeoCoordinates(latitude: 52.530932, longitude: 13.384915))
        
        // Users of the Navigate Edition can set the visibility for all the POI categories to hidden.
        // let categoryIds: [String] = []
        // MapScene.setPoiVisibility(categoryIds: categoryIds, visibility: VisibilityState.hidden)
    }

    func onEnableButtonClicked() {
        rasterMapLayerStyle.setEnabled(true)
    }

    func onDisableButtonClicked() {
        rasterMapLayerStyle.setEnabled(false)
    }

    private func createRasterDataSource(dataSourceName: String) -> RasterDataSource {
        // Note: As an example, below is an URL template of an outdoor layer from thunderforest.com.
        // On their web page you can register a key. Without setting a valid API key, the tiles will
        // show a watermark.
        // More details on the terms of usage can be found here: https://www.thunderforest.com/terms/
        // For example, your application must have working links to https://www.thunderforest.com
        // and https://www.osm.org/copyright.
        // For the below template URL, please pay attention to the following attribution:
        // Maps © www.thunderforest.com, Data © www.osm.org/copyright.
        // Alternatively, choose another tile provider or use the (customizable) map styles provided by HERE.
        let templateUrl = "https://tile.thunderforest.com/outdoors/{z}/{x}/{y}.png"
        
        // The storage levels available for this data source. Supported range [0, 31].
        let storageLevels: [Int32] = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
        var rasterProviderConfig = RasterDataSourceConfiguration.Provider(
            urlProvider: TileUrlProviderFactory.fromXyzUrlTemplate(templateUrl)!,
            tilingScheme: TilingScheme.quadTreeMercator,
            storageLevels: storageLevels)            
        
        // If you want to add transparent layers then set this to true.
        rasterProviderConfig.hasAlphaChannel = false
        
        // Raster tiles are stored in a separate cache on the device.
        let path = "cache/raster/mycustomlayer"
        let maxDiskSizeInBytes: Int64 = 1024 * 1024 * 128 // 128 MB
        let cacheConfig = RasterDataSourceConfiguration.Cache(path: path,
                                                              diskSize: maxDiskSizeInBytes)

        // Note that this will make the raster source already known to the passed map view.
        return RasterDataSource(context: mapView.mapContext,
                                configuration: RasterDataSourceConfiguration(name: dataSourceName,
                                                                             provider: rasterProviderConfig,
                                                                             cache: cacheConfig))
    }
    
    private func createMapLayer(dataSourceName: String) -> MapLayer {
        // The layer should be rendered on top of other layers.
        let priority = MapLayerPriorityBuilder().renderedLast().build()
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
