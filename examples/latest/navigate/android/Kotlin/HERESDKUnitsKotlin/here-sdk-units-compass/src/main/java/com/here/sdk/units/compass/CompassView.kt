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

package com.here.sdk.units.compass

import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource

/**
 * Jetpack Compose Compass Button that rotates with the map and
 * recenters the map to North-Up when tapped.
 */
@Composable
fun CompassView(
    unit: CompassUnit,
    modifier: Modifier = Modifier
) {
    DisposableEffect(Unit) {
        // Called when this composable enters the composition.
        onDispose {
            // Called exactly once when it leaves the composition.
            unit.onDispose()
        }
    }

    IconButton(
        onClick = { unit.resetNorthUpWithAnimation() },
        modifier = modifier.rotate(unit.uiState.rotationDegrees)
    ) {
        Icon(
            painter = painterResource(id = R.drawable.compass_icon),
            contentDescription = "Label",
            tint = Color.Unspecified
        )
    }
}
