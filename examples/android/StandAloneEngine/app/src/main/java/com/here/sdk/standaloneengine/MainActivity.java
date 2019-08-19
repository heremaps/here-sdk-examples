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

package com.here.sdk.standaloneengine;

import android.os.Bundle;
import android.support.v7.app.AppCompatActivity;
import android.util.Log;
import android.widget.TextView;

import com.here.sdk.core.GeoBoundingRect;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.errors.EngineInstantiationErrorException;
import com.here.sdk.traffic.Incident;
import com.here.sdk.traffic.IncidentQueryOptions;
import com.here.sdk.traffic.TrafficEngine;

/**
 * This example app shows that an engine can be used independently from a MapView,
 * without any further adaptions. Here we use a TrafficEngine to query traffic
 * incidents in Berlin, Germany.
 */
public class MainActivity extends AppCompatActivity {

    private static final String LOG_TAG = MainActivity.class.getName();

    private TrafficEngine trafficEngine;
    private TextView trafficInfoTextview;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        trafficInfoTextview = findViewById(R.id.infoTextView);

        try {
            trafficEngine = new TrafficEngine();
        } catch (EngineInstantiationErrorException e) {
            trafficInfoTextview.setText(e.getMessage());
            return;
        }

        queryTrafficIncidents();
    }

    private void queryTrafficIncidents() {
        trafficEngine.queryForIncidents(
                new GeoBoundingRect(new GeoCoordinates(52.373556,13.114358),
                        new GeoCoordinates(52.611022,13.479493)),
                new IncidentQueryOptions(),
                (incidentQueryError, incidents) -> {

                    if (incidentQueryError != null) {
                        trafficInfoTextview.setText("Query failed. Error: " + incidentQueryError.toString());
                        return;
                    }

                    for (Incident incident : incidents) {
                        Log.d(LOG_TAG, "Incident: " + incident.category.name()
                                + ", info: " + incident.description
                                + ", impact: " + incident.impact.name());
                    }

                    trafficInfoTextview.setText(" " + incidents.size()
                            + " traffic incident(s) found. See log for details.");
                }
        );
    }
}
