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

import android.content.Context;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.TextView;

import com.here.sdk.venue.control.Venue;
import com.here.sdk.venue.control.VenueMap;
import com.here.sdk.venue.data.VenueModel;

import java.util.List;

public class VenueArrayAdapter extends ArrayAdapter<Venue> {
    VenueMap venueMap;
    VenuesController venuesController;

    VenueArrayAdapter(
            @NonNull Context context,
            VenueMap venueMap,
            VenuesController venuesController,
            List<Venue> venues) {
        super(context, R.layout.text_item, venues);
        this.venueMap = venueMap;
        this.venuesController = venuesController;
    }

    @Override
    @NonNull
    public View getView(int position, @Nullable View convertView, @NonNull ViewGroup parent) {
        if (convertView == null) {
            convertView =
                    LayoutInflater.from(getContext()).inflate(R.layout.venue_item, parent, false);
        }
        TextView textView = convertView.findViewById(R.id.itemText);
        Venue venue = getItem(position);
        if (venue != null) {
            textView.setOnClickListener(v -> {
                venueMap.setSelectedVenue(venue);
                venuesController.setVisible(false);
            });
            VenueModel venueModel = venue.getVenueModel();
            textView.setText(
                    venueModel.getId() + ": " + venueModel.getProperties().get("name").getString());

            View removeButton = convertView.findViewById(R.id.removeVenueButton);
            removeButton.setOnClickListener(v -> venueMap.removeVenue(venue));
        }
        return convertView;
    }
}
