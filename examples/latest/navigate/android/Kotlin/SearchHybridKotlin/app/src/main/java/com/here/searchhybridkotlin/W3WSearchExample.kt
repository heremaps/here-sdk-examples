/*
 * Copyright (C) 2019-2025 HERE Europe B.V.
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
package com.here.searchhybridkotlin

import android.app.AlertDialog
import android.content.Context
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.core.errors.InstantiationErrorException
import com.here.sdk.mapview.MapMeasure
import com.here.sdk.mapview.MapView
import com.here.sdk.search.W3WSearchCallback
import com.here.sdk.search.W3WSearchEngine
import com.here.sdk.search.W3WSearchError
import com.here.sdk.search.W3WSquare

/**
 * The W3WSearchExample class demonstrates the use of the W3WSearchEngine
 * to perform operations with what3words terms.
 *
 * With the W3WSearchEngine, you can:
 * - Resolve a what3words term to an address and geographic coordinates.
 * - Find a what3words term for given geographic coordinates.
 *
 * Both approaches are demonstrated in the examples below.
 * The W3WSearchEngine interacts with the https://what3words.com/ backend
 * to perform these operations.
 */
class W3WSearchExample(private val context: Context, mapView: MapView) {
    private val camera = mapView.camera
    private var w3wSearchEngine: W3WSearchEngine

    init {
        val distanceInMeters = (1000 * 10).toDouble()
        val mapMeasureZoom = MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, distanceInMeters)
        camera.lookAt(GeoCoordinates(52.520798, 13.409408), mapMeasureZoom)

        try {
            w3wSearchEngine = W3WSearchEngine()
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("Initialization of W3WSearchEngine failed: " + e.error.name)
        }
    }

    fun onW3WSearchButtonClicked() {
        // W3W sample "dizzy.vanilla.singer" used for demonstration purposes. Replace with user input as needed.
        val searchWords = "dizzy.vanilla.singer"

        /* Finds the location of a known What3Words term.
         * This method searches for the geographic location corresponding to a given three-word address
         * (e.g., "dizzy.vanilla.singer").
         */
        w3wSearchEngine.search(searchWords, object : W3WSearchCallback {
            override fun onW3WSearchCompleted(
                w3WSearchError: W3WSearchError?,
                w3WSquare: W3WSquare?
            ) {
                handleW3WSearchResult(w3WSearchError, w3WSquare)
            }
        })
    }

    fun onW3WGeocodeButtonClicked() {
        val geoCoordinates = GeoCoordinates(53.520798, 13.409408)
        // The language code for the desired three-word address.
        // ISO 639-1 code "en" specifies that the three-word address will be in English.
        val w3wLanguageCode = "en"

        /* Resolves geographic coordinates to a What3Words address (three-word format).
         * This method uses the What3Words search engine to find a three-word address based
         * on the provided coordinates (latitude and longitude).
         */
        w3wSearchEngine.search(geoCoordinates, w3wLanguageCode, object : W3WSearchCallback {
            override fun onW3WSearchCompleted(
                w3WSearchError: W3WSearchError?,
                w3WSquare: W3WSquare?
            ) {
                handleW3WSearchResult(w3WSearchError, w3WSquare)
            }
        })
    }

    private fun handleW3WSearchResult(w3WSearchError: W3WSearchError?, w3WSquare: W3WSquare?) {
        if (w3WSearchError != null) {
            showDialog("W3Words Search Error", "Error: $w3WSearchError")
        } else if (w3WSquare != null) {
            // If the search was successful, extract the What3Words.
            val W3Words = w3WSquare.words

            // Retrieve additional details, such as the coordinates of the square.
            val southWestCorner = w3WSquare.square.southWestCorner
            val northEastCorner = w3WSquare.square.northEastCorner

            // Check if the details are available and display them in a dialog.
            showDialog(
                "W3Words Details",
                """
                    W3Words: $W3Words
                    Language: ${w3WSquare.languageCode}
                    southWestCorner coordinates: ${southWestCorner.latitude}, ${southWestCorner.longitude}
                    northEastCorner coordinates: ${northEastCorner.latitude}, ${northEastCorner.longitude}
                    """.trimIndent()
            )
        }
    }

    private fun showDialog(title: String, message: String) {
        val builder: AlertDialog.Builder = AlertDialog.Builder(context)
        builder.setTitle(title)
        builder.setMessage(message)
        builder.show()
    }
}