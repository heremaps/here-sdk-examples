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

 package com.here.sdk.camera;

 import android.app.Activity;
 import android.content.Context;
 import androidx.annotation.NonNull;
 import androidx.appcompat.app.AlertDialog.Builder;
 import android.util.Log;
 import android.view.animation.AccelerateDecelerateInterpolator;
 import android.widget.ImageView;
 import android.widget.Toast;

 import com.here.sdk.core.Anchor2D;
 import com.here.sdk.core.GeoCircle;
 import com.here.sdk.core.GeoCoordinates;
 import com.here.sdk.core.Point2D;
 import com.here.sdk.mapviewlite.Camera;
 import com.here.sdk.mapviewlite.CameraObserver;
 import com.here.sdk.mapviewlite.CameraUpdate;
 import com.here.sdk.mapviewlite.MapCircle;
 import com.here.sdk.mapviewlite.MapCircleStyle;
 import com.here.sdk.mapviewlite.MapViewLite;
 import com.here.sdk.mapviewlite.PixelFormat;

 /**
  * This example shows how to use the Camera class to rotate and tilt the map programmatically, to set
  * a new transform center that influences those operations, and to move to a new location using
  * Android's Animation framework.
  * For more features of the Camera class, please consult the API Reference and the Developer's Guide.
  */
 public class CameraExample {

     private static final float DEFAULT_ZOOM_LEVEL = 14;

     private Context context;
     private MapViewLite mapView;
     private Camera camera;
     private CameraAnimator cameraAnimator;
     private ImageView cameraTargetView;
     private MapCircle poiMapCircle;

     public void onMapSceneLoaded(Context context, MapViewLite mapView) {
         this.context = context;
         this.mapView = mapView;

         camera = mapView.getCamera();
         camera.setTarget(new GeoCoordinates(52.750731,13.007375));
         camera.setZoomLevel(DEFAULT_ZOOM_LEVEL);

         cameraAnimator = new CameraAnimator(camera);
         cameraAnimator.setTimeInterpolator(new AccelerateDecelerateInterpolator());

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
         cameraAnimator.moveTo(geoCoordinates, DEFAULT_ZOOM_LEVEL);
     }

     // Rotate the map by x degrees. Tip: Try to see what happens for negative values.
     private void rotateMap(int bearingStepInDegrees) {
         double currentBearing = camera.getBearing();
         double newBearing = currentBearing + bearingStepInDegrees;

         //By default, bearing will be clamped to the range (0, 360].
         camera.setBearing(newBearing);
     }

     // Tilt the map by x degrees.
     private void tiltMap(int tiltStepInDegrees) {
         double currentTilt = camera.getTilt();
         double newTilt = currentTilt + tiltStepInDegrees;

         //By default, tilt will be clamped to the range [0, 70].
         camera.setTilt(newTilt);
     }

     private void setTapGestureHandler(MapViewLite mapView) {
         mapView.getGestures().setTapListener(this::setTransformCenter);
     }

     // The new transform center will be used for all programmatical map transformations (like rotate and tilt)
     // and determines where the target is located in the view.
     // By default, the anchor point is located at x = 0.5, y = 0.5.
     // Note: Gestures are not affected, for example, the pinch-rotate gesture and
     // the two-finger-pan (=> tilt) will work like before.
     private void setTransformCenter(Point2D mapViewPoint) {
         double normalizedX = (1F / mapView.getWidth()) * mapViewPoint.x;
         double normalizedY = (1F / mapView.getHeight()) * mapViewPoint.y;

         Anchor2D transformationCenter = new Anchor2D(normalizedX, normalizedY);
         camera.setTargetAnchorPoint(transformationCenter);

         // Reposition view on screen to indicate the new target.
         cameraTargetView.setX((float) mapViewPoint.x - cameraTargetView.getWidth() / 2);
         cameraTargetView.setY((float) mapViewPoint.y - cameraTargetView.getHeight() / 2);

         Toast.makeText(context, "New transform center: " +
                         transformationCenter.horizontal + ", " +
                         transformationCenter.vertical, Toast.LENGTH_SHORT).show();
     }

     private void updatePoiCircle(GeoCoordinates geoCoordinates) {
         if (poiMapCircle != null) {
             mapView.getMapScene().removeMapCircle(poiMapCircle);
         }
         poiMapCircle = createMapCircle(geoCoordinates, 0x00FF00A0, 80d, 1000);
         mapView.getMapScene().addMapCircle(poiMapCircle);
     }

     private MapCircle createMapCircle(GeoCoordinates geoCoordinates,
                                       long color, double radiusInMeters, long drawOrder) {
         GeoCircle geoCircle = new GeoCircle(geoCoordinates, radiusInMeters);
         MapCircleStyle mapCircleStyle = new MapCircleStyle();
         mapCircleStyle.setFillColor(color, PixelFormat.RGBA_8888);
         mapCircleStyle.setDrawOrder(drawOrder);
         return new MapCircle(geoCircle, mapCircleStyle);
     }

     private final CameraObserver cameraObserver = new CameraObserver() {
         @Override
         public void onCameraUpdated(@NonNull CameraUpdate cameraUpdate) {
             GeoCoordinates camTarget = cameraUpdate.target;
             Log.d("CameraObserver", "New camera target: " +
                     camTarget.latitude + ", " + camTarget.longitude);
         }
     };

     private void addCameraObserver() {
         mapView.getCamera().addObserver(cameraObserver);
     }

     private GeoCoordinates getRandomGeoCoordinates() {
         GeoCoordinates currentTarget = camera.getTarget();
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
