import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:OnlineMusic/store/PlayStore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import './pages/search.dart';
import 'package:provider/provider.dart';
import './pages/list.dart';
import './pages/setting.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

final String USER_AGENT =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

Future<void> saveFileToDisk(String filePath, Stream<List<int>> stream) async {
  var file = File(filePath);
  var sink = file.openWrite();

  await for (var chunk in stream) {
    sink.add(chunk);
  }
  await sink.close();
}

Future<shelf.Response> handleRequest(shelf.Request request) async {
  // Extract URI and query parameters
  Uri uri = request.requestedUri;
  String queryParams = uri.query ?? '';

  String urlValue = '';
  String bvidValue = '';
  uri.queryParameters.forEach((key, value) {
    if (key == 'url') {
      urlValue = value ?? '';
    } else if(key == 'bvid') {
      bvidValue = value ?? '';
    }
  });
  String decodedUrl = utf8.decode(base64.decode(urlValue));
  log("decodedUrl:$decodedUrl");
  // Extract host from URL
  RegExp re = RegExp(r'(?:https?://)?([^/?#]+)');
  String host = '';
  Match? match = re.firstMatch(decodedUrl);
  if (match != null) {
    host = match.group(1) ?? '';
    host = host.replaceAll('https://', '');
    print('host: $host');
  }
  Uri targetUrl = Uri.parse(decodedUrl);

  var client = http.Client();
  var proxyRequest = http.Request(request.method, targetUrl);
  proxyRequest.headers.addAll(request.headers);
  proxyRequest.headers.addAll({
    'Referer': 'https://www.bilibili.com', // Replace with actual referer
    'User-Agent': USER_AGENT, // Replace with actual user agent
    'Host': host, // Replace with actual host
  });

  var streamedResponse = await client.send(proxyRequest);
  print('代理请求的头部信息: ${proxyRequest.headers}');
  print('目标服务器响应的头部信息: ${streamedResponse.headers}');

  //缓存到本地
  final Directory tempDir = await getTemporaryDirectory();
  final String tempPath = tempDir.path;
  final String fileName = "$bvidValue.m4s";
  final String filePath = path.join(tempPath,fileName);
  File file = File(filePath);

//   streamedResponse.stream.listen(
//         (data) {
//       // 将数据写入缓存文件
//       file.writeAsBytesSync(data, mode: FileMode.append);
//       // 将数据通过控制器发送给客户端
//       responseController.add(data);
//     },
//     onError: (error, stackTrace) {
//       // 发生错误时关闭文件流和控制器，并删除缓存文件
//       file.deleteSync();
//       responseController.close();
//     },
//     onDone: () async {
//       // 下载完成时关闭文件流和控制器
//       // await file.close();
//       responseController.close();
//     },
//   );
//
// // 返回代理请求的响应，使用自定义的控制器作为响应体
//   return shelf.Response(streamedResponse.statusCode, body: responseController.stream, headers: streamedResponse.headers);
// 返回代理请求的响应，包括文件的流和相应的头部信息
//   return shelf.Response(streamedResponse.statusCode, body: responseStream, headers: streamedResponse.headers);
  // await saveFileToDisk(filePath, streamedResponse.stream);
  //
  return shelf.Response(streamedResponse.statusCode, body: streamedResponse.stream, headers: streamedResponse.headers);
  // 创建一个流式的响应对象，并同时将文件保存到本地缓存
  // var responseStream = streamedResponse.stream.transform(
  //   StreamTransformer<List<int>, List<int>>.fromHandlers(
  //     handleData: (data, sink) async {
  //       await file.writeAsBytes(data, mode: FileMode.append);
  //       sink.add(data);
  //     },
  //     handleError: (error, stackTrace, sink) {
  //       // 发生错误时关闭文件流和sink
  //       file.deleteSync();
  //       sink.close();
  //     },
  //     handleDone: (sink) {
  //       sink.close();
  //     },
  //   ),
  // );

  // 返回代理请求的响应，包括文件的流和相应的头部信息
  // return shelf.Response(streamedResponse.statusCode, body: responseStream, headers: streamedResponse.headers);
}


Future<void> main() async {
  runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(
            value: PlayStore(), // 这里会返回PlayStore的单例实例
          ),
        ],
        child: MyApp()
      )
  );
  var handler = const shelf.Pipeline().addHandler(handleRequest);
  var server = await shelf_io.serve(handler, '0.0.0.0', 8888);
  print('Server listening on localhost:${server.port}');
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        textTheme: TextTheme(
          bodyText2: TextStyle(fontSize: 18), // 这里设置默认的字体大小为20
        ),
      ),
      themeMode: context.watch<PlayStore>().isDarkMode ? ThemeMode.dark : ThemeMode.light,
      darkTheme: ThemeData.dark().copyWith(
        textTheme: TextTheme(
          bodyText2: TextStyle(fontSize: 18), // 这里设置默认的字体大小为20
        ),
      ),
      home: MyTabPage(),
    );
  }
}

class MyTabPage extends StatefulWidget {
  @override
  _MyTabPageState createState() => _MyTabPageState();
}

class _MyTabPageState extends State<MyTabPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  var dplayNext;
  var dplayPrev;
  var dplay;
  var dpause;
  String _int2String(int val) {
    // 将毫秒转换为秒
    int seconds = val;

    // 将秒转换为分钟和剩余的秒
    int minutes = (seconds / 60).toInt();
    int remainingSeconds = seconds % 60;

    // 将分钟和秒格式化为两位数的字符串
    String formattedMinutes = minutes.toString().padLeft(2, '0');
    String formattedSeconds = remainingSeconds.toString().padLeft(2, '0');

    // 返回格式化的时间字符串
    return '${formattedMinutes}:${formattedSeconds}';
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

  @override
  void initState(){
    super.initState();
    Future.delayed(Duration(milliseconds: 0),() async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      context.read<PlayStore>().setCookie(prefs.getString('cookie')??'');
      context.read<PlayStore>().setShuffleVal(prefs.getBool('isShuffle')??false);
      context.read<PlayStore>().setDarkMode(prefs.getBool('isDarkMode')??true);
      context.read<PlayStore>().setCurrent(prefs.getInt('current')??0);
      context.read<PlayStore>().getUserInfo();
    });
    //防抖
    dplayNext = debounce(() => context.read<PlayStore>().playNext(), Duration(milliseconds: 500));
    dplayPrev = debounce(() => context.read<PlayStore>().playPrev(), Duration(milliseconds: 500));
    dplay = debounce(() => context.read<PlayStore>().playOrPause(true), Duration(milliseconds: 500));
    dpause = debounce(() => context.read<PlayStore>().playOrPause(false), Duration(milliseconds: 500));
    _tabController = TabController(length: 3, vsync: this); // 3是选项卡数量
    context.read<PlayStore>().getMp3sData();
    Future.delayed(Duration(milliseconds: 100),(){
        _initializeProviderState();
    });
  }
  Future<void> _initializeProviderState() async {
    const MethodChannel _channel = MethodChannel('com.example/mediaControl');
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'sendKeyCode':
        // 处理来自原生平台的方法调用
        print(call.arguments);
          if(call.arguments == "next") {
            dplayNext();
          } else if(call.arguments == "prev") {
            dplayPrev();
          } else if(call.arguments == "pause") {
            dplay();
          } else if(call.arguments == 'play') {
            dpause();
          }
          break;
        default:
          throw UnimplementedError();
      }
    });

    // 执行其他初始化操作，如果需要的话
  }
  int _String2Int(String val) {
    // log('String:$val');
    if(val.isEmpty || val ==null || val=='null'){
      // log('val isEmpty');
      return 0;
    }
    List<String> parts = val.split(':');
    int minutes = int.parse(parts[0]);
    int seconds = int.parse(parts[1]);
    final result = minutes * 60 + seconds;
    return minutes * 60 + seconds;
  }

  String _removeHtmlTags(String htmlText) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: false);
    var unescape = HtmlUnescape();
    // print(unescape.convert(htmlText.replaceAll(exp, '')));
    return unescape.convert(htmlText.replaceAll(exp, ''));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('播放器'),
      ),
      body: Container(
          // color: Colors.red,
          child: Stack(
            children: [
              TabBarView(
                controller: _tabController,
                children: [
                  // 第一个选项卡的内容
                  SearchPage(),
                  // 第二个选项卡的内容
                  ListPage(),
                  // 第三个选项卡的内容
                  SettingPage()
                ],
              ),
              context.watch<PlayStore>().musicList.length >
                      context.watch<PlayStore>().current
                  ? Positioned(
                      bottom: 27,
                      right: 0,
                      child: Container(
                          width: MediaQuery.of(context).size.width,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 1,
                              thumbShape: RoundSliderThumbShape(
                                enabledThumbRadius: 4, // 调整滑块的大小
                              ),
                              // 设置轨道高度
                            ),
                            child: Slider(
                                value: _String2Int(
                                        context.watch<PlayStore>().position)
                                    .toDouble(),
                                min: 0,
                                max: _String2Int(
                                        context.watch<PlayStore>().duration)
                                    .toDouble(),
                                // divisions: 1,
                                thumbColor: Colors.blue,
                                activeColor: Colors.blue,
                                onChanged: (value) {
                                  // setState(() {
                                  //   _sliderValue = value;
                                  // });

                                  context.read<PlayStore>().audioPlayer.seek(Duration(seconds: value.toInt()));
                                  // context.read<PlayStore>().audioPlayer.resume();
                                }),
                          )))
                  : Container(),
              context.watch<PlayStore>().musicList.length >
                      context.watch<PlayStore>().current
                  ? Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                          // color: Colors.white,
                          padding: EdgeInsets.only(left: 5, right: 5),
                          width: MediaQuery.of(context).size.width,
                          child: Row(
                            children: [
                              ClipRRect(
                                  //圆角图片
                                  borderRadius: BorderRadius.circular(20),
                                  child: !context
                                              .watch<PlayStore>()
                                              .musicList[context.watch<PlayStore>().current]
                                          ['isLocal']
                                      ? CachedNetworkImage(
                                    imageUrl: context.watch<PlayStore>().musicList[context.watch<PlayStore>().current]['pic'].startsWith('http')
                                        ? context.watch<PlayStore>().musicList[context.watch<PlayStore>().current]['pic']
                                        : 'https:' + context.watch<PlayStore>().musicList[context.watch<PlayStore>().current]['pic'],
                                    placeholder: (context, url) => Image.asset(
                                      'assets/placeholder.png',
                                      width: 40,
                                      height: 40,
                                    ),
                                    errorWidget: (context, url, error) => Image.asset(
                                      'assets/placeholder.png',
                                      width: 40,
                                      height: 40,
                                    ),
                                    fit: BoxFit.cover,
                                    width: 40,
                                    height: 40,
                                  )
                                      : Base64Image(context.select<PlayStore, dynamic>((value) {
                                          if (value.musicList.length >
                                              value.current) {
                                            return value
                                                    .musicList[value.current]
                                                ['albumImage'];
                                          } else {
                                            return '';
                                          }
                                        }))),
                              SizedBox(width: 5),
                              Expanded(
                                  child: Column(
                                children: [
                                  Container(
                                      width: double.infinity,
                                      child: Text(
                                        _removeHtmlTags(context
                                                .watch<PlayStore>()
                                                .musicList[
                                            context
                                                .watch<PlayStore>()
                                                .current]['title']),
                                        style: TextStyle(
                                            overflow: TextOverflow.ellipsis),
                                        // 设置文本溢出时的样式
                                        maxLines: 1, // 限制文本只显示一行
                                      )),
                                  Row(
                                    // mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(context.watch<PlayStore>().position,
                                          style: TextStyle(fontSize: 13)),
                                      context
                                              .watch<PlayStore>()
                                              .position
                                              .isNotEmpty
                                          ? Text('/',
                                              style: TextStyle(fontSize: 13))
                                          : Container(),
                                      Text(context.watch<PlayStore>().duration,
                                          style: TextStyle(fontSize: 13))
                                    ],
                                  ),
                                ],
                              )),
                              IconButton(
                                  onPressed: () =>
                                      {context.read<PlayStore>().setShuffle()},
                                  icon: Icon(
                                      context.watch<PlayStore>().isShuffle
                                          ? Icons.shuffle
                                          : Icons.repeat)),
                              IconButton(
                                  onPressed: ()
                                      {dplayPrev();},
                                  icon: Icon(Icons.arrow_left)),
                              IconButton(
                                  onPressed: (){
                                        var playS = context.read<PlayStore>();
                                        if(playS.audioPlayer!=null && playS.audioPlayer.playing){
                                          dpause();
                                        } else {
                                          dplay();
                                        }
                                      },
                                  icon: Icon(
                                      !context.watch<PlayStore>().playStatus
                                          ? Icons.play_arrow_rounded
                                          : Icons.pause)),
                              IconButton(
                                  onPressed: ()
                                      {dplayNext();},
                                  icon: Icon(Icons.arrow_right))
                            ],
                          )))
                  : Container()
            ],
          )),
      bottomNavigationBar: TabBar(
        controller: _tabController,
        tabs: [
          Tab(icon: Icon(Icons.search), text: '搜索'),
          Tab(icon: Icon(Icons.list), text: '列表'),
          Tab(icon: Icon(Icons.settings), text: '设置'),
        ],
        indicatorColor: Colors.blue,
        // 选中状态下的指示器颜色
        labelColor: Colors.blue,
        // 选中状态下的文本颜色
        unselectedLabelColor: Colors.grey, // 未选中状态下的文本颜色
      ),
    );
  }
}

class Base64Image extends StatefulWidget {
  final String base64String;

  Base64Image(this.base64String);

  @override
  _Base64ImageState createState() => _Base64ImageState();
}

class _Base64ImageState extends State<Base64Image>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    final decodedBytes = base64Decode(widget.base64String);
    return Image.asset('assets/placeholder.png', width: 30, height: 30);
    if (widget.base64String.isEmpty) {
      return Image.asset('assets/placeholder.png', width: 30, height: 30);
    } else {
      return Image.memory(decodedBytes,
          width: 30, height: 30, key: ValueKey(widget.base64String));
    }
  }

  @override
  void didUpdateWidget(Base64Image oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.base64String != widget.base64String) {
      // The base64String has changed. We need to update the image.
      setState(() {});
    }
  }
}
