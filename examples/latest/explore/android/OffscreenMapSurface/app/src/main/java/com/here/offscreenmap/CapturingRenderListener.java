package com.here.offscreenmap;

import android.graphics.Bitmap;
import android.opengl.GLES30;

import com.here.sdk.mapview.MapSurface;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;

/**
 * A {@link MapSurface.RenderListener} implementation that captures framebuffer content for each
 * drawn frame.
 * <p>
 * Use {@link #getBitmap()} to get the last rendered frame as a Bitmap.
 */
public class CapturingRenderListener implements MapSurface.RenderListener {

    // Holds raw pixel data as read from OpenGL framebuffer.
    private ByteBuffer pixelBuffer;

    // Processed pixel data used to create Bitmap object.
    private int pixels[];

    private int width = -1;
    private int height = -1;

    @Override
    public void onFramePrepared() {
        int[] dims = new int[4];
        GLES30.glGetIntegerv(GLES30.GL_VIEWPORT, dims, 0);
        int fbWidth = dims[2];
        int fbHeight = dims[3];

        if (fbWidth != width || fbHeight != height) {
            width = fbWidth;
            height = fbHeight;

            pixelBuffer = ByteBuffer.allocateDirect(4 * fbWidth * fbHeight);
            pixelBuffer.order(ByteOrder.nativeOrder());
            pixels = new int[fbWidth * fbHeight];
        }
        pixelBuffer.position(0);

        GLES30.glReadPixels(
                0, 0, fbWidth, fbHeight, GLES30.GL_RGBA, GLES30.GL_UNSIGNED_BYTE, pixelBuffer);
    }

    @Override
    public void onRenderTargetReleased() {}

    /**
     * Gets last rendered frame as a {@code Bitmap}.
     *
     * @return The image of the last drawn frame.
     */
    public Bitmap getBitmap() {
        if (pixels == null || pixelBuffer == null) {
            return null;
        }

        // Note that while getBitmap() and onFramePrepared() are called on different threads
        // (main and render thread respectively), this example app only calls getBitmap()
        // when renderer is in idle state. This note just serves as a reminder to take care
        // when moving data around between different threads.
        pixelBuffer.asIntBuffer().get(pixels);

        // ABGR to ARGB
        abgr2argb(pixels);

        // flip upside down
        flipVertically(pixels, width, height);

        Bitmap image = Bitmap.createBitmap(pixels, width, height, Bitmap.Config.ARGB_8888);
        return image;
    }

    private void abgr2argb(int[] pixels) {
        int len = pixels.length;
        for (int i = 0; i < len - 1; ++i) {
            int pixel = pixels[i];
            pixels[i] =
                    (pixel & 0xFF00FF00) | ((pixel << 16) & 0x00FF0000) | ((pixel >> 16) & 0xFF);
        }
    }

    private void flipVertically(int[] pixels, int width, int height) {
        int colStart = 0;
        int otherColStart = pixels.length - width;
        int halfHeight = height / 2;
        for (int row = 0; row < halfHeight; ++row) {
            for (int col = 0; col < width; ++col) {
                int pixel = pixels[colStart + col];
                pixels[colStart + col] = pixels[otherColStart + col];
                pixels[otherColStart + col] = pixel;
            }
            colStart += width;
            otherColStart -= width;
        }
    }
}