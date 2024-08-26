package com.here.offlinemaps;

import android.util.Log;

import com.here.sdk.core.engine.LayerConfiguration;

import java.util.ArrayList;

public class LayerConfigurationExample {
    ArrayList<LayerConfiguration.Feature> features = new ArrayList<>();
    String TAG = LayerConfigurationExample.class.getSimpleName();

    public LayerConfigurationExample() {
        prepareFeatures();
    }

    public LayerConfiguration getCustomLayerConfiguration() {
        LayerConfiguration layerConfiguration = new LayerConfiguration();
        layerConfiguration.enabledFeatures = features;
        return layerConfiguration;
    }

    private void prepareFeatures() {
        // These features are enabled by default.
        // We specify these features as part of the layer configuration to ensure that they are included in the feature list and enabled.
        // For example, if the feature list contains navigation and TRUCK, then it enables only navigation and truck features and disables all others.
        features.add(LayerConfiguration.Feature.NAVIGATION);
        features.add(LayerConfiguration.Feature.DETAIL_RENDERING);
        features.add(LayerConfiguration.Feature.RENDERING);
        features.add(LayerConfiguration.Feature.TRUCK);
        features.add(LayerConfiguration.Feature.OFFLINE_SEARCH);
        features.add(LayerConfiguration.Feature.OFFLINE_ROUTING);

        // Enabling additional features.
        features.add(LayerConfiguration.Feature.LANDMARKS_3D);
        features.add(LayerConfiguration.Feature.TRAFFIC);
    }

    public void addFeature(LayerConfiguration.Feature feature) {
        features.add(feature);
    }

    public void disableFeature(LayerConfiguration.Feature feature) {
        features.remove(feature);
    }

    public void printCurrentFeatures() {
        Log.i(TAG, " Enabled Feature ");
        for (LayerConfiguration.Feature feature : features) {
            Log.i(TAG, " " + feature.name());
        }
    }
}
