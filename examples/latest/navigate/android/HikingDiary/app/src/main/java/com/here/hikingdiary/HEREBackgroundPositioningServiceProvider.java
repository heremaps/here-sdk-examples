/*
 * Copyright (C) 2023-2024 HERE Europe B.V.
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

import android.app.Activity;
import android.app.Dialog;
import android.content.ComponentName;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.ServiceConnection;
import android.os.IBinder;
import android.util.Log;
import androidx.appcompat.app.AlertDialog;
import com.here.HikingDiary.R;
import com.here.hikingdiary.backgroundpositioning.BackgroundServiceListener;
import com.here.hikingdiary.backgroundpositioning.HEREBackgroundPositioningService;
import com.here.sdk.core.Location;
import com.here.sdk.core.LocationListener;

public class HEREBackgroundPositioningServiceProvider {
    private final String TAG = BackgroundServiceListener.class.getSimpleName();
    private HEREBackgroundPositioningService positioningService;
    private final LocationListener locationListener;
    private Activity activity;
    private boolean shouldUnbind;
    private final Context context;

    public HEREBackgroundPositioningServiceProvider(Activity activity, LocationListener locationListener) {
        this.activity = activity;
        this.locationListener = locationListener;
        this.context = activity.getApplicationContext();
    }

    private final ServiceConnection connection = new ServiceConnection() {
        public void onServiceConnected(ComponentName className, IBinder service) {
            positioningService = ((HEREBackgroundPositioningService.LocalBinder) service).getService();
            positioningService.registerListener(new BackgroundServiceListener() {
                @Override
                public void onStateUpdate(HEREBackgroundPositioningService.State state) {
                    Log.i(TAG, "onStateUpdate: " + state);
                }

                @Override
                public void onLocationUpdated(Location location) {
                    locationListener.onLocationUpdated(location);
                }
            });
        }

        public void onServiceDisconnected(ComponentName className) {
            positioningService = null;
        }
    };

    public void startForegroundService() {
        HEREBackgroundPositioningService.start(context);
        openBinder();
    }

    public void stopForegroundService() {
        HEREBackgroundPositioningService.stop(context);
        closeBinder();
    }

    private void openBinder() {
        Intent intent = new Intent(activity, HEREBackgroundPositioningService.class);
        if (activity.bindService(intent, connection, Context.BIND_NOT_FOREGROUND)) {
            shouldUnbind = true;
        } else {
            createErrorDialog(R.string.dialog_msg_service_connection_failed, android.R.string.ok, (dialog, which) -> {
                dialog.dismiss();
                activity.finish();
            }).show();
        }
    }

    private void closeBinder() {
        if (shouldUnbind) {
            activity.unbindService(connection);
            shouldUnbind = false;
        }
    }

    private Dialog createErrorDialog(int messageId, int buttonId, DialogInterface.OnClickListener clickListener) {
        final AlertDialog.Builder builder = new AlertDialog.Builder(context);
        return builder.setMessage(messageId).setPositiveButton(buttonId, clickListener).create();
    }
}
