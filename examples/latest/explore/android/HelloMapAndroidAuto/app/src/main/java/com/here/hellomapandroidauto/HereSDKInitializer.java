/*
 * Copyright (C) 2023 HERE Europe B.V.
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

import com.here.sdk.core.engine.SDKNativeEngine;
import com.here.sdk.core.engine.SDKOptions;
import com.here.sdk.core.errors.InstantiationErrorException;

public class HereSDKInitializer {
    static void run(android.content.Context context) {
        if(SDKNativeEngine.getSharedInstance() != null)
        {
            return;
        }
        // Set your credentials for the HERE SDK.
        String accessKeyID = "YOUR_ACCESS_KEY_ID";
        String accessKeySecret = "YOUR_ACCESS_KEY_SECRET";
        SDKOptions options = new SDKOptions(accessKeyID, accessKeySecret);
        try {
            SDKNativeEngine.makeSharedInstance(context, options);
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of HERE SDK failed: " + e.error.name());
        }
    }
}
