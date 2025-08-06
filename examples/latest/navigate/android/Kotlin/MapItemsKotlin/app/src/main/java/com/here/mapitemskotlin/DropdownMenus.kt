/*
 * Copyright (C) 2025 HERE Europe B.V.
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
package com.here.mapitemskotlin

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.Alignment
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.unit.DpOffset

/*
* A helper composable to display a parent menu item that, when clicked,
* expands a nested dropdown menu directly below it.
*/
@Composable
fun DropdownSubMenuItem(
    label: String,
    expanded: Boolean,
    dropDownMenuxOffSet: Dp,
    dropDownMenuyOffSet: Dp,
    onExpandChange: (Boolean) -> Unit,
    nestedContent: @Composable () -> Unit,
) {
    DropdownMenuItem(
        text = { Text(label) },
        onClick = { onExpandChange(true) }
    )
    DropdownMenu(
        expanded = expanded,
        onDismissRequest = { onExpandChange(false) },
        offset = DpOffset(dropDownMenuxOffSet, dropDownMenuyOffSet)
    ) {
        nestedContent()
    }
}

/*
* A composable that displays a dropdown menu with nested submenus.
* The child menu expands directly below the selected parent menu item.
* 
*/
@Composable
fun DropdownMenu(
    onMapObjectClick: (String) -> Unit,
    onMapMarkerClick: (String) -> Unit,
    onMapViewPinClick: (String) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    var expandedMapObjects by remember { mutableStateOf(false) }
    var expandedMapMarkers by remember { mutableStateOf(false) }
    var expandedMapViewPins by remember { mutableStateOf(false) }
    val dropDownMenuxOffSet = getDropDownxOffset()

    Column(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.End
    ) {
        Box {
            Row(
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(
                    onClick = { expanded = true },
                    modifier = Modifier.padding(top = 16.dp, end = 16.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.MoreVert,
                        contentDescription = "More options",
                        modifier = Modifier.size(36.dp)
                    )
                }
            }

            DropdownMenu(
                expanded = expanded,
                modifier = Modifier.align(Alignment.TopEnd),
                onDismissRequest = {
                    expanded = false
                    expandedMapObjects = false
                    expandedMapMarkers = false
                    expandedMapViewPins = false
                }
            ) {
                // Map Objects
                DropdownSubMenuItem(
                    label = "Map Objects",
                    expanded = expandedMapObjects,
                    dropDownMenuxOffSet = dropDownMenuxOffSet,
                    dropDownMenuyOffSet = 40.dp,
                    onExpandChange = { expandedMapObjects = it }
                ) {
                    listOf("Polyline", "Arrow", "Polygon", "Circle", "Clear Items").forEach { item ->
                        DropdownMenuItem(
                            text = { Text(item) },
                            onClick = { onMapObjectClick(item); expanded = false }
                        )
                    }
                }

                // Map Markers
                DropdownSubMenuItem(
                    label = "Map Markers",
                    expanded = expandedMapMarkers,
                    dropDownMenuxOffSet = dropDownMenuxOffSet,
                    dropDownMenuyOffSet = 50.dp,
                    onExpandChange = { expandedMapMarkers = it }
                ) {
                    listOf(
                        "Anchored (2D)", "Centered (2D)", "Marker with Text",
                        "MapMarkerCluster", "Location (PED)", "Location (NAV)",
                        "Active/Inactive", "Flat Marker", "2D Texture",
                        "3D Object", "Clear Map"
                    ).forEach { item ->
                        DropdownMenuItem(
                            text = { Text(item) },
                            onClick = { onMapMarkerClick(item); expanded = false }
                        )
                    }
                }

                // Map View Pins
                DropdownSubMenuItem(
                    label = "Map View Pins",
                    expanded = expandedMapViewPins,
                    dropDownMenuxOffSet = dropDownMenuxOffSet,
                    dropDownMenuyOffSet = 60.dp,
                    onExpandChange = { expandedMapViewPins = it }
                ) {
                    listOf("Default", "Anchored", "Clear Map").forEach { item ->
                        DropdownMenuItem(
                            text = { Text(item) },
                            onClick = { onMapViewPinClick(item); expanded = false }
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun getDropDownxOffset(): Dp {
    // Calculate the screen display pixels.
    val configuration = LocalConfiguration.current
    val screenWidth = configuration.screenWidthDp
    var dropDownMenuxOffSet: Dp? = 200.dp
    dropDownMenuxOffSet = screenWidth.dp - 140.dp

    return dropDownMenuxOffSet
}
