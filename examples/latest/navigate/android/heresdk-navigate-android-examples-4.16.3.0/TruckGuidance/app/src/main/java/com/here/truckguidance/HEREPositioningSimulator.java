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

package com.here.truckguidance;

import com.here.sdk.core.LocationListener;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.navigation.LocationSimulator;
import com.here.sdk.navigation.LocationSimulatorOptions;
import com.here.sdk.routing.Route;
import com.here.time.Duration;

// A class that provides simulated location updates along a given route.
// The frequency of the provided updates can be set via LocationSimulatorOptions.
public class HEREPositioningSimulator {

    private LocationSimulator locationSimulator;
    private double speedFactor = 1;

    // Starts route playback.
    // Note for simplicity, we only allow two location listeners.
    public void startLocating(LocationListener locationListener1,
                              LocationListener locationListener2,
                              Route route) {
        if (locationSimulator != null) {
            locationSimulator.stop();
        }

        locationSimulator = createLocationSimulator(locationListener1,
                                                    locationListener2,
                                                    route);
        locationSimulator.start();
    }

    public void stopLocating() {
        if (locationSimulator != null) {
            locationSimulator.stop();
            locationSimulator = null;
        }
    }

    public void setSpeedFactor(double speedFactor) {
        this.speedFactor = speedFactor;
    }

    // Provides fake GPS signals based on the route geometry.
    private LocationSimulator createLocationSimulator(LocationListener locationListener1,
                                                      LocationListener locationListener2,
                                                      Route route) {
        LocationListener listener1 = locationListener1;
        LocationListener listener2 = locationListener2;
        LocationSimulatorOptions locationSimulatorOptions = new LocationSimulatorOptions();
        locationSimulatorOptions.speedFactor = speedFactor;
        locationSimulatorOptions.notificationInterval = Duration.ofMillis(500);

        LocationSimulator locationSimulator;

        try {
            locationSimulator = new LocationSimulator(route, locationSimulatorOptions);
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of LocationSimulator failed: " + e.error.name());
        }

        locationSimulator.setListener(location -> {
            listener1.onLocationUpdated(location);
            listener2.onLocationUpdated(location);
        });

        return locationSimulator;
    }
}
