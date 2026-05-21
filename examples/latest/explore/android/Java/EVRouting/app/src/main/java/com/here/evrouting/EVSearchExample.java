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
import com.here.sdk.search.EVChargingOperator;
import com.here.sdk.search.EVSEInfo;
import com.here.sdk.search.EVChargingTariff;
import com.here.sdk.search.EVSearchCallback;

import java.util.List;

// Example usage of HERE EVSearchEngine for querying detailed EV charging location information. Requires an additional EVCP3 license (not included with standard Navigation license).
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

    // Overload to support passing placeIds to EvSearchExample
    public void runSearchExample(List<String> placeIds) {
        if (evSearchEngine == null || placeIds == null || placeIds.isEmpty()) {
            Log.d(TAG, "EVSearchEngine or placeIds is null/empty");
            return;
        }
        EVSearchOptions options = new EVSearchOptions();
        evSearchEngine.setOptions(options);
        evSearchEngine.search(placeIds, new EVSearchCallback() {
            @Override
            public void onEVCP3SearchCompleted(EVSearchError evSearchError, List<EVChargingLocation> results) {
                // Per API, NO_RESULTS_FOUND is not a fatal error, but indicates no results. Document this logic.
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
        for (EVChargingTariff tariff : location.getTariffs()) {
            Log.d(TAG, "Tariff: " + tariff.name);
        }
    }
}
