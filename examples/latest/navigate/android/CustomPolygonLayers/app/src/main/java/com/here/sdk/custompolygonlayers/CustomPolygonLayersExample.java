 /*
  * Copyright (C) 2019-2024 HERE Europe B.V.
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

 package com.here.sdk.custompolygonlayers;

 import androidx.annotation.NonNull;

 import java.util.ArrayList;
 import java.util.List;
 import java.util.Random;

 import com.here.sdk.core.GeoCircle;
 import com.here.sdk.core.GeoCoordinates;
 import com.here.sdk.core.GeoPolygon;
 import com.here.sdk.mapview.JsonStyleFactory;
 import com.here.sdk.mapview.MapCamera;
 import com.here.sdk.mapview.MapContentType;
 import com.here.sdk.mapview.MapLayer;
 import com.here.sdk.mapview.MapLayerBuilder;
 import com.here.sdk.mapview.MapLayerPriority;
 import com.here.sdk.mapview.MapLayerPriorityBuilder;
 import com.here.sdk.mapview.MapLayerVisibilityRange;
 import com.here.sdk.mapview.MapMeasure;
 import com.here.sdk.mapview.MapView;
 import com.here.sdk.mapview.Style;
 import com.here.sdk.mapview.datasource.DataAttributesAccessor;
 import com.here.sdk.mapview.datasource.DataAttributesBuilder;
 import com.here.sdk.mapview.datasource.PolygonData;
 import com.here.sdk.mapview.datasource.PolygonDataAccessor;
 import com.here.sdk.mapview.datasource.PolygonDataBuilder;
 import com.here.sdk.mapview.datasource.PolygonDataSource;
 import com.here.sdk.mapview.datasource.PolygonDataSourceBuilder;

 public class CustomPolygonLayersExample {
     private static final float MAX_GEO_COORDINATES_OFFSET = 0.5f;
     public static final double LATITUDE = 52.530932;
     public static final double LONGITUDE = 13.384915;
     public static final double MAX_RADIUS_IN_METERS = 3000;
     public static final String ID_ATTRIBUTE_NAME = "polygon_id";
     public static final String COLOR_ATTRIBUTE_NAME = "polygon_color";
     public static final String LATITUDE_ATTRIBUTE_NAME = "center_latitude";
     public static final String LONGITUDE_ATTRIBUTE_NAME = "center_longitude";

     // Style for layer with 'technique' equal to 'polygon', 'layer' field equal to name of
     // map layer constructed later in code and 'color' attribute govern by
     // 'polygon_color' data attribute to be able to customize/modify colors of polygons.
     // See 'Developer Guide/Style guide for custom layers' and
     // 'Developer Guide/Style techniques reference for custom layers/polygon' for more details.
     private final static String LAYER_STYLE =
             "{\n"
             + "  \"styles\": [\n"
             + "    {\n"
             + "      \"layer\": \"MyPolygonDataSourceLayer\",\n"
             + "      \"technique\": \"polygon\",\n"
             + "      \"attr\": {\n"
             + "        \"color\": [\"to-color\", [\"get\", \"polygon_color\"]]\n"
             + "      }\n"
             + "    }\n"
             + "  ]\n"
             + "}";

     private MapView mapView;
     private MapLayer polygonMapLayer;
     private PolygonDataSource polygonDataSource;

     public CustomPolygonLayersExample(MapView mapView) {
         this.mapView = mapView;

         MapCamera camera = mapView.getCamera();
         MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.ZOOM_LEVEL, 9);
         camera.lookAt(new GeoCoordinates(LATITUDE, LONGITUDE), mapMeasureZoom);

         String dataSourceName = "MyPolygonDataSource";
         polygonDataSource = createPolygonDataSource(dataSourceName);
         polygonMapLayer = createMapLayer(dataSourceName);

         addRandomPolygons(100);
     }

     public void enableButtonClicked() {
         polygonMapLayer.setEnabled(true);
     }

     public void disableButtonClicked() {
         polygonMapLayer.setEnabled(false);
     }

     private GeoCoordinates generateRandomCoordinates() {
         return new GeoCoordinates((Math.random() * 2 - 1) * MAX_GEO_COORDINATES_OFFSET + LATITUDE,
                 (Math.random() * 2 - 1) * MAX_GEO_COORDINATES_OFFSET + LONGITUDE);
     }

     public void addRandomPolygons(int numberOfPolygons) {
         List<PolygonData> polygons = new ArrayList<>();
         for (int i = 0; i < numberOfPolygons; i++) {
             polygons.add(generateRandomPolygon());
         }
         polygonDataSource.add(polygons);
     }

     public void removeAllPolygons() {
         polygonDataSource.removeAll();
     }

     public void modifyPolygons() {
         polygonDataSource.forEach(new PolygonDataSource.PolygonDataProcessor() {
             @Override
             public boolean process(@NonNull PolygonDataAccessor polygonDataAccessor) {
                 DataAttributesAccessor attributesAccessor = polygonDataAccessor.getAttributes();
                 // 'process' function is executed on each item in data source so here is place to
                 // perform some kind of filtering. In our case we decide, based on parity of
                 //  'polygon_id' data attribute, to either modify color or geometry of item.
                 Long objectId = attributesAccessor.getInt64(ID_ATTRIBUTE_NAME);
                 if (objectId % 2 == 0) {
                     // modify color
                     attributesAccessor.addOrReplace(COLOR_ATTRIBUTE_NAME, getRandomColorString());
                 } else {
                     // read back polygon center
                     GeoCoordinates center = new GeoCoordinates(
                             attributesAccessor.getDouble(LATITUDE_ATTRIBUTE_NAME),
                             attributesAccessor.getDouble(LONGITUDE_ATTRIBUTE_NAME));
                     // set new geometry centered at previous location
                     polygonDataAccessor.setGeometry(generateRandomGeoPolygon(center));
                 }
                 // Return value 'True' denotes we want to keep processing subsequent items in data
                 // source. In case of performing modification on just one item, we could return
                 // 'False' after processing the proper one.
                 return true;
             }
         });
     }

     private PolygonData generateRandomPolygon() {
         GeoCoordinates center = generateRandomCoordinates();
         DataAttributesBuilder attributesBuilder = new DataAttributesBuilder()
                 .with(ID_ATTRIBUTE_NAME, Math.round( Math.random() ))
                 .with(COLOR_ATTRIBUTE_NAME, getRandomColorString())
                 .with(LATITUDE_ATTRIBUTE_NAME, center.latitude)
                 .with(LONGITUDE_ATTRIBUTE_NAME, center.longitude);

         PolygonData polygonData = new PolygonDataBuilder()
                 .withAttributes(attributesBuilder.build())
                 .withGeometry(generateRandomGeoPolygon(center))
                 .build();
         return polygonData;
     }

     @NonNull
     private GeoPolygon generateRandomGeoPolygon(GeoCoordinates coordinates) {
         GeoCircle geoCircle = new GeoCircle(coordinates, Math.random() * MAX_RADIUS_IN_METERS);
         return new GeoPolygon(geoCircle);
     }

     @NonNull
     private static String getRandomColorString() {
         return String.format("#%06xff", new Random().nextInt(0xffffff + 1));
     }

     private PolygonDataSource createPolygonDataSource(String dataSourceName) {
         return new PolygonDataSourceBuilder(mapView.getMapContext())
                 .withName(dataSourceName)
                 .build();
     }

     private Style createCustomStyle() {
         try {
             return JsonStyleFactory.createFromString(LAYER_STYLE);
         } catch (JsonStyleFactory.InstantiationException e) {
             throw new RuntimeException(e);
         }
     }
     private MapLayer createMapLayer(String dataSourceName) {
         // The layer should be rendered on top of other layers.
         MapLayerPriority priority = new MapLayerPriorityBuilder().renderedLast().build();
         // And it should be visible for all zoom levels.
         MapLayerVisibilityRange range = new MapLayerVisibilityRange(0, 22 + 1);

         try {
             // Build and add the layer to the map.
             MapLayer mapLayer = new MapLayerBuilder()
                     .forMap(mapView.getHereMap())
                     .withName(dataSourceName + "Layer")
                     .withDataSource(dataSourceName, MapContentType.POLYGON)
                     .withPriority(priority)
                     .withVisibilityRange(range)
                     .withStyle(createCustomStyle())
                     .build();
             return mapLayer;
         } catch (MapLayerBuilder.InstantiationException e) {
             throw new RuntimeException(e.getMessage());
         }
     }

     public void onDestroy() {
         polygonMapLayer.destroy();
         polygonDataSource.destroy();
     }
 }
