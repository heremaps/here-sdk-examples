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

 package com.here.sdk.custompointtilesource;

 import android.content.Context;

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
 import com.here.sdk.mapview.datasource.PointTileDataSource;

 public class CustomPointTileSourceExample {

     private static final float DEFAULT_DISTANCE_TO_EARTH_IN_METERS = 60 * 1000;

     // Style for layer with 'technique' equal to 'icon-text', 'layer' field equal to name of
     // map layer constructed later in code and 'text' attribute govern by 'pointText' data
     // attribute to be able to customize/modify the text of points.
     // See 'Developer Guide/Style guide for custom layers' and
     // 'Developer Guide/Style techniques reference for custom layers/icon-text' for more details.
     private final static String LAYER_STYLE =
             "{\n"
             + "  \"styles\": [\n"
             + "    {\n"
             + "      \"layer\": \"MyPointTileDataSourceLayer\",\n"
             + "      \"technique\": \"icon-text\",\n"
             + "      \"attr\": {\n"
             + "        \"text-color\": \"#ff0000ff\",\n"
             + "        \"text-size\": 40,\n"
             + "        \"text\": [\"get\", \"pointText\"]\n"
             + "      }\n"
             + "    }\n"
             + "  ]\n"
             + "}";

     private MapView mapView;
     private MapLayer pointMapLayer;
     private PointTileDataSource pointDataSource;
     private Context context;

     public void onMapSceneLoaded(MapView mapView, Context context) {
         this.mapView = mapView;
         this.context = context;

         MapCamera camera = mapView.getCamera();
         MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, DEFAULT_DISTANCE_TO_EARTH_IN_METERS);
         camera.lookAt(new GeoCoordinates(52.530932, 13.384915), mapMeasureZoom);

         String dataSourceName = "MyPointTileDataSource";
         pointDataSource = createPointDataSource(dataSourceName);
         pointMapLayer = createMapLayer(dataSourceName);
     }

     public void enableButtonClicked() {
         pointMapLayer.setEnabled(true);
     }

     public void disableButtonClicked() {
         pointMapLayer.setEnabled(false);
     }

     private PointTileDataSource createPointDataSource(String dataSourceName) {
         // Create a PointTileDataSource using a local point tile source.
         // Note that this will make the point source already known to the passed map view.
         return PointTileDataSource.create(mapView.getMapContext(), dataSourceName, new LocalPointTileSource());
     }

     // Creates a MapLayer for displaying custom point tiles.
     private MapLayer createMapLayer(String dataSourceName) {
         // The layer should be visible for all zoom levels.
         MapLayerVisibilityRange range = new MapLayerVisibilityRange(0, 22 + 1);

         try {
             // Build and add the layer to the map.
             MapLayer mapLayer = new MapLayerBuilder()
                     .forMap(mapView.getHereMap()) // mandatory parameter
                     .withName(dataSourceName + "Layer") // mandatory parameter
                     .withDataSource(dataSourceName, MapContentType.POINT)
                     .withVisibilityRange(range)
                     .withStyle(createCustomStyle())
                     .build();
             return mapLayer;
         } catch (MapLayerBuilder.InstantiationException e) {
             throw new RuntimeException(e.getMessage());
         }
     }

     // Creates a custom style for the point layer from the predefined JSON style string.
     private Style createCustomStyle() {
         try {
             return JsonStyleFactory.createFromString(LAYER_STYLE);
         } catch (JsonStyleFactory.InstantiationException e) {
             throw new RuntimeException(e);
         }
     }
     public void onDestroy() {
         pointMapLayer.destroy();
         pointDataSource.destroy();
     }
 }
