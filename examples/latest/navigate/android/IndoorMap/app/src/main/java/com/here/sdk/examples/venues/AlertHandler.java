package com.here.sdk.examples.venues;

import android.app.Dialog;
import android.content.Context;
import android.graphics.Color;
import android.os.Bundle;
import android.view.View;
import android.view.Window;
import android.widget.ImageButton;
import android.widget.ImageView;
import android.widget.TextView;

import androidx.annotation.NonNull;

public class AlertHandler extends Dialog {
    ImageView cancle;
    TextView msg;
    String errorMsg;
    public AlertHandler(@NonNull Context context, String error) {
        super(context);
        errorMsg = error;
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        setContentView(R.layout.alert_layout);
        msg = findViewById(R.id.alertText);
        msg.setText(errorMsg);
        cancle = findViewById(R.id.alertCancle);
        //cancle.setBackgroundColor(Color.TRANSPARENT);
        cancle.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                dismiss();
            }
        });
    }
}
