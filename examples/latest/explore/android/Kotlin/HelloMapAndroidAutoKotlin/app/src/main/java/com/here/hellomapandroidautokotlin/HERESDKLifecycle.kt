/*
 * Copyright (C) 2023-2026 HERE Europe B.V.
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
package com.here.hellomapandroidautokotlin

import android.content.Context
import android.util.Log
import com.here.sdk.core.engine.*
import com.here.sdk.core.errors.InstantiationErrorException

/**
 * Manages lifecycle of HERE SDK. Usages of SDK are counted and SDK is disposed only after all
 * usages ended.
 */
object HERESDKLifecycle {
    private val TAG: String = HERESDKLifecycle::class.java.simpleName

    /**
     * On first call, HERE sdk get initialized. Subsequent calls will not re-initialize the SDK, but
     * number of start calls will be tracked.
     *
     * @param context Android context
     */
    fun start(context: Context) {
        // Always remember usage.
        mUsagesCount++

        // Avoid redundant initializations.
        if (SDKNativeEngine.getSharedInstance() != null) {
            return
        }

        // Set your credentials for the HERE SDK.
        val accessKeyID = "YOUR_ACCESS_KEY_ID"
        val accessKeySecret = "YOUR_ACCESS_KEY_SECRET"
        val authenticationMode = AuthenticationMode.withKeySecret(accessKeyID, accessKeySecret)
        val options = SDKOptions(authenticationMode)
        try {
            Log.d(TAG, "Initialize HERE SDK.")
            SDKNativeEngine.makeSharedInstance(context, options)
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("Initialization of HERE SDK failed: ${e.error.name}")
        }
    }

    /**
     * Reduces internal count of SDK starts by 1. If counter reaches zero, SDK will be disposed.
     * Once disposed, the HERE SDK is no longer usable unless it is initialized again.
     * See [HERESDKLifecycle.start]. Purpose of this approach is to only
     * dispose the sdk after all usages ended.
     *
     */
    fun stop() {
        mUsagesCount--
        if (mUsagesCount > 0) {
            return
        }
        disposeSDK()
    }

    private fun disposeSDK() {
        val sdkNativeEngine = SDKNativeEngine.getSharedInstance()
        if (sdkNativeEngine != null) {
            Log.d(TAG, "Dispose HERE SDK.")
            sdkNativeEngine.dispose()
            // For safety reasons, we explicitly set the shared instance to null to
            // avoid situations, where a disposed instance is accidentally reused.
            SDKNativeEngine.setSharedInstance(null)
        }
    }

    private var mUsagesCount = 0
}
