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

package com.here.sdk.custompointtilesourcewithclustering;

import android.util.Log;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import com.here.sdk.core.GeoBox;
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
import java.util.HashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Random;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.stream.Collectors;

public class LocalPointTileSource implements PointTileSource {

  // corners of area to be filled with charging stations
  private static final com.here.sdk.core.GeoCoordinates SOUTH_WEST_CORNER =
      new GeoCoordinates(52.46219963402645, 13.292065070009812);
  private static final com.here.sdk.core.GeoCoordinates NORTH_EAST_CORNER =
      new GeoCoordinates(52.57612667444741, 13.490900369061093);

  // count of the points to be generated
  private static final int POINT_COUNT = 1000;
  // each tile gets divided into TILE_DIVIDER * TILE_DIVIDER grid cells
  private static final int TILE_DIVIDER = 6;

  // Determines if cluster representative should be the closest one to grid cell
  // center. If set to false, just take first element's position of cluster
  // position.
  private static final boolean CLUSTER_REPRESENTATIVE_CLOSE_GRID_CELL_CENTER =
      true;

  final static String LAYER_NAME = "custom_layer";

  // Represents a charging station with position and charging slots.
  private static class ChargingStation {
    public GeoCoordinates coordinate;
    public int free;
    public int occupied;

    // Stores the distance to center of grid cell. Only used for clustered
    // items. USed to choose cluster representative.
    public double distanceToCellCenter;

    public ChargingStation(GeoCoordinates coordinates, int free, int occupied) {
      this.coordinate = coordinates;
      this.free = free;
      this.occupied = occupied;
    }
  }

  private final ArrayList<ChargingStation> stations =
      new ArrayList<>(POINT_COUNT);

  // Tile source data version.
  final DataVersion mDataVersion = new DataVersion(1, 0);
  final DataVersion mDataVersionWhenEmpty = new DataVersion(2, 0);
  private AtomicBoolean mHasData = new AtomicBoolean(true);
  private Listener mListener;
  private Random randomNumberGenerator = new Random(2);

  // Tile source supported data levels.
  final List<Integer> mSupportedLevels = new ArrayList<Integer>(Arrays.asList(
      1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19));

  // Tile source supported tiling scheme.
  final TilingScheme mSupportedTilingScheme = TilingScheme.QUAD_TREE_MERCATOR;

  // Style of the custom points layer.
  public final static String LAYER_STYLE =
      "{\n"
      + "  \"styles\": [\n"
      + "    {\n"
      + "      \"layer\": \"" + LAYER_NAME + "\",\n"
      + "      \"technique\": \"icon-text\",\n"
      + "      \"attr\": {\n"
      + "      \"icon-source\": [\"get\", \"file_name\"],\n"
      + "      \"icon-width\": 75,\n"
      + "      \"icon-height\": 75,\n"
      + "      \"text\": [\"to-string\", [\"get\", \"count\"]],\n"
      + "      \"text-color\": \"#000000ff\",\n"
      + "      \"text-size\": 30\n"
      + "      }\n"
      + "    }\n"
      + "  ]\n"
      + "}";

  public LocalPointTileSource() { createRandomPoints(); }
  @Nullable
  @Override
  public LoadTileRequestHandle
  loadTile(@NonNull TileKey inputTileKey,
           @NonNull LoadResultHandler loadResultHandler) {
    Log.e("XYZ", " tileKey: " + inputTileKey.x + "x" + inputTileKey.y + "x" +
                     inputTileKey.level);
    if (!mHasData.get()) {
      loadResultHandler.loaded(
          inputTileKey, new ArrayList<>(),
          new TileMetadata(mDataVersionWhenEmpty, new Date(0)));
      // no async loading happened
      return null;
    }

    // clip stations (only deliver the ones in current tile)
    GeoBox tileBox = TilingUtils.getGeoBox(inputTileKey);
    List<ChargingStation> stations =
        this.stations.stream()
            .filter(c -> tileBox.contains(c.coordinate))
            .collect(Collectors.toList());

    // cluster charging stations
    LinkedList<LinkedList<ChargingStation>> clusters =
        clusterChargingStations(tileBox, stations);

    // build clusters & generate PointData
    LinkedList<PointData> pointData = new LinkedList<>();
    clusters.forEach((LinkedList<ChargingStation> cluster) -> {
      GeoCoordinates representativePosition =
          // represent cluster by station closest to grid cell center
          CLUSTER_REPRESENTATIVE_CLOSE_GRID_CELL_CENTER
              ? cluster.stream()
                    .min((o1, o2)
                             -> (int)Math.signum(o1.distanceToCellCenter -
                                                 o2.distanceToCellCenter))
                    .get()
                    .coordinate
              // OR: just take the first station
              : cluster.getFirst().coordinate;

      // sum up slots
      ChargingStation representative =
          new ChargingStation(representativePosition, 0, 0);
      cluster.forEach(c -> {
        representative.free += c.free;
        representative.occupied += c.occupied;
      });

      // get icon depending on occupied rate
      int percentage_resolution = 5;

      int percentage_occupied =
          (int)Math.round(100.0 * representative.occupied /
                          (representative.free + representative.occupied));

      int percentage_remainder = percentage_occupied % percentage_resolution;
      // rounding
      percentage_occupied = percentage_remainder > percentage_resolution / 2
                                ? percentage_occupied + (percentage_resolution -
                                                         percentage_remainder)
                                : percentage_occupied - percentage_remainder;

      DataAttributes pointAttributes =
          new DataAttributesBuilder()
              .with("occupied", representative.occupied)
              .with("free", representative.free)
              .with("count", representative.occupied + representative.free)
              .with("file_name",
                    String.format("donut_%d.svg", percentage_occupied))
              .build();

      pointData.add(new PointDataBuilder()
                        .withCoordinates(representative.coordinate)
                        .withAttributes(pointAttributes)
                        .build());
    });

    loadResultHandler.loaded(inputTileKey, pointData,
                             new TileMetadata(mDataVersion, new Date(0)));

    // no async loading happened
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

  // Cluster charging stations by simple grid based approach.
  private LinkedList<LinkedList<ChargingStation>>
  clusterChargingStations(GeoBox box, List<ChargingStation> stations) {

    double eastWestBinSize =
        (box.northEastCorner.longitude - box.southWestCorner.longitude) /
        TILE_DIVIDER;
    double northSouthBinSize =
        (box.northEastCorner.latitude - box.southWestCorner.latitude) /
        TILE_DIVIDER;

    class BinKey {
      int x;
      int y;
      BinKey(int x, int y) {
        this.x = x;
        this.y = y;
      }

      @Override
      public int hashCode() {
        return x * 31 + y;
      }

      @Override
      public boolean equals(@Nullable Object obj) {
        return obj instanceof BinKey && ((BinKey)obj).x == this.x &&
            ((BinKey)obj).y == this.y;
      }
    }

    // calculate grid cell and distance to center of gid cell for each center
    HashMap<BinKey, LinkedList<ChargingStation>> bins = new HashMap<>();

    stations.forEach((ChargingStation c) -> {
      double gridLatitude =
          (box.northEastCorner.longitude - c.coordinate.longitude) /
          eastWestBinSize;

      double gridLongitude =
          (box.northEastCorner.latitude - c.coordinate.latitude) /
          northSouthBinSize;

      double latitudeOffsetFromCenter =
          ((gridLatitude - (int)gridLatitude) - 0.5);
      double longitudeOffsetFromCenter =
          ((gridLongitude - (int)gridLongitude) - 0.5);

      double distanceToGridCenter =
          Math.sqrt(latitudeOffsetFromCenter * latitudeOffsetFromCenter +
                    longitudeOffsetFromCenter * longitudeOffsetFromCenter);

      BinKey key = new BinKey((int)(gridLatitude), (int)(gridLongitude));

      c.distanceToCellCenter = distanceToGridCenter;
      bins.computeIfAbsent(key, k -> new LinkedList<>()).push(c);
    });
    return new LinkedList<>(bins.values());
  }

  private void createRandomPoints() {
    // east west span (longitude)
    double eastWestSpan =
        NORTH_EAST_CORNER.longitude - SOUTH_WEST_CORNER.longitude;
    // north south span
    double northSouthSpan =
        NORTH_EAST_CORNER.latitude - SOUTH_WEST_CORNER.latitude;

    for (int i = 0; i < POINT_COUNT; i++) {
      double longitudeOffset =
          randomNumberGenerator.nextDouble() * eastWestSpan;
      double latitudeOffset =
          randomNumberGenerator.nextDouble() * northSouthSpan;

      GeoCoordinates coordinates =
          new GeoCoordinates(SOUTH_WEST_CORNER.latitude + latitudeOffset,
                             SOUTH_WEST_CORNER.longitude + longitudeOffset);

      int free = randomNumberGenerator.nextInt(3);
      int occupied = randomNumberGenerator.nextInt(3);
      // make sure at least one slot
      free = free + occupied == 0 ? 1 : free;

      stations.add(new ChargingStation(coordinates, free, occupied));
    }
  }
}
