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

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import android.util.Log;

import com.here.sdk.core.GeoPolyline;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.mapview.datasource.LineData;
import com.here.sdk.mapview.datasource.LineDataBuilder;
import com.here.sdk.mapview.datasource.PointData;
import com.here.sdk.mapview.datasource.PointDataBuilder;
import com.here.sdk.mapview.datasource.PointTileSource;
import com.here.sdk.mapview.datasource.TileKey;
import com.here.sdk.mapview.datasource.TileSource;
import com.here.sdk.mapview.datasource.TilingScheme;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Date;
import java.util.List;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.here.sdk.core.GeoBox;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.mapview.datasource.DataAttributes;
import com.here.sdk.mapview.datasource.DataAttributesBuilder;
import com.here.sdk.mapview.datasource.LineTileSource;
import com.here.sdk.mapview.datasource.TileGeoBoundsCalculator;
import com.here.sdk.mapview.datasource.TileKey;
import com.here.sdk.mapview.datasource.TilingScheme;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Date;
import java.util.List;
import java.util.Random;

/**
 * LocalLineTileSource is a custom tile source that dynamically generates line geometries for each tile.  
 * It provides the line features based on the requested TileKey, enabling custom line rendering on the map.  
 *
 * This implementation supports multiple zoom levels and calculates the geographical boundaries of each tile  
 * to generate line coordinates dynamically within that area. This approach allows for flexible visualization  
 * of line-based map features without relying on pre-existing datasets.  
 */
public class LocalLineTileSource implements LineTileSource {

    // Tile source data version.
    final DataVersion mDataVersion = new DataVersion(1, 0);

    // Supported data levels.
    final List<Integer> mSupportedLevels = new ArrayList<>(
            Arrays.asList(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16));

    // Supported tiling scheme.
    final TilingScheme mSupportedTilingScheme = TilingScheme.QUAD_TREE_MERCATOR;

    // Tile geo-bounds calculator.
    final TileGeoBoundsCalculator mTileBoundsCalculator = new TileGeoBoundsCalculator(mSupportedTilingScheme);

    @Nullable
    @Override
    public LoadTileRequestHandle loadTile(@NonNull TileKey tileKey, @NonNull LoadResultHandler loadResultHandler) {
        Log.d("LocalLineTileSource", "Loading tile for key: " + tileKey.toString());

        List<GeoCoordinates> lineCoordinates = getTileLineCoordinates(tileKey);
        if (lineCoordinates.isEmpty()) {
            Log.e("LocalLineTileSource", "No line coordinates generated for tile: " + tileKey);
            loadResultHandler.failed(tileKey);
            return null;
        }

        try {
            LineData tileData = new LineDataBuilder()
                    .withGeometry(new GeoPolyline(lineCoordinates))
                    .withAttributes(new DataAttributesBuilder().build())
                    .build();
            Log.d("LocalLineTileSource", "Tile loaded successfully");
            loadResultHandler.loaded(tileKey, Collections.singletonList(tileData), new TileSource.TileMetadata(mDataVersion, new Date(0)));
        } catch (InstantiationErrorException e) {
            Log.e("LocalLineTileSource", "Failed to create LineData", e);
            loadResultHandler.failed(tileKey);
        }

        return null;
    }

    @NonNull
    @Override
    public DataVersion getDataVersion(@NonNull TileKey tileKey) {
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
        return mSupportedTilingScheme;
    }

    @NonNull
    @Override
    public List<Integer> getStorageLevels() {
        return mSupportedLevels;
    }

    private List<GeoCoordinates> getTileLineCoordinates(TileKey tileKey) {
        GeoBox tileBoundingBox = mTileBoundsCalculator.boundsOf(tileKey);
        return Arrays.asList(
                tileBoundingBox.southWestCorner,
                tileBoundingBox.northEastCorner
        );
    }
}
