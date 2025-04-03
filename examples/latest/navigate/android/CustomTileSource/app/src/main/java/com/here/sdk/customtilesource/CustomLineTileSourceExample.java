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

 import android.content.Context;
 import android.util.Log;

import com.here.sdk.mapview.MapCameraLimits;
 import com.here.sdk.core.GeoCoordinates;
 import com.here.sdk.mapview.JsonStyleFactory;
 import com.here.sdk.mapview.MapCamera;
 import com.here.sdk.mapview.MapContentType;
 import com.here.sdk.mapview.MapLayer;
 import com.here.sdk.mapview.MapLayerBuilder;
 import com.here.sdk.mapview.MapLayerVisibilityRange;
 import com.here.sdk.mapview.MapMeasure;
 import com.here.sdk.mapview.MapView;
 import com.here.sdk.mapview.Style;
 import com.here.sdk.mapview.datasource.LineTileDataSource;

/**
 * This example app demonstrates how to load custom line layers, implement line rendering using a custom line tile source, 
 * and integrate custom styles. It enables the display of custom line tiles with configurable styling, with data sourced 
 * either from the local file system or a custom backend.
 * 
 * In this implementation, custom line data is provided to the HERE SDK based on the requested `TileKey`, allowing dynamic 
 * rendering of line geometries. 
 */
 public class CustomLineTileSourceExample {
     private static final String TAG = "CustomLineTileSource";

     private static final String LAYER_STYLE = "{ \n" +
             "  \"styles\": [ \n" +
             "    { \n" +
             "      \"layer\": \"MyLineTileDataSourceLayer\", \n" +
             "      \"technique\": \"line\", \n" +
             "      \"attr\": { \n" +
             "        \"color\": \"#FF0000\", \n" +
             "        \"width\": [\"world-scale\", 5]\n" +
             "      } \n" +
             "    } \n" +
             "  ] \n" +
             "}\n";

     private MapView mapView;
     private MapLayer lineMapLayer;
     private LineTileDataSource lineDataSource;
     private Context context;

     public void onMapSceneLoaded(MapView mapView, Context context) {
         this.mapView = mapView;
         this.context = context;

         MapCamera camera = mapView.getCamera();
         MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.ZOOM_LEVEL, 9);
         camera.lookAt(new GeoCoordinates(52.530932, 13.384915), mapMeasureZoom);
         String dataSourceName = "MyLineTileDataSource";
         lineDataSource = createLineDataSource(dataSourceName);
         lineMapLayer = createMapLayer(dataSourceName);

         if (lineMapLayer != null) {
             lineMapLayer.setEnabled(false);
             lineMapLayer.setStyle(createCustomStyle());
         }
     }

     public void enableButtonClicked() {
         if (lineMapLayer != null) {
             lineMapLayer.setEnabled(true);
             Log.d(TAG, "Line layer enabled");
         }
     }

     public void disableButtonClicked() {
         if (lineMapLayer != null) {
             lineMapLayer.setEnabled(false);
             Log.d(TAG, "Line layer disabled");
         }
     }

     private LineTileDataSource createLineDataSource(String dataSourceName) {
         Log.d(TAG, "Creating line data source: " + dataSourceName);
         return LineTileDataSource.create(mapView.getMapContext(), dataSourceName, new LocalLineTileSource());
     }

     private MapLayer createMapLayer(String dataSourceName) {
         MapLayerVisibilityRange range = new MapLayerVisibilityRange(MapCameraLimits.MIN_TILT, MapCameraLimits.MAX_ZOOM_LEVEL);

         try {
             return new MapLayerBuilder()
                     .forMap(mapView.getHereMap())
                     .withName(dataSourceName + "Layer")
                     .withDataSource(dataSourceName, MapContentType.LINE)
                     .withVisibilityRange(range)
                     .withStyle(createCustomStyle())
                     .build();
         } catch (MapLayerBuilder.InstantiationException e) {
             Log.e(TAG, "Failed to create map layer: " + e.getMessage());
             return null;
         }
     }

     private Style createCustomStyle() {
         try {
             return JsonStyleFactory.createFromString(LAYER_STYLE);
         } catch (JsonStyleFactory.InstantiationException e) {
             Log.e(TAG, "Failed to create style: " + e.getMessage());
             throw new RuntimeException(e);
         }
     }

     public void onDestroy() {
         if (lineMapLayer != null) {
             lineMapLayer.destroy();
         }
         if (lineDataSource != null) {
             lineDataSource.destroy();
         }
     }
 }
