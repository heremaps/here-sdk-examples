/*
 * Copyright (C) 2019-2024 HERE Europe B.V.
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

package com.here.truckguidance;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Typeface;
import android.util.TypedValue;
import android.view.View;

// A simple view to show the current speed limit or current driving speed.
public class SpeedView extends View {

    private Paint paint;
    private String speedText = "";
    private String labelText = "";

    private int yMarginInDP = 5;
    private int textSizeInDP = 15;
    public int circleColor = Color.RED;

    // The dimensions of the rectangle that holds all content.
    public int xInDP = 0;
    public int yInDP = 0;
    private int wInDP = 50;
    private int hInDP = wInDP + yMarginInDP + textSizeInDP;

    public SpeedView(Context context) {
        super(context);
        paint = new Paint();
    }

    public int getWidthInDP() {
        return wInDP;
    }

    public int getHeightInDP() {
        return hInDP;
    }

    public void redraw() {
        // Request a redraw.
        invalidate();
    }

    public void setSpeedLimit(String text) {
        this.speedText = text;
        redraw();
    }

    public void setLabel(String text) {
        this.labelText = text;
        redraw();
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);

        // Draw the outer circle.
        paint.setColor(circleColor);
        canvas.drawCircle(getCircleCenterX(), getCircleCenterY(), getRadius(), paint);

        // Draw the inner circle.
        paint.setColor(Color.WHITE);
        float innerCircleRadius = getPixels((int) (wInDP * 0.37));
        canvas.drawCircle(getCircleCenterX(), getCircleCenterY(), innerCircleRadius, paint);

        drawSpeedValue(canvas);
        drawLabel(canvas);
    }

    private float getRadius() {
        return getPixels(wInDP / 2);
    }

    private float getCircleCenterX() {
        return getRadius() + getPixels(xInDP);
    }

    private float getCircleCenterY() {
        return getRadius() + getPixels(yInDP) + getPixels(textSizeInDP);
    }

    private void drawSpeedValue(Canvas canvas) {
        if (speedText.isEmpty()) {
            // Nothing to draw.
            return;
        }

        // Draw the speed text centered in circle.
        paint.setColor(Color.BLACK);
        paint.setTextSize(getPixels(textSizeInDP));
        paint.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD));
        float textWidth = paint.measureText(speedText);
        float textCenterX = getCircleCenterX() - (textWidth / 2);
        float textCenterY = getCircleCenterY() - (paint.descent() + paint.ascent()) / 2;
        canvas.drawText(speedText, textCenterX, textCenterY, paint);
    }

    private void drawLabel(Canvas canvas) {
        if (labelText.isEmpty()) {
            // Nothing to draw.
            return;
        }

        // Draw the label centered on top of the circle.
        paint.setColor(Color.BLACK);
        paint.setTextSize(getPixels(textSizeInDP));
        paint.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD));
        float textWidth = paint.measureText(labelText);
        float radius = getPixels(wInDP / 2);
        float circleCenterY = getCircleCenterY() - radius - getPixels(yMarginInDP * 2);
        float textCenterX = getCircleCenterX() - (textWidth / 2);
        float textCenterY = circleCenterY - (paint.descent() + paint.ascent()) / 2;
        canvas.drawText(labelText, textCenterX, textCenterY, paint);
    }

    // Get pixel size for this particular device based on its display metrics.
    // See https://developer.android.com/training/multiscreen/screendensities
    private int getPixels(int dp) {
        int pixels = Math.round(TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP, dp, getResources().getDisplayMetrics()));
        return pixels;
    }
}
