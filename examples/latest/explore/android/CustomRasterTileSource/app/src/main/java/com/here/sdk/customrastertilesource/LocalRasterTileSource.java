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

 package com.here.sdk.customrastertilesource;

 import android.graphics.Bitmap;
 import android.graphics.Canvas;
 import android.graphics.Color;

 import androidx.annotation.NonNull;
 import androidx.annotation.Nullable;

 import com.here.sdk.mapview.datasource.RasterTileSource;
 import com.here.sdk.mapview.datasource.TileKey;
 import com.here.sdk.mapview.datasource.TilingScheme;

 import java.io.ByteArrayOutputStream;
 import java.util.ArrayList;
 import java.util.Arrays;
 import java.util.Date;
 import java.util.List;

 public class LocalRasterTileSource implements RasterTileSource {

     // Tile source data version. A single version is supported for this example.
     final DataVersion mDataVersion = new DataVersion(1, 0);

     // Tile source supported data levels.
     final List<Integer> mSupportedLevels = new ArrayList<Integer>(
             Arrays.asList(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16));

     // Tile source supported tiling scheme.
     final TilingScheme mSupportedTilingScheme = TilingScheme.QUAD_TREE_MERCATOR;

     // Local tile data (auto-generated).
     final List<byte[]> mTileData = new ArrayList<>();

     LocalRasterTileSource() {
        // Create a set of images to provide as tile data.
         mTileData.add(createTileData(512, 512, Color.RED));
         mTileData.add(createTileData(512, 512, Color.BLUE));
         mTileData.add(createTileData(512, 512, Color.GREEN));
         mTileData.add(createTileData(512, 512, Color.BLACK));
         mTileData.add(createTileData(512, 512, Color.WHITE));
         mTileData.add(createTileData(512, 512, Color.YELLOW));
         mTileData.add(createTileData(512, 512, Color.CYAN));
         mTileData.add(createTileData(512, 512, Color.MAGENTA));
     }

     @Nullable
     @Override
     public LoadTileRequestHandle loadTile(@NonNull TileKey tileKey,
                                           @NonNull LoadResultHandler loadResultHandler) {
         // Pick one of the local tile images, based on the tile key x component.
         loadResultHandler.loaded(tileKey, mTileData.get(tileKey.x % mTileData.size()),
                 new TileMetadata(mDataVersion, new Date(0)));

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

     private byte[] createTileData(int width, int height, int color) {
         // Fill-in a canvas with a color.
         Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
         Canvas canvas = new Canvas(bitmap);
         canvas.drawColor(color);
         ByteArrayOutputStream pngData = new ByteArrayOutputStream();

         if (bitmap.compress(Bitmap.CompressFormat.PNG, 100, pngData)) {
             return pngData.toByteArray();
         } else {
             return null;
         }
     }
 }
