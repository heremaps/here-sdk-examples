package com.here.offscreenmap;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.SurfaceTexture;
import android.util.Log;
import android.view.Surface;

import com.here.sdk.mapview.MapIdleListener;
import com.here.sdk.mapview.MapSurface;
import com.here.sdk.mapview.MapViewBase;

import java.util.Deque;
import java.util.LinkedList;

/**
 * Creates and manages {@link MapSurface} and its offscreen drawing surface
 * and exposes simple API to request images of the map.
 */
public class OffscreenMapRenderer implements MapIdleListener {
    private static final String TAG = OffscreenMapRenderer.class.getSimpleName();

    /**
     * Called right before generating an image of the map. The user is required
     * to modify map to their desired state.
     * <p>
     * Warning: Not changing the state of the map in any way will lock up the calling
     * {@link OffscreenMapRenderer}, as it relies on transition to idle state, which will not happen
     * if state of the map is not modified in any way.
     */
    interface MapTransformer {
        void transformMap(MapViewBase map);
    }

    /**
     * Used to pass the generated image of the map to the caller of
     * {@link #generateMapImage(MapTransformer, GenerateImageCallback)}.
     */
    interface GenerateImageCallback {
        void onMapImageReady(Bitmap image);
    }

    private static class RenderTask {
        MapTransformer setup;
        GenerateImageCallback resultCallback;

        RenderTask(MapTransformer setup, GenerateImageCallback resultCallback) {
            this.setup = setup;
            this.resultCallback = resultCallback;
        }
    }

    private final OffscreenSurfaceTexture offscreenSurfaceTexture;
    private final CapturingRenderListener renderListener;
    private final Surface offscreenRenderSurface;
    private final MapSurface mapSurface;

    private boolean isBusy;
    private boolean isReady;

    private RenderTask currentTask;
    private final Deque<RenderTask> renderTasks = new LinkedList<>();

    /**
     * Creates new offscreen map renderer for generating images of the map.
     *
     * @param context The app context.
     * @param width The width ot the generated images, in pixels.
     * @param height The height ot the generated images, in pixels.
     */
    public OffscreenMapRenderer(Context context, int width, int height) {
        offscreenSurfaceTexture = new OffscreenSurfaceTexture();
        renderListener = new CapturingRenderListener();

        try {
            offscreenSurfaceTexture.init();
        } catch (Throwable e) {
            Log.e(TAG, "init error", e);
        }
        SurfaceTexture st = offscreenSurfaceTexture.getSurfaceTexture();
        st.setDefaultBufferSize(width, height);
        offscreenRenderSurface = new Surface(st);
        mapSurface = new MapSurface();
        mapSurface.attachSurface(context, offscreenRenderSurface, width, height, renderListener);
        mapSurface.setOnReadyListener(() -> {
            isReady = true;
            Log.i(TAG, "onReady");
        });
        mapSurface.onResume();
        mapSurface.getHereMap().addMapIdleListener(this);
    }

    /**
     * Asynchronously generates a new image of the map.
     * <p>
     * Supplied {@code MapTransformer} is called to set the desired state of the map by the caller
     * of this method.
     * <p>
     * The generated image is passed to the supplied callback when it's ready.
     *
     * @param mapTransformer The user defined code that sets up the desired state of the map.
     * @param resultCallback
     */
    public void generateMapImage(MapTransformer mapTransformer, GenerateImageCallback resultCallback) {
        RenderTask newTask = new RenderTask(mapTransformer, resultCallback);
        if (!isReady || isBusy || currentTask != null) {
            renderTasks.offer(newTask);
        } else {
            executeRenderTask(newTask);
        }
    }

    /**
     * Resumes map renderer. Needs to be called from {@code onResume()} of the {@code Activity}.
     */
    public void onResume() {
        mapSurface.onResume();
    }

    /**
     * Pauses map renderer. Needs to be called from {@code onPause()} of the {@code Activity}.
     */
    public void onPause() {
        mapSurface.onPause();
    }

    /**
     * Destroys this map renderer and releases internal resources. Needs to be called from
     * {@code onDestroy()} of the {@code Activity}
     * or at any earlier moment when it's no longer used and needs to be destroyed.
     */
    public void onDestroy() {
        mapSurface.destroy();
        offscreenSurfaceTexture.release();
    }

    @Override
    public void onMapBusy() {
        isBusy = true;
    }

    @Override
    public void onMapIdle() {
        Bitmap image = renderListener.getBitmap();
        if (currentTask != null) {
            currentTask.resultCallback.onMapImageReady(image);
            currentTask = null;
        }
        if (!renderTasks.isEmpty()) {
            RenderTask task = renderTasks.poll();
            executeRenderTask(task);
        } else {
            isBusy = false;
        }
    }

    private void executeRenderTask(RenderTask task) {
        currentTask = task;
        currentTask.setup.transformMap(mapSurface);
    }

}
