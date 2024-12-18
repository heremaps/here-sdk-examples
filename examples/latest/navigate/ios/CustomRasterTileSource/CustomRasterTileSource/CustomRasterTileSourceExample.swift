/*
 * Copyright (C) 2024 HERE Europe B.V.
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

class CustomRasterTileSourceExample {

    private var mapView: MapView
    private var rasterMapLayerStyle: MapLayer!
    private var rasterDataSourceStyle: RasterDataSource!

    init(_ mapView: MapView) {
        self.mapView = mapView

        let camera = mapView.camera
        let distanceInMeters = MapMeasure(kind: .distance, value: 60 * 1000)
        camera.lookAt(point: GeoCoordinates(latitude: 52.518043, longitude: 13.405991),
                      zoom: distanceInMeters)

        // Load the map scene using a map scheme to render the map with.
        mapView.mapScene.loadScene(mapScheme: MapScheme.normalDay, completion: onLoadScene)
        
        let dataSourceName = "myRasterDataSourceStyle"
        rasterDataSourceStyle = createRasterDataSource(dataSourceName: dataSourceName)
        rasterMapLayerStyle = createMapLayer(dataSourceName: dataSourceName)

        // We want to start with the default map style.
        rasterMapLayerStyle.setEnabled(false)

        // Add a POI marker
        addPOIMapMarker(geoCoordinates: GeoCoordinates(latitude: 52.530932, longitude: 13.384915))
    }
    
    // Completion handler for loadScene().
    private func onLoadScene(mapError: MapError?) {
        guard mapError == nil else {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
            return
        }
    }

    func onEnableButtonClicked() {
        rasterMapLayerStyle.setEnabled(true)
    }

    func onDisableButtonClicked() {
        rasterMapLayerStyle.setEnabled(false)
    }

    private func createRasterDataSource(dataSourceName: String) -> RasterDataSource {
        // Create a RasterDataSource over a local raster tile source.
        // Note that this will make the raster source already known to the passed map view.
        return RasterDataSource(context: mapView.mapContext,
                                name: dataSourceName,
                                tileSource: LocalRasterTileSource())
    }

    private func createMapLayer(dataSourceName: String) -> MapLayer {
        // The layer should be rendered on top of other layers including the "labels" layer
        // so that we don't overlap the raster layer over POI markers.
        let priority = MapLayerPriorityBuilder().renderedAfterLayer(named: "labels").build()

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

