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

package com.here.traffic;

import android.content.Context;
import android.support.annotation.Nullable;
import android.util.Log;
import android.widget.Toast;

import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.LanguageCode;
import com.here.sdk.core.errors.EngineInstantiationException;
import com.here.sdk.mapviewlite.Camera;
import com.here.sdk.mapviewlite.LayerState;
import com.here.sdk.mapviewlite.MapLayer;
import com.here.sdk.mapviewlite.MapScene;
import com.here.sdk.mapviewlite.MapViewLite;
import com.here.sdk.traffic.Incident;
import com.here.sdk.traffic.IncidentCategory;
import com.here.sdk.traffic.IncidentImpact;
import com.here.sdk.traffic.IncidentQueryError;
import com.here.sdk.traffic.IncidentQueryOptions;
import com.here.sdk.traffic.QueryForIncidentsCallback;
import com.here.sdk.traffic.TrafficEngine;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class TrafficExample {

    private static final String TAG = TrafficExample.class.getSimpleName();

    private Context context;
    private MapViewLite mapView;
    private Camera camera;
    private TrafficEngine trafficEngine;

    public TrafficExample(Context context, MapViewLite mapView) {
        this.context = context;
        this.mapView = mapView;
        camera = mapView.getCamera();
        camera.setTarget(new GeoCoordinates(52.530932, 13.384915));
        camera.setZoomLevel(14);

        try {
            trafficEngine = new TrafficEngine();
        } catch (EngineInstantiationException e) {
            new RuntimeException("Initialization of TrafficEngine failed: " + e.error.name());
        }
    }

    public void enableAllIncidentTypes() {
        // By default, incidents are localized in EN_US
        // and all impacts and categories are enabled.
        IncidentQueryOptions incidentQueryOptions = new IncidentQueryOptions();
        queryIncidentsInViewport(incidentQueryOptions);

        // Show real-time traffic lines and incidents on the map.
        enableTrafficVisualization();
    }

    public void queryOnlyMinorRoadWorks() {
        IncidentQueryOptions incidentQueryOptions = new IncidentQueryOptions(
                new ArrayList<>(Collections.singletonList(
                        IncidentImpact.MINOR)),
                new ArrayList<>(Collections.singletonList(
                        IncidentCategory.CONSTRUCTION)),
                LanguageCode.EN_GB);

        queryIncidentsInViewport(incidentQueryOptions);
    }

    public void disableAll() {
        disableTrafficVisualization();
    }

    private void enableTrafficVisualization() {
        try {
            mapView.getMapScene().setLayerState(MapLayer.TRAFFIC_FLOW, LayerState.ENABLED);
            mapView.getMapScene().setLayerState(MapLayer.TRAFFIC_INCIDENTS, LayerState.ENABLED);
        } catch (MapScene.MapSceneException e) {
            Toast.makeText(context, "Exception when enabling traffic visualization.", Toast.LENGTH_LONG).show();
        }
    }

    private void disableTrafficVisualization() {
        try {
            mapView.getMapScene().setLayerState(MapLayer.TRAFFIC_FLOW, LayerState.DISABLED);
            mapView.getMapScene().setLayerState(MapLayer.TRAFFIC_INCIDENTS, LayerState.DISABLED);
        } catch (MapScene.MapSceneException e) {
            Toast.makeText(context, "Exception when disabling traffic visualization.", Toast.LENGTH_LONG).show();
        }
    }

    private void queryIncidentsInViewport(IncidentQueryOptions incidentQueryOptions) {
        trafficEngine.queryForIncidents(
                camera.getBoundingRect(),
                incidentQueryOptions,
                new QueryForIncidentsCallback() {
                    @Override
                    public void onIncidentsFetched(@Nullable IncidentQueryError incidentQueryError,
                                                   @Nullable List<Incident> incidents) {
                        if (incidentQueryError != null) {
                            Toast.makeText(context, "Search failed. Error: " +
                                    incidentQueryError.toString(), Toast.LENGTH_LONG).show();
                            return;
                        }

                        for (Incident incident : incidents) {
                            Log.d(TAG, "Incident: " + incident.category.name()
                                    + ", info: " + incident.description
                                    + ", impact: " + incident.impact.name()
                                    + ", from: " + incident.startCoordinates
                                    + " to: " + incident.endCoordinates);
                        }

                        Toast.makeText(context, incidents.size()
                                + " incident(s) found in viewport.", Toast.LENGTH_LONG).show();
                    }
                }
        );
    }
}
