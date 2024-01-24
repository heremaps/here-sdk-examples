/*
 * Copyright (C) 2023-2024 HERE Europe B.V.
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

package com.here.hellomapsurface;

import android.content.Context;
import android.os.Bundle;
import android.util.Log;
import android.view.SurfaceHolder;
import android.view.SurfaceView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;

import com.here.hellomapsurface.PermissionsRequestor.ResultListener;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.engine.SDKNativeEngine;
import com.here.sdk.core.engine.SDKOptions;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.mapview.MapError;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapScene;
import com.here.sdk.mapview.MapScheme;
import com.here.sdk.mapview.MapSurface;
import com.here.sdk.mapview.MapView;
import com.here.sdk.mapview.MapViewOptions;

import android.opengl.GLES31;
import java.nio.ByteBuffer;
import java.nio.FloatBuffer;
import java.nio.ByteOrder;
import java.nio.ShortBuffer;

public class MainActivity extends AppCompatActivity implements SurfaceHolder.Callback2 {

    private static final String TAG = MainActivity.class.getSimpleName();
    private PermissionsRequestor permissionsRequestor;
    private SurfaceView surfaceView;
    private MapSurface mapSurface;
    private boolean hasSurface = false;
    private boolean hasPermissions = false;

    // A listener for MapSurface render events that allows injecting custom render commands on top
    // of the current frame.
    // Two triangles are being rendered over the map, placed at the bottom center of it.
    private class RenderListener implements MapSurface.RenderListener {
        private boolean areTriaglesInitialized = false;
        private int mProgram;

        // Find more on OpenGL ES and the Android Graphics Shading Language here:
        // https://developer.android.com/develop/ui/views/graphics/agsl
        private final String vertexShaderCode =
                "attribute vec4 vPosition;" +
                        "void main() {" +
                        "  gl_Position = vPosition;" +
                        "}";

        private final String fragmentShaderCode =
                "precision mediump float;" +
                        "uniform vec4 vColor;" +
                        "void main() {" +
                        "  gl_FragColor = vColor;" +
                        "}";

        private int positionHandle;
        private int colorHandle;

        // Number of coordinates per vertex in this array.
        final int COORDS_PER_VERTEX = 3;
        // The normalized x,y,z screen coordinates relative to the viewport.
        // Note that the origin of the coordinate system is at the center of the screen.
        final float triangleCoords[] = {
                0.1f, -0.8f, 0.0f,   // top right
                0.1f, -0.9f, 0.0f,  // bottom right
                -0.1f, -0.9f, 0.0f, // bottom left
                -0.1f, -0.8f, 0.0f   // top left
        };

        final short indices[] = {
                0, 3, 1, // first Triangle
                3, 2, 1  // second Triangle
        };

        // Set color with red, green, blue and alpha (opacity) values.
        float color[] = { 1f, 0.1f, 0.0f, 0.7f };

        private final int vertexCount = triangleCoords.length / COORDS_PER_VERTEX;
        private final int vertexStride = COORDS_PER_VERTEX * 4; // 4 bytes per vertex

        private int[] vertexArrayObjectBuffers = new int[3];

        @Override
        public void onFramePrepared(){
            // A frame was prepared. We can inject custom render commands on top of it.
            drawTriangles();
        }

        @Override
        public void onRenderTargetReleased() {
            // Release all used graphics resources.

            if (!areTriaglesInitialized) {
                return;
            }

            GLES31.glDeleteVertexArrays(1, vertexArrayObjectBuffers, 0);
            vertexArrayObjectBuffers[0] = 0;
            GLES31.glDeleteBuffers(2, vertexArrayObjectBuffers, 1);
            vertexArrayObjectBuffers[1] = 0;
            vertexArrayObjectBuffers[2] = 0;
            GLES31.glDeleteProgram(mProgram);
            mProgram = 0;

            areTriaglesInitialized = false;
        }

        private void drawTriangles() {
            if (!areTriaglesInitialized) {
                // Compile shaders into a program
                int vShader = GLES31.glCreateShader(GLES31.GL_VERTEX_SHADER);
                GLES31.glShaderSource(vShader, vertexShaderCode);
                GLES31.glCompileShader(vShader);

                int fShader = GLES31.glCreateShader(GLES31.GL_FRAGMENT_SHADER);
                GLES31.glShaderSource(fShader, fragmentShaderCode);
                GLES31.glCompileShader(fShader);

                mProgram = GLES31.glCreateProgram();
                GLES31.glAttachShader(mProgram, vShader);
                GLES31.glAttachShader(mProgram, fShader);
                GLES31.glLinkProgram(mProgram);

                GLES31.glUseProgram(mProgram);

                // Create and initialize vertex objects
                GLES31.glGenVertexArrays(1, vertexArrayObjectBuffers, 0);
                GLES31.glGenBuffers(2, vertexArrayObjectBuffers, 1);
                GLES31.glBindVertexArray(vertexArrayObjectBuffers[0]);

                // Vertices
                GLES31.glBindBuffer(GLES31.GL_ARRAY_BUFFER, vertexArrayObjectBuffers[1]);
                ByteBuffer bb = ByteBuffer.allocateDirect(triangleCoords.length * 4);
                bb.order(ByteOrder.nativeOrder());
                FloatBuffer vertexBuffer = bb.asFloatBuffer();
                vertexBuffer.put(triangleCoords);
                vertexBuffer.position(0);
                GLES31.glBufferData(GLES31.GL_ARRAY_BUFFER, triangleCoords.length * 4, vertexBuffer, GLES31.GL_STATIC_DRAW);

                // Indices
                GLES31.glBindBuffer(GLES31.GL_ELEMENT_ARRAY_BUFFER, vertexArrayObjectBuffers[2]);
                ByteBuffer dlb = ByteBuffer.allocateDirect(indices.length * 2);
                dlb.order(ByteOrder.nativeOrder());
                ShortBuffer indicesBuffer = dlb.asShortBuffer();
                indicesBuffer.put(indices);
                indicesBuffer.position(0);
                GLES31.glBufferData(GLES31.GL_ELEMENT_ARRAY_BUFFER, indices.length * 2, indicesBuffer, GLES31.GL_STATIC_DRAW);

                // Assign shader attributes
                // - position
                positionHandle = GLES31.glGetAttribLocation(mProgram, "vPosition");
                GLES31.glEnableVertexAttribArray(positionHandle);
                vertexBuffer.position(0);
                GLES31.glVertexAttribPointer(positionHandle, COORDS_PER_VERTEX,
                        GLES31.GL_FLOAT, false,
                        vertexStride, 0);
                GLES31.glEnableVertexAttribArray(0);
                GLES31.glBindBuffer(GLES31.GL_ARRAY_BUFFER, 0);
                GLES31.glBindVertexArray(0);

                // - color
                colorHandle = GLES31.glGetUniformLocation(mProgram, "vColor");
                GLES31.glUniform4fv(colorHandle, 1, color, 0);

                areTriaglesInitialized = true;
            }

            // Draw vertices.
            GLES31.glUseProgram(mProgram);
            GLES31.glBindVertexArray(vertexArrayObjectBuffers[0]);
            GLES31.glDrawElements(GLES31.GL_TRIANGLES, indices.length,
                    GLES31.GL_UNSIGNED_SHORT, 0);
            GLES31.glBindVertexArray(0);
            GLES31.glUseProgram(0);
        }
    } // RenderListener

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
        initializeHERESDK();

        // Get a MapView instance from layout.
        MapViewOptions options = new MapViewOptions();
        options.initialBackgroundColor = new com.here.sdk.core.Color(1.0f, 1.0f, 1.0f, 1.0f);
        mapSurface = new MapSurface(getApplicationContext(), options);

        mapSurface.setOnReadyListener(new MapView.OnReadyListener() {
            @Override
            public void onMapViewReady() {
                // This will be called each time after this activity is resumed.
                // It will not be called before the first map scene was loaded.
                // Any code that requires map data may not work as expected until this event is received.
                Log.d(TAG, "HERE Rendering Engine attached.");
            }
        });

        surfaceView = new SurfaceView(getApplicationContext());
        surfaceView.getHolder().addCallback(this);

        setContentView(surfaceView);
        handleAndroidPermissions();
    }

    private void initializeHERESDK() {
        // Set your credentials for the HERE SDK.
        String accessKeyID = "YOUR_ACCESS_KEY_ID";
        String accessKeySecret = "YOUR_ACCESS_KEY_SECRET";
        SDKOptions options = new SDKOptions(accessKeyID, accessKeySecret);
        try {
            Context context = this;
            SDKNativeEngine.makeSharedInstance(context, options);
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of HERE SDK failed: " + e.error.name());
        }
    }

    private void handleAndroidPermissions() {
        permissionsRequestor = new PermissionsRequestor(this);
        permissionsRequestor.request(new ResultListener(){

            @Override
            public void permissionsGranted() {
                hasPermissions = true;
                loadMapScene();
            }

            @Override
            public void permissionsDenied() {
                Log.e(TAG, "Permissions denied by user.");
            }
        });
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        permissionsRequestor.onRequestPermissionsResult(requestCode, grantResults);
    }

    private void loadMapScene() {
        if (!hasSurface || !hasPermissions) {
            return;
        }
        double distanceInMeters = 1000 * 10;
        MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE, distanceInMeters);
        mapSurface.getCamera().lookAt(new GeoCoordinates(52.530932, 13.384915), mapMeasureZoom);

        // Load a scene from the HERE SDK to render the map with a map scheme.
        mapSurface.getMapScene().loadScene(MapScheme.NORMAL_DAY, new MapScene.LoadSceneCallback() {
            @Override
            public void onLoadScene(@Nullable MapError mapError) {
                if (mapError != null) {
                    Log.d(TAG, "Loading map failed: mapError: " + mapError.name());
                }
            }
        });
    }

    @Override
    public void surfaceRedrawNeeded(@NonNull SurfaceHolder holder) {
        // Not implemented
    }

    @Override
    public void surfaceRedrawNeededAsync(@NonNull SurfaceHolder holder, @NonNull Runnable drawingFinished) {
        if (!hasSurface) {
            if (drawingFinished != null) {
                drawingFinished.run();
            }
        } else {
            mapSurface.redraw(drawingFinished);
        }
    }

    @Override
    public void surfaceCreated(@NonNull SurfaceHolder holder) {
        mapSurface.setSurface(getApplicationContext(),
                holder.getSurface(), holder.getSurfaceFrame().width(), holder.getSurfaceFrame().height(),
                new RenderListener());
        hasSurface = true;
        loadMapScene();
    }

    @Override
    public void surfaceChanged(@NonNull SurfaceHolder holder, int format, int width, int height) {
        mapSurface.setSurface(getApplicationContext(), holder.getSurface(), width, height, new RenderListener());
        hasSurface = true;
    }

    @Override
    public void surfaceDestroyed(@NonNull SurfaceHolder holder) {
        mapSurface.destroySurface();
        hasSurface = false;
    }

    @Override
    protected void onPause() {
        mapSurface.onPause();
        super.onPause();
    }

    @Override
    protected void onResume() {
        mapSurface.onResume();
        super.onResume();
    }

    @Override
    protected void onDestroy() {
        mapSurface.destroy();
        disposeHERESDK();
        super.onDestroy();
    }

    @Override
    protected void onSaveInstanceState(@NonNull Bundle outState) {
        super.onSaveInstanceState(outState);
    }

    private void disposeHERESDK() {
        // Free HERE SDK resources before the application shuts down.
        // Usually, this should be called only on application termination.
        // Afterwards, the HERE SDK is no longer usable unless it is initialized again.
        SDKNativeEngine sdkNativeEngine = SDKNativeEngine.getSharedInstance();
        if (sdkNativeEngine != null) {
            sdkNativeEngine.dispose();
            // For safety reasons, we explicitly set the shared instance to null to avoid situations,
            // where a disposed instance is accidentally reused.
            SDKNativeEngine.setSharedInstance(null);
        }
    }
}
