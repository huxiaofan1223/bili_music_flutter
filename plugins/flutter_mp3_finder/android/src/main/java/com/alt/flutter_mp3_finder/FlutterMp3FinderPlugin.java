package com.alt.flutter_mp3_finder;

import android.Manifest;
import android.app.Activity;
import android.content.ContentResolver;
import android.content.ContentUris;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.provider.MediaStore;
import android.util.Base64;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;

import java.io.ByteArrayOutputStream;
import java.io.FileNotFoundException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.plugin.common.PluginRegistry.Registrar;

public class FlutterMp3FinderPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.RequestPermissionsResultListener {

    private MethodChannel channel;
    private Activity activity;
    private int myPermissionCode = 1;
    private boolean permissionGranted = false;
    private Result result;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        channel = new MethodChannel( flutterPluginBinding.getBinaryMessenger(),"flutter_mp3_finder");
        channel.setMethodCallHandler(this);
    }


    public static void registerWith(Registrar registrar) {
        final MethodChannel channel = new MethodChannel(registrar.messenger(), "flutter_mp3_finder");
        FlutterMp3FinderPlugin plugin = new FlutterMp3FinderPlugin();
        registrar.addRequestPermissionsResultListener(plugin);
        channel.setMethodCallHandler(plugin);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        this.result = result;
        if (call.method.equals("scanDeviceForMp3Files")) {
            checkPermission(activity);
            if (!permissionGranted) {
                ActivityCompat.requestPermissions(activity,
                        new String[]{Manifest.permission.READ_EXTERNAL_STORAGE},
                        myPermissionCode);
            } else {
                mp3Processmapper();
            }
        } else {
            result.notImplemented();
        }
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        activity = null;
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
        binding.addRequestPermissionsResultListener(this);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        activity = null;
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
        binding.addRequestPermissionsResultListener(this);

    }

    @Override
    public void onDetachedFromActivity() {

    }

    private String scanDeviceForMp3Files() {
        String selection = MediaStore.Audio.Media.IS_MUSIC + " != 0";
        Cursor cursor = null;
        List<Mp3DataModel> mp3DataList = new ArrayList<>();
        String jsonMp3List = "";

        String[] projection = {
                MediaStore.Audio.Media.DISPLAY_NAME,
                MediaStore.Audio.Media.ARTIST,
                MediaStore.Audio.Media.ALBUM,
                MediaStore.Audio.Media.DURATION,
                MediaStore.Audio.Media.SIZE,
                MediaStore.Audio.AudioColumns.DATA,
                MediaStore.Audio.Media.DATE_ADDED,
                MediaStore.Audio.Media.ALBUM_ID,
        };
        final String sortOrder = MediaStore.Audio.Media.DATE_ADDED + " COLLATE LOCALIZED DESC";

        try {
            Log.e("TAG", "------------>");
            Uri uri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI;
            cursor = activity.getContentResolver().query(uri, projection, selection, null, sortOrder);
            if (cursor != null) {
                cursor.moveToFirst();
                while (!cursor.isAfterLast()) {
                    Mp3DataModel data = new Mp3DataModel();
                    data.setDisplayName(cursor.getString(0));
                    data.setArtist(cursor.getString(1));
                    data.setAlbum(cursor.getString(2));
                    data.setDuration(cursor.getString(3));
                    data.setSize(cursor.getString(4));
                    data.setData(cursor.getString(5));
                    data.setDateAdded(cursor.getString(6));
                    String image = getImage(Long.parseLong(cursor.getString(cursor.getColumnIndex(MediaStore.Audio.Media.ALBUM_ID))));
                    data.setAlbumImage(image);
                    cursor.moveToNext();
                    mp3DataList.add(data);
                }
                Gson gson = new GsonBuilder().create();
                DataModel dataModel = new DataModel();
                dataModel.setFiles(mp3DataList);
                jsonMp3List = gson.toJson(dataModel);
            }

        } catch (Exception e) {
            Log.e("FlutterMp3FinderPlugin ", e.toString());
        } finally {
            if (cursor != null) {
                cursor.close();
            }
        }
        return jsonMp3List;
    }

    private void checkPermission(Activity context) {
        permissionGranted = ContextCompat.checkSelfPermission(context,
                Manifest.permission.READ_EXTERNAL_STORAGE) ==
                PackageManager.PERMISSION_GRANTED;
    }

    @Override
    public boolean onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        if (requestCode == 1 && grantResults.length > 0
                && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            mp3Processmapper();
            return true;
        } else {
            return false;
        }
    }

    private void mp3Processmapper() {
        String jsonStringMp3List = scanDeviceForMp3Files();
        if (jsonStringMp3List.isEmpty()) {
            result.error("Not mp3 find", "Not mp3 find or got error", null);
        } else result.success(jsonStringMp3List);
    }

    private String getImage(Long album_id) {
        Uri sArtworkUri = Uri.parse("content://media/external/audio/albumart");
        Uri uri = ContentUris.withAppendedId(sArtworkUri, album_id);
        ContentResolver res = activity.getContentResolver();
        InputStream in = null;
        try {
            in = res.openInputStream(uri);
        } catch (FileNotFoundException e) {
            e.printStackTrace();
        }
        if(in == null){
            return "";
        } else {
            Bitmap artwork = BitmapFactory.decodeStream(in);
            return getBase64Image(artwork);
        }
    }

    private String getBase64Image(Bitmap bitmap) {
        ByteArrayOutputStream byteArrayOutputStream = new ByteArrayOutputStream();
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, byteArrayOutputStream);
        byte[] byteArray = byteArrayOutputStream.toByteArray();
        return Base64.encodeToString(byteArray, Base64.NO_WRAP);
    }
}

