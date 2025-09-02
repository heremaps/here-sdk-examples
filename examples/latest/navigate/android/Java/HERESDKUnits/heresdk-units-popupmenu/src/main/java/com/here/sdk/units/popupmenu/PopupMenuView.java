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

package com.here.sdk.units.popupmenu;

import android.content.Context;
import android.util.AttributeSet;
import android.widget.LinearLayout;

import com.here.sdk.units.core.views.UnitButton;

// The view hosting this HERE SDK Unit.
// The view consists only of a button that opens a PopupMenu.
// The unit is created after inflation and provides additional logic.
public class PopupMenuView extends LinearLayout {

    public PopupMenuUnit popupMenuUnit;

    public PopupMenuView(Context context) {
        super(context);
        init(context);
    }

    public PopupMenuView(Context context, AttributeSet attrs) {
        super(context, attrs);
        init(context);
    }

    public PopupMenuView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        init(context);
    }

    private void init(Context context) {
        // Create button programmatically.
        UnitButton button = new UnitButton(context);

        // Add button to this view.
        addView(button);

        popupMenuUnit = new PopupMenuUnit(button, context);
    }
}
