/*
 * Copyright (C) 2022-2023 HERE Europe B.V.
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

// A class to show a custom raster layer on top of the default map style.
// This class has been taken and adapted for this app from the CustomerRasterLayers example app, you can find here:
// https://github.com/heremaps/here-sdk-examples/tree/master/examples/latest/navigate/ios/CustomRasterLayers
class OutdoorRasterLayer {

    private let mapView: MapView
    private var customRasterLayer: MapLayer!
    private var customRasterDataSourceStyle: RasterDataSource!

    init(mapView: MapView) {
        self.mapView = mapView

        let dataSourceName = "myRasterDataSourceStyle"
        customRasterDataSourceStyle = createRasterDataSource(dataSourceName: dataSourceName)
        customRasterLayer = createMapLayer(dataSourceName: dataSourceName)

        // We want to start with the default map style.
        customRasterLayer.setEnabled(false)
    }

    func enable() {
        customRasterLayer.setEnabled(true)
    }
    
    func disable() {
        customRasterLayer.setEnabled(false)
    }

    private func createRasterDataSource(dataSourceName: String) -> RasterDataSource {
       
        // The URL template that is used to download tiles from the device or a backend data source.
        let templateUrl = "https://tile.thunderforest.com/outdoors/{z}/{x}/{y}.png"

        // ******************************************************************************************************
        // Note: As an example, above we've set an outdoor layer from thunderforest.com. On their web page you
        // can register a key for personal use. Without setting a valid API key, the tiles will show a watermark.
        // More details on the terms of usage can be found here: https://www.thunderforest.com/terms/
        // Alternatively, choose another tile provider or use one of the default map styles provided by HERE.
        // ******************************************************************************************************
        
        // The storage levels available for this data source. Supported range [0, 31].
        let storageLevels: [Int32] = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
        var rasterProviderConfig =
            RasterDataSourceConfiguration.Provider(tilingScheme: TilingScheme.quadTreeMercator,
                                                   storageLevels: storageLevels,
                                                   urlProvider: TileUrlProviderFactory.fromXyzUrlTemplate(templateUrl))
        
        // If you want to add transparent layers then set this to true.
        rasterProviderConfig.hasAlphaChannel = false
        
        // Raster tiles are stored in a separate cache on the device.
        let path = "cache/raster/custom"
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
        // The layer should be rendered on top of other layers except the layers showing the location indicator and polylines/polygons.
        let priority = MapLayerPriorityBuilder().renderedLast()
            .renderedBeforeLayer(named: "&location_indicator_layer")
            .renderedBeforeLayer(named: "&polyline_layer")
            .build()
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
}
