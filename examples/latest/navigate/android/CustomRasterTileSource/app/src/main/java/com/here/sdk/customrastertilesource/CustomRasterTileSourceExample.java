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

 package com.here.sdk.customrastertilesource;

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

 public class CustomRasterTileSourceExample {

     private static final float DEFAULT_DISTANCE_TO_EARTH_IN_METERS = 60 * 1000;

     private MapView mapView;
     private MapLayer rasterMapLayerStyle;
     private RasterDataSource rasterDataSourceStyle;
     private Context context;

     public void onMapSceneLoaded(MapView mapView, Context context) {
         this.mapView = mapView;
         this.context = context;

         MapCamera camera = mapView.getCamera();
         MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, DEFAULT_DISTANCE_TO_EARTH_IN_METERS);
         camera.lookAt(new GeoCoordinates(52.530932, 13.384915), mapMeasureZoom);

         String dataSourceName = "myRasterDataSourceStyle";
         rasterDataSourceStyle = createRasterDataSource(dataSourceName);
         rasterMapLayerStyle = createMapLayer(dataSourceName);

         // We want to start with the default map style.
         rasterMapLayerStyle.setEnabled(false);

         // Add a POI marker
         addPOIMapMarker(new GeoCoordinates(52.530932, 13.384915));
     }

     public void enableButtonClicked() {
         rasterMapLayerStyle.setEnabled(true);
     }

     public void disableButtonClicked() {
         rasterMapLayerStyle.setEnabled(false);
     }

     private RasterDataSource createRasterDataSource(String dataSourceName) {
         // Create a RasterDataSource over a local raster tile source.
         // Note that this will make the raster source already known to the passed map view.
         return new RasterDataSource(mapView.getMapContext(), dataSourceName, new LocalRasterTileSource());
     }

     private MapLayer createMapLayer(String dataSourceName) {
         // The layer should be rendered on top of other layers except the "labels" layer
         // so that we don't overlap the raster layer over POI markers.
         MapLayerPriority priority = new MapLayerPriorityBuilder().renderedBeforeLayer("labels").build();

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
