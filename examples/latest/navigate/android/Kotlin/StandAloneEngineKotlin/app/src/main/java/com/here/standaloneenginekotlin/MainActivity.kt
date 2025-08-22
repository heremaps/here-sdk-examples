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
package com.here.standaloneenginekotlin

import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.core.LanguageCode
import com.here.sdk.core.engine.AuthenticationMode
import com.here.sdk.core.engine.SDKNativeEngine
import com.here.sdk.core.engine.SDKOptions
import com.here.sdk.core.errors.InstantiationErrorException
import com.here.sdk.search.CategoryQuery
import com.here.sdk.search.Place
import com.here.sdk.search.PlaceCategory
import com.here.sdk.search.SearchCallback
import com.here.sdk.search.SearchEngine
import com.here.sdk.search.SearchError
import com.here.sdk.search.SearchOptions
import com.here.standaloneenginekotlin.ui.theme.StandAloneEngineTheme

class MainActivity : ComponentActivity() {

    private lateinit var searchEngine: SearchEngine
    private var infoText by mutableStateOf("Info (see logs).")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
        // Before creating a MapView instance please make sure that the HERE SDK is initialized.
        initializeHERESDK()

        enableEdgeToEdge()

        setContent {
            StandAloneEngineTheme {
                Scaffold(
                    modifier = Modifier.fillMaxSize()
                ) { paddingValues ->
                    Box(modifier = Modifier.padding(paddingValues)) {
                        Text(text = infoText)
                    }
                }
            }
        }

        try {
            searchEngine = SearchEngine()
        } catch (e: InstantiationErrorException) {
            infoText = e.error.name
            return
        }

        searchForCategories()
    }

    private fun initializeHERESDK() {
        // Set your credentials for the HERE SDK.
        val accessKeyID = "YOUR_ACCESS_KEY_ID"
        val accessKeySecret = "YOUR_ACCESS_KEY_SECRET"
        val authenticationMode = AuthenticationMode.withKeySecret(accessKeyID, accessKeySecret)
        val options = SDKOptions(authenticationMode)
        try {
            val context = this
            SDKNativeEngine.makeSharedInstance(context, options)
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("Initialization of HERE SDK failed: " + e.error.name)
        }
    }

    private fun searchForCategories() {
        val categoryList: MutableList<PlaceCategory> = mutableListOf()
        categoryList.add(PlaceCategory(PlaceCategory.EAT_AND_DRINK))
        categoryList.add(PlaceCategory(PlaceCategory.SHOPPING_ELECTRONICS))

        val queryArea = CategoryQuery.Area(GeoCoordinates(52.520798, 13.409408))
        val categoryQuery = CategoryQuery(categoryList, queryArea)

        val searchOptions = SearchOptions()
        searchOptions.languageCode = LanguageCode.EN_US
        searchOptions.maxItems = 30

        searchEngine.searchByCategory(
            categoryQuery, searchOptions,
            object : SearchCallback {
                override fun onSearchCompleted(searchError: SearchError?, list: List<Place>?) {
                    if (searchError != null) {
                        this@MainActivity.infoText = "Search Error: $searchError"
                        return
                    }
                    // If error is null, list is guaranteed to be not empty.
                    val numberOfResults = "Search results: " + list!!.size + ". See log for details."
                    this@MainActivity.infoText = numberOfResults
                    for (searchResult in list) {
                        val addressText = searchResult.address.addressText
                        Log.d(TAG, addressText)
                    }
                }
            })
    }

    override fun onDestroy() {
        disposeHERESDK()
        super.onDestroy()
    }

    private fun disposeHERESDK() {
        // Free HERE SDK resources before the application shuts down.
        // Usually, this should be called only on application termination.
        // Afterwards, the HERE SDK is no longer usable unless it is initialized again.
        SDKNativeEngine.getSharedInstance()?.dispose()
        // For safety reasons, we explicitly set the shared instance to null to avoid situations,
        // where a disposed instance is accidentally reused.
        SDKNativeEngine.setSharedInstance(null)
    }

    private companion object {
        private val TAG = MainActivity::class.java.simpleName
    }
}
