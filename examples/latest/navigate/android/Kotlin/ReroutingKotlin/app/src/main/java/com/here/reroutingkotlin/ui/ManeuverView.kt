package com.here.reroutingkotlin.ui

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Typeface
import android.util.AttributeSet
import android.view.View
import androidx.annotation.NonNull
import androidx.annotation.Nullable

// A simple view to show the next maneuver event.
class ManeuverView : View {

    companion object {
        private const val TAG = "ManeuverView"
        // The default w/h constraint we use to create the icon.
        const val ROAD_SHIELD_DIM_CONSTRAINTS_IN_PIXELS = 100
    }

    private val paint = Paint()
    private var maneuverBitmap: Bitmap? = null
    private var roadShieldBitmap: Bitmap? = null
    private var maneuverIconText: String = ""
    private var roadName: String = ""
    private var distanceText: String = ""
    private var hideView: Boolean = true

    private val textSizeInDP = 15

    // The dimensions of the rectangle that holds all content.
    private var xInDP = 0
    private var yInDP = 0
    private var wInDP = 0
    private var hInDP = 80

    private var marginInDP = 3

    constructor(context: Context) : super(context)
    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs)
    constructor(context: Context, attrs: AttributeSet?, defStyleAttr: Int) : super(context, attrs, defStyleAttr)

    fun getWidthInDP(): Int = wInDP
    fun getHeightInDP(): Int = hInDP

    fun setWidthInDp(widthInDp: Int) {
        wInDP = widthInDp
        redraw()
    }

    fun redraw() {
        invalidate()
    }

    fun onManeuverEvent(@Nullable maneuverIcon: Bitmap?, @NonNull maneuverIconText: String, @NonNull distanceText: String, @NonNull roadName: String) {
        this.maneuverBitmap = maneuverIcon
        this.maneuverIconText = maneuverIconText
        this.distanceText = distanceText
        this.roadName = roadName
        hideView = false
        redraw()
    }

    fun onRoadShieldEvent(@Nullable roadShieldBitmap: Bitmap?) {
        this.roadShieldBitmap = roadShieldBitmap
        redraw()
    }

    fun onHideRoadShieldIcon() {
        roadShieldBitmap = null
        redraw()
    }

    fun onHideManeuverPanel() {
        hideView = true
        redraw()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (hideView) return

        val widthInPixels = width
        setWidthInDp(getDP(widthInPixels) - marginInDP * 2)
        xInDP = marginInDP

        val backgroundX = getPixels(xInDP)
        val backgroundY = getPixels(yInDP)
        val backgroundW = getPixels(wInDP)
        val backgroundH = getPixels(hInDP)

        val maneuverIconX = backgroundX + getPixels(marginInDP)
        val maneuverIconY = backgroundY + getPixels(marginInDP)
        val maneuverIconW = backgroundH - getPixels(marginInDP) * 2
        val maneuverIconH = maneuverIconW

        val distanceTextX = maneuverIconX + maneuverIconW + getPixels(marginInDP)
        val distanceTextY = maneuverIconY
        val distanceTextW = backgroundW - distanceTextX
        val distanceTextH = maneuverIconH / 2

        val roadNameX = distanceTextX
        val roadNameY = distanceTextY + distanceTextH + getPixels(marginInDP)
        val roadNameW = distanceTextW
        val roadNameH = distanceTextH - getPixels(marginInDP)

        val roadShieldX = roadNameX + roadNameW - maneuverIconW + getPixels(marginInDP)
        val roadShieldY = distanceTextY
        val roadShieldW = maneuverIconW - getPixels(marginInDP)
        val roadShieldH = maneuverIconH

        val backgroundRect = RectF(backgroundX.toFloat(), backgroundY.toFloat(), (backgroundX + backgroundW).toFloat(), (backgroundY + backgroundH).toFloat())
        val maneuverIconRect = RectF(maneuverIconX.toFloat(), maneuverIconY.toFloat(), (maneuverIconX + maneuverIconW).toFloat(), (maneuverIconY + maneuverIconH).toFloat())
        val distanceTextRect = RectF(distanceTextX.toFloat(), distanceTextY.toFloat(), (distanceTextX + distanceTextW).toFloat(), (distanceTextY + distanceTextH).toFloat())
        val roadNameRect = RectF(roadNameX.toFloat(), roadNameY.toFloat(), (roadNameX + roadNameW).toFloat(), (roadNameY + roadNameH).toFloat())
        val roadShieldRect = RectF(roadShieldX.toFloat(), roadShieldY.toFloat(), (roadShieldX + roadShieldW).toFloat(), (roadShieldY + roadShieldH).toFloat())

        drawBackgroundRectangle(backgroundRect, canvas)
        drawTextInRect(distanceText, (textSizeInDP * 1.5).toInt(), distanceTextRect, canvas)
        drawTextInRect(roadName, textSizeInDP, roadNameRect, canvas)

        maneuverBitmap?.let { drawBitmapInRect(it, maneuverIconRect, canvas) } ?: run { drawTextInRect(maneuverIconText, textSizeInDP, maneuverIconRect, canvas) }
        roadShieldBitmap?.let { drawBitmapInRect(it, roadShieldRect, canvas) }
    }

    private fun drawBackgroundRectangle(rectInDP: RectF, canvas: Canvas) {
        val blueColor = Color.parseColor("#126df9")
        val left = rectInDP.left.toInt()
        val top = rectInDP.top.toInt()
        val right = rectInDP.right.toInt()
        val bottom = rectInDP.bottom.toInt()
        paint.color = blueColor
        paint.style = Paint.Style.FILL
        paint.strokeWidth = 5f
        val innerAdjustedRectF = RectF(
            left + paint.strokeWidth / 2,
            top + paint.strokeWidth / 2,
            right - paint.strokeWidth / 2,
            bottom - paint.strokeWidth / 2
        )
        canvas.drawRoundRect(innerAdjustedRectF, 10f, 10f, paint)
        paint.style = Paint.Style.STROKE
        canvas.drawRoundRect(innerAdjustedRectF, 10f, 10f, paint)
    }

    private fun drawTextInRect(text: String, textSizeInDP: Int, rect: RectF, canvas: Canvas) {
        paint.style = Paint.Style.FILL
        paint.textSize = getPixels(textSizeInDP).toFloat()
        paint.color = Color.WHITE
        paint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        val marginInPixels = getPixels(marginInDP).toFloat()
        val availableWidth = rect.width() - (2 * marginInPixels)
        var displayText = text
        if (paint.measureText(displayText) > availableWidth) {
            displayText = truncateTextWithEllipsis(displayText, availableWidth)
        }
        val textX = rect.left + marginInPixels
        val textY = rect.centerY() + (paint.textSize / 2f)
        canvas.drawText(displayText, textX, textY, paint)
    }

    private fun truncateTextWithEllipsis(text: String, maxWidth: Float): String {
        val ellipsis = "..."
        val ellipsisWidth = paint.measureText(ellipsis)
        if (paint.measureText(text) <= maxWidth) return text
        var truncated = text
        while (paint.measureText(truncated) + ellipsisWidth > maxWidth && truncated.isNotEmpty()) {
            truncated = truncated.dropLast(1)
        }
        return truncated + ellipsis
    }

    private fun drawBitmapInRect(bitmap: Bitmap, rect: RectF, canvas: Canvas) {
        val srcRect = Rect(0, 0, bitmap.width, bitmap.height)
        val destRect = RectF(rect)
        val bitmapAspect = bitmap.width.toFloat() / bitmap.height
        val rectAspect = rect.width() / rect.height()
        if (bitmapAspect > rectAspect) {
            val scale = rect.width() / bitmap.width
            val height = bitmap.height * scale
            destRect.top = rect.centerY() - height / 2
            destRect.bottom = rect.centerY() + height / 2
        } else {
            val scale = rect.height() / bitmap.height
            val width = bitmap.width * scale
            destRect.left = rect.centerX() - width / 2
            destRect.right = rect.centerX() + width / 2
        }
        if (destRect.left < rect.left) destRect.left = rect.left
        if (destRect.top < rect.top) destRect.top = rect.top
        if (destRect.right > rect.right) destRect.right = rect.right
        if (destRect.bottom > rect.bottom) destRect.bottom = rect.bottom
        canvas.drawBitmap(bitmap, srcRect, destRect, paint)
    }

    private fun getPixels(dp: Int): Int {
        val scale = resources.displayMetrics.density
        return (dp * scale + 0.5f).toInt()
    }

    fun getDP(px: Int): Int {
        val metrics = resources.displayMetrics
        return (px / metrics.density).toInt()
    }
}
