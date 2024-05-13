package cn.qinqing.media_session;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import android.support.v4.media.session.MediaSessionCompat;
import android.util.Log;
import android.view.KeyEvent;
import android.content.Intent;

/** MediaSessionPlugin */
public class MediaSessionPlugin implements FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private MethodChannel channel;
  MediaSessionCompat mediaSession;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "media_session");
    mediaSession = new MediaSessionCompat(this, "tag");
    mediaSession.setCallback(new MediaSessionCompat.Callback() {
      @Override
      public boolean onMediaButtonEvent(Intent mediaButtonEvent) {
        KeyEvent keyEvent = (KeyEvent) mediaButtonEvent.getParcelableExtra(Intent.EXTRA_KEY_EVENT);
        if (keyEvent != null && keyEvent.getKeyCode() == KeyEvent.KEYCODE_MEDIA_NEXT) {
          // 在这里处理 KEYCODE_MEDIA_NEXT 事件
          Log.d("clickNext", "clickNext");
          return true;
        }
        return super.onMediaButtonEvent(mediaButtonEvent);
      }
    });
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    if (call.method.equals("getPlatformVersion")) {
      result.success("Android " + android.os.Build.VERSION.RELEASE);
    } else {
      result.notImplemented();
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
  }
}
