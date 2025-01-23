/*
 * Copyright (C) 2023-2025 HERE Europe B.V.
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

package com.here.hellomapandroidauto;

import android.content.Context;
import android.util.Log;
import com.here.sdk.core.engine.AuthenticationMode;
import com.here.sdk.core.engine.SDKNativeEngine;
import com.here.sdk.core.engine.SDKOptions;
import com.here.sdk.core.errors.InstantiationErrorException;

/**
 * Manages lifecycle of HERE SDK. Usages of SDK are counted and SDK is disposed only after all
 * usages ended.
 */
public class HERESDKLifecycle {

  private static final String TAG = HERESDKLifecycle.class.getSimpleName();

  /**
   * On first call, HERE sdk get initialized. Subsequent calls will not re-initialize the SDK, but
   * number of start calls will be tracked.
   *
   * @param context Android context
   */
  static void start(android.content.Context context) {
    // Always remember usage.
    mUsagesCount++;

    // Avoid redundant initializations.
    if (SDKNativeEngine.getSharedInstance() != null) {
      return;
    }

    // Set your credentials for the HERE SDK.
    String accessKeyID = "YOUR_ACCESS_KEY_ID";
    String accessKeySecret ="YOUR_ACCESS_KEY_SECRET";
    AuthenticationMode authenticationMode = AuthenticationMode.withKeySecret(accessKeyID, accessKeySecret);
    SDKOptions options = new SDKOptions(authenticationMode);
    try {
      Log.d(TAG, "initialize here sdk");
      SDKNativeEngine.makeSharedInstance(context, options);
    } catch (InstantiationErrorException e) {
      throw new RuntimeException("Initialization of HERE SDK failed: " +
                                 e.error.name());
    }
  }

  /**
   * Reduces internal count of SDK starts by 1. If counter reaches zero, SDK will be disposed.
   * Once disposed, the HERE SDK is no longer usable unless it is initialized again.
   * See {@link HERESDKLifecycle#start(Context)}. Purpose of this approach is to only
   * dispose the sdk after all usages ended.
   *
   */
  static void stop() {
    mUsagesCount--;
    if (mUsagesCount > 0) {
      return;
    }
    disposeSDK();
  }

  private static void disposeSDK() {
    SDKNativeEngine sdkNativeEngine = SDKNativeEngine.getSharedInstance();
    if (sdkNativeEngine != null) {
      Log.d(TAG, "dispose here sdk");
      sdkNativeEngine.dispose();
      // For safety reasons, we explicitly set the shared instance to null to
      // avoid situations, where a disposed instance is accidentally reused.
      SDKNativeEngine.setSharedInstance(null);
    }
  }

  private static int mUsagesCount = 0;
}
