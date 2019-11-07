 /*
  * Copyright (C) 2019 HERE Europe B.V.
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
 import com.here.sdk.mapviewlite.Camera;
 import com.here.sdk.mapviewlite.MapViewLite;

 public class GesturesExample {

     private static final String TAG = GesturesExample.class.getSimpleName();

     public GesturesExample(Context context, MapViewLite mapView) {
         Camera camera = mapView.getCamera();
         camera.setTarget(new GeoCoordinates(52.530932, 13.384915));
         camera.setZoomLevel(14);

         setTapGestureHandler(mapView);
         setDoubleTapGestureHandler(mapView);
         setLongPressGestureHandler(mapView);

         // Disabling the default map gesture behavior for a double tap (zooms in).
         mapView.getGestures().disableDefaultAction(GestureType.DOUBLE_TAP);

         Toast.makeText(context, "See logs for details. DoubleTap map action (zoom in) is disabled as an example.", Toast.LENGTH_LONG).show();
     }

     private void setTapGestureHandler(MapViewLite mapView) {
         mapView.getGestures().setTapListener(new TapListener() {
             @Override
             public void onTap(@NonNull Point2D touchPoint) {
                 GeoCoordinates geoCoordinates = mapView.getCamera().viewToGeoCoordinates(touchPoint);
                 Log.d(TAG, "Tap at: " + geoCoordinates);
             }
         });
     }

     private void setDoubleTapGestureHandler(MapViewLite mapView) {
         mapView.getGestures().setDoubleTapListener(new DoubleTapListener() {
             @Override
             public void onDoubleTap(@NonNull Point2D touchPoint) {
                 GeoCoordinates geoCoordinates = mapView.getCamera().viewToGeoCoordinates(touchPoint);
                 Log.d(TAG, "Zooming in is disabled. DoubleTap at: " + geoCoordinates);
             }
         });
     }

     private void setLongPressGestureHandler(MapViewLite mapView) {
         mapView.getGestures().setLongPressListener(new LongPressListener() {
             @Override
             public void onLongPress(@NonNull GestureState gestureState, @NonNull Point2D touchPoint) {
                 GeoCoordinates geoCoordinates = mapView.getCamera().viewToGeoCoordinates(touchPoint);

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

     @SuppressWarnings("unused")
     private void removeGestureHandler(MapViewLite mapView) {
         mapView.getGestures().setTapListener(null);
         mapView.getGestures().setDoubleTapListener(null);
         mapView.getGestures().setLongPressListener(null);

         // Enabling the default map gesture behavior for a double tap (zooms in).
         // It was disabled for this example, see above.
         mapView.getGestures().enableDefaultAction(GestureType.DOUBLE_TAP);
     }
}
