/*
 * Copyright (C) 2019-2022 HERE Europe B.V.
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

package com.here.sdk.examples.venues;

import android.app.Activity;
import android.content.Context;
import androidx.annotation.NonNull;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.View;
import android.view.inputmethod.InputMethodManager;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.EditText;
import android.widget.ListView;
import android.widget.Spinner;

import com.here.sdk.venue.control.Venue;
import com.here.sdk.venue.control.VenueLifecycleListener;
import com.here.sdk.venue.control.VenueMap;
import com.here.sdk.venue.control.VenueSelectionListener;
import com.here.sdk.venue.data.VenueGeometry;
import com.here.sdk.venue.data.VenueGeometryFilterType;

import java.util.ArrayList;
import java.util.List;

public class VenueSearchController {
    final VenueMap venueMap;
    final VenueTapController tapController;
    final View venueSearchLayout;
    final View visibilityButton;
    final EditText venueSearchText;
    final Spinner searchTypeSpinner;
    final ListView geometriesList;
    private Venue venue;
    private String filter = "";
    private VenueGeometryFilterType searchType = VenueGeometryFilterType.NAME;
    private boolean visible = false;
    private List<VenueGeometry> geometries;

    public VenueSearchController(VenueMap venueMap,
                                 VenueTapController tapController,
                                 View venueSearchLayout,
                                 View visibilityButton) {
        this.venueMap = venueMap;
        this.tapController = tapController;
        this.venueSearchLayout = venueSearchLayout;
        this.visibilityButton = visibilityButton;
        venueSearchText = venueSearchLayout.findViewById(R.id.venueSearch);
        searchTypeSpinner = venueSearchLayout.findViewById(R.id.searchTypeSpinner);
        initSearchTypes(venueSearchLayout);
        geometriesList = venueSearchLayout.findViewById(R.id.searchResultList);
        setVisible(false);
        venueMap.add(venueSelectionListener);
        venueMap.add(venueLifecycleListener);
        venueSearchText.addTextChangedListener(textWatcher);
        visibilityButton.setOnClickListener(v -> setVisible(!visible));
        geometriesList.setOnItemClickListener((parent, view, position, id) -> {
            if (geometries == null || position >= geometries.size()) {
                return;
            }
            VenueGeometry geometry = geometries.get(position);
            if (geometry == null) {
                return;
            }
            this.tapController.selectGeometry(geometry, geometry.getCenter(), true);
            setVisible(false);
            hideKeyboardFrom(venueSearchText.getContext(), venueSearchText);
        });
    }

    AdapterView.OnItemSelectedListener onSearchTypeSelectedListener =
            new AdapterView.OnItemSelectedListener() {
        @Override
        public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
            VenueGeometryFilterType type = VenueGeometryFilterType.values()[position];
            if (type != searchType) {
                searchType = type;
                filterGeometries();
            }
        }

        @Override
        public void onNothingSelected(AdapterView<?> parent) {

        }
    };

    private void initSearchTypes(View venueSearchLayout) {
        String[] items = new String[VenueGeometryFilterType.values().length];
        for (int i = 0; i < VenueGeometryFilterType.values().length; i++)
        {
            items[i] = VenueGeometryFilterType.values()[i].toString();
        }
        ArrayAdapter<String> adapter = new ArrayAdapter<>(venueSearchLayout.getContext(),
                android.R.layout.simple_spinner_dropdown_item, items);
        searchTypeSpinner.setAdapter(adapter);
        searchTypeSpinner.setSelection(0);
        searchTypeSpinner.setOnItemSelectedListener(onSearchTypeSelectedListener);
    }

    private void setVisible(boolean value) {
        if (visible == value) {
            return;
        }
        visible = value;
        venueSearchLayout.setVisibility(visible ? View.VISIBLE : View.GONE);
    }

    public static void hideKeyboardFrom(Context context, View view) {
        InputMethodManager imm =
                (InputMethodManager) context.getSystemService(Activity.INPUT_METHOD_SERVICE);
        imm.hideSoftInputFromWindow(view.getWindowToken(), 0);
    }

    @Override
    protected void finalize() throws Throwable {
        removeListeners();
        super.finalize();
    }

    private void removeListeners() {
        if (venueMap != null) {
            venueMap.remove(venueSelectionListener);
            venueMap.remove(venueLifecycleListener);
        }

        if (venueSearchText != null) {
            venueSearchText.removeTextChangedListener(textWatcher);
        }
    }

    private void onVenueChanged(Venue venue) {
        if (this.venue == venue)
        {
            return;
        }
        this.venue = venue;
        filterGeometries();
    }

    private void filterGeometries() {
        if (venue == null)
        {
            geometriesList.setAdapter(null);
            return;
        }
        geometries = filter.isEmpty()
                ? venue.getVenueModel().getGeometriesByName()
                : venue.getVenueModel().filterGeometry(filter, searchType);
        List<String> names = new ArrayList<>();
        for (VenueGeometry geometry : geometries) {
            StringBuilder name = new StringBuilder();
            name.append(geometry.getName()).append(", ").append(geometry.getLevel().getName());
            if ((searchType == VenueGeometryFilterType.ADDRESS
                    || searchType == VenueGeometryFilterType.NAME_OR_ADDRESS)
                    && geometry.getInternalAddress() != null)
            {
                name.append("\n(Address: ").append(geometry.getInternalAddress().getLongAddress())
                        .append(")");
            }
            else if (searchType == VenueGeometryFilterType.ICON_NAME
                    && geometry.getLookupType() == VenueGeometry.LookupType.ICON)
            {
                name.append("\n(Icon: ").append(geometry.getLabelName()).append(")");
            }
            names.add(name.toString());
        }
        final StringArrayAdapter adapter =
                new StringArrayAdapter(geometriesList.getContext(), names);
        geometriesList.setAdapter(adapter);
    }

    private final VenueSelectionListener venueSelectionListener =
            (deselectedController, selectedController) -> onVenueChanged(selectedController);

    private final VenueLifecycleListener venueLifecycleListener = new VenueLifecycleListener() {
        @Override
        public void onVenueAdded(@NonNull Venue venue) {
        }

        @Override
        public void onVenueRemoved(int i) {
            onVenueChanged(venueMap.getSelectedVenue());
        }
    };

    private final TextWatcher textWatcher = new TextWatcher() {
        @Override
        public void beforeTextChanged(CharSequence s, int start, int count, int after) {
        }

        @Override
        public void onTextChanged(CharSequence s, int start, int before, int count) {
            filter = s != null ?  s.toString() : "";
            filterGeometries();
        }

        @Override
        public void afterTextChanged(Editable s) {
        }
    };


}
