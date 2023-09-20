package com.here.offscreenmap;

import android.widget.ImageView;

import com.here.sdk.mapview.MapScheme;

/**
 * A simple helper class that handles the logistics of asking for a new image of the map
 * and setting it on the ImageView when it's ready.
 */
class MapPanel {
    private ImageView imageView;
    private OffscreenMapRenderer mapRenderer;

    /**
     * @param imageView The image view used for showing generated image of the map.
     * @param mapScheme The map scheme to be used for initializing map scene.
     */
    MapPanel(ImageView imageView, MapScheme mapScheme) {
        this.imageView = imageView;
        mapRenderer = new OffscreenMapRenderer(imageView.getContext(), imageView.getWidth(), imageView.getHeight());
        // Load a scene and show initial map.
        mapRenderer.generateMapImage(map -> map.getMapScene().loadScene(mapScheme, null), image -> {
            imageView.setImageBitmap(image);
        });
    }

    /**
     * Generates a new image of the map at a random zoom level and sets it to the image view.
     */
    public void redraw() {
        mapRenderer.generateMapImage(map -> {
            map.getCamera().zoomTo(1.0 + Math.random() * 19);
        }, image -> imageView.setImageBitmap(image));
    }

    /**
     * Resumes underlying map renderer. Needs to be called from {@code onResume()}
     * of the {@code Activity}.
     */
    public void onResume() {
        mapRenderer.onResume();
    }

    /**
     * Pauses underlying map renderer. Needs to be called from {@code onPause()}
     * of the {@code Activity}.
     */
    public void onPause() {
        mapRenderer.onPause();
    }

    /**
     * Destroys underlying map renderer. Needs to be called from {@code onDestroy()}
     * of the {@code Activity}.
     */
    public void onDestroy() {
        mapRenderer.onDestroy();
    }
}
