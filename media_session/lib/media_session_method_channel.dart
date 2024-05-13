import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'media_session_platform_interface.dart';

/// An implementation of [MediaSessionPlatform] that uses method channels.
class MethodChannelMediaSession extends MediaSessionPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('media_session');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
