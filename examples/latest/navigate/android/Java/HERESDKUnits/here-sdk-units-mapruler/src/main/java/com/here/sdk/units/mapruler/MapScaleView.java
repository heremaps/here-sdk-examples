package com.here.sdk.units.mapruler;

import android.content.Context;
import android.util.AttributeSet;
import android.view.LayoutInflater;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.here.sdk.mapview.MapView;

public class MapScaleView extends LinearLayout {

    private MapScaleUnit mapScaleUnit;
    private TextView scaleText;

    public MapScaleView(Context context) {
        super(context);
        init(context);
    }

    public MapScaleView(Context context, AttributeSet attrs) {
        super(context, attrs);
        init(context);
    }

    public MapScaleView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        init(context);
    }

    private void init(Context context) {
        LayoutInflater.from(context).inflate(R.layout.heresdk_units_mapruler, this, true);
        scaleText = findViewById(R.id.scaleText);
    }

    public void setup(MapView mapView) {
        mapScaleUnit = new MapScaleUnit(mapView, scaleText);
    }
}
