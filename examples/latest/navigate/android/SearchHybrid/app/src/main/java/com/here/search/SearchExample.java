/*
 * Copyright (C) 2019-2021 HERE Europe B.V.
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
import android.util.Log;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;

import com.here.sdk.core.Anchor2D;
import com.here.sdk.core.CustomMetadataValue;
import com.here.sdk.core.GeoBox;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.LanguageCode;
import com.here.sdk.core.Metadata;
import com.here.sdk.core.Point2D;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.gestures.GestureState;
import com.here.sdk.mapview.MapCamera;
import com.here.sdk.mapview.MapImage;
import com.here.sdk.mapview.MapImageFactory;
import com.here.sdk.mapview.MapMarker;
import com.here.sdk.mapview.MapView;
import com.here.sdk.mapview.MapViewBase;
import com.here.sdk.mapview.PickMapItemsResult;
import com.here.sdk.search.Address;
import com.here.sdk.search.AddressQuery;
import com.here.sdk.search.OfflineSearchEngine;
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
    private final MapView mapView;
    private final MapCamera camera;
    private final List<MapMarker> mapMarkerList = new ArrayList<>();
    private final SearchEngine searchEngine;
    private final OfflineSearchEngine offlineSearchEngine;
    private boolean isDeviceConnected = true;

    public SearchExample(Context context, MapView mapView) {
        this.context = context;
        this.mapView = mapView;
        camera = mapView.getCamera();
        double distanceInMeters = 1000 * 10;
        camera.lookAt(new GeoCoordinates(52.520798, 13.409408), distanceInMeters);

        try {
            searchEngine = new SearchEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of SearchEngine failed: " + e.error.name());
        }

        try {
            // Allows to search on already downloaded or cached map data.
            offlineSearchEngine = new OfflineSearchEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of OfflineSearchEngine failed: " + e.error.name());
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
        // Set map to expected location.
        GeoCoordinates geoCoordinates = new GeoCoordinates(52.53086, 13.38469);
        camera.flyTo(geoCoordinates);

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
                GeoCoordinates geoCoordinates = mapView.viewToGeoCoordinates(touchPoint);
                if (geoCoordinates == null) {
                    return;
                }
                addPoiMapMarker(geoCoordinates);
                getAddressForCoordinates(geoCoordinates);
            }
        });
    }

    private void getAddressForCoordinates(GeoCoordinates geoCoordinates) {
        int maxItems = 1;
        SearchOptions reverseGeocodingOptions = new SearchOptions(LanguageCode.EN_GB, maxItems);

        if (isDeviceConnected()) {
            searchEngine.search(geoCoordinates, reverseGeocodingOptions, addressSearchCallback);
        } else {
            offlineSearchEngine.search(geoCoordinates, reverseGeocodingOptions, addressSearchCallback);
        }
    }

    private final SearchCallback addressSearchCallback = new SearchCallback() {
        @Override
        public void onSearchCompleted(@Nullable SearchError searchError, @Nullable List<Place> list) {
            if (searchError != null) {
                showDialog("Reverse geocoding", "Error: " + searchError.toString());
                return;
            }

            // If error is null, list is guaranteed to be not empty.
            showDialog("Reverse geocoded address:", list.get(0).getAddress().addressText);
        }
    };

    private void pickMapMarker(final Point2D point2D) {
        float radiusInPixel = 2;
        mapView.pickMapItems(point2D, radiusInPixel, new MapViewBase.PickMapItemsCallback() {
            @Override
            public void onPickMapItems(@Nullable PickMapItemsResult pickMapItemsResult) {
                if (pickMapItemsResult == null) {
                    return;
                }

                List<MapMarker> mapMarkerList = pickMapItemsResult.getMarkers();
                if (mapMarkerList.size() == 0) {
                    return;
                }
                MapMarker topmostMapMarker = mapMarkerList.get(0);

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
        TextQuery query = new TextQuery(queryString, viewportGeoBox);

        int maxItems = 30;
        SearchOptions searchOptions = new SearchOptions(LanguageCode.EN_US, maxItems);

        if (isDeviceConnected()) {
            searchEngine.search(query, searchOptions, querySearchCallback);
        } else {
            offlineSearchEngine.search(query, searchOptions, querySearchCallback);
        }
    }

    private final SearchCallback querySearchCallback = new SearchCallback() {
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
                // Note: getGeoCoordinates() may return null only for Suggestions.
                addPoiMapMarker(searchResult.getGeoCoordinates(), metadata);
            }
        }
    };

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
        int maxItems = 5;
        SearchOptions searchOptions = new SearchOptions(LanguageCode.EN_US, maxItems);

        if (isDeviceConnected()) {
            // Simulate a user typing a search term.
            searchEngine.suggest(
                    new TextQuery("p", // User typed "p".
                            centerGeoCoordinates),
                    searchOptions,
                    autosuggestCallback);

            searchEngine.suggest(
                    new TextQuery("pi", // User typed "pi".
                            centerGeoCoordinates),
                    searchOptions,
                    autosuggestCallback);

            searchEngine.suggest(
                    new TextQuery("piz", // User typed "piz".
                            centerGeoCoordinates),
                    searchOptions,
                    autosuggestCallback);
        } else {
            // Simulate a user typing a search term.
            offlineSearchEngine.suggest(
                    new TextQuery("p", // User typed "p".
                            centerGeoCoordinates),
                    searchOptions,
                    autosuggestCallback);

            offlineSearchEngine.suggest(
                    new TextQuery("pi", // User typed "pi".
                            centerGeoCoordinates),
                    searchOptions,
                    autosuggestCallback);

            offlineSearchEngine.suggest(
                    new TextQuery("piz", // User typed "piz".
                            centerGeoCoordinates),
                    searchOptions,
                    autosuggestCallback);
        }
    }

    private void geocodeAddressAtLocation(String queryString, GeoCoordinates geoCoordinates) {
        clearMap();

        AddressQuery query = new AddressQuery(queryString, geoCoordinates);

        int maxItems = 30;
        SearchOptions options = new SearchOptions(LanguageCode.DE_DE, maxItems);

        if (isDeviceConnected()) {
            searchEngine.search(query, options, geocodeAddressSearchCallback);
        } else {
            offlineSearchEngine.search(query, options, geocodeAddressSearchCallback);
        }
    }

    private final SearchCallback geocodeAddressSearchCallback = new SearchCallback() {
        @Override
        public void onSearchCompleted(SearchError searchError, List<Place> list) {
            if (searchError != null) {
                showDialog("Geocoding", "Error: " + searchError.toString());
                return;
            }

            for (Place geocodingResult : list) {
                // Note: getGeoCoordinates() may return null only for Suggestions.
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
    };

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
        return new MapMarker(geoCoordinates, mapImage, new Anchor2D(0.5F, 1));
    }

    private GeoCoordinates getMapViewCenter() {
        GeoCoordinates centerGeoCoordinates = mapView.viewToGeoCoordinates(new Point2D(mapView.getWidth() / 2, mapView.getHeight() / 2));
        if (centerGeoCoordinates == null) {
            // Should never happen for center coordinates.
            throw new RuntimeException("CenterGeoCoordinates are null");
        }
        return centerGeoCoordinates;
    }

    private GeoBox getMapViewGeoBox() {
        int mapViewWidthInPixels = mapView.getWidth();
        int mapViewHeightInPixels = mapView.getHeight();
        Point2D bottomLeftPoint2D = new Point2D(0, mapViewHeightInPixels);
        Point2D topRightPoint2D = new Point2D(mapViewWidthInPixels, 0);

        GeoCoordinates southWestCorner = mapView.viewToGeoCoordinates(bottomLeftPoint2D);
        GeoCoordinates northEastCorner = mapView.viewToGeoCoordinates(topRightPoint2D);

        if (southWestCorner == null || northEastCorner == null) {
            throw new RuntimeException("GeoBox creation failed, corners are null.");
        }

        // Note: This algorithm assumes an unrotated map view.
        return new GeoBox(southWestCorner, northEastCorner);
    }

    private void clearMap() {
        for (MapMarker mapMarker : mapMarkerList) {
            mapView.getMapScene().removeMapMarker(mapMarker);
        }
        mapMarkerList.clear();
    }

    public void onSwitchOnlineButtonClicked() {
        isDeviceConnected = true;
        Toast.makeText(context,"The app will now use the SearchEngine.", Toast.LENGTH_LONG).show();
    }

    public void onSwitchOfflineButtonClicked() {
        isDeviceConnected = false;
        Toast.makeText(context,"The app will now use the OfflineSearchEngine.", Toast.LENGTH_LONG).show();
    }

    private boolean isDeviceConnected() {
        // An application may define here a logic to determine whether a device is connected or not.
        // For this example app, the flag is set from UI.
        return isDeviceConnected;
    }

    private void showDialog(String title, String message) {
        AlertDialog.Builder builder =
                new AlertDialog.Builder(context);
        builder.setTitle(title);
        builder.setMessage(message);
        builder.show();
    }
}
