package com.here.truckguidance;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Rect;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.util.TypedValue;
import android.view.View;

// A simple view to show the next TruckRestrictionWarning event.
public class TruckRestrictionView extends View  {

    private Paint paint;
    private String description = "";

    private int textSizeInDP = 15;

    // The dimensions of the rectangle that holds all content.
    public int xInDP = 0;
    public int yInDP = 0;
    private int wInDP = 160;
    private int hInDP = 40;

    public TruckRestrictionView(Context context) {
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

    public void onTruckRestrictionWarning(String description) {
        this.description = description;
        redraw();
    }

    public void onHideTruckRestrictionWarning() {
        description = "";
        redraw();
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);

        if (description == "") {
            // Nothing to draw: Clear any previous content.
            return;
        }

        RectF rect = drawBackgroundRectangle(canvas);
        drawDescriptionInRect(rect, canvas);
    }

    private RectF drawBackgroundRectangle(Canvas canvas) {
        paint.setColor(Color.WHITE);
        int left = getPixels(xInDP);
        int top = getPixels(yInDP);
        int right = getPixels(xInDP) + getPixels(wInDP);
        int bottom = getPixels(yInDP) + getPixels(hInDP);
        RectF rectf = new RectF(left, top, right, bottom);

        // Set the inner stroke color and width.
        paint.setStyle(Paint.Style.FILL);
        paint.setStrokeWidth(15);

        // Calculate the adjusted rectangle for the inner stroke.
        float innerAdjustedLeft = left + paint.getStrokeWidth() / 2;
        float innerAdjustedTop = top + paint.getStrokeWidth() / 2;
        float innerAdjustedRight = right - paint.getStrokeWidth() / 2;
        float innerAdjustedBottom = bottom - paint.getStrokeWidth() / 2;
        RectF innerAdjustedRectF = new RectF(innerAdjustedLeft, innerAdjustedTop, innerAdjustedRight, innerAdjustedBottom);

        // Draw the white background.
        paint.setColor(Color.WHITE);
        canvas.drawRoundRect(innerAdjustedRectF, 10, 10, paint);

        // Set the inner stroke color.
        paint.setColor(Color.RED);
        paint.setStyle(Paint.Style.STROKE);

        // Draw the inner stroke.
        canvas.drawRoundRect(innerAdjustedRectF, 10, 10, paint);

        return rectf;
    }

    private void drawDescriptionInRect(RectF rect, Canvas canvas) {
        paint.setStyle(Paint.Style.FILL);
        paint.setTextSize(getPixels(textSizeInDP));
        paint.setColor(Color.BLACK);
        paint.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD));
        Rect textBounds = new Rect();
        paint.getTextBounds(description, 0, description.length(), textBounds);
        float textX = rect.centerX() - textBounds.width() / 2;
        float textY = rect.centerY() + textBounds.height() / 2;
        canvas.drawText(description, textX, textY, paint);
    }

    // Get pixel size for this particular device based on its display metrics.
    // See https://developer.android.com/training/multiscreen/screendensities
    private int getPixels(int dp) {
        int pixels = Math.round(TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP, dp, getResources().getDisplayMetrics()));
        return pixels;
    }
}
