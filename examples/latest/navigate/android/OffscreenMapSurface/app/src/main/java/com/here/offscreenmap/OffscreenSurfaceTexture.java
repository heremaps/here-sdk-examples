package com.here.offscreenmap;

import android.graphics.SurfaceTexture;
import android.opengl.EGL14;
import android.opengl.EGLConfig;
import android.opengl.EGLContext;
import android.opengl.EGLDisplay;
import android.opengl.EGLSurface;
import android.opengl.GLES30;
import android.opengl.GLU;

/**
 * Helper class for managing a {@code SurfaceTexture} backed by a texture.
 */
public class OffscreenSurfaceTexture {

    private static final int DEFAULT_SURFACE_WIDTH = 1;
    private static final int DEFAULT_SURFACE_HEIGHT = 1;

    private static final int[] EGL_CONFIG_ATTRIBUTES = new int[] {
            EGL14.EGL_RENDERABLE_TYPE,
            EGL14.EGL_OPENGL_ES2_BIT,
            EGL14.EGL_RED_SIZE,
            8,
            EGL14.EGL_GREEN_SIZE,
            8,
            EGL14.EGL_BLUE_SIZE,
            8,
            EGL14.EGL_ALPHA_SIZE,
            8,
            EGL14.EGL_DEPTH_SIZE,
            0,
            EGL14.EGL_CONFIG_CAVEAT,
            EGL14.EGL_NONE,
            EGL14.EGL_SURFACE_TYPE,
            EGL14.EGL_PBUFFER_BIT,
            EGL14.EGL_NONE};

    private final int[] textureIdHolder = new int[1];

    private EGLDisplay display;
    private EGLContext context;
    private EGLSurface surface;
    private SurfaceTexture texture;

    /**
     * Creates the {@link SurfaceTexture}.
     */
    public void init() {
        display = getDefaultDisplay();
        EGLConfig config = chooseEGLConfig(display);
        context = createEGLContext(display, config);
        surface = createEGLSurface(display, config, context);
        generateTextures(textureIdHolder);
        texture = new SurfaceTexture(textureIdHolder[0]);
    }

    /**
     * Releases OpenGL resources.
     */
    public void release() {
        try {
            if (texture != null) {
                texture.release();
                GLES30.glDeleteTextures(1, textureIdHolder, 0);
            }
        } finally {
            if (display != null && !display.equals(EGL14.EGL_NO_DISPLAY)) {
                EGL14.eglMakeCurrent(
                        display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT);
            }
            if (surface != null && !surface.equals(EGL14.EGL_NO_SURFACE)) {
                EGL14.eglDestroySurface(display, surface);
            }
            if (context != null) {
                EGL14.eglDestroyContext(display, context);
            }
            EGL14.eglReleaseThread();
            if (display != null && !display.equals(EGL14.EGL_NO_DISPLAY)) {
                // Android is unusual in that it uses a reference-counted EGLDisplay.  So for
                // every eglInitialize() we need an eglTerminate().
                EGL14.eglTerminate(display);
            }
            display = null;
            context = null;
            surface = null;
            texture = null;
        }
    }

    /**
     * @return {@link SurfaceTexture} created by {@link #init()}.
     */
    public SurfaceTexture getSurfaceTexture() {
        return texture;
    }

    private static EGLDisplay getDefaultDisplay() {
        EGLDisplay display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY);
        if (display == null) {
            throw new RuntimeException("eglGetDisplay failed");
        }

        int[] version = new int[2];
        boolean eglInitialized = EGL14.eglInitialize(
                display, version, 0, version,1);
        if (!eglInitialized) {
            throw new RuntimeException("eglInitialize failed");
        }
        return display;
    }

    private static EGLConfig chooseEGLConfig(EGLDisplay display) {
        EGLConfig[] configs = new EGLConfig[1];
        int[] configsCount = new int[1];
        boolean isSuccess = EGL14.eglChooseConfig(
                display, EGL_CONFIG_ATTRIBUTES, 0, configs, 0, 1, configsCount, 0);
        if (!(isSuccess && configsCount[0] > 0 && configs[0] != null)) {
            throw new RuntimeException("eglChooseConfig failed");
        }

        return configs[0];
    }

    private static EGLContext createEGLContext(EGLDisplay display, EGLConfig config) {
        int[] attributes;
        attributes = new int[] {EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE};
        EGLContext context = EGL14.eglCreateContext(
                display, config, EGL14.EGL_NO_CONTEXT, attributes, 0);
        if (context == null) {
            throw new RuntimeException("eglCreateContext failed");
        }
        return context;
    }

    private static EGLSurface createEGLSurface(
            EGLDisplay display, EGLConfig config, EGLContext context) {
        int[] attributes = new int[] {
                EGL14.EGL_WIDTH,
                DEFAULT_SURFACE_WIDTH,
                EGL14.EGL_HEIGHT,
                DEFAULT_SURFACE_HEIGHT,
                EGL14.EGL_NONE};
        EGLSurface surface = EGL14.eglCreatePbufferSurface(display, config, attributes, 0);
        if (surface == null) {
            throw new RuntimeException("eglCreatePbufferSurface failed");
        }
        if (!EGL14.eglMakeCurrent(display, surface, surface, context)) {
            throw new RuntimeException("eglMakeCurrent failed");
        }
        return surface;
    }

    private static void generateTextures(int[] textureIds) throws RuntimeException {
        GLES30.glGenTextures(1, textureIds, 0);
        throwOnGlError();
    }

    private static void throwOnGlError() throws RuntimeException {
        StringBuilder errorMessage = new StringBuilder();
        boolean isErrorFound = false;
        int error;
        while ((error = GLES30.glGetError()) != GLES30.GL_NO_ERROR) {
            if (isErrorFound) {
                errorMessage.append('\n');
            }
            errorMessage.append("OpenGL error: '").append(GLU.gluErrorString(error)).append('\'');
            isErrorFound = true;
        }
        if (isErrorFound) {
            throw new RuntimeException(errorMessage.toString());
        }
    }
}