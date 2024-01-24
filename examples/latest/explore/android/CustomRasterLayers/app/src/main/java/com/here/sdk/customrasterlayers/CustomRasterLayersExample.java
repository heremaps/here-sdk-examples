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

 package com.here.sdk.customrasterlayers;

 import android.content.Context;

 import com.here.sdk.core.Anchor2D;
 import com.here.sdk.core.GeoCoordinates;
 import com.here.sdk.mapview.MapCamera;
 import com.here.sdk.mapview.MapContentType;
 import com.here.sdk.mapview.MapImage;
 import com.here.sdk.mapview.MapImageFactory;
 import com.here.sdk.mapview.MapLayer;
 import com.here.sdk.mapview.MapLayerBuilder;
 import com.here.sdk.mapview.MapLayerPriority;
 import com.here.sdk.mapview.MapLayerPriorityBuilder;
 import com.here.sdk.mapview.MapLayerVisibilityRange;
 import com.here.sdk.mapview.MapMarker;
 import com.here.sdk.mapview.MapMeasure;
 import com.here.sdk.mapview.MapView;
 import com.here.sdk.mapview.datasource.RasterDataSource;
 import com.here.sdk.mapview.datasource.RasterDataSourceConfiguration;
 import com.here.sdk.mapview.datasource.TileUrlProviderFactory;
 import com.here.sdk.mapview.datasource.TilingScheme;

 import java.util.Arrays;
 import java.util.List;

 public class CustomRasterLayersExample {

     private static final float DEFAULT_DISTANCE_TO_EARTH_IN_METERS = 60 * 1000;

     private MapView mapView;
     private MapLayer rasterMapLayerStyle;
     private RasterDataSource rasterDataSourceStyle;
     private Context context;

     public void onMapSceneLoaded(MapView mapView, Context context) {
         this.mapView = mapView;
         this.context = context;

         MapCamera camera = mapView.getCamera();
         MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE, DEFAULT_DISTANCE_TO_EARTH_IN_METERS);
         camera.lookAt(new GeoCoordinates(52.530932, 13.384915), mapMeasureZoom);

         String dataSourceName = "myRasterDataSourceStyle";
         rasterDataSourceStyle = createRasterDataSource(dataSourceName);
         rasterMapLayerStyle = createMapLayer(dataSourceName);

         // We want to start with the default map style.
         rasterMapLayerStyle.setEnabled(false);

         // Add a POI marker
         addPOIMapMarker(new GeoCoordinates(52.530932, 13.384915));

         // Users of the Navigate Edition can set the visibility for all the POI categories to hidden.
         // List<String> categoryIds = new ArrayList<>();
         // MapScene.setPoiVisibility(categoryIds, VisibilityState.HIDDEN);
     }

     public void enableButtonClicked() {
         rasterMapLayerStyle.setEnabled(true);
     }

     public void disableButtonClicked() {
         rasterMapLayerStyle.setEnabled(false);
     }

     private RasterDataSource createRasterDataSource(String dataSourceName) {
         // Note: As an example, below is an URL template of an outdoor layer from thunderforest.com.
         // On their web page you can register a key. Without setting a valid API key, the tiles will
         // show a watermark.
         // More details on the terms of usage can be found here: https://www.thunderforest.com/terms/
         // For example, your application must have working links to https://www.thunderforest.com
         // and https://www.osm.org/copyright.
         // For the below template URL, please pay attention to the following attribution:
         // Maps © www.thunderforest.com, Data © www.osm.org/copyright.
         // Alternatively, choose another tile provider or use the (customizable) map styles provided by HERE.
         String templateUrl = "https://tile.thunderforest.com/outdoors/{z}/{x}/{y}.png";

         // The storage levels available for this data source. Supported range [0, 31].
         List<Integer> storageLevels = Arrays.asList(2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);
         RasterDataSourceConfiguration.Provider rasterProviderConfig = new RasterDataSourceConfiguration.Provider(
                 TileUrlProviderFactory.fromXyzUrlTemplate(templateUrl),
                 TilingScheme.QUAD_TREE_MERCATOR,
                 storageLevels);

         // If you want to add transparent layers then set this to true.
         rasterProviderConfig.hasAlphaChannel = false;

         // Raster tiles are stored in a separate cache on the device.
         String path = "cache/raster/mycustomlayer";
         long maxDiskSizeInBytes = 1024 * 1024 * 128; // 128
         RasterDataSourceConfiguration.Cache cacheConfig = new RasterDataSourceConfiguration.Cache(path, maxDiskSizeInBytes);

         // Note that this will make the raster source already known to the passed map view.
         return new RasterDataSource(mapView.getMapContext(),
                 new RasterDataSourceConfiguration(dataSourceName, rasterProviderConfig, cacheConfig));
     }

     private MapLayer createMapLayer(String dataSourceName) {
         // The layer should be rendered on top of other layers.
         MapLayerPriority priority = new MapLayerPriorityBuilder().renderedLast().build();
         // And it should be visible for all zoom levels.
         MapLayerVisibilityRange range = new MapLayerVisibilityRange(0, 22 + 1);

         try {
             // Build and add the layer to the map.
             MapLayer mapLayer = new MapLayerBuilder()
                     .forMap(mapView.getHereMap()) // mandatory parameter
                     .withName(dataSourceName + "Layer") // mandatory parameter
                     .withDataSource(dataSourceName, MapContentType.RASTER_IMAGE)
                     .withPriority(priority)
                     .withVisibilityRange(range)
                     .build();
             return mapLayer;
         } catch (MapLayerBuilder.InstantiationException e) {
             throw new RuntimeException(e.getMessage());
         }
     }

     public void onDestroy() {
         rasterMapLayerStyle.destroy();
         rasterDataSourceStyle.destroy();
     }

     private void addPOIMapMarker(GeoCoordinates geoCoordinates) {
         MapImage mapImage = MapImageFactory.fromResource(context.getResources(), R.drawable.poi);

         // The bottom, middle position should point to the location.
         // By default, the anchor point is set to 0.5, 0.5.
         Anchor2D anchor2D = new Anchor2D(0.5F, 1);
         MapMarker mapMarker = new MapMarker(geoCoordinates, mapImage, anchor2D);

         mapView.getMapScene().addMapMarker(mapMarker);
     }
 }
