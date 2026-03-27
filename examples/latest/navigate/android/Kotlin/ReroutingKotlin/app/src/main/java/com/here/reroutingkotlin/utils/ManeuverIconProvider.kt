package com.here.reroutingkotlin.utils

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.util.Log
import androidx.annotation.Nullable
import com.here.sdk.routing.ManeuverAction
import java.io.IOException
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.MalformedURLException
import java.net.URL
import java.util.concurrent.Executors

class ManeuverIconProvider {

    companion object { private const val TAG = "ManeuverIconProvider" }

    private val iconLibrary =
        "https://raw.githubusercontent.com/heremaps/here-icons/master/icons/guidance-icons/manoeuvers/2x/"

    private val maneuverURLs = HashMap<ManeuverAction, String>()
    private val maneuverIcons = HashMap<ManeuverAction, Bitmap>()

    init {
        val fileType = "_solid_24px.png"
        val fileTypeV2 = "-solid_24px.png"

        maneuverURLs[ManeuverAction.DEPART] = iconLibrary + "depart" + fileType
        maneuverURLs[ManeuverAction.ARRIVE] = iconLibrary + "arrive" + fileType
        maneuverURLs[ManeuverAction.LEFT_U_TURN] = iconLibrary + "left-u-turn" + fileType
        maneuverURLs[ManeuverAction.SHARP_LEFT_TURN] = iconLibrary + "sharp-left-turn" + fileType
        maneuverURLs[ManeuverAction.LEFT_TURN] = iconLibrary + "left-turn" + fileType
        maneuverURLs[ManeuverAction.SLIGHT_LEFT_TURN] = iconLibrary + "slide-left-turn" + fileTypeV2
        maneuverURLs[ManeuverAction.CONTINUE_ON] = iconLibrary + "continue-on" + fileType
        maneuverURLs[ManeuverAction.SLIGHT_RIGHT_TURN] = iconLibrary + "slight-right-turn" + fileTypeV2
        maneuverURLs[ManeuverAction.RIGHT_TURN] = iconLibrary + "right-turn" + fileType
        maneuverURLs[ManeuverAction.SHARP_RIGHT_TURN] = iconLibrary + "sharp-right-turn" + fileType
        maneuverURLs[ManeuverAction.RIGHT_U_TURN] = iconLibrary + "right-u-turn" + fileType
        maneuverURLs[ManeuverAction.LEFT_EXIT] = iconLibrary + "left_exit" + fileType
        maneuverURLs[ManeuverAction.RIGHT_EXIT] = iconLibrary + "right-exit" + fileType
        maneuverURLs[ManeuverAction.LEFT_RAMP] = iconLibrary + "left-ramp" + fileType
        maneuverURLs[ManeuverAction.RIGHT_RAMP] = iconLibrary + "right-ramp" + fileType
        maneuverURLs[ManeuverAction.LEFT_FORK] = iconLibrary + "left-fork" + fileType
        maneuverURLs[ManeuverAction.MIDDLE_FORK] = iconLibrary + "middle-fork" + fileType
        maneuverURLs[ManeuverAction.RIGHT_FORK] = iconLibrary + "right-fork" + fileType
        maneuverURLs[ManeuverAction.ENTER_HIGHWAY_FROM_LEFT] = iconLibrary + "enter-highway-right" + fileType
        maneuverURLs[ManeuverAction.ENTER_HIGHWAY_FROM_RIGHT] = iconLibrary + "enter-highway-left" + fileType
        maneuverURLs[ManeuverAction.LEFT_ROUNDABOUT_ENTER] = iconLibrary + "left-roundabout-enter" + fileType
        maneuverURLs[ManeuverAction.RIGHT_ROUNDABOUT_ENTER] = iconLibrary + "right-roundabout-enter" + fileType
        maneuverURLs[ManeuverAction.LEFT_ROUNDABOUT_PASS] = iconLibrary + "left-roundabout-exit4" + fileType
        maneuverURLs[ManeuverAction.RIGHT_ROUNDABOUT_PASS] = iconLibrary + "right-roundabout-exit4" + fileType
        maneuverURLs[ManeuverAction.LEFT_ROUNDABOUT_EXIT1] = iconLibrary + "left-roundabout-exit1" + fileType
        maneuverURLs[ManeuverAction.LEFT_ROUNDABOUT_EXIT2] = iconLibrary + "left-roundabout-exit2" + fileType
        maneuverURLs[ManeuverAction.LEFT_ROUNDABOUT_EXIT3] = iconLibrary + "left-roundabout-exit3" + fileType
        maneuverURLs[ManeuverAction.LEFT_ROUNDABOUT_EXIT4] = iconLibrary + "left-roundabout-exit4" + fileType
        maneuverURLs[ManeuverAction.LEFT_ROUNDABOUT_EXIT5] = iconLibrary + "left-roundabout-exit5" + fileType
        maneuverURLs[ManeuverAction.LEFT_ROUNDABOUT_EXIT6] = iconLibrary + "left-roundabout-exit6" + fileType
        maneuverURLs[ManeuverAction.LEFT_ROUNDABOUT_EXIT7] = iconLibrary + "left-roundabout-exit7" + fileType
        maneuverURLs[ManeuverAction.LEFT_ROUNDABOUT_EXIT8] = iconLibrary + "left-roundabout-exit7" + fileType
        maneuverURLs[ManeuverAction.LEFT_ROUNDABOUT_EXIT9] = iconLibrary + "left-roundabout-exit7" + fileType
        maneuverURLs[ManeuverAction.LEFT_ROUNDABOUT_EXIT10] = iconLibrary + "left-roundabout-exit7" + fileType
        maneuverURLs[ManeuverAction.LEFT_ROUNDABOUT_EXIT11] = iconLibrary + "left-roundabout-exit7" + fileType
        maneuverURLs[ManeuverAction.LEFT_ROUNDABOUT_EXIT12] = iconLibrary + "left-roundabout-exit7" + fileType
        maneuverURLs[ManeuverAction.RIGHT_ROUNDABOUT_EXIT1] = iconLibrary + "right-roundabout-exit1" + fileType
        maneuverURLs[ManeuverAction.RIGHT_ROUNDABOUT_EXIT2] = iconLibrary + "right-roundabout-exit2" + fileType
        maneuverURLs[ManeuverAction.RIGHT_ROUNDABOUT_EXIT3] = iconLibrary + "right-roundabout-exit3" + fileType
        maneuverURLs[ManeuverAction.RIGHT_ROUNDABOUT_EXIT4] = iconLibrary + "right-roundabout-exit4" + fileType
        maneuverURLs[ManeuverAction.RIGHT_ROUNDABOUT_EXIT5] = iconLibrary + "right-roundabout-exit5" + fileType
        maneuverURLs[ManeuverAction.RIGHT_ROUNDABOUT_EXIT6] = iconLibrary + "right-roundabout-exit6" + fileType
        maneuverURLs[ManeuverAction.RIGHT_ROUNDABOUT_EXIT7] = iconLibrary + "right-roundabout-exit7" + fileType
        maneuverURLs[ManeuverAction.RIGHT_ROUNDABOUT_EXIT8] = iconLibrary + "right-roundabout-exit7" + fileType
        maneuverURLs[ManeuverAction.RIGHT_ROUNDABOUT_EXIT9] = iconLibrary + "right-roundabout-exit7" + fileType
        maneuverURLs[ManeuverAction.RIGHT_ROUNDABOUT_EXIT10] = iconLibrary + "right-roundabout-exit7" + fileType
        maneuverURLs[ManeuverAction.RIGHT_ROUNDABOUT_EXIT11] = iconLibrary + "right-roundabout-exit7" + fileType
        maneuverURLs[ManeuverAction.RIGHT_ROUNDABOUT_EXIT12] = iconLibrary + "right-roundabout-exit7" + fileType
    }

    fun getManeuverIcon(key: ManeuverAction): Bitmap? = maneuverIcons[key]

    fun loadManeuverIcons() {
        val executor = Executors.newFixedThreadPool(3)
        maneuverURLs.values.forEach { url ->
            executor.submit { loadManeuverIcon(url) }
        }
        executor.shutdown()
    }

    private fun loadManeuverIcon(imageUrl: String) {
        val bitmap = downloadBitmapFromUrl(imageUrl) ?: run {
            Log.e(TAG, "Error when trying to download icon: $imageUrl")
            return
        }
        val converted = convertBlackLinesToWhite(bitmap)
        val key = getKeyForValue(maneuverURLs, imageUrl)
        key?.let { maneuverIcons[it] = converted }
    }

    private fun downloadBitmapFromUrl(imageUrl: String): Bitmap? {
        val url: URL = try { URL(imageUrl) } catch (e: MalformedURLException) { return null }
        val connection: HttpURLConnection = try { url.openConnection() as HttpURLConnection } catch (e: IOException) { return null }
        connection.setDoInput(true)
        try { connection.connect() } catch (e: IOException) { return null }
        val inputStream: InputStream = try { connection.inputStream } catch (e: IOException) { return null }
        val bitmap = BitmapFactory.decodeStream(inputStream)
        try { inputStream.close() } catch (_: IOException) {}
        return bitmap
    }

    private fun getKeyForValue(map: HashMap<ManeuverAction, String>, value: String): ManeuverAction? {
        for (entry in map.entries) {
            if (entry.value == value) return entry.key
        }
        return null
    }

    // Convert black lines to white, preserve alpha channel.
    private fun convertBlackLinesToWhite(originalBitmap: Bitmap): Bitmap {
        val convertedBitmap = originalBitmap.copy(Bitmap.Config.ARGB_8888, true)
        val width = convertedBitmap.width
        val height = convertedBitmap.height
        for (x in 0 until width) {
            for (y in 0 until height) {
                val pixel = convertedBitmap.getPixel(x, y)
                val alpha = Color.alpha(pixel)
                val whitePixel = Color.argb(alpha, 255, 255, 255)
                convertedBitmap.setPixel(x, y, whitePixel)
            }
        }
        return convertedBitmap
    }
}
