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
package com.here.sdk.units.core.utils

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

/**
 * Convenience class to request the Android permissions as defined by manifest.
 */
class PermissionsRequestor(private val activity: Activity) {

    companion object {
        private const val PERMISSIONS_REQUEST_CODE = 42
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
            ActivityCompat.requestPermissions(
                activity,
                missingPermissions.toTypedArray(),
                PERMISSIONS_REQUEST_CODE
            )
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

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        val listener = resultListener ?: return

        if (grantResults.isEmpty()) {
            // Request was cancelled.
            return
        }

        if (requestCode == PERMISSIONS_REQUEST_CODE) {
            val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }

            if (allGranted) {
                listener.permissionsGranted()
            } else {
                listener.permissionsDenied()
            }
        }
    }
}
