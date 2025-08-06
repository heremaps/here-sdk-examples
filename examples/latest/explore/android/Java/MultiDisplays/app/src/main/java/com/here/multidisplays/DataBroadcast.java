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

package com.here.multidisplays;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;

import com.here.sdk.core.GeoCoordinates;

// A BroadcastReceiver to send/receive messages between the two activities of this example app.
public abstract class DataBroadcast extends BroadcastReceiver {
    public static String MESSAGE_FROM_PRIMARY_DISPLAY = "com.here.example.multidisplays.broadcast.primary";
    public static String MESSAGE_FROM_SECONDARY_DISPLAY = "com.here.example.multidisplays.broadcast.secondary";

    public IntentFilter getFilter(String action) {
        IntentFilter filter = new IntentFilter();
        filter.addAction(action);
        return filter;
    }

    public void sendMessageToPrimaryDisplay(Context context, GeoCoordinates geoCoordinates) {
        sendMessage(context, MESSAGE_FROM_SECONDARY_DISPLAY, geoCoordinates);
    }

    public void sendMessageToSecondaryDisplay(Context context, GeoCoordinates geoCoordinates) {
        sendMessage(context, MESSAGE_FROM_PRIMARY_DISPLAY, geoCoordinates);
    }

    private void sendMessage(Context context, String action, GeoCoordinates geoCoordinates) {
        Intent intent = new Intent();
        intent.setAction(action);
        intent.putExtra("latitude", geoCoordinates.latitude);
        intent.putExtra("longitude", geoCoordinates.longitude);
        context.sendBroadcast(intent);
    }
}
