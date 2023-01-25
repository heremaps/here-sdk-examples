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

package com.here.sdk.examples.venues;

import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.List;

// Adapter that connects text names with a ListView.
class StringArrayAdapter extends ArrayAdapter<String> {
    private final int listTextSize;
    private final int listTextColor;

    StringArrayAdapter(
            @NonNull Context context,
            List<String> names,
            int listTextSize,
            int listTextColor) {
        super(context, R.layout.text_item, names);
        this.listTextSize = listTextSize;
        this.listTextColor = listTextColor;
    }

    StringArrayAdapter(
            @NonNull Context context,
            List<String> names) {
        this(context, names, 14, 0xFF444444);
    }

    @Override
    public @NonNull View
    getView(int position, @Nullable View convertView, @NonNull ViewGroup parent) {
        if (convertView == null) {
            convertView = LayoutInflater.from(getContext()).inflate(R.layout.text_item, parent, false);
        }
        TextView textView = convertView.findViewById(R.id.itemText);
        textView.setTextSize(listTextSize);
        textView.setTextColor(listTextColor);
        textView.setText(getItem(position));
        return convertView;
    }
}
