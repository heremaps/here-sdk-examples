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

package com.here.sdk.units.mapruler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.material3.Text
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.platform.LocalDensity

// Fixed dimensions for the scale bar.
val SCALE_BAR_WIDTH: Dp = 90.dp
val SCALE_BAR_HEIGHT: Dp = 10.dp

/**
 * Jetpack Compose view that shows the animated scale bar with scale text.
 * This composable itself has a fixed width and wraps its height.
 */
@Composable
fun MapScaleView(
    unit: MapScaleUnit,
    modifier: Modifier = Modifier
) {

    val density = LocalDensity.current

    // Tell the unit class what the actual width in pixels is.
    LaunchedEffect(density) {
        val widthPx = with(density) { SCALE_BAR_WIDTH.toPx() }
        unit.setScaleBarWidthPx(widthPx.toDouble())
    }

    DisposableEffect(Unit) {
        onDispose {
            unit.onDispose()
        }
    }

    // No fillMaxSize, just a fixed-width column.
    Column(
        modifier = modifier
            .width(SCALE_BAR_WIDTH)
    ) {
        // Scale text with fixed width box.
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(Color(0xAA000000))
        ) {
            Text(
                text = unit.uiState.scaleText,
                color = Color.White,
                fontSize = 14.sp,
                modifier = Modifier
                    .padding(start = 8.dp, top = 4.dp, bottom = 4.dp, end = 8.dp)
                    .align(Alignment.CenterStart)
            )
        }

        Spacer(modifier = Modifier.height(10.dp))

        ScaleLines(
            modifier = Modifier
                .fillMaxWidth() // same width as parent
        )
    }
}

@Composable
private fun ScaleLines(
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .height(SCALE_BAR_HEIGHT)
    ) {
        // Left vertical line.
        Box(
            modifier = Modifier
                .width(4.dp)
                .height(SCALE_BAR_HEIGHT)
                .background(Color.Black)
                .align(Alignment.TopStart)
        )

        // Right vertical line.
        Box(
            modifier = Modifier
                .width(4.dp)
                .height(SCALE_BAR_HEIGHT)
                .background(Color.Black)
                .align(Alignment.TopEnd)
        )

        // Bottom horizontal line spans the full width.
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(4.dp)
                .background(Color.Black)
                .align(Alignment.BottomCenter)
        )
    }
}
