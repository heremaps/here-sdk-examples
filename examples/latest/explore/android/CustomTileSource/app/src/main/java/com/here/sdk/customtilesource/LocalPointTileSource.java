 /*
  * Copyright (C) 2025 HERE Europe B.V.
  *
  * Licensed under the Apache License, Version 2.0 (the "License");
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

 package com.here.sdk.customtilesource;

 import android.util.Pair;

 import androidx.annotation.NonNull;
 import androidx.annotation.Nullable;

 import com.here.sdk.core.GeoBox;
 import com.here.sdk.core.GeoCoordinates;
 import com.here.sdk.mapview.datasource.DataAttributes;
 import com.here.sdk.mapview.datasource.DataAttributesBuilder;
 import com.here.sdk.mapview.datasource.PointData;
 import com.here.sdk.mapview.datasource.PointDataBuilder;
 import com.here.sdk.mapview.datasource.PointTileSource;
 import com.here.sdk.mapview.datasource.TileGeoBoundsCalculator;
 import com.here.sdk.mapview.datasource.TileKey;
 import com.here.sdk.mapview.datasource.TilingScheme;

 import java.util.ArrayList;
 import java.util.Arrays;
 import java.util.Date;
 import java.util.List;
 import java.util.Random;

 public class LocalPointTileSource implements PointTileSource {

     // Tile source data version. A single version is supported for this example.
     final DataVersion mDataVersion = new DataVersion(1, 0);

     // Tile source supported data levels.
     final List<Integer> mSupportedLevels = new ArrayList<Integer>(
             Arrays.asList(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16));

     // Tile source supported tiling scheme.
     final TilingScheme mSupportedTilingScheme = TilingScheme.QUAD_TREE_MERCATOR;

     // Tile geo-bounds calculator for supported tiling scheme.
     final TileGeoBoundsCalculator mTileBoundsCalculator = new TileGeoBoundsCalculator(mSupportedTilingScheme);

     @Nullable
     @Override
     public LoadTileRequestHandle loadTile(@NonNull TileKey tileKey,
                                           @NonNull LoadResultHandler loadResultHandler) {
         // For each tile, provide the tile geodetic center as a custom point, with a single
         // named attribute "pointText" containing the tile key representation as a string.
         DataAttributes pointAttributes = new DataAttributesBuilder()
                 .with("pointText", String.format("Tile: (%d, %d, %d)",
                                                   tileKey.x, tileKey.y, tileKey.level)).build();
         PointData tileData = new PointDataBuilder().withCoordinates(getTileCenter(tileKey))
                                                    .withAttributes(pointAttributes)
                                                    .build();
         loadResultHandler.loaded(tileKey, Arrays.asList(tileData), new TileMetadata(mDataVersion, new Date(0)));

         // No request handle is returned here since there is no asynchronous loading happening.
         return null;
     }

     @NonNull
     @Override
     public DataVersion getDataVersion(@NonNull TileKey tileKey) {
         // Latest version of the tile data.
         return mDataVersion;
     }

     @Override
     public void addListener(@NonNull Listener listener) {
         // Not needed by this implementation.
         // Listener can be used to signal the data source the update of data version.
     }

     @Override
     public void removeListener(@NonNull Listener listener) {
         // Not used by this implementation.
     }

     @NonNull
     @Override
     public TilingScheme getTilingScheme() {
         // The tiling scheme supported by this tile source.
         return mSupportedTilingScheme;
     }

     @NonNull
     @Override
     public List<Integer> getStorageLevels() {
         // The storage levels supported by this tile source.
         return mSupportedLevels;
     }

     private GeoCoordinates getTileCenter(TileKey tileKey) {
         final GeoBox tileBoundingBox = mTileBoundsCalculator.boundsOf(tileKey);
         final GeoCoordinates sw = tileBoundingBox.southWestCorner;
         final GeoCoordinates ne = tileBoundingBox.northEastCorner;

         final double latitude = (sw.latitude + ne.latitude) * 0.5;
         final double west = sw.longitude;
         final double east = ne.longitude;

         if (west <= east)
         {
             return new GeoCoordinates(latitude, (west + east) * 0.5);
         }

         double longitude = (2 * Math.PI + east + west) * 0.5;
         if (longitude > Math.PI )
         {
             longitude -= 2 * Math.PI;
         }

         return new GeoCoordinates(latitude, longitude);
     }
 }
