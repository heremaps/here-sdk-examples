 /*
  * Copyright (C) 2019-2022 HERE Europe B.V.
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

 import com.here.sdk.core.GeoCoordinates;
 import com.here.sdk.mapview.MapCamera;
 import com.here.sdk.mapview.MapContentType;
 import com.here.sdk.mapview.MapLayer;
 import com.here.sdk.mapview.MapLayerBuilder;
 import com.here.sdk.mapview.MapLayerPriority;
 import com.here.sdk.mapview.MapLayerPriorityBuilder;
 import com.here.sdk.mapview.MapLayerVisibilityRange;
 import com.here.sdk.mapview.MapMeasure;
 import com.here.sdk.mapview.MapView;
 import com.here.sdk.mapview.datasource.RasterDataSource;
 import com.here.sdk.mapview.datasource.RasterDataSourceConfiguration;
 import com.here.sdk.mapview.datasource.TilingScheme;

 import java.util.Arrays;
 import java.util.List;

 public class CustomRasterLayersExample {

     private static final float DEFAULT_DISTANCE_TO_EARTH_IN_METERS = 200 * 1000;

     private MapView mapView;
     private MapLayer rasterMapLayerTonerStyle;
     private RasterDataSource rasterDataSourceTonerStyle;

     public void onMapSceneLoaded(MapView mapView) {
         this.mapView = mapView;

         MapCamera camera = mapView.getCamera();
         MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE, DEFAULT_DISTANCE_TO_EARTH_IN_METERS);
         camera.lookAt(new GeoCoordinates(52.530932, 13.384915), mapMeasureZoom);

         String dataSourceName = "myRasterDataSourceTonerStyle";
         rasterDataSourceTonerStyle = createRasterDataSource(dataSourceName);
         rasterMapLayerTonerStyle = createMapLayer(dataSourceName);

         // We want to start with the default map style.
         rasterMapLayerTonerStyle.setEnabled(false);
     }

     public void enableButtonClicked() {
         rasterMapLayerTonerStyle.setEnabled(true);
     }

     public void disableButtonClicked() {
         rasterMapLayerTonerStyle.setEnabled(false);
     }

     // Note: Map tile data source by Stamen Design (http://stamen.com),
     // under CC BY 3.0 (http://creativecommons.org/licenses/by/3.0).
     // Data by OpenStreetMap, under ODbL (http://www.openstreetmap.org/copyright):
     // For more details, check: http://maps.stamen.com/#watercolor/12/37.7706/-122.3782.
     private RasterDataSource createRasterDataSource(String dataSourceName) {
         // The URL template that is used to download tiles from the device or a backend data source.
         String templateUrl = "https://stamen-tiles.a.ssl.fastly.net/toner/{z}/{x}/{y}.png";
         // The storage levels available for this data source. Supported range [0, 31].
         List<Integer> storageLevels = Arrays.asList(2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);
         RasterDataSourceConfiguration.Provider rasterProviderConfig = new RasterDataSourceConfiguration.Provider(
                 templateUrl,
                 TilingScheme.QUAD_TREE_MERCATOR,
                 storageLevels);

         // Raster tiles are stored in a separate cache on the device.
         String path = "cache/raster/toner";
         long maxDiskSizeInBytes = 1024 * 1024 * 32;
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
         rasterMapLayerTonerStyle.destroy();
         rasterDataSourceTonerStyle.destroy();
     }
 }
