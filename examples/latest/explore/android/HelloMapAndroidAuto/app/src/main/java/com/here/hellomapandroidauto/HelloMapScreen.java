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

package com.here.hellomapandroidauto;

import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.car.app.AppManager;
import androidx.car.app.CarContext;
import androidx.car.app.Screen;
import androidx.car.app.SurfaceCallback;
import androidx.car.app.SurfaceContainer;
import androidx.car.app.model.Action;
import androidx.car.app.model.ActionStrip;
import androidx.car.app.model.CarIcon;
import androidx.car.app.model.Template;
import androidx.car.app.navigation.model.NavigationTemplate;
import androidx.core.graphics.drawable.IconCompat;

import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.Point2D;
import com.here.sdk.core.Size2D;
import com.here.sdk.mapview.MapError;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapScene;
import com.here.sdk.mapview.MapScheme;
import com.here.sdk.mapview.MapSurface;

/**
 * A screen that shows a HERE SDK map view - when connected to a DHU or an in-car head unit.
 *
 * <p>See {@link HelloMapCarAppService} for the app's entry point to the car host.
 */
public class HelloMapScreen extends Screen implements SurfaceCallback {

    private MapSurface mapSurface;
    private CarContext carContext;

    public HelloMapScreen(@NonNull CarContext carContext) {
        super(carContext);
        this.carContext = carContext;

        Log.d("HelloMapScreen", "Register surface callback");
        carContext.getCarService(AppManager.class).setSurfaceCallback(this);

        // Since the MapSurface implements MapViewBase, it behaves like a MapView, except that it
        // renders on the DHU running Android Auto.
        mapSurface = new MapSurface();
    }

    @NonNull
    @Override
    public Template onGetTemplate() {
        CarIcon zoomInIcon = new CarIcon.Builder(
                IconCompat.createWithResource(carContext, R.drawable.plus)).build();
        CarIcon zoomOutIcon = new CarIcon.Builder(
                IconCompat.createWithResource(carContext, R.drawable.minus)).build();

        // Add buttons to zoom in/out the map view and to exit the app.
        ActionStrip.Builder actionStripBuilder = new ActionStrip.Builder();
        actionStripBuilder.addAction(
                new Action.Builder()
                        .setIcon(zoomInIcon)
                        .setOnClickListener(this::zoomIn)
                        .build());
        actionStripBuilder.addAction(
                new Action.Builder()
                        .setIcon(zoomOutIcon)
                        .setOnClickListener(this::zoomOut)
                        .build());
        actionStripBuilder.addAction(
                new Action.Builder()
                        .setTitle("Exit")
                        .setOnClickListener(this::exit)
                        .build());

        NavigationTemplate.Builder builder = new NavigationTemplate.Builder();
        builder.setActionStrip(actionStripBuilder.build());
        return builder.build();
    }

    @Override
    public void onSurfaceAvailable(@NonNull SurfaceContainer surfaceContainer) {
        Log.d("HelloMapScreen", "Received a surface.");
        mapSurface.setSurface(
                carContext,
                surfaceContainer.getSurface(),
                surfaceContainer.getWidth(),
                surfaceContainer.getHeight());

        mapSurface.getMapScene().loadScene(MapScheme.NORMAL_DAY, new MapScene.LoadSceneCallback() {
            @Override
            public void onLoadScene(@Nullable MapError mapError) {
                if (mapError == null) {
                    double distanceInMeters = 1000 * 10;
                    MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE, distanceInMeters);
                    mapSurface.getCamera().lookAt(new GeoCoordinates(52.530932, 13.384915), mapMeasureZoom);
                } else {
                    Log.d("HelloMapScreen", "Loading map failed: mapError: " + mapError.name());
                }
            }
        });
    }

    @Override
    public void onSurfaceDestroyed(@NonNull SurfaceContainer surfaceContainer) {
        mapSurface.destroySurface();
    }

    private void zoomIn() {
        double zoomFactor = 2;
        mapSurface.getCamera().zoomBy(zoomFactor, getCenterPoint());
    }

    private void zoomOut() {
        double zoomFactor = 0.5;
        mapSurface.getCamera().zoomBy(zoomFactor, getCenterPoint());
    }

    private void exit() {
        carContext.finishCarApp();
    }

    private Point2D getCenterPoint() {
        Size2D viewport = mapSurface.getViewportSize();
        return new Point2D(viewport.width * 0.5, viewport.height * 0.5);
    }
}
