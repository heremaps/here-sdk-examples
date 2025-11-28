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

package com.here.sdk.units.cityselector;

import android.content.Context;
import android.view.MenuItem;
import android.view.View;
import android.widget.PopupMenu;

import com.here.sdk.units.core.views.UnitButton;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

// The HERE SDK unit class that defines the logic for the city selector view.
// The logic provides a list of predefined cities with their coordinates.
public class CitySelectorUnit {

    private final Context context;
    private final UnitButton button;
    private String selectedCity = "Select City";
    private OnCitySelectedListener listener;

    private static final Map<String, double[]> CITY_COORDINATES = new HashMap<>();
    private static final List<String> CITY_LIST = new ArrayList<>();

    static {
        CITY_COORDINATES.put("Mumbai", new double[]{19.0760, 72.8777});
        CITY_COORDINATES.put("Delhi", new double[]{28.6139, 77.2090});
        CITY_COORDINATES.put("Kolkata", new double[]{22.5726, 88.3639});
        CITY_COORDINATES.put("Chennai", new double[]{13.0827, 80.2707});
        CITY_COORDINATES.put("Bangalore", new double[]{12.9716, 77.5946});
        CITY_COORDINATES.put("Berlin", new double[]{52.5200, 13.4050});
        CITY_COORDINATES.put("New York", new double[]{40.7128, -74.0060});
        CITY_COORDINATES.put("London", new double[]{51.5074, -0.1278});
        CITY_COORDINATES.put("Paris", new double[]{48.8566, 2.3522});
        CITY_COORDINATES.put("Tokyo", new double[]{35.6895, 139.6917});
        CITY_COORDINATES.put("Sydney", new double[]{-33.8688, 151.2093});
        CITY_COORDINATES.put("Dubai", new double[]{25.2048, 55.2708});
        CITY_COORDINATES.put("Singapore", new double[]{1.3521, 103.8198});
        CITY_COORDINATES.put("Rio de Janeiro", new double[]{-22.9068, -43.1729});
        CITY_COORDINATES.put("Moscow", new double[]{55.7558, 37.6173});
        CITY_COORDINATES.put("Cape Town", new double[]{-33.9249, 18.4241});

        CITY_LIST.addAll(CITY_COORDINATES.keySet());
    }

    /**
     * Listener interface for city selection events.
     */
    public interface OnCitySelectedListener {
        void onCitySelected(double latitude, double longitude, String cityName);
    }

    /**
     * Constructs a new instance. Usually, this is constructed from the associated view, but
     * it can be also accessed programmatically for quick customization.
     *
     * @param button  The button that opens a PopupMenu with cities.
     * @param context The {@link Context} in which the view is running.
     */
    public CitySelectorUnit(UnitButton button, Context context) {
        this.button = button;
        this.context = context;
        button.setText(selectedCity);
        button.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                showCityPopupMenu();
            }
        });
    }

    /**
     * Shows a popup menu with predefined cities.
     */
    private void showCityPopupMenu() {
        PopupMenu popupMenu = new PopupMenu(context, button);

        // Add all cities to the popup menu
        for (int i = 0; i < CITY_LIST.size(); i++) {
            String city = CITY_LIST.get(i);
            popupMenu.getMenu().add(0, i, i, city);
        }

        // Set menu item click listener
        popupMenu.setOnMenuItemClickListener(new PopupMenu.OnMenuItemClickListener() {
            @Override
            public boolean onMenuItemClick(MenuItem item) {
                String city = CITY_LIST.get(item.getItemId());
                selectedCity = city;
                button.setText(city);

                double[] coordinates = CITY_COORDINATES.get(city);
                if (listener != null && coordinates != null) {
                    listener.onCitySelected(coordinates[0], coordinates[1], city);
                }
                return true;
            }
        });

        popupMenu.show();
    }

    /**
     * Sets the listener for city selection events.
     *
     * @param listener The listener to be notified when a city is selected.
     */
    public void setOnCitySelectedListener(OnCitySelectedListener listener) {
        this.listener = listener;
    }
}

