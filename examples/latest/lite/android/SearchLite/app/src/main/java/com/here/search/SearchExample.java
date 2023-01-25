/*
 * Copyright (C) 2019-2023 HERE Europe B.V.
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

package com.here.search;

import android.content.Context;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import android.util.Log;
import android.widget.Toast;

import com.here.sdk.core.Anchor2D;
import com.here.sdk.core.CustomMetadataValue;
import com.here.sdk.core.GeoBox;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.LanguageCode;
import com.here.sdk.core.Metadata;
import com.here.sdk.core.Point2D;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.gestures.GestureState;
import com.here.sdk.mapviewlite.Camera;
import com.here.sdk.mapviewlite.MapImage;
import com.here.sdk.mapviewlite.MapImageFactory;
import com.here.sdk.mapviewlite.MapMarker;
import com.here.sdk.mapviewlite.MapMarkerImageStyle;
import com.here.sdk.mapviewlite.MapViewLite;
import com.here.sdk.mapviewlite.PickMapItemsCallback;
import com.here.sdk.mapviewlite.PickMapItemsResult;
import com.here.sdk.search.Address;
import com.here.sdk.search.AddressQuery;
import com.here.sdk.search.Place;
import com.here.sdk.search.SearchCallback;
import com.here.sdk.search.SearchEngine;
import com.here.sdk.search.SearchError;
import com.here.sdk.search.SearchOptions;
import com.here.sdk.search.SuggestCallback;
import com.here.sdk.search.Suggestion;
import com.here.sdk.search.TextQuery;

import java.util.ArrayList;
import java.util.List;

public class SearchExample {

    private static final String LOG_TAG = SearchExample.class.getName();

    private final Context context;
    private final MapViewLite mapView;
    private final Camera camera;
    private final List<MapMarker> mapMarkerList = new ArrayList<>();
    private final SearchEngine searchEngine;

    public SearchExample(Context context, MapViewLite mapView) {
        this.context = context;
        this.mapView = mapView;
        camera = mapView.getCamera();
        camera.setTarget(new GeoCoordinates(52.530932, 13.384915));
        camera.setZoomLevel(14);

        try {
            searchEngine = new SearchEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of SearchEngine failed: " + e.error.name());
        }

        setTapGestureHandler();
        setLongPressGestureHandler();

        Toast.makeText(context,"Long press on map to get the address for that position using reverse geocoding.", Toast.LENGTH_LONG).show();
    }

    public void onSearchButtonClicked() {
        // Search for "Pizza" and show the results on the map.
        searchExample();

        // Search for auto suggestions and log the results to the console.
        autoSuggestExample();
    }

    public void onGeocodeButtonClicked() {
        // Search for the location that belongs to an address and show it on the map.
        geocodeAnAddress();
    }

    private void searchExample() {
        String searchTerm = "Pizza";

        Toast.makeText(context,"Searching in viewport: " + searchTerm, Toast.LENGTH_LONG).show();
        searchInViewport(searchTerm);
    }

    private void geocodeAnAddress() {
        // Set map near to expected location.
        GeoCoordinates geoCoordinates = new GeoCoordinates(52.537931, 13.384914);
        camera.setTarget(geoCoordinates);
        camera.setZoomLevel(14);

        String queryString = "Invalidenstraße 116, Berlin";

        Toast.makeText(context,"Finding locations for: " + queryString
               + ". Tap marker to see the coordinates. Check the logs for the address.", Toast.LENGTH_LONG).show();

        geocodeAddressAtLocation(queryString, geoCoordinates);
    }

    private void setTapGestureHandler() {
        mapView.getGestures().setTapListener(touchPoint -> pickMapMarker(touchPoint));
    }

    private void setLongPressGestureHandler() {
        mapView.getGestures().setLongPressListener((gestureState, touchPoint) -> {
            if (gestureState == GestureState.BEGIN) {
                GeoCoordinates geoCoordinates = mapView.getCamera().viewToGeoCoordinates(touchPoint);
                addPoiMapMarker(geoCoordinates);
                getAddressForCoordinates(geoCoordinates);
            }
        });
    }

    private void getAddressForCoordinates(GeoCoordinates geoCoordinates) {
        SearchOptions reverseGeocodingOptions = new SearchOptions();
        reverseGeocodingOptions.languageCode = LanguageCode.EN_GB;
        reverseGeocodingOptions.maxItems = 1;

        searchEngine.search(geoCoordinates, reverseGeocodingOptions, new SearchCallback() {
            @Override
            public void onSearchCompleted(@Nullable SearchError searchError, @Nullable List<Place> list) {
                if (searchError != null) {
                    showDialog("Reverse geocoding", "Error: " + searchError.toString());
                    return;
                }

                // If error is null, list is guaranteed to be not empty.
                showDialog("Reverse geocoded address:", list.get(0).getAddress().addressText);
            }
        });
    }

    private void pickMapMarker(final Point2D point2D) {
        float radiusInPixel = 2;
        mapView.pickMapItems(point2D, radiusInPixel, new PickMapItemsCallback() {
            @Override
            public void onMapItemsPicked(@Nullable PickMapItemsResult pickMapItemsResult) {
                if (pickMapItemsResult == null) {
                    return;
                }

                MapMarker topmostMapMarker = pickMapItemsResult.getTopmostMarker();
                if (topmostMapMarker == null) {
                    return;
                }

                Metadata metadata = topmostMapMarker.getMetadata();
                if (metadata != null) {
                    CustomMetadataValue customMetadataValue = metadata.getCustomValue("key_search_result");
                    if (customMetadataValue != null) {
                        SearchResultMetadata searchResultMetadata = (SearchResultMetadata) customMetadataValue;
                        String title = searchResultMetadata.searchResult.getTitle();
                        String vicinity = searchResultMetadata.searchResult.getAddress().addressText;
                        showDialog("Picked Search Result",title + ". Vicinity: " + vicinity);
                        return;
                    }
                }

                showDialog("Picked Map Marker",
                        "Geographic coordinates: " +
                                topmostMapMarker.getCoordinates().latitude + ", " +
                                topmostMapMarker.getCoordinates().longitude);
            }
        });
    }

    private void searchInViewport(String queryString) {
        clearMap();

        GeoBox viewportGeoBox = getMapViewGeoBox();
        TextQuery.Area queryArea = new TextQuery.Area(viewportGeoBox);
        TextQuery query = new TextQuery(queryString, queryArea);

        SearchOptions searchOptions = new SearchOptions();
        searchOptions.languageCode = LanguageCode.EN_US;
        searchOptions.maxItems = 30;

        searchEngine.search(query, searchOptions, new SearchCallback() {
            @Override
            public void onSearchCompleted(@Nullable SearchError searchError, @Nullable List<Place> list) {
                if (searchError != null) {
                    showDialog("Search", "Error: " + searchError.toString());
                    return;
                }

                // If error is null, list is guaranteed to be not empty.
                showDialog("Search", "Results: " + list.size());

                // Add new marker for each search result on map.
                for (Place searchResult : list) {
                    Metadata metadata = new Metadata();
                    metadata.setCustomValue("key_search_result", new SearchResultMetadata(searchResult));
                    addPoiMapMarker(searchResult.getGeoCoordinates(), metadata);
                }
            }
        });
    }

    private static class SearchResultMetadata implements CustomMetadataValue {

        public final Place searchResult;

        public SearchResultMetadata(Place searchResult) {
            this.searchResult = searchResult;
        }

        @NonNull
        @Override
        public String getTag() {
            return "SearchResult Metadata";
        }
    }

    private final SuggestCallback autosuggestCallback = new SuggestCallback() {
        @Override
        public void onSuggestCompleted(@Nullable SearchError searchError, @Nullable List<Suggestion> list) {
            if (searchError != null) {
                Log.d(LOG_TAG, "Autosuggest Error: " + searchError.name());
                return;
            }

            // If error is null, list is guaranteed to be not empty.
            Log.d(LOG_TAG, "Autosuggest results: " + list.size());

            for (Suggestion autosuggestResult : list) {
                String addressText = "Not a place.";
                Place place = autosuggestResult.getPlace();
                if (place != null) {
                    addressText = place.getAddress().addressText;
                }

                Log.d(LOG_TAG, "Autosuggest result: " + autosuggestResult.getTitle() +
                        " addressText: " + addressText);
            }
        }
    };

    private void autoSuggestExample() {
        GeoCoordinates centerGeoCoordinates = getMapViewCenter();

        SearchOptions searchOptions = new SearchOptions();
        searchOptions.languageCode = LanguageCode.EN_US;
        searchOptions.maxItems = 5;

        TextQuery.Area queryArea = new TextQuery.Area(centerGeoCoordinates);

        // Simulate a user typing a search term.
        searchEngine.suggest(
                new TextQuery("p", // User typed "p".
                        queryArea),
                searchOptions,
                autosuggestCallback);

        searchEngine.suggest(
                new TextQuery("pi", // User typed "pi".
                        queryArea),
                searchOptions,
                autosuggestCallback);

        searchEngine.suggest(
                new TextQuery("piz", // User typed "piz".
                        queryArea),
                searchOptions,
                autosuggestCallback);
    }

    private void geocodeAddressAtLocation(String queryString, GeoCoordinates geoCoordinates) {
        clearMap();

        AddressQuery query = new AddressQuery(queryString, geoCoordinates);

        SearchOptions searchOptions = new SearchOptions();
        searchOptions.languageCode = LanguageCode.DE_DE;
        searchOptions.maxItems = 30;

        searchEngine.search(query, searchOptions, new SearchCallback() {
            @Override
            public void onSearchCompleted(SearchError searchError, List<Place> list) {
                if (searchError != null) {
                    showDialog("Geocoding", "Error: " + searchError.toString());
                    return;
                }

                for (Place geocodingResult : list) {
                    GeoCoordinates geoCoordinates = geocodingResult.getGeoCoordinates();
                    Address address = geocodingResult.getAddress();
                    String locationDetails = address.addressText
                            + ". GeoCoordinates: " + geoCoordinates.latitude
                            + ", " + geoCoordinates.longitude;

                    Log.d(LOG_TAG, "GeocodingResult: " + locationDetails);
                    addPoiMapMarker(geoCoordinates);
                }

                showDialog("Geocoding result","Size: " + list.size());
            }
        });
    }

    private void addPoiMapMarker(GeoCoordinates geoCoordinates) {
        MapMarker mapMarker = createPoiMapMarker(geoCoordinates);
        mapView.getMapScene().addMapMarker(mapMarker);
        mapMarkerList.add(mapMarker);
    }

    private void addPoiMapMarker(GeoCoordinates geoCoordinates, Metadata metadata) {
        MapMarker mapMarker = createPoiMapMarker(geoCoordinates);
        mapMarker.setMetadata(metadata);
        mapView.getMapScene().addMapMarker(mapMarker);
        mapMarkerList.add(mapMarker);
    }

    private MapMarker createPoiMapMarker(GeoCoordinates geoCoordinates) {
        MapImage mapImage = MapImageFactory.fromResource(context.getResources(), R.drawable.poi);
        MapMarker mapMarker = new MapMarker(geoCoordinates);
        MapMarkerImageStyle mapMarkerImageStyle = new MapMarkerImageStyle();
        mapMarkerImageStyle.setAnchorPoint(new Anchor2D(0.5F, 1));
        mapMarker.addImage(mapImage, mapMarkerImageStyle);
        return mapMarker;
    }

    private GeoCoordinates getMapViewCenter() {
        return mapView.getCamera().getTarget();
    }

    private GeoBox getMapViewGeoBox() {
        return mapView.getCamera().getBoundingBox();
    }

    private void clearMap() {
        for (MapMarker mapMarker : mapMarkerList) {
            mapView.getMapScene().removeMapMarker(mapMarker);
        }
        mapMarkerList.clear();
    }

    private void showDialog(String title, String message) {
        AlertDialog.Builder builder =
                new AlertDialog.Builder(context);
        builder.setTitle(title);
        builder.setMessage(message);
        builder.show();
    }
}
