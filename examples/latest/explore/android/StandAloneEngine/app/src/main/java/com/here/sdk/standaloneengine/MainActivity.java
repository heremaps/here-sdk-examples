/*
 * Copyright (C) 2019-2022 HERE Europe B.V.
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
import androidx.appcompat.app.AppCompatActivity;
import android.util.Log;
import android.widget.TextView;

import com.here.sdk.core.engine.SDKNativeEngine;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.LanguageCode;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.search.CategoryQuery;
import com.here.sdk.search.Place;
import com.here.sdk.search.PlaceCategory;
import com.here.sdk.search.SearchCallback;
import com.here.sdk.search.SearchEngine;
import com.here.sdk.search.SearchError;
import com.here.sdk.search.SearchOptions;

import java.util.ArrayList;
import java.util.List;

/**
 * This example app shows that an engine can be used independently from a MapView,
 * without any further adaptions. Here we use a SearchEngine to start a category search
 * in Berlin, Germany.
 */
public class MainActivity extends AppCompatActivity {

    private static final String TAG = MainActivity.class.getName();

    private SearchEngine searchEngine;
    private TextView infoTextview;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        infoTextview = findViewById(R.id.infoTextView);

        try {
            searchEngine = new SearchEngine();
        } catch (InstantiationErrorException e) {
            infoTextview.setText(e.error.name());
            return;
        }

        searchForCategories();
    }

    private void searchForCategories() {
        List<PlaceCategory> categoryList = new ArrayList<>();
        categoryList.add(new PlaceCategory(PlaceCategory.EAT_AND_DRINK));
        categoryList.add(new PlaceCategory(PlaceCategory.SHOPPING_ELECTRONICS));

        CategoryQuery.Area queryArea = new CategoryQuery.Area(new GeoCoordinates(52.520798, 13.409408));
        CategoryQuery categoryQuery = new CategoryQuery(categoryList, queryArea);

        SearchOptions searchOptions = new SearchOptions();
        searchOptions.languageCode = LanguageCode.EN_US;
        searchOptions.maxItems = 30;

        searchEngine.search(categoryQuery, searchOptions, new SearchCallback() {
            @Override
            public void onSearchCompleted(SearchError searchError, List<Place> list) {
                if (searchError != null) {
                    infoTextview.setText("Search Error: " + searchError.toString());
                    return;
                }

                // If error is null, list is guaranteed to be not empty.
                String numberOfResults = "Search results: " + list.size() + ". See log for details.";
                infoTextview.setText(numberOfResults);

                for (Place searchResult : list) {
                    String addressText = searchResult.getAddress().addressText;
                    Log.d(TAG, addressText);
                }
            }
        });
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();

        // Free HERE SDK resources before the application shuts down.
        SDKNativeEngine hereSDKEngine = SDKNativeEngine.getSharedInstance();
        if (hereSDKEngine != null) {
            hereSDKEngine.dispose();
        }
    }
}
