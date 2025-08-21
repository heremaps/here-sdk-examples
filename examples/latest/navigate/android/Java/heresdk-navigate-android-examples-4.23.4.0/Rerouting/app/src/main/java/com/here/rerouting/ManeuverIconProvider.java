package com.here.rerouting;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.util.Log;

import androidx.annotation.Nullable;

import com.here.sdk.routing.ManeuverAction;

import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

// This class loads all supported maneuver icons from the HERE Icon Library to support quick testing of the HERE SDK features.
//
// Note: In an application used in production it is recommended to pre-download all assets
// and store them in your application's asset bundle. Asset names and folders in the HERE Icon library may change any time and
// there is no guarantee that the links will be stable. On top, in a real application you do want to save unnecessary
// bandwidth from your users. However, this class provides a convenient way to always access the latest resources from the
// HERE Icon Library.
public class ManeuverIconProvider {

    private static final String TAG = ManeuverIconProvider.class.getName();

    // The HERE Icon Library provides free-to-use icons for your projects based on the license terms you
    // can find on https://github.com/heremaps/here-icons.
    private final String iconLibrary =
            "https://raw.githubusercontent.com/heremaps/here-icons/master/icons/guidance-icons/manoeuvers/2x/";

    private final HashMap< ManeuverAction, String> maneuverURLs = new HashMap<>();
    private final HashMap< ManeuverAction, Bitmap> maneuverIcons = new HashMap<>();

    public ManeuverIconProvider() {
        String fileType = "_solid_24px.png";
        String fileTypeV2 = "-solid_24px.png";

        // Currently, the HERE SDK supports 48 maneuver actions.
        maneuverURLs.put(ManeuverAction.DEPART, iconLibrary + "depart" + fileType);
        maneuverURLs.put(ManeuverAction.ARRIVE, iconLibrary + "arrive" + fileType);
        maneuverURLs.put(ManeuverAction.LEFT_U_TURN, iconLibrary + "left-u-turn" + fileType);
        maneuverURLs.put(ManeuverAction.SHARP_LEFT_TURN, iconLibrary + "sharp-left-turn" + fileType);
        maneuverURLs.put(ManeuverAction.LEFT_TURN, iconLibrary + "left-turn" + fileType);
        maneuverURLs.put(ManeuverAction.SLIGHT_LEFT_TURN, iconLibrary + "slide-left-turn" + fileTypeV2);
        maneuverURLs.put(ManeuverAction.CONTINUE_ON, iconLibrary + "continue-on" + fileType);
        maneuverURLs.put(ManeuverAction.SLIGHT_RIGHT_TURN, iconLibrary + "slight-right-turn" + fileTypeV2);
        maneuverURLs.put(ManeuverAction.RIGHT_TURN, iconLibrary + "right-turn" + fileType);
        maneuverURLs.put(ManeuverAction.SHARP_RIGHT_TURN, iconLibrary + "sharp-right-turn" + fileType);
        maneuverURLs.put(ManeuverAction.RIGHT_U_TURN, iconLibrary + "right-u-turn" + fileType);
        maneuverURLs.put(ManeuverAction.LEFT_EXIT, iconLibrary + "left_exit" + fileType);
        maneuverURLs.put(ManeuverAction.RIGHT_EXIT, iconLibrary + "right-exit" + fileType);
        maneuverURLs.put(ManeuverAction.LEFT_RAMP, iconLibrary + "left-ramp" + fileType);
        maneuverURLs.put(ManeuverAction.RIGHT_RAMP, iconLibrary + "right-ramp" + fileType);
        maneuverURLs.put(ManeuverAction.LEFT_FORK, iconLibrary + "left-fork" + fileType);
        maneuverURLs.put(ManeuverAction.MIDDLE_FORK, iconLibrary + "middle-fork" + fileType);
        maneuverURLs.put(ManeuverAction.RIGHT_FORK, iconLibrary + "right-fork" + fileType);
        maneuverURLs.put(ManeuverAction.ENTER_HIGHWAY_FROM_LEFT, iconLibrary + "enter-highway-right" + fileType);
        maneuverURLs.put(ManeuverAction.ENTER_HIGHWAY_FROM_RIGHT, iconLibrary + "enter-highway-left" + fileType);
        maneuverURLs.put(ManeuverAction.LEFT_ROUNDABOUT_ENTER, iconLibrary + "left-roundabout-enter" + fileType);
        maneuverURLs.put(ManeuverAction.RIGHT_ROUNDABOUT_ENTER, iconLibrary + "right-roundabout-enter" + fileType);

        // Currently, no PNG assets are available for LEFT_ROUNDABOUT_PASS, so we use a fallback icon.
        maneuverURLs.put(ManeuverAction.LEFT_ROUNDABOUT_PASS, iconLibrary + "left-roundabout-exit4" + fileType);
        // Currently, no PNG assets are available for RIGHT_ROUNDABOUT_PASS, so we use a fallback icon.
        maneuverURLs.put(ManeuverAction.RIGHT_ROUNDABOUT_PASS, iconLibrary + "right-roundabout-exit4" + fileType);

        maneuverURLs.put(ManeuverAction.LEFT_ROUNDABOUT_EXIT1, iconLibrary + "left-roundabout-exit1" + fileType);
        maneuverURLs.put(ManeuverAction.LEFT_ROUNDABOUT_EXIT2, iconLibrary + "left-roundabout-exit2" + fileType);
        maneuverURLs.put(ManeuverAction.LEFT_ROUNDABOUT_EXIT3, iconLibrary + "left-roundabout-exit3" + fileType);
        maneuverURLs.put(ManeuverAction.LEFT_ROUNDABOUT_EXIT4, iconLibrary + "left-roundabout-exit4" + fileType);
        maneuverURLs.put(ManeuverAction.LEFT_ROUNDABOUT_EXIT5, iconLibrary + "left-roundabout-exit5" + fileType);
        maneuverURLs.put(ManeuverAction.LEFT_ROUNDABOUT_EXIT6, iconLibrary + "left-roundabout-exit6" + fileType);
        maneuverURLs.put(ManeuverAction.LEFT_ROUNDABOUT_EXIT7, iconLibrary + "left-roundabout-exit7" + fileType);

        // Currently, no PNG assets are available for LEFT_ROUNDABOUT_EXIT_8..12, so we use a fallback icon.
        maneuverURLs.put(ManeuverAction.LEFT_ROUNDABOUT_EXIT8, iconLibrary + "left-roundabout-exit7" + fileType);
        maneuverURLs.put(ManeuverAction.LEFT_ROUNDABOUT_EXIT9, iconLibrary + "left-roundabout-exit7" + fileType);
        maneuverURLs.put(ManeuverAction.LEFT_ROUNDABOUT_EXIT10, iconLibrary + "left-roundabout-exit7" + fileType);
        maneuverURLs.put(ManeuverAction.LEFT_ROUNDABOUT_EXIT11, iconLibrary + "left-roundabout-exit7" + fileType);
        maneuverURLs.put(ManeuverAction.LEFT_ROUNDABOUT_EXIT12, iconLibrary + "left-roundabout-exit7" + fileType);

        maneuverURLs.put(ManeuverAction.RIGHT_ROUNDABOUT_EXIT1, iconLibrary + "right-roundabout-exit1" + fileType);
        maneuverURLs.put(ManeuverAction.RIGHT_ROUNDABOUT_EXIT2, iconLibrary + "right-roundabout-exit2" + fileType);
        maneuverURLs.put(ManeuverAction.RIGHT_ROUNDABOUT_EXIT3, iconLibrary + "right-roundabout-exit3" + fileType);
        maneuverURLs.put(ManeuverAction.RIGHT_ROUNDABOUT_EXIT4, iconLibrary + "right-roundabout-exit4" + fileType);
        maneuverURLs.put(ManeuverAction.RIGHT_ROUNDABOUT_EXIT5, iconLibrary + "right-roundabout-exit5" + fileType);
        maneuverURLs.put(ManeuverAction.RIGHT_ROUNDABOUT_EXIT6, iconLibrary + "right-roundabout-exit6" + fileType);
        maneuverURLs.put(ManeuverAction.RIGHT_ROUNDABOUT_EXIT7, iconLibrary + "right-roundabout-exit7" + fileType);

        // Currently, no PNG assets are available for RIGHT_ROUNDABOUT_EXIT_8..12, so we use a fallback icon.
        maneuverURLs.put(ManeuverAction.RIGHT_ROUNDABOUT_EXIT8, iconLibrary + "right-roundabout-exit7" + fileType);
        maneuverURLs.put(ManeuverAction.RIGHT_ROUNDABOUT_EXIT9, iconLibrary + "right-roundabout-exit7" + fileType);
        maneuverURLs.put(ManeuverAction.RIGHT_ROUNDABOUT_EXIT10, iconLibrary + "right-roundabout-exit7" + fileType);
        maneuverURLs.put(ManeuverAction.RIGHT_ROUNDABOUT_EXIT11, iconLibrary + "right-roundabout-exit7" + fileType);
        maneuverURLs.put(ManeuverAction.RIGHT_ROUNDABOUT_EXIT12, iconLibrary + "right-roundabout-exit7" + fileType);
    }

    @Nullable
    public Bitmap getManeuverIcon(ManeuverAction key) {
        return maneuverIcons.get(key);
    }

    // Asynchronously loads maneuver assets as PNG from the HERE Icon library.
    // Note that you can also find SVG content in the library.
    // Alternatively, consider to include the desired assets in your application`s
    // resource folder to avoid consuming bandwidth and to support offline use cases.
    // Here we load all assets asynchronously from the internet.
    // The total size of all downloaded maneuver assets is around 73 KB.
    // Note: For simplicity, we do not cache already downloaded assets and we'll redownload all at next
    // start of app. Alternatively, consider to store already downloaded icons on your device.
    public void loadManeuverIcons() {
        // Create a thread pool with a fixed number of threads.
        ExecutorService executorService = Executors.newFixedThreadPool(3);

        // Submit the tasks to the thread pool.
        for (String url : maneuverURLs.values()) {
            executorService.submit(() -> loadManeuverIcons(url));
        }

        // Shutdown the thread pool.
        // The tasks that have been submitted to the ExecutorService will continue to execute in the background.
        executorService.shutdown();
    }

    private void loadManeuverIcons(String imageUrl) {
        Bitmap bitmap = downloadBitmapFromUrl(imageUrl);
        if (bitmap == null) {
            Log.e(TAG, "Error when trying to download icon: " + imageUrl);
            return;
        }
        bitmap = convertBlackLinesToWhite(bitmap);
        ManeuverAction maneuverAction = getKeyForValue(maneuverURLs, imageUrl);
        if (maneuverAction != null) {
            maneuverIcons.put(maneuverAction, bitmap);
        }
    }

    // Synchronously downloads a bitmap from the specified URL.
    @Nullable
    private Bitmap downloadBitmapFromUrl(String imageUrl) {
        URL url = null;
        try {
            url = new URL(imageUrl);
        } catch (MalformedURLException e) {
            e.printStackTrace();
        }

        HttpURLConnection connection = null;
        try {
            connection = (HttpURLConnection) url.openConnection();
        } catch (IOException e) {
            e.printStackTrace();
        }
        connection.setDoInput(true);

        try {
            connection.connect();
        } catch (IOException e) {
            e.printStackTrace();
        }

        InputStream inputStream;
        try {
            inputStream = connection.getInputStream();
        } catch (IOException e) {
            e.printStackTrace();
            // Probably, file not found.
            return null;
        }

        Bitmap bitmap = BitmapFactory.decodeStream(inputStream);
        try {
            inputStream.close();
        } catch (IOException e) {
            e.printStackTrace();
        }

        return bitmap;
    }

    @Nullable
    private ManeuverAction getKeyForValue(HashMap<ManeuverAction, String> map, String value) {
        for (Map.Entry<ManeuverAction, String> entry : map.entrySet()) {
            if (entry.getValue().equals(value)) {
                return entry.getKey();
            }
        }
        // Value not found in the map.
        return null;
    }

    // The HERE maneuver icons are black on transparent, by default.
    // Here we convert the bitmaps to be white on transparent.
    private Bitmap convertBlackLinesToWhite(Bitmap originalBitmap) {
        // Convert the original bitmap to ARGB_8888 if the configuration is different.
        Bitmap convertedBitmap = originalBitmap.copy(Bitmap.Config.ARGB_8888, true);

        int width = convertedBitmap.getWidth();
        int height = convertedBitmap.getHeight();

        for (int x = 0; x < width; x++) {
            for (int y = 0; y < height; y++) {
                int pixel = convertedBitmap.getPixel(x, y);

                // Extract the alpha channel from the pixel.
                int alpha = Color.alpha(pixel);

                // Set the pixel to white while preserving alpha channel.
                pixel = Color.argb(alpha, 255, 255, 255);

                convertedBitmap.setPixel(x, y, pixel);
            }
        }

        // Return the convertedBitmap.
        return convertedBitmap;
    }
}
