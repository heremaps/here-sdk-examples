/*
 * Copyright (C) 2025 HERE Europe B.V.
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
import SwiftUI

/**
 * This example app demonstrates how to load custom polygon layers, implement polygon tile rendering using a custom polygon tile source,
 * and integrate custom styles. It enables the display of custom polygon tiles with configurable styling, with data sourced
 * either from the local file system or a custom backend. However, we have not shown how to use a custom backend in this example.
 * 
 * In this implementation, custom polygon data is provided to the HERE SDK based on the requested `TileKey`, allowing dynamic 
 * rendering of polygon geometries. 
 * 
 * Note: `PolygonTileDataSource` is triggered based on the viewport (visible data), while the points for `MapPolygon` need to be 
 * provided upfront. For rendering up to 2000 polygons `MapPolygon` is sufficient. However, it is recommended to use `PolygonTileDataSource` 
 * in place of `MapPolygon` when rendering for more polygons, as it is more memory efficient.
 */
class CustomPolygonTileSourceExample {

    private let mapView: MapView
    private var polygonMapLayer: MapLayer!
    private var polygonDataSource: PolygonTileDataSource!

    private let polygonLayerStyle = """
    {
       "styles": [
           {
               "layer": "MyPolygonTileDataSourceLayer",
               "technique": "polygon",
               "attr": {
                   "color": "#ff000066"
               }
            }
        ]
    }
    """

    init(_ mapView: MapView) {
        self.mapView = mapView

        let camera = mapView.camera
        let distanceInMeters = MapMeasure(kind: MapMeasure.Kind.distanceInMeters, value: 60 * 1000)
        camera.lookAt(point: GeoCoordinates(latitude: 52.518043, longitude: 13.405991),
                      zoom: distanceInMeters)

        let dataSourceName = "MyPolygonTileDataSource"
        polygonDataSource = createPolygonTileDataSource(dataSourceName: dataSourceName)
        polygonMapLayer = createMapLayer(dataSourceName: dataSourceName)
        
        if let polygonMapLayer = polygonMapLayer {
            polygonMapLayer.setEnabled(false)
        }
        
        // Load the map scene using a map scheme to render the map with.
        mapView.mapScene.loadScene(mapScheme: MapScheme.normalDay, completion: onLoadScene)
    }

    // Completion handler for loadScene().
    private func onLoadScene(mapError: MapError?) {
        guard mapError == nil else {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
            return
        }
    }
    
    func enableLayer() {
        polygonMapLayer.setEnabled(true)
    }

    func disableLayer() {
        polygonMapLayer.setEnabled(false)
    }

    private func createPolygonTileDataSource(dataSourceName: String) -> PolygonTileDataSource {
        // Create a PolygonTileDataSource using a local polygon tile source.
        return PolygonTileDataSource.create(context: mapView.mapContext,
                                         name: dataSourceName,
                                            tileSource: LocalPolygonTileSource())
    }

    // Creates a MapLayer for displaying custom polygon tiles.
    private func createMapLayer(dataSourceName: String) -> MapLayer {
        //  The layer should be visible for all zoom levels. The minimum tilt level is 0 and maximum zoom level is 23.
        let range = MapLayerVisibilityRange(minimumZoomLevel: MapCameraLimits.minTilt, maximumZoomLevel: MapCameraLimits.maxZoomLevel)

        let mapLayer: MapLayer

        do {
            try mapLayer = MapLayerBuilder()
                .forMap(mapView.hereMap)
                .withName(dataSourceName + "Layer")
                .withDataSource(named: dataSourceName,
                                contentType: MapContentType.polygon)
                .withVisibilityRange(range)
                .withStyle(JsonStyleFactory.createFromString(polygonLayerStyle))
                .build()
            return mapLayer
        } catch let InstantiationException {
            fatalError("MapLayer creation failed Cause: \(InstantiationException)")
        }
    }
}
