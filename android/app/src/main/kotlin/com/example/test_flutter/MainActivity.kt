package com.example.bili_music
import io.flutter.plugins.GeneratedPluginRegistrant
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.support.v4.media.session.MediaSessionCompat
import android.util.Log
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngine
import android.content.Context
import android.content.pm.PackageManager

class MainActivity : FlutterActivity() {
    private final val CHANNEL = "com.example/mediaControl";
    private lateinit var mediaSession: MediaSessionCompat;
    lateinit var channel:MethodChannel;

    private fun sendKeyCodeToFlutter(keyCode: String) {
        channel.invokeMethod(
            "sendKeyCode",
            keyCode
        )
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        channel = MethodChannel(flutterEngine.dartExecutor, CHANNEL);
        mediaSession = MediaSessionCompat(this, "tag")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "restartApp" -> {
                    Log.d("restartApp","restartApp");
                    restartApp();
                    result.success(null)
                }
                "closeApp" -> {
                    Log.d("closeApp","closeApp");
                    android.os.Process.killProcess(android.os.Process.myPid())
                    System.exit(1)
                }
                else -> result.notImplemented()
            }
        }
        mediaSession.setCallback(object : MediaSessionCompat.Callback() {
            override fun onMediaButtonEvent(mediaButtonEvent: Intent): Boolean {
                val keyEvent: KeyEvent? = mediaButtonEvent.getParcelableExtra(Intent.EXTRA_KEY_EVENT)
                Log.d("callBack","callBack");
                Log.d("callBack","${keyEvent?.keyCode}");
                if (keyEvent?.keyCode == KeyEvent.KEYCODE_MEDIA_NEXT) {
                    sendKeyCodeToFlutter("next");
                    Log.d("clickNext","clickNext");
                    return true
                } else if(keyEvent?.keyCode == KeyEvent.KEYCODE_MEDIA_PREVIOUS){
                    sendKeyCodeToFlutter("prev");
                    return true
                } else if(keyEvent?.keyCode == KeyEvent.KEYCODE_MEDIA_PAUSE){
                    Log.d("click","pause");
                    sendKeyCodeToFlutter("pause");
                    return true
                }  else if(keyEvent?.keyCode == KeyEvent.KEYCODE_MEDIA_PLAY){
                    Log.d("click","play");
                    sendKeyCodeToFlutter("play");
                    return true
                } else if(keyEvent?.keyCode == KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE){
                    Log.d("click","toggle_play");
                    sendKeyCodeToFlutter("toggle_play");
                    return true
                }
                return super.onMediaButtonEvent(mediaButtonEvent)
            }
        })
        mediaSession.setActive(true)
        mediaSession.setFlags(MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS or MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS)
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine);
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }
    // 添加重启应用的方法
    fun Context.restartApp() {
        Log.d("restartApp2", "restartApp2");
        val intent = Intent(this, MainActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK or Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }
}