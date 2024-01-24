package com.here.sdk.examples.venues;

import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.RelativeLayout;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.here.sdk.venue.data.VenueGeometry;
import com.here.sdk.venue.data.VenueInfo;

import java.util.List;

class SpaceViewHolder extends RecyclerView.ViewHolder{

    public TextView spaceName, spaceAddress;
    public RelativeLayout relativeLayout;
    public LinearLayout addressLayout;

    public SpaceViewHolder(@NonNull View itemView) {
        super(itemView);
        spaceName = itemView.findViewById(R.id.SpaceName);
        spaceAddress = itemView.findViewById(R.id.SpaceAddress);
        addressLayout = itemView.findViewById(R.id.AddressLayout);
        relativeLayout = itemView.findViewById(R.id.SpaceContainer);
    }
}

public class SpaceAdapter extends RecyclerView.Adapter<SpaceViewHolder> {

    private static final String TAG = SpaceAdapter.class.getSimpleName();
    private Context context;
    private List<VenueGeometry> items;
    private MainActivity mainActivity;

    public SpaceAdapter(Context context, List<VenueGeometry> items, MainActivity mainActivity){
        this.context = context;
        this.items = items;
        this.mainActivity = mainActivity;
    }
    @NonNull
    @Override
    public SpaceViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        return new SpaceViewHolder(LayoutInflater.from(context).inflate(R.layout.space_item, parent, false));
    }

    @Override
    public void onBindViewHolder(@NonNull SpaceViewHolder holder, int position) {
        String spaceName, spaceAddress;
        VenueGeometry geometry = items.get(position);
        spaceName = geometry.getName() + ", " + geometry.getLevel().getName();
        spaceAddress = geometry.getInternalAddress() != null? geometry.getInternalAddress().getAddress() : "";
        holder.spaceName.setText(spaceName);
        if(spaceAddress.isEmpty())
            holder.addressLayout.setVisibility(View.GONE);
        else
            holder.spaceAddress.setText(spaceAddress);
        holder.relativeLayout.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                mainActivity.onSpaceItemClicked(items.get(position));
            }
        });

    }

    @Override
    public int getItemCount() {
        return items.size();
    }
}
