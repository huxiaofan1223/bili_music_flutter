
import 'media_session_platform_interface.dart';

class MediaSession {
  Future<String?> getPlatformVersion() {
    return MediaSessionPlatform.instance.getPlatformVersion();
  }
}
