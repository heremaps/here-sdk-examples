/*
 * Copyright (C) 2025 HERE Europe B.V.
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

package com.here.sdk.units.core.views;

import android.content.Context;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.animation.AccelerateDecelerateInterpolator;
import android.view.animation.OvershootInterpolator;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.widget.AppCompatTextView;


/**
 * A custom resuable Material-style dialog with rounded corners 
 * and built-in pre-configured entrance animation.
 */
public class UnitDialog extends AlertDialog {

    public UnitDialog(Context context) {
        super(context);
    }

    /**
     * Show a Material-style dialog.
     *
     * @param title   Mandatory dialog title (bold).
     * @param message Mandatory description (scrollable if long).
     */
    public void showDialog(String title, String message) {
        LinearLayout rootLayout = createRootLayout();

        // Add title and message
        rootLayout.addView(createTitleView(title));
        rootLayout.addView(createScrollableMessage(message));

        // Optional rounded corners and animation
        applyRoundedCorners(rootLayout, 8f);
        applyMaterialAnimation(rootLayout);

        // Set and show
        setView(rootLayout);
        show();

        animateDialogAppearance(rootLayout);
    }

    // --- Helper methods ---
    private LinearLayout createRootLayout() {
        LinearLayout layout = new LinearLayout(getContext());
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setPadding(60, 50, 60, 50);
        layout.setGravity(Gravity.CENTER);
        return layout;
    }

    private AppCompatTextView createTitleView(String title) {
        AppCompatTextView titleView = new AppCompatTextView(getContext());
        titleView.setText(title);
        titleView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 20);
        titleView.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.NORMAL));
        titleView.setTextColor(Color.BLACK);
        titleView.setGravity(Gravity.CENTER);
        titleView.setPadding(0, 16, 0, 16);
        return titleView;
    }

    private View createScrollableMessage(String message) {
        ScrollView scrollView = new ScrollView(getContext());
        LinearLayout.LayoutParams scrollParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
        );
        scrollParams.setMargins(0, 0, 0, 40);
        scrollView.setLayoutParams(scrollParams);

        LinearLayout wrapper = new LinearLayout(getContext());
        wrapper.setLayoutParams(new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
        ));
        wrapper.setGravity(Gravity.CENTER);

        AppCompatTextView messageView = new AppCompatTextView(getContext());
        messageView.setText(message);
        messageView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
        messageView.setTextColor(Color.DKGRAY);
        messageView.setPadding(0, 8, 0, 8);
        messageView.setGravity(Gravity.CENTER);
        wrapper.addView(messageView);

        scrollView.addView(wrapper);
        return scrollView;
    }

    private void animateDialogAppearance(View rootLayout) {
        rootLayout.setAlpha(0f);
        rootLayout.setTranslationY(100f);
        rootLayout.animate()
                .alpha(1f)
                .translationY(0f)
                .setInterpolator(new AccelerateDecelerateInterpolator())
                .setDuration(250)
                .start();
    }

    private void applyRoundedCorners(LinearLayout rootLayout, float cornerRadiusDp) {
        GradientDrawable background = new GradientDrawable();
        background.setColor(Color.WHITE);            
        background.setCornerRadius(dpToPx(cornerRadiusDp)); 
        background.setStroke(2, Color.LTGRAY);       
        rootLayout.setBackground(background);

        // Elevation for shadow effect (Material Design)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            rootLayout.setElevation(12f);
        }
    }

    // Helper to convert dp to pixels.
    private float dpToPx(float dp) {
        return dp * getContext().getResources().getDisplayMetrics().density;
    }

    // Scale from 95%→100% with OvershootInterpolator + fade+slide+scale
    // combined for smooth, dynamic Material-style animation.
    private void applyMaterialAnimation(View contentView) {
        if (getWindow() != null) {
            // Transparent background to allow rounded corners
            getWindow().setBackgroundDrawable(new ColorDrawable(Color.TRANSPARENT));
            getWindow().setWindowAnimations(0); 

            // Initial state: invisible, slightly below, and scaled down
            contentView.setAlpha(0f);
            contentView.setTranslationY(100f);
            contentView.setScaleX(0.95f);
            contentView.setScaleY(0.95f);

            // Animate to final state: fully visible, in position, normal size
            contentView.animate()
                    .alpha(1f)
                    .translationY(0f)
                    .scaleX(1f)
                    .scaleY(1f)
                    // Subtle bounce
                    .setInterpolator(new OvershootInterpolator(1.0f)) 
                    // Slightly longer for smooth effect
                    .setDuration(350)  
                    .start();
        }
    }
}
