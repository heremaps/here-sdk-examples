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
import com.here.sdk.core.errors.EngineInstantiationErrorException;
import com.here.sdk.mapview.Camera;
import com.here.sdk.mapview.LayerState;
import com.here.sdk.mapview.MapLayer;
import com.here.sdk.mapview.MapView;
import com.here.sdk.mapview.SceneError;
import com.here.sdk.mapview.SetLayerStateCallback;
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
    private MapView mapView;
    private Camera camera;
    private TrafficEngine trafficEngine;

    public void onMapSceneLoaded(Context context, MapView mapView) {
        this.context = context;
        this.mapView = mapView;
        camera = mapView.getCamera();
        camera.setTarget(new GeoCoordinates(52.530932, 13.384915));
        camera.setZoomLevel(14);

        try {
            trafficEngine = new TrafficEngine();
        } catch (EngineInstantiationErrorException e) {
            e.printStackTrace();
        }
    }

    public void enableAll() {
        // By default, incidents are localized in EN_US
        // and all impacts and categories are enabled.
        IncidentQueryOptions incidentQueryOptions = new IncidentQueryOptions();
        logIncidentsInViewport(incidentQueryOptions);

        // Show real-time traffic lines on the map.
        enableTrafficFlow();
    }

    public void enableOnlyMinorRoadWorksVisualisation() {
        IncidentQueryOptions incidentQueryOptions = new IncidentQueryOptions(
                new ArrayList<>(Collections.singletonList(
                        IncidentImpact.MINOR)),
                new ArrayList<>(Collections.singletonList(
                        IncidentCategory.CONSTRUCTION)),
                LanguageCode.EN_GB);

        logIncidentsInViewport(incidentQueryOptions);
    }

    public void disableAll() {
        disableTrafficFlow();
    }

    private void enableTrafficFlow() {
        mapView.getMapScene().setLayerState(
                MapLayer.TRAFFIC_FLOW, LayerState.ENABLED, new SetLayerStateCallback() {
                    @Override
                    public void onSetLayerState(@Nullable SceneError sceneError) {
                        if (sceneError != null) {
                            Toast.makeText(context, "Error when enabling traffic flow.", Toast.LENGTH_LONG).show();
                        }
                    }
                });
    }

    private void disableTrafficFlow() {
        mapView.getMapScene().setLayerState(
                MapLayer.TRAFFIC_FLOW, LayerState.DISABLED, new SetLayerStateCallback() {
                    @Override
                    public void onSetLayerState(@Nullable SceneError sceneError) {
                        if (sceneError != null) {
                            Toast.makeText(context, "Error when disabling traffic flow.", Toast.LENGTH_LONG).show();
                        }
                    }
                });
    }

    private void logIncidentsInViewport(IncidentQueryOptions incidentQueryOptions) {
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
