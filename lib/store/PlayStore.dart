import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_mp3_finder/flutter_mp3_finder.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'dart:core';
import 'package:just_audio/just_audio.dart';
import 'package:fluttertoast/fluttertoast.dart';

final String USER_AGENT =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

class PlayStore with ChangeNotifier, DiagnosticableTreeMixin {
  static final PlayStore _instance = PlayStore._internal();
  bool _isDarkMode = true;

  bool get isDarkMode => _isDarkMode;

  String _cookie = '';
  String get cookie => _cookie;
  void setCookie(val){
    _cookie = val;
    saveMusicList2Storage();
    notifyListeners();
  }

  bool _isLogin = false;
  bool get isLogin => _isLogin;
  void setLogin(val){
    _isLogin = val;
    notifyListeners();
  }
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    saveMusicList2Storage();
    notifyListeners();
  }
  factory PlayStore() {
    return _instance;
  }
  PlayStore._internal(){
    log('playStore已经被创建');
  }

  int _current = 0;
  var _musicList = [];
  bool _playStatus = false;
  var _audioPlayer = null;
  String _duration = '';
  String _position = '';
  double _progress = 0;
  bool _isShuffle = false;

  int get current => _current;

  List get musicList => _musicList;

  bool get playStatus => _playStatus;

  dynamic get audioPlayer => _audioPlayer;

  String get duration => _duration;

  String get position => _position;

  double get progress => _progress;

  bool get isShuffle => _isShuffle;

  int getRandomNumberBetween0AndN(int n, int notVal) {
    math.Random random = new math.Random();
    int randomNumber = random.nextInt(n);
    while (randomNumber < 0 && randomNumber == notVal) {
      randomNumber = random.nextInt(n);
    }
    return randomNumber;
  }

  void playShuffle() {
    log('printShuffle');
    _current = getRandomNumberBetween0AndN(_musicList.length, current);
    playOrPause(true, changeFlag: true);
    notifyListeners();
  }

  void playPrev() {
    log('printPrev');
    if (isShuffle) {
      playShuffle();
      return;
    }
    if (_current > 0) {
      _current--;
    } else {
      _current = _musicList.length - 1;
    }
    playOrPause(true, changeFlag: true);
    notifyListeners();
  }

  void playNext() {
    log('printNext');
    if (isShuffle) {
      playShuffle();
      return;
    }
    if (_current == _musicList.length - 1) {
      _current = 0;
    } else {
      _current++;
    }
    print("printNextCurrent $_current");
    playOrPause(true, changeFlag: true);
    notifyListeners();
  }
  Future<String> getProxyUrlByBid(bvid) async {
    var bUrl = await _getAudioUrl(bvid);
    var proxyUrl = 'http://localhost:8888/?url=${ base64.encode(utf8.encode(bUrl))}&bvid=${bvid}';
    return proxyUrl;
  }

  String? _getHostFromUrl(String url){
    RegExp regex = RegExp(r'(?<=\/\/).*?(?=\/)');
    Match match = regex.firstMatch(url) as Match;
    if (match != null) {
      String? host = match.group(0);
      return host;
    } else {
      return "";
    }
  }
  //获取新的url和文件大小
  Future<Object> getFileSize(String bvid) async {
    var newUrl = await _getAudioUrl(bvid);
    log("newUrl:$newUrl");
    var Host = _getHostFromUrl(newUrl);
    Map<String, dynamic> headers = {
      'Referer': 'https://www.bilibili.com',
      'User-Agent': USER_AGENT,
      'Host':Host,
      'Range':"bytes=0-5"
    };
    Map<String, dynamic> myMap = {};
    log('请求文件大小');
    Dio dio = Dio();
    dio.options.headers.addAll(headers);

    try {
      // 发起 GET 请求
      Response response = await dio.get(
        newUrl,
        options: Options(
          headers:headers,
          responseType: ResponseType.bytes, // 设置响应类型为字节流，以便手动读取响应体
        ),
      );

      dio.interceptors.clear();
      myMap['size'] = int.parse(response.headers.value('Content-Range')!.split("/")[1]);
      myMap['url'] = newUrl;
      return myMap;
    } catch (e) {
      print('Error: $e');
      return myMap;
    }
  }
  Future<bool> hasDownloadFile(String bvid) async {
    final Directory tempDir = await getTemporaryDirectory();
    final String tempPath = tempDir.path;
    final String fileName = "$bvid.m4s";
    final String filePath = path.join(tempPath,fileName);
    log(filePath);
    var ele = _musicList.firstWhere((item) => item['bvid']  == bvid, orElse: () => null);
    if(ele['fileSize']!=null){
      if(File(filePath).existsSync() && File(filePath).lengthSync() == ele['fileSize']){
        print('文件存在,请求过大小并且文件大小一致');
        return true;
      }
    }
    if(!isLogin){
      Fluttertoast.showToast(
          msg: "请前往设置界面登录",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.grey,
          textColor: Colors.white,
          fontSize: 16.0
      );
    }
    dynamic remoteFileSizeObj = await getFileSize(bvid);
    print('remoteFIleSize:${remoteFileSizeObj['size']}');
    ele['fileSize'] = remoteFileSizeObj['size'];
    saveMusicList2Storage();
    if(File(filePath).existsSync()){
      print("文件存在");
      print('localFIleSize:${File(filePath).lengthSync()}');
      if(File(filePath).lengthSync() == remoteFileSizeObj['size']){
        return true;
      } else{
        print("但是文件大小不对,需要重新下载");
      }
    }
    print('文件不存在并且需要下载');
    return false;
  }

  Future<File> downloadFile(String bvid) async {
    final Directory tempDir = await getTemporaryDirectory();
    final String tempPath = tempDir.path;
    final String fileName = "$bvid.m4s";
    // 构建完整的文件路径
    final String filePath = path.join(tempPath,fileName);
    log(filePath);
    // var idx = _musicList.indexOf((item){
    //   return item['bvid'] == bvid;
    // });
    var ele = _musicList.firstWhere((item) => item['bvid']  == bvid, orElse: () => null);
    if(ele['fileSize']!=null){
      if(File(filePath).existsSync() && File(filePath).lengthSync() == ele['fileSize']){
        print('文件存在,请求过大小并且文件大小一致');
        return File(filePath);
      }
    }
    if(!isLogin){
      Fluttertoast.showToast(
          msg: "请前往设置界面登录",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.grey,
          textColor: Colors.white,
          fontSize: 16.0
      );
    }
    dynamic remoteFileSizeObj = await getFileSize(bvid);
    log('remoteFIleSize:${remoteFileSizeObj['size']}');
    ele['fileSize'] = remoteFileSizeObj['size'];
    saveMusicList2Storage();
    if(File(filePath).existsSync()){
      print("文件存在");
      log('localFIleSize:${File(filePath).lengthSync()}');
      if(File(filePath).lengthSync() == remoteFileSizeObj['size']){
        return File(filePath);
      } else{
        print("但是文件大小不对,需要重新下载");
      }
    }
    print('文件不存在,正在下载');

    final Dio dio = Dio();
    try{
      var Host2 = _getHostFromUrl(remoteFileSizeObj['url']);
      Map<String, dynamic> headers2 = {
        'Referer': 'https://www.bilibili.com',
        'User-Agent': USER_AGENT,
        'Host':Host2
      };
      final Response response = await dio.download(remoteFileSizeObj['url'], filePath, options: Options(headers: headers2));
    }on DioError catch (e) {
      print('Download failed with DioError: $e');
    } catch (e) {
      print('Download failed with error: $e');
    }

    return File(filePath);
  }

  void playLocalOrRemote(String path, {isUsedCache = false,bvid=null,fileSize=null}) async {
    final debouncedPlayNext = debounce(() => playNext(), Duration(milliseconds: 500));
    log('playLocalOrRemote');
    final isLocal = !path.startsWith('http');
    await _audioPlayer?.stop();
    _audioPlayer = new AudioPlayer();
    if(bvid != null){
      var hasD = await hasDownloadFile(bvid);
      if(hasD){
        File downloadedFile = await downloadFile(bvid);
        await _audioPlayer.setFilePath(downloadedFile.path);
      } else {
        var url = await getProxyUrlByBid(bvid);
        print('url:$url');
        await _audioPlayer.setUrl(url);
        Future.delayed(const Duration(milliseconds: 100), () async {
          downloadFile(bvid);
        });
      }
    } else {
      await _audioPlayer.setFilePath(path);
    }
    log("_audioPlayer.duration:${_audioPlayer.duration}");
    _playStatus = true;
    Future.delayed(const Duration(milliseconds: 100), () async {
      _audioPlayer.play();
    });
    RegExp exp = RegExp(r"^0:", multiLine: true, caseSensitive: false);
    _audioPlayer.durationStream.listen((state) {
      String d = state.toString().split('.')[0].replaceFirst(exp, '');
      setDuration(d);
    });
    _audioPlayer.positionStream.listen((state) {
      String p = state.toString().split('.')[0].replaceFirst(exp, '');
      // log("position:$p,duration:$duration");
      if(p.isNotEmpty && duration.isNotEmpty && p == duration){
        debouncedPlayNext();
      }
      setPosition(state.toString().split('.')[0].replaceFirst(exp, ''));
    });
    notifyListeners();
  }
  Function debounce(Function function, Duration duration) {
    Timer? timer;
    bool isExecuting = false;

    return () {
      if (timer != null && timer!.isActive) {
        timer!.cancel();
      }

      if (!isExecuting) {
        function();
        isExecuting = true;
      }

      timer = Timer(duration, () {
        isExecuting = false;
      });
    };
  }

  Future<String> _getAudioUrl(String bid) async {
    const String url = "https://api.bilibili.com/x/web-interface/view";
    final cidResponse = await http.get(Uri.parse('$url?bvid=$bid'), headers: {
      'user-agent': USER_AGENT,
      'cookie': cookie,
    });

    final cidJson = jsonDecode(cidResponse.body);
    // log(cidJson.toString());
    final String cid = cidJson['data']['cid'].toString();

    const String url2 = "https://api.bilibili.com/x/player/wbi/playurl";
    final response = await http.get(
        Uri.parse('$url2?bvid=$bid&qn=80&cid=$cid&fnval=16'),
        headers: {'user-agent': USER_AGENT, 'cookie': cookie});

    final jsonResult = jsonDecode(response.body);
    // log(jsonResult.toString());
    if (jsonResult['code'] == 0) {
      return jsonResult['data']['dash']['audio'][0]['base_url'];
    } else {
      return '';
    }
  }

  String _int2String(int val) {
    int seconds = (val / 1000).toInt();
    int minutes = (seconds / 60).toInt();
    int remainingSeconds = seconds % 60;
    String formattedMinutes = minutes.toString().padLeft(2, '0');
    String formattedSeconds = remainingSeconds.toString().padLeft(2, '0');
    return '${formattedMinutes}:${formattedSeconds}';
  }

  void playOrPause(bool playFlag, {bool changeFlag = false}) async {
    print('playMusicIndex $_current');
    saveMusicList2Storage();
    log('playOrPause hashCode:${audioPlayer.hashCode}');
    var musicUrl = _musicList[_current]['path'];
    var bvid = _musicList[_current]['bvid'];
    log('playStatus $playFlag');
    log('changeFlag $changeFlag');
    if(playFlag){
      _playStatus = true;
      if(changeFlag){
        playLocalOrRemote(musicUrl,bvid: bvid);
      } else {
        try {
          log("tryResume");
          if(_audioPlayer==null){
            playLocalOrRemote(musicUrl,bvid: bvid);
          } else {
            if(_audioPlayer!=null && _audioPlayer.playing){
              _audioPlayer.pause();
            } else {
              _audioPlayer.play();
            }
          }
        }catch(e){
          log('resumeError'+e.toString());
        }
      }
    } else {
      _playStatus = false;
      _audioPlayer.pause();
    }
    notifyListeners();
  }

  void appendMusic(dynamic music) async {
    final tempIds = _musicList.map((item) => item['id']).toList();
    if (tempIds.contains(music['id'])) {
      final current = tempIds.indexOf(music['id']);
      _current = current;
      playOrPause(true, changeFlag: true);
      return;
    }
    // log(music.toString());
    _musicList.insert(0, music);
    _current = 0;
    playOrPause(true, changeFlag: true);
    _playStatus = true;

    saveMusicList2Storage();

    notifyListeners();
  }

  void playCurrentMusic(int currentVal) async {
    // print('clickCurrent $currentVal');
    final isCurrent = _current == currentVal;
    final playFlag = isCurrent ? !_playStatus : true;
    _current = currentVal;
    playOrPause(playFlag, changeFlag: !isCurrent);
    notifyListeners();
  }

  Future<void> getMp3sData() async {
    print('startGetMusicList');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _musicList = json.decode((prefs.getString('musicList') ?? '[]'));
    //   var mp3String = await FlutterMp3Finder.scanDeviceForMp3Files;
    //   var _tempList = json.decode(mp3String);
    //   log(_tempList.toString());
    try {
      var mp3String = await FlutterMp3Finder.scanDeviceForMp3Files;
      var _tempList = json.decode(mp3String)['Mp3Files'];
      _tempList.forEach((item) {
        item['isLocal'] = true;
        var arr = item['displayName'].split('.');
        if (arr.length != 1) {
          item['displayName'] = arr[0];
        }
        item['title'] = item['displayName'];
        item['duration'] = _int2String(int.parse(item['duration']));
      });

      _musicList.removeWhere((item){
        if (item['isLocal']) {
          return true;
        }
        return false;
      });  //删除本地音乐再重新添加
      _musicList.addAll(_tempList);

      saveMusicList2Storage();
    } on Exception catch (e) {
      print('getMusicListError');
      print(e);
    }
    print('endGetMusicList');
    notifyListeners();
  }

  int bool2Int(bool flag) {
    return flag ? 1 : 0;
  }

  void setCurrent(int num) {
    _current = num;
    notifyListeners();
  }

  void setPlayStatus(bool b) {
    _playStatus = b;
    notifyListeners();
  }

  void setDuration(String duration) {
    _duration = duration;
    notifyListeners();
  }

  void setPosition(String position) {
    _position = position;
    notifyListeners();
  }

  void setProgress(double progress) {
    _progress = progress;
    notifyListeners();
  }

  void setMusicList(String listString) {
    _musicList = json.decode(listString);
    notifyListeners();
  }

  void setShuffle() {
    _isShuffle = !_isShuffle;
    saveMusicList2Storage();
    notifyListeners();
  }

  void setShuffleVal(val) {
    _isShuffle = val;
    notifyListeners();
  }

  Future<void> removeMusic(idx) async {
    if(idx==current){
      _musicList.removeAt(idx);
      playOrPause(true,changeFlag: true);
    } else if(idx<current){
      _current -= 1;
      _musicList.removeAt(idx);
    } else {
      _musicList.removeAt(idx);
    }

    saveMusicList2Storage();
    notifyListeners();
  }

  Future<void> saveMusicList2Storage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('musicList', json.encode(_musicList));
    await prefs.setString('cookie', cookie);
    await prefs.setBool('isShuffle', isShuffle);
    await prefs.setBool('isDarkMode', isDarkMode);
    await prefs.setInt('current', current);
  }
  void setDarkMode(val){
    _isDarkMode = val;
    notifyListeners();
  }

  Future<dynamic> getUserInfo() async{
    const String url = "https://api.bilibili.com/x/web-interface/nav";
    final res = await http.get(Uri.parse('$url'), headers: {
      'user-agent': USER_AGENT,
      'cookie':cookie
    });
    final result = jsonDecode(res.body);
    // print({result:result});
    if (result['code'] == 0) {
      setLogin(true);
    } else {
      setLogin(false);
    }
  }

  Map<String, dynamic> getMusicByIndex(int index) {
    return musicList[index];
  }
}
