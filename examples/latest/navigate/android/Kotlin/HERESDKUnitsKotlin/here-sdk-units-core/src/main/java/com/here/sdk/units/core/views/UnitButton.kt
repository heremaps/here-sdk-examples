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
package com.here.sdk.units.core.views

import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.here.sdk.units.core.animations.UnitAnimations
import com.here.sdk.units.core.theme.DefaultUnitButtonColor

@Composable
fun UnitButton(
    text: String,
    modifier: Modifier = Modifier,
    scaleActionDown: FloatArray = floatArrayOf(0.92f, 0.85f),
    scaleActionNormal: FloatArray = floatArrayOf(1f, 1f),
    durationMs: Int = 150,
    onClick: () -> Unit
) {
    UnitButtonInternal(
        text = text,
        modifier = modifier,
        scaleActionDown = scaleActionDown,
        scaleActionNormal = scaleActionNormal,
        durationMs = durationMs,
        onClick = onClick,
        onClickComposable = null
    )
}

@Composable
fun UnitButton(
    text: String,
    modifier: Modifier = Modifier,
    scaleActionDown: FloatArray = floatArrayOf(0.92f, 0.85f),
    scaleActionNormal: FloatArray = floatArrayOf(1f, 1f),
    durationMs: Int = 150,
    onClickComposable: @Composable () -> Unit
) {
    UnitButtonInternal(
        text = text,
        modifier = modifier,
        scaleActionDown = scaleActionDown,
        scaleActionNormal = scaleActionNormal,
        durationMs = durationMs,
        onClick = null,
        onClickComposable = onClickComposable
    )
}

@Composable
private fun UnitButtonInternal(
    text: String,
    modifier: Modifier,
    scaleActionDown: FloatArray,
    scaleActionNormal: FloatArray,
    durationMs: Int,
    onClick: (() -> Unit)?,
    onClickComposable: (@Composable () -> Unit)?
) {
    var showComposable by remember { mutableStateOf(false) }

    UnitAnimations.ClickAnimation(
        scaleActionDown = scaleActionDown,
        scaleActionNormal = scaleActionNormal,
        durationMs = durationMs
    ) {
        Button(
            onClick = {
                onClick?.invoke()
                if (onClickComposable != null) {
                    showComposable = true
                }
            },
            modifier = modifier,
            colors = ButtonDefaults.buttonColors(
                containerColor = DefaultUnitButtonColor
            )
        ) {
            Text(text)
        }
    }

    if (showComposable && onClickComposable != null) {
        onClickComposable()
    }
}
