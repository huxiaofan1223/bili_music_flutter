import 'dart:async';

import 'package:flutter/services.dart';

class FlutterMp3Finder {
  static const MethodChannel _channel =
      const MethodChannel('flutter_mp3_finder');

  static Future<String> get scanDeviceForMp3Files async {
    final String version = await _channel.invokeMethod('scanDeviceForMp3Files');
    return version;
  }
}
