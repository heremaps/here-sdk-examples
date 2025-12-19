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

package com.here.sdk.units.speedlimit

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

// The HERE SDK unit class that defines the logic for the view.
// The logic sets the speed limit and label to the speed limit view.
data class SpeedLimitUiState(
    val label: String = "",
    val speedText: String = "n/a"
)

class SpeedLimitUnit {
    internal var uiState by mutableStateOf(SpeedLimitUiState())
        private set

    fun setLabel(value: String) {
        uiState = uiState.copy(label = value)
    }

    fun setSpeedLimit(value: Int) {
        val speedText = value.toString()
        uiState = uiState.copy(speedText = speedText)
    }
}