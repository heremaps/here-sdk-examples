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
import android.util.Log
import android.widget.Toast
import com.here.sdk.core.Anchor2D
import com.here.sdk.core.CustomMetadataValue
import com.here.sdk.core.GeoBox
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.core.LanguageCode
import com.here.sdk.core.Metadata
import com.here.sdk.core.Point2D
import com.here.sdk.core.Rectangle2D
import com.here.sdk.core.Size2D
import com.here.sdk.core.errors.InstantiationErrorException
import com.here.sdk.gestures.GestureState
import com.here.sdk.gestures.LongPressListener
import com.here.sdk.gestures.TapListener
import com.here.sdk.mapview.MapImageFactory
import com.here.sdk.mapview.MapMarker
import com.here.sdk.mapview.MapMeasure
import com.here.sdk.mapview.MapPickResult
import com.here.sdk.mapview.MapScene.MapPickFilter
import com.here.sdk.mapview.MapView
import com.here.sdk.mapview.MapViewBase.MapPickCallback
import com.here.sdk.search.AddressQuery
import com.here.sdk.search.OfflineSearchEngine
import com.here.sdk.search.Place
import com.here.sdk.search.SearchCallback
import com.here.sdk.search.SearchEngine
import com.here.sdk.search.SearchError
import com.here.sdk.search.SearchOptions
import com.here.sdk.search.SuggestCallback
import com.here.sdk.search.Suggestion
import com.here.sdk.search.TextQuery

class SearchExample(private val context: Context, private val mapView: MapView) {
    private val camera = mapView.camera
    private val mapMarkerList: MutableList<MapMarker> = mutableListOf()
    private var searchEngine: SearchEngine
    private var offlineSearchEngine: OfflineSearchEngine

    // An application may define here a logic to determine whether a device is connected or not.
    // For this example app, the flag is set from UI.
    private var isDeviceConnected = true

    init {
        val distanceInMeters = 5000.0
        val mapMeasureZoom = MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, distanceInMeters)
        camera.lookAt(GeoCoordinates(52.520798, 13.409408), mapMeasureZoom)

        try {
            searchEngine = SearchEngine()
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("Initialization of SearchEngine failed: " + e.error.name)
        }

        try {
            // Allows to search on already downloaded or cached map data.
            offlineSearchEngine = OfflineSearchEngine()
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("Initialization of OfflineSearchEngine failed: " + e.error.name)
        }

        setTapGestureHandler()
        setLongPressGestureHandler()

        Toast.makeText(
            context,
            "Long press on map to get the address for that position using reverse geocoding.",
            Toast.LENGTH_LONG
        ).show()
    }

    fun onSearchButtonClicked() {
        // Search for "Pizza" and show the results on the map.
        searchExample()

        // Search for auto suggestions and log the results to the console.
        autoSuggestExample()
    }

    fun onGeocodeButtonClicked() {
        // Search for the location that belongs to an address and show it on the map.
        geocodeAnAddress()
    }

    private fun searchExample() {
        val searchTerm = "Pizza"

        Toast.makeText(context, "Searching in viewport: $searchTerm", Toast.LENGTH_LONG).show()
        searchInViewport(searchTerm)
    }

    private fun geocodeAnAddress() {
        // Set map to expected location.
        val geoCoordinates = GeoCoordinates(52.53086, 13.38469)
        val distanceInMeters = (1000 * 7).toDouble()
        val mapMeasureZoom = MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, distanceInMeters)
        camera.lookAt(geoCoordinates, mapMeasureZoom)

        val queryString = "Invalidenstraße 116, Berlin"

        Toast.makeText(
            context,
            "Finding locations for: $queryString. Tap marker to see the coordinates. Check the logs for the address.",
            Toast.LENGTH_LONG
        ).show()

        geocodeAddressAtLocation(queryString, geoCoordinates)
    }

    private fun setTapGestureHandler() {
        mapView.gestures.tapListener =
            TapListener { touchPoint: Point2D -> pickMapMarker(touchPoint) }
    }

    private fun setLongPressGestureHandler() {
        mapView.gestures.longPressListener =
            LongPressListener { gestureState: GestureState, touchPoint: Point2D ->
                if (gestureState == GestureState.BEGIN) {
                    val geoCoordinates =
                        mapView.viewToGeoCoordinates(touchPoint) ?: return@LongPressListener
                    addPoiMapMarker(geoCoordinates)
                    getAddressForCoordinates(geoCoordinates)
                }
            }
    }

    private fun getAddressForCoordinates(geoCoordinates: GeoCoordinates) {
        val reverseGeocodingOptions = SearchOptions()
        reverseGeocodingOptions.languageCode = LanguageCode.EN_GB
        reverseGeocodingOptions.maxItems = 1

        if (isDeviceConnected) {
            searchEngine.searchByCoordinates(
                geoCoordinates,
                reverseGeocodingOptions,
                addressSearchCallback
            )
        } else {
            offlineSearchEngine.searchByCoordinates(
                geoCoordinates,
                reverseGeocodingOptions,
                addressSearchCallback
            )
        }
    }

    private val addressSearchCallback = object : SearchCallback {
        override fun onSearchCompleted(searchError: SearchError?, list: MutableList<Place>?) {
            if (searchError != null) {
                showDialog("Reverse geocoding", "Error: $searchError")
                return
            }
            // If error is null, list is guaranteed to be not empty.
            showDialog("Reverse geocoded address:", list!![0].address.addressText)
        }
    }

    private fun pickMapMarker(touchPOint: Point2D) {
        val originInPixels = Point2D(touchPOint.x, touchPOint.y)
        val sizeInPixels = Size2D(1.0, 1.0)
        val rectangle = Rectangle2D(originInPixels, sizeInPixels)

        // Creates a list of map content type from which the results will be picked.
        // The content type values can be MAP_CONTENT, MAP_ITEMS and CUSTOM_LAYER_DATA.
        val contentTypesToPickFrom = ArrayList<MapPickFilter.ContentType>()

        // MAP_CONTENT is used when picking embedded carto POIs, traffic incidents, vehicle restriction etc.
        // MAP_ITEMS is used when picking map items such as MapMarker, MapPolyline, MapPolygon etc.
        // Currently we need map markers so adding the MAP_ITEMS filter.
        contentTypesToPickFrom.add(MapPickFilter.ContentType.MAP_ITEMS)
        val filter = MapPickFilter(contentTypesToPickFrom)

        // If you do not want to specify any filter you can pass filter as NULL and all of the pickable contents will be picked.
        mapView.pick(
            filter, rectangle,
            object : MapPickCallback {
                override fun onPickMap(mapPickResult: MapPickResult?) {
                    if (mapPickResult == null) {
                        // An error occurred while performing the pick operation.
                        return
                    }
                    val mapMarkerList = mapPickResult.mapItems!!
                        .markers
                    if (mapMarkerList.isEmpty()) {
                        return
                    }
                    val topmostMapMarker = mapMarkerList[0]
                    val metadata: Metadata? = topmostMapMarker.metadata
                    metadata?.let {
                        val customMetadataValue: CustomMetadataValue? =
                            metadata.getCustomValue("key_search_result")
                        customMetadataValue?.let {
                            val searchResultMetadata = customMetadataValue as SearchResultMetadata
                            val title = searchResultMetadata.searchResult.title
                            val vicinity = searchResultMetadata.searchResult.address.addressText
                            showDialog("Picked Search Result", "$title. Vicinity: $vicinity")
                            return
                        }
                    }
                    showDialog(
                        "Picked Map Marker",
                        "Geographic coordinates: ${topmostMapMarker.coordinates.latitude}, ${topmostMapMarker.coordinates.longitude}"
                    )
                }
            })
    }

    private fun searchInViewport(queryString: String) {
        clearMap()

        val viewportGeoBox = mapViewGeoBox
        val queryArea = TextQuery.Area(viewportGeoBox)
        val query = TextQuery(queryString, queryArea)

        val searchOptions = SearchOptions()
        searchOptions.languageCode = LanguageCode.EN_US
        searchOptions.maxItems = 30

        if (isDeviceConnected) {
            searchEngine.searchByText(query, searchOptions, querySearchCallback)
        } else {
            offlineSearchEngine.searchByText(query, searchOptions, querySearchCallback)
        }
    }

    private val querySearchCallback = object : SearchCallback {
        override fun onSearchCompleted(searchError: SearchError?, list: MutableList<Place>?) {
            if (searchError != null) {
                // Note: When using the OfflineSearchEngine, the HERE SDK searches only on cached map data and
                // search results may not be available for all zoom levels.
                // Please also note that it may take time until the required map data is loaded.
                // Subsequently, the cache is filled when a user pans and zooms the map.
                //
                // For best results, it is recommended to permanently install offline region data and use the
                // OfflineSearchEngine for areas where region data has been installed.
                showDialog("Search", "Error: $searchError")
                return
            }
            // If error is null, list is guaranteed to be not empty.
            showDialog("Search", "Results: ${list!!.size}")

            // Add new marker for each search result on map.
            for (searchResult in list) {
                val metadata = Metadata()
                metadata.setCustomValue("key_search_result", SearchResultMetadata(searchResult))
                // Note: getGeoCoordinates() may return null only for Suggestions.
                addPoiMapMarker(searchResult.geoCoordinates!!, metadata)
            }
        }
    }

    private class SearchResultMetadata(val searchResult: Place) : CustomMetadataValue {
        override fun getTag(): String {
            return "SearchResult Metadata"
        }
    }

    private val autosuggestCallback = object : SuggestCallback {
        override fun onSuggestCompleted(searchError: SearchError?, list: MutableList<Suggestion>?) {
            if (searchError != null) {
                Log.d(LOG_TAG, "Autosuggest Error: ${searchError.name}")
                return
            }
            // If error is null, list is guaranteed to be not empty.
            Log.d(LOG_TAG, "Autosuggest results: ${list!!.size}")
            for (autosuggestResult in list) {
                var addressText = "Not a place."
                val place = autosuggestResult.place
                place?.let {
                    addressText = place.address.addressText
                }
                Log.d(LOG_TAG, "Autosuggest result: ${autosuggestResult.title} addressText: $addressText")
            }
        }
    }

    private fun autoSuggestExample() {
        val centerGeoCoordinates = mapViewCenter
        val searchOptions = SearchOptions()
        searchOptions.languageCode = LanguageCode.EN_US
        searchOptions.maxItems = 5

        val queryArea = TextQuery.Area(centerGeoCoordinates)

        if (isDeviceConnected) {
            // Simulate a user typing a search term.
            searchEngine.suggestByText(
                TextQuery(
                    "p",  // User typed "p".
                    queryArea
                ),
                searchOptions,
                autosuggestCallback
            )

            searchEngine.suggestByText(
                TextQuery(
                    "pi",  // User typed "pi".
                    queryArea
                ),
                searchOptions,
                autosuggestCallback
            )

            searchEngine.suggestByText(
                TextQuery(
                    "piz",  // User typed "piz".
                    queryArea
                ),
                searchOptions,
                autosuggestCallback
            )
        } else {
            // Simulate a user typing a search term.
            offlineSearchEngine.suggestByText(
                TextQuery(
                    "p",  // User typed "p".
                    queryArea
                ),
                searchOptions,
                autosuggestCallback
            )

            offlineSearchEngine.suggestByText(
                TextQuery(
                    "pi",  // User typed "pi".
                    queryArea
                ),
                searchOptions,
                autosuggestCallback
            )

            offlineSearchEngine.suggestByText(
                TextQuery(
                    "piz",  // User typed "piz".
                    queryArea
                ),
                searchOptions,
                autosuggestCallback
            )
        }
    }

    private fun geocodeAddressAtLocation(queryString: String, geoCoordinates: GeoCoordinates) {
        clearMap()

        val query = AddressQuery(queryString, geoCoordinates)

        val options = SearchOptions()
        options.languageCode = LanguageCode.DE_DE
        options.maxItems = 30

        if (isDeviceConnected) {
            searchEngine.searchByAddress(query, options, geocodeAddressSearchCallback)
        } else {
            offlineSearchEngine.searchByAddress(query, options, geocodeAddressSearchCallback)
        }
    }

    private val geocodeAddressSearchCallback = object : SearchCallback {
        override fun onSearchCompleted(searchError: SearchError?, list: MutableList<Place>?) {
            if (searchError != null) {
                showDialog("Geocoding", "Error: $searchError")
                return
            }
            for (geocodingResult in list!!) {
                // Note: getGeoCoordinates() may return null only for Suggestions.
                val geoCoordinates = geocodingResult.geoCoordinates
                val address = geocodingResult.address
                val locationDetails = "${address.addressText}. GeoCoordinates: ${geoCoordinates!!.latitude}, ${geoCoordinates.longitude}"

                Log.d(
                    LOG_TAG,
                    "GeocodingResult: $locationDetails"
                )
                addPoiMapMarker(geoCoordinates)
            }
            showDialog("Geocoding result", "Size: ${list.size}")
        }
    }

    private fun addPoiMapMarker(geoCoordinates: GeoCoordinates) {
        val mapMarker = createPoiMapMarker(geoCoordinates)
        mapView.mapScene.addMapMarker(mapMarker)
        mapMarkerList.add(mapMarker)
    }

    private fun addPoiMapMarker(geoCoordinates: GeoCoordinates, metadata: Metadata) {
        val mapMarker = createPoiMapMarker(geoCoordinates)
        mapMarker.metadata = metadata
        mapView.mapScene.addMapMarker(mapMarker)
        mapMarkerList.add(mapMarker)
    }

    private fun createPoiMapMarker(geoCoordinates: GeoCoordinates): MapMarker {
        val mapImage = MapImageFactory.fromResource(context.resources, R.drawable.poi)
        return MapMarker(geoCoordinates, mapImage, Anchor2D(0.5, 1.0))
    }

    private val mapViewCenter: GeoCoordinates
        get() = mapView.camera.state.targetCoordinates

    private val mapViewGeoBox: GeoBox
        get() {
            val mapViewWidthInPixels = mapView.width
            val mapViewHeightInPixels = mapView.height
            val bottomLeftPoint2D = Point2D(0.0, mapViewHeightInPixels.toDouble())
            val topRightPoint2D = Point2D(mapViewWidthInPixels.toDouble(), 0.0)

            val southWestCorner = mapView.viewToGeoCoordinates(bottomLeftPoint2D)
            val northEastCorner = mapView.viewToGeoCoordinates(topRightPoint2D)

            if (southWestCorner == null || northEastCorner == null) {
                throw RuntimeException("GeoBox creation failed, corners are null.")
            }

            // Note: This algorithm assumes an unrotated map view.
            return GeoBox(southWestCorner, northEastCorner)
        }

    private fun clearMap() {
        for (mapMarker in mapMarkerList) {
            mapView.mapScene.removeMapMarker(mapMarker)
        }
        mapMarkerList.clear()
    }

    fun onSwitchOnlineButtonClicked() {
        isDeviceConnected = true
        Toast.makeText(context, "The app will now use the SearchEngine.", Toast.LENGTH_LONG).show()
    }

    fun onSwitchOfflineButtonClicked() {
        isDeviceConnected = false
        Toast.makeText(context, "The app will now use the OfflineSearchEngine.", Toast.LENGTH_LONG)
            .show()
    }

    private fun showDialog(title: String, message: String) {
        val builder: AlertDialog.Builder =
            AlertDialog.Builder(context)
        builder.setTitle(title)
        builder.setMessage(message)
        builder.show()
    }

    companion object {
        private val LOG_TAG: String = SearchExample::class.java.name
    }
}