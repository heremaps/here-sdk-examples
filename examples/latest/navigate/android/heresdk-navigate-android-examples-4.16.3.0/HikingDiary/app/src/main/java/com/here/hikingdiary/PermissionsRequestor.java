/*
 * Copyright (C) 2019-2023 HERE Europe B.V.
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

package com.here.hikingdiary;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.os.Build;

import java.util.ArrayList;
import java.util.LinkedList;
import java.util.List;

import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import com.here.HikingDiary.R;

/**
 * Convenience class to request the Android permissions as defined by manifest.
 */
public class PermissionsRequestor {

    private static final String TAG = PermissionsRequestor.class.getSimpleName();

    private static final int PERMISSIONS_REQUEST_CODE = 42;
    private ResultListener resultListener;
    private final Activity activity;
    private static boolean requestBackgroundLocation = false;

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
                        if (Build.VERSION.SDK_INT == Build.VERSION_CODES.M &&
                                permission.equals(Manifest.permission.CHANGE_NETWORK_STATE)) {
                            // Exclude CHANGE_NETWORK_STATE as it does not require explicit user approval.
                            // This workaround is needed for devices running Android 6.0.0,
                            // see https://issuetracker.google.com/issues/37067994
                            continue;
                        }
                        // ACCESS_BACKGROUND_LOCATION is needed on Android 10+ (API 29+)
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
                                permission.equals(Manifest.permission.ACCESS_BACKGROUND_LOCATION)) {
                            continue;
                        }
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
        for (final String permission : permissions) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && permission.equals(
                    Manifest.permission.ACCESS_BACKGROUND_LOCATION) && !requestBackgroundLocation) {
                // In >= Android 11 background location access cannot be requested at the same time
                // as basic location access (fine or coarse) but user should be provided a way to
                // enable it from application settings after basic location access has been granted.

                // This flag enables this functionality in onRequestPermissionsResult()
                requestBackgroundLocation = true;

                if (permissions.length == 1) {
                    // Only background access requested -> request it now.
                    requestBackgroundLocationAccess();
                }
            } else {
                newPermissionList.add(permission);
            }
        }

        if (newPermissionList.size() > 0) {
            ActivityCompat.requestPermissions(activity, newPermissionList.toArray(new String[0]), PERMISSIONS_REQUEST_CODE);
        }
        // else might be zero if only background location access was requested (see handling above).
    }

    public void onRequestPermissionsResult(
            int requestCode, String[] permissions, int[] grantResults) {
        boolean result = true;
        if (requestCode == PERMISSIONS_REQUEST_CODE) {
            for (int i = 0; i < permissions.length; i++) {
                final String permission = permissions[i];
                final int grantResult = grantResults[i];

                if ((permission.equals(Manifest.permission.ACCESS_FINE_LOCATION) ||
                        permission.equals(Manifest.permission.ACCESS_COARSE_LOCATION)) &&
                        (grantResult == PackageManager.PERMISSION_DENIED)) {
                    // Do not request background location if basic location access has been denied.
                    requestBackgroundLocation = false;
                }

                result &= grantResult == PackageManager.PERMISSION_GRANTED;
            }

            if (requestBackgroundLocationAccess()) {
                // Signal that not all permissions have been granted yet.
                result = false;
            }

            if (result) {
                resultListener.permissionsGranted();
            } else {
                resultListener.permissionsDenied();
            }
        }
    }

    private boolean requestBackgroundLocationAccess() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
                requestBackgroundLocation &&
                ActivityCompat.shouldShowRequestPermissionRationale(
                        activity,
                        Manifest.permission.ACCESS_BACKGROUND_LOCATION)) {
            // Show alert dialog to set background location access enabled.
            AlertDialog.Builder builder = new AlertDialog.Builder(activity);
            builder.setTitle(R.string.background_access_dialog_title);

            builder.setMessage(String.format(activity.getString(R.string.background_access_dialog_text), activity.getPackageManager().getBackgroundPermissionOptionLabel()));
            builder.setPositiveButton(R.string.background_access_button_settings, new DialogInterface.OnClickListener() {
                @Override
                public void onClick(DialogInterface dialog, int which) {
                    requestPermissions(new String[]{Manifest.permission.ACCESS_BACKGROUND_LOCATION});
                    requestBackgroundLocation = false;
                }
            });
            AlertDialog dialog = builder.create();
            dialog.show();
            return true;
        } else {
            return false;
        }
    }

    public boolean isLocationAccessDenied() {
        return ContextCompat.checkSelfPermission(activity, Manifest.permission.ACCESS_FINE_LOCATION)
                == PackageManager.PERMISSION_DENIED ||
                ContextCompat.checkSelfPermission(activity, Manifest.permission.ACCESS_COARSE_LOCATION)
                        == PackageManager.PERMISSION_DENIED;
    }

    public boolean isBackgroundLocationDenied() {
        if (requestBackgroundLocation) {
            return false;
        }
        return ContextCompat.checkSelfPermission(activity, Manifest.permission.ACCESS_BACKGROUND_LOCATION)
                == PackageManager.PERMISSION_DENIED;
    }

    public boolean isNotificationDenied() {
        return ContextCompat.checkSelfPermission(activity, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_DENIED ||
                ContextCompat.checkSelfPermission(activity, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED;
    }
}
