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
import android.view.MenuItem;
import android.view.MotionEvent;
import android.view.View;
import android.widget.Button;
import android.widget.PopupMenu;

import com.here.sdk.units.core.views.UnitButton;

import java.util.Map;
import java.util.Objects;

// The HERE SDK unit class that defines the logic for the view.
// The logic accepts a list of menu entries with associated actions.
public class PopupMenuUnit {

    private final Context context;
    private final UnitButton button;

    /**
     * Constructs a new instance. Usually, this is constructed from the associated view, but
     * it can be also accessed programmatically for quick customization.
     *
     * @param button  The button that opens a PopupMenu.
     * @param context The {@link Context} in which the view is running.
     */
    public PopupMenuUnit(UnitButton button, Context context) {
        this.button = button;
        this.context = context;
    }

    /**
     * Sets up a popup menu with the given menu items and associates each item with an action.
     * Multiple PopupMenuView instances are supported.
     *
     * @param buttonText The text for the button that opens the popup menu.
     * @param menuItems  A map of menu item titles and their corresponding actions. Each key is a
     *                   menu item label, and the value is a {@link Runnable} that will be executed
     *                   when the item is selected.
     */
    public void setMenuContent(String buttonText, Map<String, Runnable> menuItems) {
        button.setText(buttonText);
        button.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                // Create and show the PopupMenu on-the-fly.
                PopupMenu popupMenu = new PopupMenu(context, view);

                // Add each menu item on-the-fly to the PopupMenu.
                for (String title : menuItems.keySet()) {
                    popupMenu.getMenu().add(title);
                }

                popupMenu.setOnMenuItemClickListener(new PopupMenu.OnMenuItemClickListener() {
                    @Override
                    public boolean onMenuItemClick(MenuItem item) {
                        String clickedItemtitle = Objects.requireNonNull(item.getTitle()).toString();
                        // Execute the code that was defined for the clicked menu item in the LinkedHashMap.
                        Runnable callbackAction = menuItems.get(clickedItemtitle);
                        if (callbackAction != null) {
                            callbackAction.run();
                            return true;
                        }
                        return false;
                    }
                });

                popupMenu.show();
            }
        });
    }
}
