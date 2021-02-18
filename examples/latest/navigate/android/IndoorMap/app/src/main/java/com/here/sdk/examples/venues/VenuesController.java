/*
 * Copyright (C) 2019-2021 HERE Europe B.V.
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

import android.support.annotation.NonNull;
import android.view.View;
import android.widget.ListView;

import com.here.sdk.venue.control.Venue;
import com.here.sdk.venue.control.VenueLifecycleListener;
import com.here.sdk.venue.control.VenueMap;

import java.util.ArrayList;

public class VenuesController {
    final VenueMap venueMap;
    final View venuesLayer;
    final View visibilityButton;
    final ListView venuesList;
    private boolean visible = false;

    public VenuesController(VenueMap venueMap, View venueLayer, View visibilityButton) {
        this.venueMap = venueMap;
        this.venuesLayer = venueLayer;
        this.visibilityButton = visibilityButton;
        venueMap.add(venueLifecycleListener);
        visibilityButton.setOnClickListener(v -> setVisible(!visible));
        venuesList = venueLayer.findViewById(R.id.venuesList);
        setVisible(false);
        updateVenueList();
    }

    public void setVisible(boolean value) {
        if (visible == value) {
            return;
        }
        visible = value;
        venuesLayer.setVisibility(visible ? View.VISIBLE : View.GONE);
    }

    private void updateVenueList() {
        ArrayList<Venue> venues = new ArrayList<>(venueMap.getVenues().values());
        final VenueArrayAdapter adapter =
                new VenueArrayAdapter(venuesList.getContext(), venueMap, this, venues);
        venuesList.setAdapter(adapter);
    }

    private final VenueLifecycleListener venueLifecycleListener = new VenueLifecycleListener() {
        @Override
        public void onVenueAdded(@NonNull Venue venue) {
            updateVenueList();
        }

        @Override
        public void onVenueRemoved(int i) {
            updateVenueList();
        }
    };

    @Override
    protected void finalize() throws Throwable {
        removeListeners();
        super.finalize();
    }

    private void removeListeners() {
        if (venueMap != null) {
            venueMap.remove(venueLifecycleListener);
        }
    }
}
