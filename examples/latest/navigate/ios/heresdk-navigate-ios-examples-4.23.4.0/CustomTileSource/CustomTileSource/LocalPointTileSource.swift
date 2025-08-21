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

class LocalPointTileSource : PointTileSource {
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
    
    func loadTile(tileKey: TileKey, completionHandler: any PointTileSourceLoadResultHandler) -> (any TileSourceLoadTileRequestHandle)? {
        // For each tile, provide the tile geodetic center as a custom point, with a single
        // named attribute "pointText" containing the tile key representation as a string.
        let pointAttributes = DataAttributesBuilder()
            .with(name: "pointText", value: String(format: "Tile: (%d, %d, %d)", tileKey.x, tileKey.y, tileKey.level))
            .build()
        let tileData = PointDataBuilder().withCoordinates(getTileCenter(tileKey: tileKey))
                                         .withAttributes(pointAttributes)
                                         .build();
        
        completionHandler.loaded(tileKey: tileKey, data: [tileData],
                                 metadata: TileSourceTileMetadata(dataVersion: dataVersion,
                                                                  dataExpiryTimestamp: Date(timeIntervalSince1970: TimeInterval(0))))
        
        // No request handle is returned here since there is no asynchronous loading happening.
        return nil
    }   
    
    func getTileCenter(tileKey: TileKey) -> GeoCoordinates {
         let tileBoundingBox = tileBoundsCalculator.boundsOf(tileKey)
         let sw = tileBoundingBox.southWestCorner
         let ne = tileBoundingBox.northEastCorner
         let latitude = (sw.latitude + ne.latitude) * 0.5

         let west = sw.longitude
         let east = ne.longitude

         if (west <= east)
         {
             return GeoCoordinates(latitude: latitude, longitude: (west + east) * 0.5)
         }

         var longitude = (2 * Double.pi + east + west) * 0.5
         if (longitude > Double.pi )
         {
             longitude -= 2 * Double.pi;
         }

         return GeoCoordinates(latitude: latitude,longitude:  longitude)
     }
}
