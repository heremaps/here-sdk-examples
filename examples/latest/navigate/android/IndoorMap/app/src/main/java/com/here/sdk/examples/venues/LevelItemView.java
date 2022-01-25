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
import android.os.Build;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.RelativeLayout;
import android.widget.TextView;

// Represents a level inside LevelSwitcher.
class LevelItemView extends RelativeLayout {
    private TextView textView;
    private View separator;

    public LevelItemView(Context context) {
        super(context);

        LayoutInflater.from(context).inflate(R.layout.level_item, this, true);
        textView = findViewById(R.id.levelName);
        separator = findViewById(R.id.levelGroundSep);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            textView.setAutoSizeTextTypeWithDefaults(TextView.AUTO_SIZE_TEXT_TYPE_UNIFORM);
        }
    }

    public void setText(CharSequence text) {
        textView.setText(text);
    }

    public void setShowSeparator(boolean isVisible) {
        separator.setVisibility(isVisible ? View.VISIBLE : View.INVISIBLE);
    }
}
