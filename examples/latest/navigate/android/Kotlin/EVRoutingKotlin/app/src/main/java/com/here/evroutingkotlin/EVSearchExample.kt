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
import com.here.sdk.search.EVChargingLocationFeature
import com.here.sdk.search.EVSearchCallback
import com.here.sdk.search.EVSearchEngine
import com.here.sdk.search.EVSearchError
import com.here.sdk.search.EVSearchOptions

// Example usage of HERE EVSearchEngine for querying detailed EV charging location information.
// Requires an additional EVCP3 license that is not included with a standard Navigate license.
class EVSearchExample {
    var evSearchEngine: EVSearchEngine? = null

    init {
        try {
            evSearchEngine = EVSearchEngine()
        } catch (e: InstantiationErrorException) {
            Log.d(TAG, "EVSearchEngine instantiation failed", e)
        }
    }

    // This standalone EVCP3 lookup is useful only when the caller already has HERE Place IDs.
    // EVRoutingExample uses SearchEngine.setEVInterface(...) for generic EV enrichment and this
    // direct lookup when it needs feature-gated EVCP3 fields such as tariffs and EVSE details.
    fun runSearchExample(placeIds: List<String>) {
        runSearchExample(placeIds, null)
    }

    fun runSearchExample(placeIds: List<String>, callback: EVSearchCallback?) {
        if (evSearchEngine == null || placeIds == null || placeIds.isEmpty()) {
            Log.d(TAG, "EVSearchEngine or placeIds is null/empty")
            return
        }
        val options = createEVCP3DetailsOptions()
        evSearchEngine!!.setOptions(options)
        evSearchEngine!!.search(
            placeIds,
            EVSearchCallback { evSearchError: EVSearchError?, results: List<EVChargingLocation>? ->
                callback?.onEVCP3SearchCompleted(evSearchError, results)
                if (evSearchError != null && evSearchError != EVSearchError.NO_RESULTS_FOUND) {
                    Log.d(TAG, "EV search failed: $evSearchError")
                    return@EVSearchCallback
                }
                if (evSearchError == EVSearchError.NO_RESULTS_FOUND) {
                    Log.d(TAG, "EV search completed: No results found.")
                }
                if (results != null) {
                    for (location in results) {
                        printLocation(location)
                    }
                }
            })
    }

    private fun createEVCP3DetailsOptions(): EVSearchOptions {
        return EVSearchOptions().apply {
            additionalFeatures = listOf(
                EVChargingLocationFeature.EVSES,
                EVChargingLocationFeature.TARIFFS,
                EVChargingLocationFeature.CONNECTOR_GROUPS,
                EVChargingLocationFeature.EMSPS,
                EVChargingLocationFeature.LOCATION_INFO,
                EVChargingLocationFeature.TRUCK_RESTRICTIONS
            )
        }
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
        val tariffs = location.tariffs
        Log.d(
            TAG,
            "Tariff count: ${tariffs.size} (requires TARIFFS plus EVSES or CONNECTOR_GROUPS in EVSearchOptions)"
        )
        for (tariff in tariffs) {
            Log.d(TAG, "Tariff: " + tariff.name)
        }
    }

    companion object {
        private const val TAG = "EvSearchExample"
    }
}
