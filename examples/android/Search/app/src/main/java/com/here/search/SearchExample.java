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

package com.here.search;

import android.content.Context;
import android.support.annotation.Nullable;
import android.support.v7.app.AlertDialog;
import android.widget.Toast;

import com.here.sdk.core.Anchor2D;
import com.here.sdk.core.CustomMetadataValue;
import com.here.sdk.core.GeoBoundingRect;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.LanguageCode;
import com.here.sdk.core.Metadata;
import com.here.sdk.core.Point2D;
import com.here.sdk.core.errors.EngineInstantiationErrorException;
import com.here.sdk.mapview.Camera;
import com.here.sdk.mapview.MapImage;
import com.here.sdk.mapview.MapImageFactory;
import com.here.sdk.mapview.MapMarker;
import com.here.sdk.mapview.MapMarkerImageStyle;
import com.here.sdk.mapview.MapView;
import com.here.sdk.mapview.PickMapItemsCallback;
import com.here.sdk.mapview.PickMapItemsResult;
import com.here.sdk.mapview.gestures.GestureState;
import com.here.sdk.search.Address;
import com.here.sdk.search.GeocodingCallback;
import com.here.sdk.search.GeocodingEngine;
import com.here.sdk.search.GeocodingError;
import com.here.sdk.search.GeocodingOptions;
import com.here.sdk.search.GeocodingResult;
import com.here.sdk.search.ReverseGeocodingCallback;
import com.here.sdk.search.ReverseGeocodingEngine;
import com.here.sdk.search.ReverseGeocodingError;
import com.here.sdk.search.ReverseGeocodingOptions;
import com.here.sdk.search.SearchCallback;
import com.here.sdk.search.SearchEngine;
import com.here.sdk.search.SearchError;
import com.here.sdk.search.SearchItem;
import com.here.sdk.search.SearchOptions;

import java.util.ArrayList;
import java.util.List;

public class SearchExample {

    private Context context;
    private MapView mapView;
    private Camera camera;
    private List<MapMarker> mapMarkerList = new ArrayList<>();
    private SearchEngine searchEngine;
    private GeocodingEngine geocodingEngine;
    private ReverseGeocodingEngine reverseGeocodingEngine;

    public void onMapSceneLoaded(Context context, MapView mapView) {
        this.context = context;
        this.mapView = mapView;
        camera = mapView.getCamera();
        camera.setTarget(new GeoCoordinates(52.530932, 13.384915));
        camera.setZoomLevel(14);

        try {
            searchEngine = new SearchEngine();
        } catch (EngineInstantiationErrorException e) {
            e.printStackTrace();
        }

        try {
            geocodingEngine = new GeocodingEngine();
        } catch (EngineInstantiationErrorException e) {
            e.printStackTrace();
        }

        try {
            reverseGeocodingEngine = new ReverseGeocodingEngine();
        } catch (EngineInstantiationErrorException e) {
            e.printStackTrace();
        }

        setTapGestureHandler();
        setLongPressGestureHandler();

        Toast.makeText(context,"Long press on map to get the address for that position using reverse geocoding.", Toast.LENGTH_LONG).show();
    }

    public void searchExample() {
        String searchTerm = "Pizza";

        Toast.makeText(context,"Searching around current map center location: " + searchTerm, Toast.LENGTH_LONG).show();
        searchAtMapCenter(searchTerm);
    }

    public void geocodeAnAddress() {
        // Set map to expected location.
        camera.setTarget(new GeoCoordinates(52.530932, 13.384915));

        String streetName = "Invalidenstraße 116";

        Toast.makeText(context,"Finding locations for: " + streetName
               + ". Tap marker to see the coordinates.", Toast.LENGTH_LONG).show();

        geocodeAddressInViewport(streetName);
    }

    private void setTapGestureHandler() {
        mapView.getGestures().setTapListener(origin -> pickMapMarker(origin));
    }

    private void setLongPressGestureHandler() {
        mapView.getGestures().setLongPressListener((gestureState, origin) -> {
            if (gestureState == GestureState.BEGIN) {
                GeoCoordinates geoCoordinates = mapView.getCamera().viewToGeoCoordinates(origin);
                addPoiMapMarker(geoCoordinates);
                getAddressForCoordinates(geoCoordinates);
            }
        });
    }

    private void getAddressForCoordinates(GeoCoordinates geoCoordinates) {
        // By default results are localized in EN_US.
        ReverseGeocodingOptions reverseGeocodingOptions = new ReverseGeocodingOptions(LanguageCode.EN_GB);

        reverseGeocodingEngine.searchAddress(
                geoCoordinates, reverseGeocodingOptions, new ReverseGeocodingCallback() {
            @Override
            public void onSearchCompleted(@Nullable ReverseGeocodingError reverseGeocodingError,
                                          @Nullable Address address) {
                if (reverseGeocodingError != null) {
                    showDialog("Reverse geocoding", "Error: " + reverseGeocodingError.toString());
                    return;
                }
                showDialog("Reverse geocoded address:", address.addressText);
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
                    CustomMetadataValue customMetadataValue = metadata.getCustomValue("key_search_item");
                    if (customMetadataValue != null) {
                        SearchItemMetadata searchItemMetadata = (SearchItemMetadata) customMetadataValue;
                        String title = searchItemMetadata.searchItem.title;
                        String vicinity = searchItemMetadata.searchItem.vicinity;
                        showDialog("Picked Search Result",
                                title + ", " + vicinity);
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

    private void searchAtMapCenter(String queryString) {
        clearMap();

        int maxSearchResults = 30;
        SearchOptions searchOptions = new SearchOptions(
                LanguageCode.EN_US,
                maxSearchResults);

        GeoCoordinates mapCenterGeoCoordinates = mapView.getCamera().getTarget();
        searchEngine.search(mapCenterGeoCoordinates, queryString, searchOptions, new SearchCallback() {
            @Override
            public void onSearchCompleted(@Nullable SearchError searchError, @Nullable List<SearchItem> list) {
                if (searchError != null) {
                    showDialog("Search", "Error: " + searchError.toString());
                    return;
                }

                if (list.isEmpty()) {
                    showDialog("Search", "No results found");
                } else {
                    showDialog("Search", "Results: " + list.size());
                }

                // Add new marker for each search result on map.
                for (SearchItem searchItem : list) {
                    Metadata metadata = new Metadata();
                    metadata.setCustomValue("key_search_item", new SearchItemMetadata(searchItem));
                    addPoiMapMarker(searchItem.coordinates, metadata);
                }
            }
        });
    }

    private class SearchItemMetadata implements CustomMetadataValue {

        public SearchItem searchItem;

        public SearchItemMetadata(SearchItem searchItem) {
            this.searchItem = searchItem;
        }

        @Override
        public String getTag() {
            return "SearchItem Metadata";
        }
    }

    private void geocodeAddressInViewport(String queryString) {
        clearMap();

        GeoBoundingRect geoBoundingRect = mapView.getCamera().getBoundingRect();
        long maxResultCount = 30;
        GeocodingOptions geocodingOptions = new GeocodingOptions(
                 LanguageCode.DE_DE, maxResultCount);

        geocodingEngine.searchLocations(geoBoundingRect, queryString, geocodingOptions, new GeocodingCallback() {
            @Override
            public void onSearchCompleted(@Nullable GeocodingError geocodingError,
                                          @Nullable List<GeocodingResult> list) {
                if (geocodingError != null) {
                    showDialog("Geocoding", "Error: " + geocodingError.toString());
                    return;
                }

                if (list.isEmpty()) {
                    showDialog("Geocoding", "No geocoding results found.");
                    return;
                }

                String locationDetails = "";
                for (GeocodingResult geocodingResult : list) {
                    GeoCoordinates geoCoordinates = geocodingResult.geoCoordinates;
                    Address address = geocodingResult.address;
                    if (geoCoordinates != null && address != null) {
                        locationDetails = address.addressText
                                + ". GeoCoordinates: " + geoCoordinates.latitude
                                + ", " + geoCoordinates.longitude;

                        addPoiMapMarker(geoCoordinates);
                    }
                }

                showDialog("Geocoding result",
                        "Size: " + list.size() + ", Details: " + locationDetails);
            }
        });
    }

    private void addPoiMapMarker(GeoCoordinates geoCoordinates) {
        MapMarker mapMarker = createMPoiapMarker(geoCoordinates);
        mapView.getMapScene().addMapMarker(mapMarker);
        mapMarkerList.add(mapMarker);
    }

    private void addPoiMapMarker(GeoCoordinates geoCoordinates, Metadata metadata) {
        MapMarker mapMarker = createMPoiapMarker(geoCoordinates);
        mapMarker.setMetadata(metadata);
        mapView.getMapScene().addMapMarker(mapMarker);
        mapMarkerList.add(mapMarker);
    }

    private MapMarker createMPoiapMarker(GeoCoordinates geoCoordinates) {
        MapImage mapImage = MapImageFactory.fromResource(context.getResources(), R.drawable.poi);
        MapMarker mapMarker = new MapMarker(geoCoordinates);
        MapMarkerImageStyle mapMarkerImageStyle = new MapMarkerImageStyle();
        mapMarkerImageStyle.setAnchorPoint(new Anchor2D(0.5F, 1));
        mapMarker.addImage(mapImage, mapMarkerImageStyle);
        return mapMarker;
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
