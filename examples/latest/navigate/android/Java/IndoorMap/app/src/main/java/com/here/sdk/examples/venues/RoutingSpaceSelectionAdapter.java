/*
 * Copyright (C) 2026 HERE Europe B.V.
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
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.RelativeLayout;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.here.sdk.venue.data.VenueGeometry;

import java.util.List;

class RoutingSpaceSelectionViewHolder extends RecyclerView.ViewHolder{

    public TextView spaceName, spaceAddress;
    public RelativeLayout relativeLayout;
    public LinearLayout addressLayout;

    public RoutingSpaceSelectionViewHolder(@NonNull View itemView) {
        super(itemView);
        spaceName = itemView.findViewById(R.id.SpaceName);
        spaceAddress = itemView.findViewById(R.id.SpaceAddress);
        addressLayout = itemView.findViewById(R.id.AddressLayout);
        relativeLayout = itemView.findViewById(R.id.SpaceContainer);
    }
}

public class RoutingSpaceSelectionAdapter extends RecyclerView.Adapter<RoutingSpaceSelectionViewHolder> {
    private static final String TAG = RoutingSpaceSelectionAdapter.class.getSimpleName();
    private List<VenueGeometry> items;
    private IndoorRoutingUIController routingController;
    private boolean fromSrc = false;

    public RoutingSpaceSelectionAdapter(List<VenueGeometry> items, IndoorRoutingUIController routingController, boolean fromSrc){
        this.items = items;
        this.routingController = routingController;
        this.fromSrc = fromSrc;
    }
    @NonNull
    @Override
    public RoutingSpaceSelectionViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        return new RoutingSpaceSelectionViewHolder(LayoutInflater.from(parent.getContext()).inflate(R.layout.space_item, parent, false));
    }

    @Override
    public void onBindViewHolder(@NonNull RoutingSpaceSelectionViewHolder holder, int position) {
        String spaceName, spaceAddress;
        VenueGeometry geometry = items.get(position);
        spaceName = geometry.getName() + ", " + geometry.getLevel().getName();
        spaceAddress = geometry.getInternalAddress() != null? geometry.getInternalAddress().getAddress() : "";
        holder.spaceName.setText(spaceName);
        if(spaceAddress.isEmpty())
            holder.addressLayout.setVisibility(View.GONE);
        else
            holder.spaceAddress.setText(spaceAddress);
        holder.relativeLayout.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                routingController.onSpaceItemClicked(items.get(position), fromSrc);
            }
        });

    }

    @Override
    public int getItemCount() {
        return items.size();
    }
}

