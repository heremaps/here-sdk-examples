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
package com.here.sdk.units.core.animations

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.isPrimaryPressed
import androidx.compose.ui.input.pointer.pointerInput

object UnitAnimations {

    // Method to apply a default click animation to any view.
    // The view scales down to 96% of its size when pressed and returns to normal size when released.
    // Duration of the animation is set to 100 milliseconds.
    @Composable
    fun ClickAnimation(
        content: @Composable () -> Unit
    ) {
        ClickAnimation(
            scaleActionDown = floatArrayOf(0.96f, 0.96f),
            scaleActionNormal = floatArrayOf(1.0f, 1.0f),
            durationMs = 100,
            content = content
        )
    }

    // Method to apply click animation to any view with custom parameters.
    // scaleActionDown: [scaleX, scaleY] when view is pressed down.
    // scaleActionNormal: [scaleX, scaleY] when view is released.
    // durationMs: duration of the animation in milliseconds.
    @Composable
    fun ClickAnimation(
        scaleActionDown: FloatArray,
        scaleActionNormal: FloatArray,
        durationMs: Int,
        content: @Composable () -> Unit
    ) {
        var pressed by remember { mutableStateOf(false) }

        val scaleX by animateFloatAsState(
            targetValue = if (pressed) scaleActionDown[0] else scaleActionNormal[0],
            animationSpec = tween(durationMs)
        )

        val scaleY by animateFloatAsState(
            targetValue = if (pressed) scaleActionDown[1] else scaleActionNormal[1],
            animationSpec = tween(durationMs)
        )

        Box(
            modifier = Modifier
                .graphicsLayer(
                    scaleX = scaleX,
                    scaleY = scaleY
                )
                .pointerInput(Unit) {
                    awaitPointerEventScope {
                        while (true) {
                            val event = awaitPointerEvent()
                            val pressedNow = event.buttons.isPrimaryPressed
                            pressed = pressedNow
                        }
                    }
                }
        ) {
            content()
        }
    }
}
