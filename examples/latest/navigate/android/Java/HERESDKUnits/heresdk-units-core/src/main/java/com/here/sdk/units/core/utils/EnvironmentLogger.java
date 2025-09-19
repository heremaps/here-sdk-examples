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

package com.here.sdk.units.core.utils;

import android.util.Log;
import com.here.sdk.core.engine.SDKBuildInformation;

public class EnvironmentLogger {

    public void logEnvironment(String sourceLanguage){
        // Log HERE SDK version details.
        log("HERE SDK Version Name: " + SDKBuildInformation.sdkVersion().versionName);
        log("HERE SDK Variant: " + SDKBuildInformation.sdkVersion().productVariant);

        // Log Android details.
        log("Android API Level: " + android.os.Build.VERSION.SDK_INT);
        log("Android OS Version: " + android.os.Build.VERSION.RELEASE);

        // Log Device details.
        log("Device Model: " + android.os.Build.MODEL);
        log("Device Manufacturer: " + android.os.Build.MANUFACTURER);
        log("Device Brand: " + android.os.Build.BRAND);
        log("Device Hardware: " + android.os.Build.HARDWARE);

        // Log Source language of the application.
        log("Application Source Language: " + sourceLanguage);
    }

    public void log(String message){
        String TAG = "UnitLogger";
        Log.d(TAG, message);
    }

}
