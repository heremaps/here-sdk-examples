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

package com.here.evroutingkotlin

import android.util.Log
import com.here.sdk.core.errors.InstantiationErrorException
import com.here.sdk.search.EVChargingLocation
import com.here.sdk.search.EVSearchCallback
import com.here.sdk.search.EVSearchEngine
import com.here.sdk.search.EVSearchError
import com.here.sdk.search.EVSearchOptions

// Example usage of HERE EVSearchEngine for querying detailed EV charging location information. Requires an additional EVCP3 license (not included with standard Navigation license).
class EVSearchExample {
    var evSearchEngine: EVSearchEngine? = null

    init {
        try {
            evSearchEngine = EVSearchEngine()
        } catch (e: InstantiationErrorException) {
            Log.d(TAG, "EVSearchEngine instantiation failed", e)
        }
    }

    // Overload to support passing placeIds to EvSearchExample
    fun runSearchExample(placeIds: List<String>) {
        if (evSearchEngine == null || placeIds == null || placeIds.isEmpty()) {
            Log.d(TAG, "EVSearchEngine or placeIds is null/empty")
            return
        }
        val options = EVSearchOptions()
        // Add any additional options if needed
        evSearchEngine!!.search(
            placeIds,
            EVSearchCallback { evSearchError: EVSearchError?, results: List<EVChargingLocation>? ->
                if (evSearchError != null && evSearchError != EVSearchError.NO_RESULTS_FOUND) {
                    Log.d(TAG, "EV search failed: " + evSearchError)

                }
                if (results != null) {
                    for (location in results) {
                        printLocation(location)
                    }
                }
            })
    }

    private fun printLocation(location: EVChargingLocation) {
        Log.d(TAG, "=== EV Charging Location ===")
        // Operator Information
        val operator = location.evChargingOperator
        if (operator != null) {
            Log.d(TAG, "Operator: " + operator.name)
        }
        for (evse in location.evses) {
            Log.d(TAG, "EVSE ID: " + evse.id)
            for (c in evse.connectors) {
                Log.d(TAG, " - Connector: " + c.id)
            }
        }
        for (tariff in location.tariffs) {
            Log.d(TAG, "Tariff: " + tariff.name)
        }
    }

    companion object {
        private const val TAG = "EvSearchExample"
    }
}
