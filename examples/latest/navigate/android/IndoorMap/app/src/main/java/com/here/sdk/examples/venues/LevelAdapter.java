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

import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;

import com.here.sdk.venue.data.VenueLevel;

import java.util.ArrayList;
import java.util.List;

// Adapter that connects levels with LevelSwitcher.
class LevelAdapter extends BaseAdapter {
    private final List<VenueLevel> levels;

    LevelAdapter(List<VenueLevel> levels) {
        this.levels = new ArrayList<>();

        for (int i = levels.size() - 1; i >= 0; i--) {
            VenueLevel level = levels.get(i);
            this.levels.add(level);
        }
    }

    @Override
    public int getCount() {
        return levels.size();
    }

    @Override
    public Object getItem(int position) {
        return levels.get(position);
    }

    @Override
    public long getItemId(int position) {
        return position;
    }

    @Override
    public View getView(int position, View convertView, ViewGroup parent) {
        LevelItemView item;
        if (convertView instanceof LevelItemView) {
            item = (LevelItemView) convertView;
        } else {
            item = new LevelItemView(parent.getContext());
        }
        VenueLevel level = levels.get(position);
        // Sets the level's short name as a text of the item.
        item.setText(level.getShortName());

        // If the level is the main one, visually separates it from the levels below it.
        item.setShowSeparator(level.isMainLevel() && position != levels.size() - 1);
        return item;
    }
}
