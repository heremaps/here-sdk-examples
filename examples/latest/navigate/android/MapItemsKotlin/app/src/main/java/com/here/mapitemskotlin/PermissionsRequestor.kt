/*
 * Copyright (C) 2025 HERE Europe B.V.
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
package com.here.mapitemskotlin

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat

// Convenience class to request the Android permissions as defined by manifest.
class PermissionsRequestor(private val activity: Activity) {

    private lateinit var activityResultLauncher: ActivityResultLauncher<Array<String>>
    private lateinit var resultListener: ResultListener

    interface ResultListener {
        fun permissionsGranted()
        fun permissionsDenied(deniedPermissions: List<String>)
    }

    init {
        createActivityResultLauncher(activity)
    }

    fun requestPermissionsFromManifest(resultListener: ResultListener) {
        this.resultListener = resultListener

        val permissionsList = getPermissionsFromManifest()
        val permissionsToRequest = ArrayList<String>()

        for (permission in permissionsList) {
            if (ContextCompat.checkSelfPermission(activity, permission) != PackageManager.PERMISSION_GRANTED) {
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q && permission == Manifest.permission.ACCESS_BACKGROUND_LOCATION) {
                    // Skip ACCESS_BACKGROUND_LOCATION for pre-Q devices.
                    continue
                }
                permissionsToRequest.add(permission)
            }
        }

        if (permissionsToRequest.isEmpty()) {
            resultListener.permissionsGranted()
        } else {
            activityResultLauncher.launch(permissionsToRequest.toTypedArray())
        }
    }

    private fun createActivityResultLauncher(activity: Activity) {
        if (activity is androidx.activity.ComponentActivity) {
            activityResultLauncher = activity.registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { permissions ->
                val deniedPermissions = permissions.filterValues { !it }.keys.toList()
                if (deniedPermissions.isEmpty()) {
                    resultListener.permissionsGranted()
                } else {
                    resultListener.permissionsDenied(deniedPermissions)
                }
            }
        } else {
            throw IllegalArgumentException("Activity must extend ComponentActivity.")
        }
    }

    private fun getPermissionsFromManifest(): List<String> {
        return try {
            val packageInfo = activity.packageManager.getPackageInfo(
                activity.packageName,
                PackageManager.GET_PERMISSIONS
            )
            packageInfo.requestedPermissions?.toList() ?: emptyList()
        } catch (e: Exception) {
            e.printStackTrace()
            emptyList()
        }
    }
}
