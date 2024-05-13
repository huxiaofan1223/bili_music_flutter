package com.alt.flutter_mp3_finder;

import com.google.gson.annotations.SerializedName;
import java.util.List;

public class DataModel {
    @SerializedName("Mp3Files")
    private List<Mp3DataModel> mp3Files;

    public List<Mp3DataModel> getFiles() {
        return mp3Files;
    }

    public void setFiles(List<Mp3DataModel> files) {
        this.mp3Files = files;
    }
}
