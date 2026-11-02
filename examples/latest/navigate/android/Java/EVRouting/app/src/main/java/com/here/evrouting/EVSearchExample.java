/*
 * Copyright (C) 2019-2026 HERE Europe B.V.
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

package com.here.evrouting;

import android.util.Log;

import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.search.EVChargingConnector;
import com.here.sdk.search.EVSearchEngine;
import com.here.sdk.search.EVSearchOptions;
import com.here.sdk.search.EVSearchError;
import com.here.sdk.search.EVChargingLocation;
import com.here.sdk.search.EVChargingLocationFeature;
import com.here.sdk.search.EVChargingOperator;
import com.here.sdk.search.EVSEInfo;
import com.here.sdk.search.EVChargingTariff;
import com.here.sdk.search.EVSearchCallback;

import java.util.Arrays;
import java.util.List;

// Example usage of HERE EVSearchEngine for querying detailed EV charging location information.
// Requires an additional EVCP3 license that is not included with a standard Navigate license.
public class EVSearchExample {

    private static final String TAG = "EvSearchExample";
    private EVSearchEngine evSearchEngine;

    public EVSearchExample() {
        try {
            evSearchEngine = new EVSearchEngine();
        } catch (InstantiationErrorException e) {
            Log.d(TAG, "EVSearchEngine instantiation failed", e);
        }
    }

    public EVSearchEngine getEvSearchEngine() {
        return evSearchEngine;
    }

    // This standalone EVCP3 lookup is useful only when the caller already has HERE Place IDs.
    // EVRoutingExample uses SearchEngine.setEVInterface(...) for generic EV enrichment and this
    // direct lookup when it needs feature-gated EVCP3 fields such as tariffs and EVSE details.
    public void runSearchExample(List<String> placeIds) {
        runSearchExample(placeIds, null);
    }

    public void runSearchExample(List<String> placeIds, EVSearchCallback callback) {
        if (evSearchEngine == null || placeIds == null || placeIds.isEmpty()) {
            Log.d(TAG, "EVSearchEngine or placeIds is null/empty");
            return;
        }

        EVSearchOptions options = createEVCP3DetailsOptions();
        evSearchEngine.setOptions(options);
        evSearchEngine.search(placeIds, new EVSearchCallback() {
            @Override
            public void onEVCP3SearchCompleted(EVSearchError evSearchError, List<EVChargingLocation> results) {
                if (callback != null) {
                    callback.onEVCP3SearchCompleted(evSearchError, results);
                }

                // Per API, NO_RESULTS_FOUND is not a fatal error, but indicates no results.
                if (evSearchError != null && evSearchError != EVSearchError.NO_RESULTS_FOUND) {
                    Log.d(TAG, "EV search failed: " + evSearchError);
                    return;
                }

                if (evSearchError == EVSearchError.NO_RESULTS_FOUND) {
                    Log.d(TAG, "EV search completed: No results found.");
                }

                if (results != null) {
                    for (EVChargingLocation location : results) {
                        printLocation(location);
                    }
                }
            }
        });
    }

    private EVSearchOptions createEVCP3DetailsOptions() {
        EVSearchOptions options = new EVSearchOptions();
        options.additionalFeatures = Arrays.asList(
                EVChargingLocationFeature.EVSES,
                EVChargingLocationFeature.TARIFFS,
                EVChargingLocationFeature.CONNECTOR_GROUPS,
                EVChargingLocationFeature.EMSPS,
                EVChargingLocationFeature.LOCATION_INFO,
                EVChargingLocationFeature.TRUCK_RESTRICTIONS);
        return options;
    }

    private void printLocation(EVChargingLocation location) {
        Log.d(TAG, "=== EV Charging Location ===");
        // Operator Information
        EVChargingOperator operator = location.getEvChargingOperator();
        if (operator != null) {
            Log.d(TAG, "Operator: " + operator.name);
        }
        for (EVSEInfo evse : location.getEvses()) {
            Log.d(TAG, "EVSE ID: " + evse.id);
            for (EVChargingConnector c : evse.connectors) {
                Log.d(TAG, " - Connector: " + c.id );
            }
        }

        List<EVChargingTariff> tariffs = location.getTariffs();
        Log.d(TAG, "Tariff count: " + tariffs.size()
                + " (requires TARIFFS plus EVSES or CONNECTOR_GROUPS in EVSearchOptions)");
        for (EVChargingTariff tariff : tariffs) {
            Log.d(TAG, "Tariff: " + tariff.name);
        }
    }
}
