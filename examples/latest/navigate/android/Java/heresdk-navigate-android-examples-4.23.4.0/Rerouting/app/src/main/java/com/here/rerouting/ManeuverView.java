package com.here.rerouting;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Rect;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.util.AttributeSet;
import android.util.DisplayMetrics;
import android.util.Log;
import android.util.TypedValue;
import android.view.View;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

// A simple view to show the next maneuver event.
public class ManeuverView extends View  {

    private static final String TAG = ManeuverView.class.getName();

    // The default w/h constraint we use to create the icon with IconProvider.
    public static final int ROAD_SHIELD_DIM_CONSTRAINTS_IN_PIXELS = 100;

    private final Context context;
    private Paint paint;
    private Bitmap maneuverBitmap;
    private Bitmap roadShieldBitmap;
    private String maneuverIconText = "";
    private String roadName = "";
    private String distanceText = "";
    private boolean hideView = true;

    private final int textSizeInDP = 15;

    // The dimensions of the rectangle that holds all content.
    private int xInDP = 0; // The view's left point.
    private int yInDP = 0; // The view's top point.
    private int wInDP = 0; // Dynamically set based on available width.
    private int hInDP = 80; // Fixed height as defined here.

    private int marginInDP = 3;

    public ManeuverView(Context context) {
        super(context);
        this.context = context;
        init();
    }

    public ManeuverView(Context context, AttributeSet attrs) {
        super(context, attrs);
        this.context = context;
        init();
    }

    public ManeuverView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        this.context = context;
        init();
    }

    private void init() {
        paint = new Paint();
    }

    public int getWidthInDP() {
        return wInDP;
    }

    public int getHeightInDP() {
        return hInDP;
    }

    public void setWidthInDp(int widthInDp) {
        wInDP = widthInDp;
        redraw();
    }

    public void redraw() {
        // Request a redraw.
        invalidate();
    }

    /**
     * Handles a maneuver event by updating the UI component with the provided maneuver icon, text, distance to the maneuver, and road name.
     * If the maneuver icon is not provided (i.e., it is {@code null}), the maneuver icon text is used as a fallback to indicate the maneuver.
     * This method also marks the view for redrawing to reflect the new maneuver information.
     *
     * @param maneuverIcon The bitmap of the maneuver icon. Can be {@code null} if no icon is provided. In such cases, {@code maneuverIconText} is used.
     * @param maneuverIconText The text that describes the maneuver. It is used when {@code maneuverIcon} is not provided. Must not be {@code null}.
     * @param distanceText The text describing the distance to the maneuver. Must not be {@code null}.
     * @param roadName The name of the road on which the maneuver occurs. Must not be {@code null}.
     */
    public void onManeuverEvent(@Nullable Bitmap maneuverIcon,
                                @NonNull String maneuverIconText,
                                @NonNull String distanceText,
                                @NonNull String roadName) {
        this.maneuverBitmap = maneuverIcon;
        this.maneuverIconText = maneuverIconText;
        this.distanceText = distanceText;
        this.roadName = roadName;
        hideView = false;
        redraw();
    }

    /**
     * Updates the road shield icon displayed on the UI. This method allows for dynamically changing the road shield
     * based on events such as changes in the road or navigation instructions. If a {@code null} value is passed,
     * it effectively hides the road shield icon, similar to calling {@code onHideRoadShieldIcon()}.
     * Triggers a redraw of the UI to apply this change.
     *
     * @param roadShieldBitmap The bitmap of the road shield icon to be displayed. Passing {@code null} will remove
     *                         any currently displayed road shield icon, effectively hiding it.
     */
    public void onRoadShieldEvent(@Nullable Bitmap roadShieldBitmap) {
        this.roadShieldBitmap = roadShieldBitmap;
        redraw();
    }

    /**
     * Hides the road shield icon currently displayed on the view - if it was shown. Otherwise, this
     * does nothing. Triggers a redraw of the UI to apply this change.
     */
    public void onHideRoadShieldIcon() {
        roadShieldBitmap = null;
        redraw();
    }

    /**
     * Hides the maneuver panel from the view. This method sets a flag to indicate that the maneuver
     * panel should not be displayed and triggers a redraw of the UI to apply this change.
     */
    public void onHideManeuverPanel() {
        hideView = true;
        redraw();
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);

        if (hideView) {
            // Nothing to draw: Clear any previous content.
            return;
        }

        // We want to occupy the maximum available width minus some margin.
        int widthInPixels = getWidth();
        setWidthInDp(getDP(widthInPixels) - marginInDP * 2);

        // Set x position in density-independent pixels.
        // The y position is defined by the XML layout - or optionally programmatically via yInDP.
        xInDP = marginInDP;

        // The maneuver panel.
        int backgroundX = getPixels(xInDP);
        int backgroundY = getPixels(yInDP);
        int backgroundW = getPixels(wInDP);
        int backgroundH = getPixels(hInDP);

        // The maneuver icon. Shown left-aligned.
        int maneuverIconX = backgroundX + getPixels(marginInDP);
        int maneuverIconY = backgroundY + getPixels(marginInDP);
        int maneuverIconW = backgroundH - getPixels(marginInDP) * 2;
        int maneuverIconH = maneuverIconW;

        // The distance text. Shown left of maneuver icon, above road name text.
        int distanceTextX = maneuverIconX + maneuverIconW + getPixels(marginInDP);
        int distanceTextY = maneuverIconY;
        int distanceTextW = backgroundW - distanceTextX;
        int distanceTextH = maneuverIconH / 2;

        // The road name text. Shown below distance text.
        int roadNameX = distanceTextX;
        int roadNameY = distanceTextY + distanceTextH + getPixels(marginInDP);
        int roadNameW = distanceTextW;
        int roadNameH = distanceTextH - getPixels(marginInDP);

        // The road shield icon. Shown right-aligned.
        int roadShieldX = roadNameX + roadNameW - maneuverIconW + getPixels(marginInDP);
        int roadShieldY = distanceTextY;
        int roadShieldW = maneuverIconW - getPixels(marginInDP);
        int roadShieldH = maneuverIconH;

        // Reduce available space if no road shield icon is shown.
        if (roadShieldBitmap != null) {
            roadNameW = roadNameW - roadShieldW - getPixels(marginInDP);
            distanceTextW = roadNameW;
        }

        // The bounding boxes for all content we want to show.
        RectF backgroundRect = new RectF(backgroundX, backgroundY, backgroundX + backgroundW, backgroundY + backgroundH);
        RectF maneuverIconRect = new RectF(maneuverIconX, maneuverIconY, maneuverIconX + maneuverIconW, maneuverIconY + maneuverIconH);
        RectF distanceTextRect = new RectF(distanceTextX, distanceTextY, distanceTextX + distanceTextW, distanceTextY + distanceTextH);
        RectF roadNameRect = new RectF(roadNameX, roadNameY, roadNameX + roadNameW, roadNameY + roadNameH);
        RectF roadShieldRect = new RectF(roadShieldX, roadShieldY, roadShieldX + roadShieldW, roadShieldY + roadShieldH);

        // Render all available content.
        drawBackgroundRectangle(backgroundRect, canvas);
        drawTextInRect(distanceText, (int) (textSizeInDP * 1.5), distanceTextRect, canvas);
        drawTextInRect(roadName, textSizeInDP, roadNameRect, canvas);

        if (maneuverBitmap != null) {
            // Scale the bitmap if necessary to fit the rect.
            canvas.drawBitmap(maneuverBitmap, null, maneuverIconRect, paint);
        } else {
            // Render a replacement string until the icon is loaded.
            drawTextInRect(maneuverIconText, textSizeInDP, maneuverIconRect, canvas);
            Log.d(TAG, "No maneuver icon provided: " + maneuverIconText);
        }

        if (roadShieldBitmap != null) {
            // Scale the bitmap if necessary to fit the rect while preserving its aspect ratio.
            drawBitmapInRect(roadShieldBitmap, roadShieldRect, canvas);
        } else {
            // Nothing to do. The available space for text will expand.
        }
    }

    private void drawBackgroundRectangle(RectF rectInDP, Canvas canvas) {
        String blueColorString = "#126df9";
        int blueColor = Color.parseColor(blueColorString);

        int left = (int) rectInDP.left;
        int top = (int) rectInDP.top;
        int right = (int) rectInDP.right;
        int bottom = (int) rectInDP.bottom;

        // Set the inner stroke color and width.
        paint.setColor(blueColor);
        paint.setStyle(Paint.Style.FILL);
        paint.setStrokeWidth(5);

        // Calculate the adjusted rectangle for the inner stroke.
        float innerAdjustedLeft = left + paint.getStrokeWidth() / 2;
        float innerAdjustedTop = top + paint.getStrokeWidth() / 2;
        float innerAdjustedRight = right - paint.getStrokeWidth() / 2;
        float innerAdjustedBottom = bottom - paint.getStrokeWidth() / 2;
        RectF innerAdjustedRectF = new RectF(innerAdjustedLeft, innerAdjustedTop, innerAdjustedRight, innerAdjustedBottom);

        // Draw the background.
        paint.setColor(blueColor);
        canvas.drawRoundRect(innerAdjustedRectF, 10, 10, paint);

        // Set the inner stroke color.
        paint.setColor(blueColor);
        paint.setStyle(Paint.Style.STROKE);

        // Draw the inner stroke.
        canvas.drawRoundRect(innerAdjustedRectF, 10, 10, paint);
    }

    private void drawTextInRect(String text, int textSizeInDP, RectF rect, Canvas canvas) {
        paint.setStyle(Paint.Style.FILL);
        paint.setTextSize(getPixels(textSizeInDP));
        paint.setColor(Color.WHITE);
        paint.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD));
        float marginInPixels = getPixels(marginInDP);

        // Calculate the available width for the text.
        float availableWidth = rect.width() - (2 * marginInPixels);

        // Truncate the text if it exceeds the available width.
        if (paint.measureText(text) > availableWidth) {
            text = truncateTextWithEllipsis(text, availableWidth);
        }

        // Draw the truncated or original text on the canvas.
        float textX = rect.left + marginInPixels;
        float textY = rect.centerY() + (paint.getTextSize() / 2f);
        canvas.drawText(text, textX, textY, paint);
    }

    private String truncateTextWithEllipsis(String text, float maxWidth) {
        String ellipsis = "...";
        float ellipsisWidth = paint.measureText(ellipsis);

        if (paint.measureText(text) <= maxWidth) {
            return text;
        } else {
            StringBuilder truncatedText = new StringBuilder();
            float width = 0;
            int endIndex = 0;

            // Find the index of the last character that fits within the available width.
            while (width + ellipsisWidth < maxWidth && endIndex < text.length()) {
                char c = text.charAt(endIndex);
                float charWidth = paint.measureText(String.valueOf(c));
                if (width + charWidth <= maxWidth - ellipsisWidth) {
                    truncatedText.append(c);
                    width += charWidth;
                } else {
                    break;
                }
                endIndex++;
            }

            truncatedText.append(ellipsis);
            return truncatedText.toString();
        }
    }

    // Scales and centers the bitmap within the given rect while preserving its aspect ratio.
    private void drawBitmapInRect(Bitmap bitmap, RectF rect, Canvas canvas) {
        Rect srcRect = new Rect(0, 0, bitmap.getWidth(), bitmap.getHeight());

        // Calculate the destination rectangle with aspect ratio preserved.
        RectF destRect = new RectF(rect);
        float bitmapAspectRatio = (float) bitmap.getWidth() / bitmap.getHeight();
        float rectAspectRatio = rect.width() / rect.height();

        if (bitmapAspectRatio > rectAspectRatio) {
            // Scale the height to fit.
            float scaledHeight = rect.width() / bitmapAspectRatio;
            float topOffset = (rect.height() - scaledHeight) / 2;
            destRect.top += topOffset;
            destRect.bottom = destRect.top + scaledHeight;
        } else {
            // Scale the width to fit.
            float scaledWidth = rect.height() * bitmapAspectRatio;
            float leftOffset = (rect.width() - scaledWidth) / 2;
            destRect.left += leftOffset;
            destRect.right = destRect.left + scaledWidth;
        }

        // Adjust the destRect to fit within the provided rect.
        // For this, we compare the edges of destRect with the
        // corresponding edges of rect and adjust them accordingly
        // to ensure the bitmap is fully contained within rect.
        if (destRect.left < rect.left) {
            float offset = rect.left - destRect.left;
            destRect.left += offset;
            destRect.right += offset;
        }
        if (destRect.top < rect.top) {
            float offset = rect.top - destRect.top;
            destRect.top += offset;
            destRect.bottom += offset;
        }
        if (destRect.right > rect.right) {
            float offset = destRect.right - rect.right;
            destRect.left -= offset;
            destRect.right -= offset;
        }
        if (destRect.bottom > rect.bottom) {
            float offset = destRect.bottom - rect.bottom;
            destRect.top -= offset;
            destRect.bottom -= offset;
        }

        // This scales the bitmap if necessary to fit in the destRect.
        // However, the code above ensures that this is not necessary.
        canvas.drawBitmap(bitmap, srcRect, destRect, paint);
    }

    // Get pixel size for this particular device based on its display metrics.
    // See https://developer.android.com/training/multiscreen/screendensities
    private int getPixels(int dp) {
        int pixels = Math.round(TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP, dp, getResources().getDisplayMetrics()));
        return pixels;
    }

    public int getDP(float px) {
        DisplayMetrics displayMetrics = context.getResources().getDisplayMetrics();
        return (int) (px / ((float) displayMetrics.densityDpi / DisplayMetrics.DENSITY_DEFAULT));
    }
}
