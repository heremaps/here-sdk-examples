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

package com.here.navigationkotlin

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/**
 * A singleton utility for showing global dialogs in a Compose application.
 *
 * Use this to manage simple text-based dialogs or HTML content dialogs from anywhere in the app.
 * The actual display is handled in the @Composable DialogScreen, see MainActivity.
 *
 * Usage example:
 * DialogManager.show("title", "text", buttonText = "Ok") {}
 */
object DialogManager {
    // By the default, the dialog is hidden.
    var showDialog by mutableStateOf(false)
    var dialogTitle by mutableStateOf("")
    var dialogButtonText by mutableStateOf("")
    var cancelable by mutableStateOf(true)
    var dialogText by mutableStateOf<String?>(null)
    // Optional composable content to show in the dialog.
    // Used when displaying custom HTML views like WebView or complex layouts.
    var dialogContent: (@Composable (() -> Unit))? = null
    var onDismissCallback: (() -> Unit)? = null

    // Show a basic text dialog.
    fun show(
        title: String,
        text: String,
        buttonText: String,
        // By default, the dialog is not cancelable by pressing back.
        cancelable: Boolean = false,
        onDismiss: () -> Unit
    ) {
        dialogTitle = title
        dialogText = text
        dialogContent = null
        dialogButtonText = buttonText
        this.cancelable = cancelable
        onDismissCallback = onDismiss
        showDialog = true
    }

    // Show a dialog with custom composable content.
    fun showWithCustomContent(
        title: String,
        content: @Composable () -> Unit,
        buttonText: String,
        // By default, the dialog is not cancelable by pressing back.
        cancelable: Boolean = false,
        onDismiss: () -> Unit
    ) {
        dialogTitle = title
        dialogText = null
        dialogContent = content
        dialogButtonText = buttonText
        this.cancelable = cancelable
        onDismissCallback = onDismiss
        showDialog = true
    }

    fun hide() {
        showDialog = false
    }
}
