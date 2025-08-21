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
 * This example app demonstrates how to load custom line layers, implement line rendering using a custom line tile source,
 * and integrate custom styles. It enables the display of custom line tiles with configurable styling, with data sourced
 * either from the local file system or a custom backend.
 *
 * In this implementation, custom line data is provided to the HERE SDK based on the requested `TileKey`, allowing dynamic
 * rendering of line geometries.
 */
class CustomLineTileSourceExample {

    private let mapView: MapView
    private var lineMapLayer: MapLayer!
    private var lineDataSource: LineTileDataSource!

    // Style for layer with 'technique' equal to 'line', 'layer' field equal to name of
    // map layer constructed later in code and 'lineColor' attribute to customize line appearance.
    private let lineLayerStyle = """
    {
       "styles": [
           {
               "layer": "MyLineTileDataSourceLayer",
               "technique": "line",
               "attr": {
                   "color": "#FF0000",
                   "width": ["world-scale", 5]
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

        let dataSourceName = "MyLineTileDataSource"
        lineDataSource = createLineTileDataSource(dataSourceName: dataSourceName)
        lineMapLayer = createMapLayer(dataSourceName: dataSourceName)
        
        if let lineMapLayer = lineMapLayer {
            lineMapLayer.setEnabled(false)
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
        lineMapLayer.setEnabled(true)
    }

    func disableLayer() {
        lineMapLayer.setEnabled(false)
    }

    private func createLineTileDataSource(dataSourceName: String) -> LineTileDataSource {
        // Create a LineTileDataSource using a local line tile source.
        return LineTileDataSource.create(context: mapView.mapContext,
                                         name: dataSourceName,
                                         tileSource: LocalLineTileSource())
    }

    // Creates a MapLayer for displaying custom line tiles.
    private func createMapLayer(dataSourceName: String) -> MapLayer {
        //  The layer should be visible for all zoom levels. The minimum tilt level is 0 and maximum zoom level is 23.
        let range = MapLayerVisibilityRange(minimumZoomLevel: MapCameraLimits.minTilt, maximumZoomLevel: MapCameraLimits.maxZoomLevel)

        let mapLayer: MapLayer

        do {
            try mapLayer = MapLayerBuilder()
                .forMap(mapView.hereMap)
                .withName(dataSourceName + "Layer")
                .withDataSource(named: dataSourceName,
                                contentType: MapContentType.line)
                .withVisibilityRange(range)
                .withStyle(JsonStyleFactory.createFromString(lineLayerStyle))
                .build()
            return mapLayer
        } catch let InstantiationException {
            fatalError("MapLayer creation failed Cause: \(InstantiationException)")
        }
    }
}
