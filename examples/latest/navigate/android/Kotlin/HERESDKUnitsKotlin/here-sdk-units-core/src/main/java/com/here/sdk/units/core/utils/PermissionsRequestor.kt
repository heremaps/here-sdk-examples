/*
 * Copyright (C) 2019-2026 HERE Europe B.V.
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
package com.here.sdk.units.core.utils

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.here.sdk.units.core.R

/**
 * Convenience class to request the Android permissions as defined by manifest.
 * It reads all permissions declared in the app's manifest, filters to those not yet granted, and requests them from the user.
 */
class PermissionsRequestor(private val activity: Activity) {

    companion object {
        private const val PERMISSIONS_REQUEST_CODE = 42
        private var requestBackgroundLocation = false
    }

    private var resultListener: ResultListener? = null

    interface ResultListener {
        fun permissionsGranted()
        fun permissionsDenied()
    }

    fun request(resultListener: ResultListener) {
        this.resultListener = resultListener

        val missingPermissions = getPermissionsToRequest()
        if (missingPermissions.isEmpty()) {
            resultListener.permissionsGranted()
        } else {
            requestPermissions(missingPermissions.toTypedArray())
        }
    }

    @Suppress("DEPRECATION")
    private fun getPermissionsToRequest(): List<String> {
        val permissionList = mutableListOf<String>()

        try {
            val packageName = activity.packageName
            val packageInfo =
                if (Build.VERSION.SDK_INT >= 33) {
                    activity.packageManager.getPackageInfo(
                        packageName,
                        PackageManager.PackageInfoFlags.of(PackageManager.GET_PERMISSIONS.toLong())
                    )
                } else {
                    activity.packageManager.getPackageInfo(
                        packageName,
                        PackageManager.GET_PERMISSIONS
                    )
                }

            packageInfo.requestedPermissions?.forEach { permission ->
                // Only runtime (dangerous) permissions can be requested.
                // Non-runtime permissions (e.g. androidx.car.app.*) are granted at
                // install time and must not be passed to requestPermissions(),
                // as they would be immediately denied, blocking all other grants.
                if (!permission.startsWith("android.permission.")) {
                    return@forEach
                }

                val notGranted = ContextCompat.checkSelfPermission(
                    activity,
                    permission
                ) != PackageManager.PERMISSION_GRANTED

                if (notGranted) {
                    // Skip ACCESS_BACKGROUND_LOCATION for Android < Q.
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
                        permission == Manifest.permission.ACCESS_BACKGROUND_LOCATION
                    ) {
                        return@forEach
                    }
                    permissionList.add(permission)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return permissionList
    }

    private fun requestPermissions(permissions: Array<String>) {
        val newPermissionList = mutableListOf<String>()
        for (permission in permissions) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
                permission == Manifest.permission.ACCESS_BACKGROUND_LOCATION &&
                !requestBackgroundLocation
            ) {
                // In >= Android 11 background location access cannot be requested at the same time
                // as basic location access (fine or coarse) but user should be provided a way to
                // enable it from application settings after basic location access has been granted.

                // This flag enables this functionality in onRequestPermissionsResult().
                requestBackgroundLocation = true

                if (permissions.size == 1) {
                    // Only background access requested -> request it now.
                    requestBackgroundLocationAccess()
                }
            } else {
                newPermissionList.add(permission)
            }
        }

        if (newPermissionList.isNotEmpty()) {
            ActivityCompat.requestPermissions(
                activity,
                newPermissionList.toTypedArray(),
                PERMISSIONS_REQUEST_CODE
            )
        }
        // else might be zero if only background location access was requested (see handling above).
    }

    fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        val listener = resultListener ?: return

        if (grantResults.isEmpty()) {
            // Request was cancelled.
            return
        }

        if (requestCode == PERMISSIONS_REQUEST_CODE) {
            var result = true
            for (i in permissions.indices) {
                val permission = permissions[i]
                val grantResult = grantResults[i]

                if ((permission == Manifest.permission.ACCESS_FINE_LOCATION ||
                            permission == Manifest.permission.ACCESS_COARSE_LOCATION) &&
                    grantResult == PackageManager.PERMISSION_DENIED
                ) {
                    // Do not request background location if basic location access has been denied.
                    requestBackgroundLocation = false
                }

                result = result && (grantResult == PackageManager.PERMISSION_GRANTED)
            }

            if (requestBackgroundLocationAccess()) {
                // Signal that not all permissions have been granted yet.
                result = false
            }

            if (result) {
                listener.permissionsGranted()
            } else {
                listener.permissionsDenied()
            }
        }
    }

    private fun requestBackgroundLocationAccess(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
            requestBackgroundLocation &&
            ActivityCompat.shouldShowRequestPermissionRationale(
                activity,
                Manifest.permission.ACCESS_BACKGROUND_LOCATION
            )
        ) {
            val builder = AlertDialog.Builder(activity)
            builder.setTitle(R.string.here_sdk_units_background_access_dialog_title)
            builder.setMessage(
                String.format(
                    activity.getString(R.string.here_sdk_units_background_access_dialog_text),
                    activity.packageManager.backgroundPermissionOptionLabel
                )
            )
            builder.setPositiveButton(R.string.here_sdk_units_background_access_button_settings) { _, _ ->
                requestPermissions(arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION))
                requestBackgroundLocation = false
            }
            builder.create().show()
            return true
        }
        return false
    }

    fun isLocationAccessDenied(): Boolean {
        return ContextCompat.checkSelfPermission(activity, Manifest.permission.ACCESS_FINE_LOCATION) ==
                PackageManager.PERMISSION_DENIED ||
                ContextCompat.checkSelfPermission(activity, Manifest.permission.ACCESS_COARSE_LOCATION) ==
                PackageManager.PERMISSION_DENIED
    }

    fun isBackgroundLocationDenied(): Boolean {
        if (requestBackgroundLocation) {
            return false
        }
        return ContextCompat.checkSelfPermission(activity, Manifest.permission.ACCESS_BACKGROUND_LOCATION) ==
                PackageManager.PERMISSION_DENIED
    }

    fun isNotificationDenied(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            return ContextCompat.checkSelfPermission(activity, Manifest.permission.POST_NOTIFICATIONS) ==
                    PackageManager.PERMISSION_DENIED
        }
        return false
    }
}
