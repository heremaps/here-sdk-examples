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

class CustomPointTileSourceExample {

    private let mapView: MapView
    private var pointMapLayer: MapLayer!
    private var pointDataSource: PointTileDataSource!

    // Style for layer with 'technique' equal to 'icon-text', 'layer' field equal to name of
    // map layer constructed later in code and 'text' attribute govern by 'pointText' data
    // attribute to be able to customize/modify the text of points.
    // See 'Developer Guide/Style guide for custom layers' and
    // 'Developer Guide/Style techniques reference for custom layers/icon-text' for more details.
    private let pointLayerStyle = """
    {
       "styles": [
           {
               "layer": "MyPointDataSourceLayer",
               "technique": "icon-text",
               "attr": {
                   "text-color": "#ff0000ff",
                   "text-size": 30,
                   "text": ["get", "pointText"]
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

        let dataSourceName = "MyPointDataSource"
        pointDataSource = createPointTileDataSource(dataSourceName: dataSourceName)
        pointMapLayer = createMapLayer(dataSourceName: dataSourceName)
        
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
    
    func onEnableButtonClicked() {
        pointMapLayer.setEnabled(true)
    }

    func onDisableButtonClicked() {
        pointMapLayer.setEnabled(false)
    }

    private func createPointTileDataSource(dataSourceName: String) -> PointTileDataSource {
        // Create a PointTileDataSource using a local point tile source.
        // Note that this will make the point source already known to the passed map view.
        return PointTileDataSource.create(context: mapView.mapContext,
                                          name: dataSourceName,
                                          tileSource: LocalPointTileSource())
    }

    // Creates a MapLayer for displaying custom point tiles.
    private func createMapLayer(dataSourceName: String) -> MapLayer {
        //  The layer should be visible for all zoom levels. The minimum tilt level is 0 and maximum zoom level is 23.
        let range = MapLayerVisibilityRange(minimumZoomLevel: MapCameraLimits.minTilt, maximumZoomLevel: MapCameraLimits.maxZoomLevel)
        

        let mapLayer: MapLayer

        do {
            // Build and add the layer to the map.
            try mapLayer = MapLayerBuilder()
                .forMap(mapView.hereMap) // mandatory parameter
                .withName(dataSourceName + "Layer") // mandatory parameter
                .withDataSource(named: dataSourceName,
                                contentType: MapContentType.point)
                .withVisibilityRange(range)
                .withStyle(JsonStyleFactory.createFromString(pointLayerStyle)) // Creates a custom style for the point layer from the predefined JSON style string.
                .build()
            return mapLayer
        } catch let InstantiationException {
            fatalError("MapLayer creation failed Cause: \(InstantiationException)")
        }
    }
}
