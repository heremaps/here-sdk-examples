package com.here.sdk.examples.venues;

import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.RelativeLayout;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.here.sdk.venue.data.VenueInfo;

import java.util.List;

class VenueViewHolder extends RecyclerView.ViewHolder {

    public TextView venueName;
    public RelativeLayout relativeLayout;

    public VenueViewHolder(@NonNull View itemView) {
        super(itemView);
        venueName = itemView.findViewById(R.id.VenueName);
        relativeLayout = itemView.findViewById(R.id.VenueContainer);
    }
}
public class VenueAdapter extends RecyclerView.Adapter<VenueViewHolder> {

    private static final String TAG = VenueAdapter.class.getSimpleName();
    private Context context;
    private List<VenueInfo> items;
    private MainActivity mainActivity;

    public VenueAdapter(Context context, List<VenueInfo> items, MainActivity mainActivity) {
        this.context = context;
        this.items = items;
        this.mainActivity = mainActivity;
    }

    @NonNull
    @Override
    public VenueViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        return new VenueViewHolder(LayoutInflater.from(context).inflate(R.layout.venue_item, parent,false));
    }

    @Override
    public void onBindViewHolder(@NonNull VenueViewHolder holder, int position) {
        holder.venueName.setText(items.get(position).getVenueName());

        holder.relativeLayout.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                mainActivity.onVenueItemClicked(items.get(position));
            }
        });

    }

    @Override
    public int getItemCount() {
        return items.size();
    }
}
