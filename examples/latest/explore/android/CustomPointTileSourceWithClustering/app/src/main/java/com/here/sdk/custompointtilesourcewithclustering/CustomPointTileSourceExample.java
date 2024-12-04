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

import android.os.Looper;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.mapview.HereMap;
import com.here.sdk.mapview.JsonStyleFactory;
import com.here.sdk.mapview.MapContentType;
import com.here.sdk.mapview.MapLayer;
import com.here.sdk.mapview.MapLayerBuilder;
import com.here.sdk.mapview.MapLayerPriority;
import com.here.sdk.mapview.MapLayerPriorityBuilder;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapView;
import com.here.sdk.mapview.Style;
import com.here.sdk.mapview.datasource.PointTileDataSource;

public class CustomPointTileSourceExample {

  private final static String DATASOURCE_NAME = "custom_point_tile_datasource";

  private MapView mapView;
  private LocalPointTileSource mTileSource;
  private PointTileDataSource mDataSource;
  private MapLayer mLayer;

  public void onMapSceneLoaded(MapView mapView) {
    this.mapView = mapView;

    // The camera can be configured before or after a scene is loaded.
    mapView.getCamera().lookAt(
        new GeoCoordinates(52.51723846978555, 13.3734757987928),
        new MapMeasure(MapMeasure.Kind.ZOOM_LEVEL, 11));

    createPointTileDatasourceAndLayer(mapView, createPointLayerStyle());
  }

  private void createPointTileDatasourceAndLayer(MapView mapView, Style style) {
    // check for main thread
    if (Looper.myLooper() != Looper.getMainLooper()) {
      throw new AssertionError();
    }

    mTileSource = new LocalPointTileSource();
    mDataSource = PointTileDataSource.create(mapView.getMapContext(),
                                             DATASOURCE_NAME, mTileSource);

    HereMap hereMap = mapView.getHereMap();

    MapLayerPriority priority =
        new MapLayerPriorityBuilder().renderedLast().build();

    try {
      MapLayerBuilder newLayerBuilder =
          new MapLayerBuilder()
              .withName(LocalPointTileSource.LAYER_NAME)
              .withPriority(priority)
              .forMap(hereMap)
              .withDataSource(DATASOURCE_NAME, MapContentType.POINT);
      if (style != null) {
        newLayerBuilder.withStyle(style);
      }
      mLayer = newLayerBuilder.build();
    } catch (MapLayerBuilder.InstantiationException e) {
      throw new AssertionError();
    }
  }

  private Style createPointLayerStyle() {
    try {
      return JsonStyleFactory.createFromString(
          LocalPointTileSource.LAYER_STYLE);
    } catch (JsonStyleFactory.InstantiationException e) {
      throw new AssertionError();
    }
  }
  public void onDestroy() {
    mLayer.destroy();
    mDataSource.destroy();
  }
}
