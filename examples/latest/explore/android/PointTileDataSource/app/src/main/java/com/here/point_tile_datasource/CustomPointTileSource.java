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

package com.here.point_tile_datasource;

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
import java.util.concurrent.atomic.AtomicBoolean;

public class CustomPointTileSource implements PointTileSource {

  // Tile source data version.
  final DataVersion mDataVersion = new DataVersion(1, 0);
  final DataVersion mDataVersionWhenEmpty = new DataVersion(2, 0);
  private AtomicBoolean mHasData = new AtomicBoolean(true);
  private Listener mListener;

  // Tile source supported data levels.
  final List<Integer> mSupportedLevels = new ArrayList<Integer>(
      Arrays.asList(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16));

  // Tile source supported tiling scheme.
  final TilingScheme mSupportedTilingScheme = TilingScheme.QUAD_TREE_MERCATOR;

  @Nullable
  @Override
  public LoadTileRequestHandle
  loadTile(@NonNull TileKey tileKey,
           @NonNull LoadResultHandler loadResultHandler) {
    if (mHasData.get()) {
      DataAttributes pointAttributes =
          new DataAttributesBuilder()
              .with("pointText", String.format("Tile: (%d, %d, %d)", tileKey.x,
                                               tileKey.y, tileKey.level))
              .build();

      GeoCoordinates tileCenter =
          TilingUtils.geoBoxCenter(TilingUtils.getGeoBox(tileKey));

      PointData tileData = new PointDataBuilder()
                               .withCoordinates(tileCenter)
                               .withAttributes(pointAttributes)
                               .build();
      loadResultHandler.loaded(tileKey, Arrays.asList(tileData),
                               new TileMetadata(mDataVersion, new Date(0)));
    } else {
      loadResultHandler.loaded(
          tileKey, new ArrayList<>(),
          new TileMetadata(mDataVersionWhenEmpty, new Date(0)));
    }

    // No request handle is returned here since there is no asynchronous loading
    // happening.
    return null;
  }

  @NonNull
  @Override
  public DataVersion getDataVersion(@NonNull TileKey tileKey) {
    // Latest version of the tile data.
    return mHasData.get() ? mDataVersion : mDataVersionWhenEmpty;
  }

  @Override
  public void addListener(@NonNull Listener listener) {
    mListener = listener;
  }

  @Override
  public void removeListener(@NonNull Listener listener) {
    mListener = null;
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

  public void setHasData(boolean hasData) {
    if (mHasData.getAndSet(hasData) == hasData) {
      return;
    }

    if (mListener != null) {
      mListener.onDataVersionChanged(mHasData.get() ? mDataVersion
                                                    : mDataVersionWhenEmpty);
    }
  }
}
