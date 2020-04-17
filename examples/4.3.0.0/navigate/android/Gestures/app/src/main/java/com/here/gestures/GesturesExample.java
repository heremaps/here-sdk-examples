 /*
  * Copyright (C) 2019-2020 HERE Europe B.V.
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

package com.here.gestures;

 import android.content.Context;
 import android.support.annotation.NonNull;
 import android.util.Log;
 import android.widget.Toast;

 import com.here.sdk.core.GeoCoordinates;
 import com.here.sdk.core.Point2D;
 import com.here.sdk.gestures.DoubleTapListener;
 import com.here.sdk.gestures.GestureState;
 import com.here.sdk.gestures.GestureType;
 import com.here.sdk.gestures.LongPressListener;
 import com.here.sdk.gestures.TapListener;
 import com.here.sdk.gestures.TwoFingerTapListener;
 import com.here.sdk.mapview.MapCamera;
 import com.here.sdk.mapview.MapView;

 public class GesturesExample {

     private static final String TAG = GesturesExample.class.getSimpleName();

     private final GestureMapAnimator gestureMapAnimator;

     public GesturesExample(Context context, MapView mapView) {
         MapCamera camera = mapView.getCamera();
         double distanceInMeters = 1000 * 10;
         camera.lookAt(new GeoCoordinates(52.520798, 13.409408), distanceInMeters);

         gestureMapAnimator = new GestureMapAnimator(mapView.getCamera());

         setTapGestureHandler(mapView);
         setDoubleTapGestureHandler(mapView);
         setTwoFingerTapGestureHandler(mapView);
         setLongPressGestureHandler(mapView);

         // Disable the default map gesture behavior for DoubleTap (zooms in) and TwoFingerTap (zooms out)
         // as we want to enable custom map animations when such gestures are detected.
         mapView.getGestures().disableDefaultAction(GestureType.DOUBLE_TAP);
         mapView.getGestures().disableDefaultAction(GestureType.TWO_FINGER_TAP);

         Toast.makeText(context, "Shows Tap and LongPress gesture handling. " +
                 "See log for details. DoubleTap / TwoFingerTap map action (zoom in/out) is disabled " +
                 "and replaced with a custom animation.", Toast.LENGTH_LONG).show();
     }

     private void setTapGestureHandler(MapView mapView) {
         mapView.getGestures().setTapListener(new TapListener() {
             @Override
             public void onTap(@NonNull Point2D touchPoint) {
                 GeoCoordinates geoCoordinates = mapView.viewToGeoCoordinates(touchPoint);
                 Log.d(TAG, "Tap at: " + geoCoordinates);
             }
         });
     }

     private void setDoubleTapGestureHandler(MapView mapView) {
         mapView.getGestures().setDoubleTapListener(new DoubleTapListener() {
             @Override
             public void onDoubleTap(@NonNull Point2D touchPoint) {
                 GeoCoordinates geoCoordinates = mapView.viewToGeoCoordinates(touchPoint);
                 Log.d(TAG, "Default zooming in is disabled. DoubleTap at: " + geoCoordinates);

                 // Start our custom zoom in animation.
                 gestureMapAnimator.zoomIn(touchPoint);
             }
         });
     }

     private void setTwoFingerTapGestureHandler(MapView mapView) {
         mapView.getGestures().setTwoFingerTapListener(new TwoFingerTapListener() {
             @Override
             public void onTwoFingerTap(@NonNull Point2D touchCenterPoint) {
                 GeoCoordinates geoCoordinates = mapView.viewToGeoCoordinates(touchCenterPoint);
                 Log.d(TAG, "Default zooming in is disabled. TwoFingerTap at: " + geoCoordinates);

                 // Start our custom zoom out animation.
                 gestureMapAnimator.zoomOut(touchCenterPoint);
             }
         });
     }

     private void setLongPressGestureHandler(MapView mapView) {
         mapView.getGestures().setLongPressListener(new LongPressListener() {
             @Override
             public void onLongPress(@NonNull GestureState gestureState, @NonNull Point2D touchPoint) {
                 GeoCoordinates geoCoordinates = mapView.viewToGeoCoordinates(touchPoint);

                 if (gestureState == GestureState.BEGIN) {
                     Log.d(TAG, "LongPress detected at: " + geoCoordinates);
                 }

                 if (gestureState == GestureState.UPDATE) {
                     Log.d(TAG, "LongPress update at: " + geoCoordinates);
                 }

                 if (gestureState == GestureState.END) {
                     Log.d(TAG, "LongPress finger lifted at: " + geoCoordinates);
                 }
             }
         });
     }

     // This is just an example how to clean up.
     @SuppressWarnings("unused")
     private void removeGestureHandler(MapView mapView) {
         // Stop listening.
         mapView.getGestures().setTapListener(null);
         mapView.getGestures().setDoubleTapListener(null);
         mapView.getGestures().setTwoFingerTapListener(null);
         mapView.getGestures().setLongPressListener(null);

         // Bring back the default map gesture behavior for DoubleTap (zooms in)
         // and TwoFingerTap (zooms out). These actions were disabled above.
         mapView.getGestures().enableDefaultAction(GestureType.DOUBLE_TAP);
         mapView.getGestures().enableDefaultAction(GestureType.TWO_FINGER_TAP);
     }
}
