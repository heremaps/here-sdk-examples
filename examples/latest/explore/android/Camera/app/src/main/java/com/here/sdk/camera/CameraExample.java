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

 package com.here.sdk.camera;

 import android.app.Activity;
 import android.content.Context;

 import androidx.annotation.NonNull;
 import androidx.appcompat.app.AlertDialog.Builder;
 import android.util.Log;
 import android.widget.ImageView;
 import android.widget.Toast;

 import com.here.sdk.core.Color;
 import com.here.sdk.core.GeoCircle;
 import com.here.sdk.core.GeoCoordinates;
 import com.here.sdk.core.GeoOrientationUpdate;
 import com.here.sdk.core.GeoPolygon;
 import com.here.sdk.core.Point2D;
 import com.here.sdk.mapview.MapCamera;
 import com.here.sdk.mapview.MapCameraListener;
 import com.here.sdk.mapview.MapPolygon;
 import com.here.sdk.mapview.MapView;

 /**
  * This example shows how to use the Camera class to rotate and tilt the map programmatically, to set
  * a new transform center that influences those operations, and to move to a new location.
  * For more features of the Camera class, please consult the API Reference and the Developer's Guide.
  */
 public class CameraExample {

     private static final float DEFAULT_DISTANCE_TO_EARTH_IN_METERS = 8000;

     private Context context;
     private MapView mapView;
     private MapCamera camera;
     private ImageView cameraTargetView;
     private MapPolygon poiMapCircle;

     public void onMapSceneLoaded(Context context, MapView mapView) {
         this.context = context;
         this.mapView = mapView;

         camera = mapView.getCamera();
         camera.lookAt(new GeoCoordinates(52.750731,13.007375), DEFAULT_DISTANCE_TO_EARTH_IN_METERS);

         // The red circle dot indicates the camera's current target location.
         // By default, the dot is centered on the full screen map view.
         // Same as the camera, which is also centered above the map view.
         // Later on, we will adjust the dot's location on screen programmatically when the camera's target changes.
         cameraTargetView = ((Activity) context).findViewById(R.id.cameraTargetDot);

         // The POI MapCircle (green) indicates the next location to move to.
         updatePoiCircle(getRandomGeoCoordinates());

         addCameraObserver();
         setTapGestureHandler(mapView);

         showDialog("Note", "Tap the map to set a new transform center.");
     }

     public void rotateButtonClicked() {
         rotateMap(10);
     }

     public void tiltButtonClicked() {
         tiltMap(5);
     }

     public void moveToXYButtonClicked() {
         GeoCoordinates geoCoordinates = getRandomGeoCoordinates();
         updatePoiCircle(geoCoordinates);
         camera.flyTo(geoCoordinates);
     }

     // Rotate the map by x degrees. Tip: Try to see what happens for negative values.
     private void rotateMap(int bearingStepInDegrees) {
         double currentBearing = camera.getState().orientationAtTarget.bearing;
         double newBearing = currentBearing + bearingStepInDegrees;

         //By default, bearing will be clamped to the range (0, 360].
         GeoOrientationUpdate orientationUpdate = new GeoOrientationUpdate(newBearing, null);
         camera.setOrientationAtTarget(orientationUpdate);
     }

     // Tilt the map by x degrees.
     private void tiltMap(int tiltStepInDegrees) {
         double currentTilt = camera.getState().orientationAtTarget.tilt;
         double newTilt = currentTilt + tiltStepInDegrees;

         //By default, tilt will be clamped to the range [0, 70].
         GeoOrientationUpdate orientationUpdate = new GeoOrientationUpdate(null, newTilt);
         camera.setOrientationAtTarget(orientationUpdate);
     }

     private void setTapGestureHandler(MapView mapView) {
         mapView.getGestures().setTapListener(this::setTransformCenter);
     }

     // The new transform center will be used for all programmatical map transformations
     // and determines where the target is located in the view.
     // By default, the target point is located at the center of the view.
     // Note: Gestures are not affected, for example, the pinch-rotate gesture and
     // the two-finger-pan (=> tilt) will work like before.
     private void setTransformCenter(Point2D mapViewTouchPointInPixels) {
         // Note that this moves the current camera's target at the locatiion where you tapped the screen.
         // Effectively, you move the map by changing the camera's target.
         camera.setPrincipalPoint(mapViewTouchPointInPixels);

         // Reposition circle view on screen to indicate the new target.
         cameraTargetView.setX((float) mapViewTouchPointInPixels.x - cameraTargetView.getWidth() / 2);
         cameraTargetView.setY((float) mapViewTouchPointInPixels.y - cameraTargetView.getHeight() / 2);

         Toast.makeText(context, "New transform center: " +
                 mapViewTouchPointInPixels.x + ", " +
                 mapViewTouchPointInPixels.y, Toast.LENGTH_SHORT).show();
     }

     private void updatePoiCircle(GeoCoordinates geoCoordinates) {
         if (poiMapCircle != null) {
             mapView.getMapScene().removeMapPolygon(poiMapCircle);
         }
         poiMapCircle = createMapCircle(geoCoordinates);
         mapView.getMapScene().addMapPolygon(poiMapCircle);
     }

     private MapPolygon createMapCircle(GeoCoordinates geoCoordinates) {
         float radiusInMeters = 300;
         GeoCircle geoCircle = new GeoCircle(geoCoordinates, radiusInMeters);

         GeoPolygon geoPolygon = new GeoPolygon(geoCircle);
         Color fillColor = Color.valueOf(0, 1, 0, 1); // RGBA
         MapPolygon mapPolygon = new MapPolygon(geoPolygon, fillColor);

         return mapPolygon;
     }

     private final MapCameraListener cameraListener = new MapCameraListener() {
         @Override
         public void onMapCameraUpdated(@NonNull MapCamera.State state) {
             GeoCoordinates camTarget = state.targetCoordinates;
             Log.d("CameraListener", "New camera target: " +
                     camTarget.latitude + ", " + camTarget.longitude);
         }
     };

     private void addCameraObserver() {
         mapView.getCamera().addListener(cameraListener);
     }

     private GeoCoordinates getRandomGeoCoordinates() {
         GeoCoordinates currentTarget = camera.getState().targetCoordinates;
         double amount = 0.05;
         double latitude = getRandom(currentTarget.latitude - amount, currentTarget.latitude + amount);
         double longitude = getRandom(currentTarget.longitude - amount, currentTarget.longitude + amount);
         return new GeoCoordinates(latitude, longitude);
     }

     private double getRandom(double min, double max) {
         return min + Math.random() * (max - min);
     }

     private void showDialog(String title, String message) {
         Builder builder = new Builder(context);
         builder.setTitle(title);
         builder.setMessage(message);
         builder.show();
     }
 }
