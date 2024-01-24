/*
 * Copyright (C) 2019-2024 HERE Europe B.V.
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
package com.here.hellomap

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import java.util.*

/**
 * Convenience class to request the Android permissions as defined by manifest.
 */
class PermissionsRequestor(private val activity: Activity) {
    private var resultListener: ResultListener? = null

    interface ResultListener {
        fun permissionsGranted()
        fun permissionsDenied()
    }

    fun request(resultListener: ResultListener) {
        this.resultListener = resultListener
        val missingPermissions = permissionsToRequest
        if (missingPermissions.size == 0) {
            resultListener.permissionsGranted()
        } else {
            ActivityCompat.requestPermissions(activity, missingPermissions, PERMISSIONS_REQUEST_CODE)
        }
    }

    private val permissionsToRequest: Array<String>
        private get() {
            val permissionList = ArrayList<String>()
            try {
                @Suppress("DEPRECATION")
                val packageInfo = activity.packageManager.getPackageInfo(
                        activity.packageName, PackageManager.GET_PERMISSIONS)
                if (packageInfo.requestedPermissions != null) {
                    for (permission in packageInfo.requestedPermissions) {
                        if (ContextCompat.checkSelfPermission(
                                        activity, permission) != PackageManager.PERMISSION_GRANTED) {
                            if (Build.VERSION.SDK_INT == Build.VERSION_CODES.M && permission == Manifest.permission.CHANGE_NETWORK_STATE) {
                                // Exclude CHANGE_NETWORK_STATE as it does not require explicit user approval.
                                // This workaround is needed for devices running Android 6.0.0,
                                // see https://issuetracker.google.com/issues/37067994
                                continue
                            }
                            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
                                permission == Manifest.permission.ACCESS_BACKGROUND_LOCATION) {
                                continue
                            }
                            permissionList.add(permission)
                        }
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
            return permissionList.toTypedArray()
        }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (resultListener == null) {
            return
        }
        if (grantResults.size == 0) {
            // Request was cancelled.
            return
        }
        if (requestCode == PERMISSIONS_REQUEST_CODE) {
            var allGranted = true
            for (result in grantResults) {
                allGranted = allGranted and (result == PackageManager.PERMISSION_GRANTED)
            }
            if (allGranted) {
                resultListener!!.permissionsGranted()
            } else {
                resultListener!!.permissionsDenied()
            }
        }
    }

    companion object {
        private const val PERMISSIONS_REQUEST_CODE = 42
    }
}
