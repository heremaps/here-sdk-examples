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

class LocalRasterTileSource : RasterTileSource {
    // Tile source supported tiling scheme.
    var tilingScheme: TilingScheme = TilingScheme.quadTreeMercator
    
    // Tile source supported data levels.
    var storageLevels: [Int32] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
    
    // Tile source data version. A single version is supported for this example.
    var dataVersion: TileSourceDataVersion = TileSourceDataVersion(majorVersion: 1, minorVersion: 0)
    
    // Local tile data (auto-generated).
    private var tileData: [Data] = [Data]()
    
    init() {
        // Create a set of images to provide as tile data.
        tileData.append(createTileData(width: 512, height: 512, color: UIColor.red))
        tileData.append(createTileData(width: 512, height: 512, color: UIColor.blue))
        tileData.append(createTileData(width: 512, height: 512, color: UIColor.green))
        tileData.append(createTileData(width: 512, height: 512, color: UIColor.black))
        tileData.append(createTileData(width: 512, height: 512, color: UIColor.white))
        tileData.append(createTileData(width: 512, height: 512, color: UIColor.yellow))
        tileData.append(createTileData(width: 512, height: 512, color: UIColor.cyan))
        tileData.append(createTileData(width: 512, height: 512, color: UIColor.magenta))
    }
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
    
    func loadTile(tileKey: TileKey, completionHandler: any RasterTileSourceLoadResultHandler) -> (any TileSourceLoadTileRequestHandle)? {
        // Pick one of the local tile images, based on the tile key x component.
        
        completionHandler.loaded(tileKey: tileKey, data: tileData[Int(tileKey.x % Int32(tileData.count))],
                                 metadata: TileSourceTileMetadata(dataVersion: dataVersion, dataExpiryTimestamp: Date(timeIntervalSince1970: TimeInterval(0))))
        
        // No request handle is returned here since there is no asynchronous loading happening.
        return nil
    }
    
    func createTileData(width: Int, height: Int, color: UIColor) -> Data {
        // Fill-in a canvas with a color.
        let size = CGSize(width: width, height: height)
        let renderFormat = UIGraphicsImageRendererFormat()
        renderFormat.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: renderFormat)
        let uiImage = renderer.image { context in
            color.setFill()
            context.cgContext.fill(CGRect(origin: CGPoint.zero, size: size))
        }
        
        return uiImage.pngData()!
    }
}
