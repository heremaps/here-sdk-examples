 /*
  * Copyright (C) 2024 HERE Europe B.V.
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

 package com.here.sdk.custompointtilesource;
 ;
 import android.util.Pair;

 import androidx.annotation.NonNull;
 import androidx.annotation.Nullable;

 import com.here.sdk.core.GeoCoordinates;
 import com.here.sdk.mapview.datasource.DataAttributes;
 import com.here.sdk.mapview.datasource.DataAttributesBuilder;
 import com.here.sdk.mapview.datasource.PointData;
 import com.here.sdk.mapview.datasource.PointDataBuilder;
 import com.here.sdk.mapview.datasource.PointTileSource;
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

     private static GeoCoordinates getTileCenter(TileKey tileKey) {
         Pair<GeoCoordinates, GeoCoordinates> tileBoundingBox = tileKeyToGeoBox(tileKey);
         final double latitude = (tileBoundingBox.first.latitude + tileBoundingBox.second.latitude) * 0.5;

         final double west = tileBoundingBox.first.longitude;
         final double east = tileBoundingBox.second.longitude;

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

     /**
      * Computes the geo box out of a tile key, assuming a TMS tile key, spherical projection and quadtree
      * mercator tiling scheme.
      * @param tileKey Key of the tile for which to compute
      * @return Tile geo box (SW, NE).
      */
     private static Pair<GeoCoordinates, GeoCoordinates> tileKeyToGeoBox(TileKey tileKey) {
        // TMS -> XYZ
         final int tileZ = tileKey.level;
         final int tileX = tileKey.x;
         final int tileY = (1 << tileZ) - 1 - tileKey.y;

         final int tileSize = 256;
         final double earthRadius = 6378137.0;
         final double twoPi = 2.0 * Math.PI;
         final double halfPi = Math.PI * 0.5;
         final double toRadiansFactor = Math.PI / 180.0;
         final double toDegreesFactor = 180.0 / Math.PI;
         final double originShift = twoPi * earthRadius * 0.5;
         final double initialResolution = twoPi * earthRadius / tileSize;

         final double pointXWest = tileX * tileSize;
         final double pointYNorth = tileY * tileSize;
         final double pointXEast = (tileX + 1) * tileSize;
         final double pointYSouth = (tileY + 1) * tileSize;

         // Compute corner coordinates.
         final double resolutionAtCurrentZ = initialResolution / (1 << tileZ);
         final double halfSize = tileSize * (1 << tileZ) * 0.5;
         // SW
         final double meterXW = Math.abs(pointXWest * resolutionAtCurrentZ - originShift) *
                 (pointXWest < halfSize ? -1 : 1);
         final double meterYS = Math.abs(pointYSouth * resolutionAtCurrentZ - originShift) *
                 (pointYSouth > halfSize ? -1 : 1);
         double longitudeSW = (meterXW / originShift) * 180.0;
         double latitudeSW = (meterYS / originShift) * 180.0;
         latitudeSW = toDegreesFactor * (2 * Math.atan(Math.exp(latitudeSW * toRadiansFactor)) - halfPi);
         // NE
         final double meterXE = Math.abs(pointXEast * resolutionAtCurrentZ - originShift) *
                 (pointXEast < halfSize ? -1 : 1);
         final double meterYN = Math.abs(pointYNorth * resolutionAtCurrentZ - originShift) *
                 (pointYNorth > halfSize ? -1 : 1);
         double longitudeNE = (meterXE / originShift) * 180.0;
         double latitudeNE = (meterYN / originShift) * 180.0;
         latitudeNE = toDegreesFactor * (2 * Math.atan(Math.exp(latitudeNE * toRadiansFactor)) - halfPi);

         return new Pair<>(new GeoCoordinates(latitudeSW, longitudeSW), new GeoCoordinates(latitudeNE, longitudeNE));
     }
 }
