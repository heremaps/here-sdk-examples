/*
 * Copyright (C) 2022-2025 HERE Europe B.V.
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

package com.here.examples.positioningwithbackgroundupdates;

import android.Manifest;
import android.app.Activity;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.os.Build;

import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedList;
import java.util.List;

import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

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
            requestPermissions(missingPermissions);
        }
    }

    @SuppressWarnings("deprecation")
    private String[] getPermissionsToRequest() {
        ArrayList<String> permissionList = new ArrayList<>();
        try {
            String packageName = activity.getPackageName();
            PackageInfo packageInfo;
            if (Build.VERSION.SDK_INT >= 33) {
                packageInfo = activity.getPackageManager().getPackageInfo(
                        packageName,
                        PackageManager.PackageInfoFlags.of(PackageManager.GET_PERMISSIONS));
            } else {
                packageInfo = activity.getPackageManager().getPackageInfo(
                        packageName,
                        PackageManager.GET_PERMISSIONS);
            }
            if (packageInfo.requestedPermissions != null) {
                for (String permission : packageInfo.requestedPermissions) {
                    if (ContextCompat.checkSelfPermission(
                            activity, permission) != PackageManager.PERMISSION_GRANTED) {
                        // FOREGROUND_SERVICE is needed on Android 9+ (API 28+)
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P &&
                                permission.equals(Manifest.permission.FOREGROUND_SERVICE)) {
                            continue;
                        }
                        // POST_NOTIFICATIONS is needed on Android 13+ (API 33+)
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU &&
                                permission.equals(Manifest.permission.POST_NOTIFICATIONS)) {
                            continue;
                        }

                        if (Build.VERSION.SDK_INT <
                                Build.VERSION_CODES.UPSIDE_DOWN_CAKE &&
                            permission.equals(
                                Manifest.permission
                                    .FOREGROUND_SERVICE_LOCATION)) {
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

    private void requestPermissions(String[] permissions) {
        List<String> newPermissionList = new LinkedList<>();
        Collections.addAll(newPermissionList, permissions);
        if (!newPermissionList.isEmpty()) {
            ActivityCompat.requestPermissions(activity, newPermissionList.toArray(new String[0]), PERMISSIONS_REQUEST_CODE);
        }
    }

    public void onRequestPermissionsResult(
            int requestCode, String[] permissions, int[] grantResults) {
        boolean result = true;
        if (requestCode == PERMISSIONS_REQUEST_CODE) {
            for (int i = 0; i < permissions.length; i++) {
                final int grantResult = grantResults[i];
                result &= grantResult == PackageManager.PERMISSION_GRANTED;
            }

            if (result) {
                resultListener.permissionsGranted();
            } else {
                resultListener.permissionsDenied();
            }
        }
    }

    public boolean isPostNotificationsAccessDenied() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            return ContextCompat.checkSelfPermission(activity, Manifest.permission.POST_NOTIFICATIONS)
                    == PackageManager.PERMISSION_DENIED;
        }
        return false;
    }

    public boolean isLocationAccessDenied() {
        return ContextCompat.checkSelfPermission(activity, Manifest.permission.ACCESS_FINE_LOCATION)
                == PackageManager.PERMISSION_DENIED ||
                ContextCompat.checkSelfPermission(activity, Manifest.permission.ACCESS_COARSE_LOCATION)
                        == PackageManager.PERMISSION_DENIED;
    }
}
