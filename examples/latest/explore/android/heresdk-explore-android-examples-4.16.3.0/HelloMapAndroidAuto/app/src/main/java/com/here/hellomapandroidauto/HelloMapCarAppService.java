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

package com.here.hellomapandroidauto;

import android.content.Intent;
import android.content.pm.ApplicationInfo;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.car.app.CarAppService;
import androidx.car.app.Screen;
import androidx.car.app.Session;
import androidx.car.app.validation.HostValidator;
import androidx.lifecycle.DefaultLifecycleObserver;
import androidx.lifecycle.LifecycleOwner;

/**
 * Entry point for Android Auto - when connected to a DHU or an in-car head unit.
 *
 * <p>{@link CarAppService} is the main interface between the app and the car host. For more
 * details, see the <a href="https://developer.android.com/training/cars/navigation">Android for
 * Cars Library developer guide</a>.
 */
public final class HelloMapCarAppService extends CarAppService {

    public HelloMapCarAppService() {
        // Exported services must have an empty public constructor.
    }

    @Override
    @NonNull
    public Session onCreateSession() {

        Session session = new Session() {
            @Override
            @NonNull
            public Screen onCreateScreen(@Nullable Intent intent) {
                return new HelloMapScreen(getCarContext());
            }
        };

        session.getLifecycle().addObserver(new DefaultLifecycleObserver() {
            @Override
            public void onCreate(@NonNull LifecycleOwner owner) {
                HERESDKLifecycle.start(HelloMapCarAppService.this);
            }

            @Override
            public void onDestroy(@NonNull LifecycleOwner owner) {
                HERESDKLifecycle.stop();
            }
        });

        return session;
    }

    @NonNull
    @Override
    public HostValidator createHostValidator() {
        if ((getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0) {
            return HostValidator.ALLOW_ALL_HOSTS_VALIDATOR;
        } else {
            return new HostValidator.Builder(getApplicationContext())
                    .addAllowedHosts(androidx.car.app.R.array.hosts_allowlist_sample)
                    .build();
        }
    }
}
