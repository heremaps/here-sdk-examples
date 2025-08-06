 /*
  * Copyright (C) 2019-2025 HERE Europe B.V.
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

 package com.here.sdk.custommapstyles;

 import android.content.Context;
 import android.content.res.AssetManager;
 import android.util.Log;

 import androidx.annotation.Nullable;

 import com.here.sdk.core.GeoCoordinates;
 import com.here.sdk.mapview.MapCamera;
 import com.here.sdk.mapview.MapError;
 import com.here.sdk.mapview.MapMeasure;
 import com.here.sdk.mapview.MapScene;
 import com.here.sdk.mapview.MapScheme;
 import com.here.sdk.mapview.MapView;

 import java.io.IOException;

 public class CustomMapStylesExample {

     private static final float DEFAULT_DISTANCE_TO_EARTH_IN_METERS = 200 * 1000;
     private Context context;
     private MapView mapView;

     public void onMapSceneLoaded(Context context, MapView mapView) {
         this.context = context;
         this.mapView = mapView;

         MapCamera camera = mapView.getCamera();
         MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, DEFAULT_DISTANCE_TO_EARTH_IN_METERS);
         camera.lookAt(new GeoCoordinates(52.530932, 13.384915), mapMeasureZoom);
     }

     public void loadButtonClicked() {
         loadMapStyle();
     }

     private void loadMapStyle() {
         // Place the style into the "assets" directory.
         // Full path example: app/src/main/assets/mymapstyle.json
         // Adjust file name and path as appropriate for your project.
         String fileName = "custom-dark-style-neon-rds.json";
         AssetManager assetManager = context.getAssets();
         try {
             assetManager.open(fileName);
         } catch (IOException e) {
             Log.e("CustomMapStylesExample", "Error: Map style not found!");
             return;
         }

         mapView.getMapScene().loadScene("" + fileName, new MapScene.LoadSceneCallback() {
             @Override
             public void onLoadScene(@Nullable MapError mapError) {
                 if (mapError == null) {
                     // Scene loaded.
                 } else {
                     Log.d("CustomMapStylesExample", "onLoadScene failed: " + mapError);
                 }
             }
         });
     }

     public void unloadButtonClicked() {
         mapView.getMapScene().loadScene(MapScheme.NORMAL_DAY, new MapScene.LoadSceneCallback() {
             @Override
             public void onLoadScene(@Nullable MapError mapError) {
                 if (mapError == null) {
                    // Scene loaded.
                 } else {
                     Log.d("CustomMapStylesExample", "onLoadScene failed: " + mapError);
                 }
             }
         });
     }
 }
