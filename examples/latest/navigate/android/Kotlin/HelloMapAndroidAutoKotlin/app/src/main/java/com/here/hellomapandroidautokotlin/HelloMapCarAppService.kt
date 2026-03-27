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
package com.here.hellomapandroidautokotlin

import android.content.Intent
import android.content.pm.ApplicationInfo
import androidx.car.app.CarAppService
import androidx.car.app.R
import androidx.car.app.Screen
import androidx.car.app.Session
import androidx.car.app.validation.HostValidator
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner

/**
 * Entry point for Android Auto - when connected to a DHU or an in-car head unit.
 *
 *
 * [CarAppService] is the main interface between the app and the car host. For more
 * details, see the [Android for
 * Cars Library developer guide](https://developer.android.com/training/cars/navigation).
 */
class HelloMapCarAppService : CarAppService() {
    override fun onCreateSession(): Session {
        val session: Session = object : Session() {
            override fun onCreateScreen(intent: Intent): Screen {
                return HelloMapScreen(carContext)
            }
        }

        session.lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onCreate(owner: LifecycleOwner) {
                HERESDKLifecycle.start(this@HelloMapCarAppService)
            }

            override fun onDestroy(owner: LifecycleOwner) {
                HERESDKLifecycle.stop()
            }
        })

        return session
    }

    override fun createHostValidator(): HostValidator {
        return if ((applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0) {
            HostValidator.ALLOW_ALL_HOSTS_VALIDATOR
        } else {
            HostValidator.Builder(applicationContext)
                .addAllowedHosts(R.array.hosts_allowlist_sample)
                .build()
        }
    }
}