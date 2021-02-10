/*
 * Copyright (C) 2019-2021 HERE Europe B.V.
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

package com.here.search;

import android.Manifest;
import android.app.Activity;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.os.Build;
import android.support.annotation.NonNull;
import android.support.v4.app.ActivityCompat;
import android.support.v4.content.ContextCompat;

import java.util.ArrayList;

/**
 * Convenience class to request the Android permissions as defined by manifest.
 */
public class PermissionsRequestor {

    private static final int PERMISSIONS_REQUEST_CODE = 42;
    private ResultListener resultListener;
    private final Activity activity;

    public PermissionsRequestor(Activity activity) {
        this.activity = activity;
    }

    public interface ResultListener {
        void permissionsGranted();
        void permissionsDenied();
    }

    public void request(ResultListener resultListener) {
        this.resultListener = resultListener;

        String[] missingPermissions = getPermissionsToRequest();
        if (missingPermissions.length == 0) {
            resultListener.permissionsGranted();
        } else {
            ActivityCompat.requestPermissions(activity, missingPermissions, PERMISSIONS_REQUEST_CODE);
        }
    }

    private String[] getPermissionsToRequest() {
        ArrayList<String> permissionList = new ArrayList<>();
        try {
            PackageInfo packageInfo = activity.getPackageManager().getPackageInfo(
                    activity.getPackageName(), PackageManager.GET_PERMISSIONS);
            if (packageInfo.requestedPermissions != null) {
                for (String permission : packageInfo.requestedPermissions) {
                    if (ContextCompat.checkSelfPermission(
                            activity, permission) != PackageManager.PERMISSION_GRANTED) {
                        if (Build.VERSION.SDK_INT == Build.VERSION_CODES.M &&
                                permission.equals(Manifest.permission.CHANGE_NETWORK_STATE)) {
                            // Exclude CHANGE_NETWORK_STATE as it does not require explicit user approval.
                            // This workaround is needed for devices running Android 6.0.0,
                            // see https://issuetracker.google.com/issues/37067994
                            continue;
                        }
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
                                (permission.equals(Manifest.permission.ACTIVITY_RECOGNITION) ||
                                        permission.equals(Manifest.permission.ACCESS_BACKGROUND_LOCATION))) {
                            continue;
                        }
                        permissionList.add(permission);
                    }
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return permissionList.toArray(new String[0]);
    }

    public void onRequestPermissionsResult(int requestCode, @NonNull int[] grantResults) {
        if (resultListener == null) {
            return;
        }

        if (grantResults.length == 0) {
            // Request was cancelled.
            return;
        }

        if (requestCode == PERMISSIONS_REQUEST_CODE) {
            boolean allGranted = true;
            for (int result : grantResults) {
                allGranted &= result == PackageManager.PERMISSION_GRANTED;
            }

            if (allGranted) {
                resultListener.permissionsGranted();
            } else {
                resultListener.permissionsDenied();
            }
        }
    }
}
