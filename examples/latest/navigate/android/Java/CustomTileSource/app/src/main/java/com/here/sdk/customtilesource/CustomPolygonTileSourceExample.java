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

 import com.here.sdk.core.GeoCoordinates;
 import com.here.sdk.mapview.JsonStyleFactory;
 import com.here.sdk.mapview.MapCamera;
 import com.here.sdk.mapview.MapCameraLimits;
 import com.here.sdk.mapview.MapContentType;
 import com.here.sdk.mapview.MapLayer;
 import com.here.sdk.mapview.MapLayerBuilder;
 import com.here.sdk.mapview.MapLayerPriority;
 import com.here.sdk.mapview.MapLayerPriorityBuilder;
 import com.here.sdk.mapview.MapLayerVisibilityRange;
 import com.here.sdk.mapview.MapMeasure;
 import com.here.sdk.mapview.MapView;
 import com.here.sdk.mapview.Style;
 import com.here.sdk.mapview.datasource.PolygonTileDataSource;

 /**
 * This example app demonstrates how to load custom polygon layers, implement polygon rendering using a custom polygon tile source, 
 * and integrate custom styles. It enables the display of custom polygon tiles with configurable styling, with data sourced 
 * either from the local file system or a custom backend. However, we have not shown how to use a custom backend in this example.
 * 
 * In this implementation, custom polygon data is provided to the HERE SDK based on the requested `TileKey`, allowing dynamic 
 * rendering of polygon geometries. 
 * 
 * Note: `PolygonTileDataSource` is triggered based on the viewport (visible data), while the points for `MapPolygon` need to be 
 * provided upfront. For rendering up to 2000 polygons `MapPolygon` is sufficient. However, it is recommended to use `PolygonTileDataSource` 
 * in place of `MapPolygon` when rendering for more polygons, as it is more memory efficient.
 */
 public class CustomPolygonTileSourceExample {
     private static final String TAG = "CustomPolygonTileSource";

     private final static String LAYER_STYLE =
            "{\n" + 
            "  \"styles\": [\n" + 
            "    {\n" + 
            "      \"layer\": \"MyPolygonDataSourceLayer\",\n" + 
            "      \"technique\": \"polygon\",\n" + 
            "      \"attr\": {\n" +
            "        \"color\": \"#FF000066\"\n" +
            "      }\n" + 
            "    }\n" + 
            "  ]\n" + 
            "}";

     private final MapView mapView;
     private final MapLayer polygonMapLayer;
     private final PolygonTileDataSource polygonDataSource;
     private final Context context;

     CustomPolygonTileSourceExample(MapView mapView, Context context) {
         this.mapView = mapView;
         this.context = context;

         MapCamera camera = mapView.getCamera();
         MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.ZOOM_LEVEL, 9);
         camera.lookAt(new GeoCoordinates(52.530932, 13.384915), mapMeasureZoom);

         String dataSourceName = "MyPolygonDataSource";
         polygonDataSource = createPolygonDataSource(dataSourceName);
         polygonMapLayer = createMapLayer(dataSourceName);

         if (polygonMapLayer != null) {
             polygonMapLayer.setEnabled(false);
             polygonMapLayer.setStyle(createCustomStyle());
         }
     }

     public void enableLayer() {
         if (polygonMapLayer != null) {
             polygonMapLayer.setEnabled(true);
             Log.d(TAG, "Polygon layer enabled");
         }
     }

     public void disableLayer() {
         if (polygonMapLayer != null) {
             polygonMapLayer.setEnabled(false);
             Log.d(TAG, "Polygon layer disabled");
         }
     }

     private PolygonTileDataSource createPolygonDataSource(String dataSourceName) {
         Log.d(TAG, "Creating polygon data source: " + dataSourceName);
         return PolygonTileDataSource.create(mapView.getMapContext(), dataSourceName, new LocalPolygonTileSource());
     }

     private MapLayer createMapLayer(String dataSourceName) {
         // Set the layer to be rendered on top of other layers.
         MapLayerPriority priority = new MapLayerPriorityBuilder().renderedLast().build();
         // The minimum tilt level is 0 and maximum zoom level is 23.
         MapLayerVisibilityRange range = new MapLayerVisibilityRange(MapCameraLimits.MIN_TILT, MapCameraLimits.MAX_ZOOM_LEVEL);

         try {
             return new MapLayerBuilder()
                     .forMap(mapView.getHereMap())
                     .withName(dataSourceName + "Layer")
                     .withDataSource(dataSourceName, MapContentType.POLYGON)
                     .withPriority(priority)
                     .withVisibilityRange(range)
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
         if (polygonMapLayer != null) {
             polygonMapLayer.destroy();
         }
         if (polygonDataSource != null) {
             polygonDataSource.destroy();
         }
     }
 }
