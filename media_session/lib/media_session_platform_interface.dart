import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'media_session_method_channel.dart';

abstract class MediaSessionPlatform extends PlatformInterface {
  /// Constructs a MediaSessionPlatform.
  MediaSessionPlatform() : super(token: _token);

  static final Object _token = Object();

  static MediaSessionPlatform _instance = MethodChannelMediaSession();

  /// The default instance of [MediaSessionPlatform] to use.
  ///
  /// Defaults to [MethodChannelMediaSession].
  static MediaSessionPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [MediaSessionPlatform] when
  /// they register themselves.
  static set instance(MediaSessionPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
