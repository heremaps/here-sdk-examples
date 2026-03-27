/*
 * Copyright (C) 2025-2026 HERE Europe B.V.
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

package com.here.camerakeyframetrackskotlin

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
    dropDownMenuXOffset: Dp,
    dropDownMenuYOffset: Dp,
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
        offset = DpOffset(dropDownMenuXOffset, dropDownMenuYOffset)
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
    onAnimateToRouteClick: (String) -> Unit,
    onTripToNycClick: (String) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    var expandedMapObjects by remember { mutableStateOf(false) }
    var expandedMapMarkers by remember { mutableStateOf(false) }
    var expandedMapViewPins by remember { mutableStateOf(false) }
    val dropDownMenuXOffset = getDropDownxOffset()

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
                // Animate to route
                DropdownSubMenuItem(
                    label = "Animate to route",
                    expanded = expandedMapObjects,
                    dropDownMenuXOffset = dropDownMenuXOffset,
                    dropDownMenuYOffset = 40.dp,
                    onExpandChange = { expandedMapObjects = it }
                ) {
                    listOf("Start Route Animation", "Stop Route Animation"
                    ).forEach { item ->
                        DropdownMenuItem(
                            text = { Text(item) },
                            onClick = { onAnimateToRouteClick(item); expanded = false }
                        )
                    }
                }

                // Trip to NYC
                DropdownSubMenuItem(
                    label = "Trip to NYC",
                    expanded = expandedMapMarkers,
                    dropDownMenuXOffset = dropDownMenuXOffset,
                    dropDownMenuYOffset = 50.dp,
                    onExpandChange = { expandedMapMarkers = it }
                ) {
                    listOf(
                        "Start NYC Animation", "Stop NYC Animation"
                    ).forEach { item ->
                        DropdownMenuItem(
                            text = { Text(item) },
                            onClick = { onTripToNycClick(item); expanded = false }
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
    var dropDownMenuXOffset: Dp? = 200.dp
    dropDownMenuXOffset = screenWidth.dp - 140.dp

    return dropDownMenuXOffset
}
