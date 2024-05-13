import 'package:flutter_test/flutter_test.dart';
import 'package:media_session/media_session.dart';
import 'package:media_session/media_session_platform_interface.dart';
import 'package:media_session/media_session_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMediaSessionPlatform
    with MockPlatformInterfaceMixin
    implements MediaSessionPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final MediaSessionPlatform initialPlatform = MediaSessionPlatform.instance;

  test('$MethodChannelMediaSession is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelMediaSession>());
  });

  test('getPlatformVersion', () async {
    MediaSession mediaSessionPlugin = MediaSession();
    MockMediaSessionPlatform fakePlatform = MockMediaSessionPlatform();
    MediaSessionPlatform.instance = fakePlatform;

    expect(await mediaSessionPlugin.getPlatformVersion(), '42');
  });
}
