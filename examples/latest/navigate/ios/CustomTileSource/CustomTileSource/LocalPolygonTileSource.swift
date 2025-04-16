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

import Foundation
import heresdk

/**
 * LocalPolygonTileSource is a custom tile source that dynamically generates polygon geometries for each tile.
 * It provides the polygon features based on the requested TileKey, enabling custom polygon rendering on the map.
 *
 * This implementation supports multiple zoom levels and calculates the geographical boundaries of each tile
 * to generate polygon coordinates dynamically within that area. This approach allows for flexible visualization
 * of polygon-based map features without relying on pre-existing datasets.
 */
class LocalPolygonTileSource: PolygonTileSource {
    // Tile source supported tiling scheme.
    var tilingScheme: TilingScheme = TilingScheme.quadTreeMercator

    // Tile geo-bounds calculator for supported tiling scheme.
    var tileBoundsCalculator: TileGeoBoundsCalculator = TileGeoBoundsCalculator(TilingScheme.quadTreeMercator)

    // Tile source supported data levels.
    var storageLevels: [Int32] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]

    // Tile source data version. A single version is supported for this example.
    var dataVersion: TileSourceDataVersion = TileSourceDataVersion(majorVersion: 1, minorVersion: 0)

    func getDataVersion(tileKey: TileKey) -> TileSourceDataVersion {
        // Latest version of the tile data.
        return dataVersion
    }

    func addDelegate(_ delegate: any TileSourceDelegate) {
        // Not needed by this implementation.
        // Delegate can be used to signal the data source the update of data version.
    }

    func removeDelegate(_ delegate: any TileSourceDelegate) {
        // Not used by this implementation.
    }
    
    func loadTile(tileKey: TileKey, completionHandler: any PolygonTileSourceLoadResultHandler) -> (any TileSourceLoadTileRequestHandle)? {
        do {
            let tileData = PolygonDataBuilder()
                .withGeometry(try GeoPolygon(vertices: getPolygonTileCoordinates(tileKey: tileKey)))
                .withAttributes(DataAttributesBuilder().build())
                .build()
            
            completionHandler.loaded(tileKey: tileKey, data: [tileData],
                                     metadata: TileSourceTileMetadata(dataVersion: dataVersion,
                                                                      dataExpiryTimestamp: Date(timeIntervalSince1970: TimeInterval(0))))
        } catch {
            print("Error creating GeoPolygon: \(error)")
            completionHandler.failed(tileKey)
            return nil
        }

        return nil
    }

    func getPolygonTileCoordinates(tileKey: TileKey) -> [GeoCoordinates] {
        let tileBoundingBox = tileBoundsCalculator.boundsOf(tileKey)
        return [
            tileBoundingBox.southWestCorner,
            GeoCoordinates(latitude: tileBoundingBox.northEastCorner.longitude, longitude: tileBoundingBox.northEastCorner.latitude),
            GeoCoordinates(latitude: tileBoundingBox.northEastCorner.latitude, longitude: tileBoundingBox.northEastCorner.longitude),
            tileBoundingBox.southWestCorner
        ]
    }
}
