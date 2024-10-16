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
import Foundation

class LocalPointTileSource : PointTileSource {
    // Tile source supported tiling scheme.
    var tilingScheme: TilingScheme = TilingScheme.quadTreeMercator
    
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
        let tileData = PointDataBuilder().withCoordinates(LocalPointTileSource.getTileCenter(tileKey: tileKey))
                                         .withAttributes(pointAttributes)
                                         .build();
        
        completionHandler.loaded(tileKey: tileKey, data: [tileData],
                                 metadata: TileSourceTileMetadata(dataVersion: dataVersion,
                                                                  dataExpiryTimestamp: Date(timeIntervalSince1970: TimeInterval(0))))
        
        // No request handle is returned here since there is no asynchronous loading happening.
        return nil
    }   
    
    static func getTileCenter(tileKey: TileKey) -> GeoCoordinates {
         let tileBoundingBox = tileKeyToGeoBox(tileKey: tileKey)
         let latitude = (tileBoundingBox.sw.latitude + tileBoundingBox.ne.latitude) * 0.5

         let west = tileBoundingBox.sw.longitude
         let east = tileBoundingBox.ne.longitude

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

     /**
      * Computes the geo box out of a tile key, assuming a TMS tile key, spherical projection and quadtree
      * mercator tiling scheme.
      * @param tileKey Key of the tile for which to compute
      * @return Tile geo box (SW, NE).
      */
    static func tileKeyToGeoBox(tileKey: TileKey) -> (sw: GeoCoordinates, ne: GeoCoordinates) {
        // TMS -> XYZ
        let tileZ = tileKey.level
        let tileX = tileKey.x
        let tileY = (1 << tileZ) - 1 - tileKey.y

        let tileSize: Int32 = 256
        let earthRadius = 6378137.0
        let twoPi = 2.0 * Double.pi
        let halfPi = Double.pi * 0.5
        let toRadiansFactor = Double.pi / 180.0
        let toDegreesFactor = 180.0 / Double.pi
        let originShift = twoPi * earthRadius * 0.5
        let initialResolution = twoPi * earthRadius / Double(tileSize)

        let pointXWest = Double(tileX * tileSize)
        let pointYNorth = Double(tileY * tileSize)
        let pointXEast = Double((tileX + 1) * tileSize)
        let pointYSouth = Double((tileY + 1) * tileSize)

        // Compute corner coordinates.
        let resolutionAtCurrentZ = initialResolution / Double(1 << tileZ)
        let halfSize = Double(tileSize * (1 << tileZ)) * 0.5
        // SW
        let meterXW = abs(pointXWest * resolutionAtCurrentZ - originShift) *
                 (pointXWest < halfSize ? -1 : 1)
        let meterYS = abs(pointYSouth * resolutionAtCurrentZ - originShift) *
                 (pointYSouth > halfSize ? -1 : 1)
        let longitudeSW = (meterXW / originShift) * 180.0
        var latitudeSW = (meterYS / originShift) * 180.0
        latitudeSW = toDegreesFactor * (2 * atan(exp(latitudeSW * toRadiansFactor)) - halfPi)
        // NE
        let meterXE = abs(pointXEast * resolutionAtCurrentZ - originShift) *
                 (pointXEast < halfSize ? -1 : 1)
        let meterYN = abs(pointYNorth * resolutionAtCurrentZ - originShift) *
                 (pointYNorth > halfSize ? -1 : 1)
        let longitudeNE = (meterXE / originShift) * 180.0
        var latitudeNE = (meterYN / originShift) * 180.0
        latitudeNE = toDegreesFactor * (2 * atan(exp(latitudeNE * toRadiansFactor)) - halfPi)

        return (GeoCoordinates(latitude: latitudeSW, longitude: longitudeSW), GeoCoordinates(latitude: latitudeNE, longitude: longitudeNE))
    }
}
