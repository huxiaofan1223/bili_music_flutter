import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../store/PlayStore.dart';
import 'package:path/path.dart' as path;
import 'dart:developer';
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
// import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oktoast/oktoast.dart';

class SettingPage extends StatefulWidget {
  @override
  _SettingPageState createState() => _SettingPageState();
}
final String USER_AGENT =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

// 定义页面状态
class _SettingPageState extends State<SettingPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late MethodChannel _channel;
  var limitSeconds=180;
  var qrcodeKey;
  var qrUrl='';
  Timer? timer = null;
  bool showCode = false;
  bool isLogin = false;
  var totalSize;
  var noUseSize;
  dynamic userInfo;
  Future<void> calcCacheSize() async {
    final Directory tempDir = await getTemporaryDirectory();
    //缓存所有的文件
    var fileList = tempDir.listSync().where((item)=>item.path.endsWith(".m4s")).map((item)=>item.path);

    var musicList = context.read<PlayStore>().musicList;
    // 列表中的文件
    var pathList = musicList.map((item)=>path.join(tempDir.path,"${item['bvid']}.m4s"));

    // 没用的文件
    List<String> leftList = fileList.where((element) => !pathList.contains(element)).toList();
    setState(() {
      totalSize = fileList.fold(0, (accumulator, currentValue) => accumulator + File(currentValue).lengthSync());
      noUseSize = leftList.fold(0, (accumulator, currentValue) => accumulator + File(currentValue).lengthSync());
    });
  }
  @override
  void initState() {
    super.initState();
    _channel = MethodChannel('com.example/mediaControl');
    getUserInfo();
    calcCacheSize();
  }

  Future<dynamic> getLoopLoginQuery(String qrcodeKey) async {
    print('qrcodeKey:$qrcodeKey');
    final url = Uri.parse('https://passport.bilibili.com/x/passport-login/web/qrcode/poll?qrcode_key=$qrcodeKey');

    final response = await http.get(url, headers: {
      'User-Agent': USER_AGENT
    });

    if (response.statusCode == 200) {
      final String result = response.body;
      final Map<String, String> headers = response.headers;
      String? cookie = null;
      if (headers.containsKey('set-cookie')) {
        cookie = headers['set-cookie']!;
      }
      final Map<String, dynamic> responseData = {
        'result': result,
        'cookie': cookie,
      };
      return responseData;
    } else {
      throw Exception('Failed to load data: ${response.statusCode}');
    }
  }

  String? _getHostFromUrl(String url){
    if(url.isEmpty){return '';}
    RegExp regex = RegExp(r'(?<=\/\/).*?(?=\/)');
    Match match = regex.firstMatch(url) as Match;
    if (match != null) {
      String? host = match.group(0);
      print('host:$host');
      return host;
    } else {
      return "";
    }
  }
  Future<dynamic> get_login_png_url() async {
    const String url = "https://passport.bilibili.com/x/passport-login/web/qrcode/generate";
    final cidResponse = await http.get(Uri.parse('$url'), headers: {
      'user-agent': USER_AGENT,
    });
    return jsonDecode(cidResponse.body);
  }


  Future<dynamic> getUserInfo() async{
    const String url = "https://api.bilibili.com/x/web-interface/nav";
    final res = await http.get(Uri.parse('$url'), headers: {
      'user-agent': USER_AGENT,
      'cookie':context.read<PlayStore>().cookie
    });
    final result = jsonDecode(res.body);
    if (result['code'] == 0) {
      context.read<PlayStore>().setLogin(true);
      setState(() {
        userInfo = result['data'];
      });
    } else {
        context.read<PlayStore>().setLogin(false);
    }
  }

  void handleScanCode() async {
    if(showCode){
      return;
    }
    final jsonResult = await get_login_png_url();
    setState(() {
      limitSeconds = 180;
    });
    setState(() {
      qrcodeKey = jsonResult['data']['qrcode_key'];
      qrUrl = jsonResult['data']['url'];
      showCode = true;
    });
    loopQueryLogin();
  }

  void loopQueryLogin() async {
    if(timer!=null){
      timer?.cancel();
    }
    timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      final parseResult = await getLoopLoginQuery(qrcodeKey);
      final res = json.decode(parseResult['result']);
      final code = res['data']['code'];
      final msg = res['data']['message'];
      final cookie = parseResult['cookie'];
      print({'msg': msg});
      if (code == 0) {
        timer?.cancel();
        // message.success('登录成功!');
        // Fluttertoast.showToast(
        //     msg: "登录成功!",
        //     toastLength: Toast.LENGTH_SHORT,
        //     gravity: ToastGravity.CENTER,
        //     timeInSecForIosWeb: 1,f
        //     backgroundColor: Colors.grey,
        //     textColor: Colors.white,
        //     fontSize: 16.0
        // );
        showToast('登录成功!',backgroundColor: Colors.grey);
        setState(() {
          showCode = false;
        });
        context.read<PlayStore>().setCookie(cookie);
        Future.delayed(Duration(milliseconds: 200), () {
          // store.getUserInfo();
          getUserInfo();
        });
      } else {
        if (msg != '未扫码') {
          // Fluttertoast.showToast(
          //     msg:msg,
          //     toastLength: Toast.LENGTH_SHORT,
          //     gravity: ToastGravity.CENTER,
          //     timeInSecForIosWeb: 1,
          //     backgroundColor: Colors.grey,
          //     textColor: Colors.white,
          //     fontSize: 16.0
          // );
          showToast(msg,backgroundColor: Colors.grey);
        }
      }
      if (limitSeconds > 0) {
        setState(() {
          limitSeconds -= 1;
          print({'limitSeconds': limitSeconds});
        });
      } else {
        timer?.cancel();
        // handleScanCode();
        // Fluttertoast.showToast(
        //     msg:'二维码已过期,请更新二维码',
        //     toastLength: Toast.LENGTH_SHORT,
        //     gravity: ToastGravity.CENTER,
        //     timeInSecForIosWeb: 1,
        //     backgroundColor: Colors.grey,
        //     textColor: Colors.white,
        //     fontSize: 16.0
        // );
        showToast('二维码已过期,请更新二维码',backgroundColor: Colors.grey);
        setState(() {
          limitSeconds=180;
          showCode=false;
        });
      }
      print({'parseResult': parseResult});
    });

  }
  String byte2Txt(dynamic size) {
    if(size == null){return '';};
    const List<String> unitArr = ['B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB', 'BB'];
    int count = 0;
    double newSize = size.toDouble();

    // 循环直到 newSize 小于或等于 1024
    while (newSize > 1024) {
      newSize /= 1024;
      count++;

      // 确保不超出 unitArr 的长度
      if (count >= unitArr.length) {
        break;
      }
    }

    // 使用 String.format 格式化 newSize 到两位小数
    return newSize.toStringAsFixed(2) + unitArr[count];
  }
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom:50),
      child: Column(
        children: [
          SizedBox(height:10),
          Row(
            children: [
              SizedBox(width:20),
              ElevatedButton(
                onPressed: () async {
                  final Directory tempDir = await getTemporaryDirectory();
                  //缓存所有的文件
                  var fileList = tempDir.listSync().where((item)=>item.path.endsWith(".m4s")).map((item)=>item.path);

                  var musicList = context.read<PlayStore>().musicList;
                  // 列表中的文件
                  var pathList = musicList.map((item)=>path.join(tempDir.path,"${item['bvid']}.m4s"));

                  // 没用的文件
                  List<String> leftList = fileList.where((element) => !pathList.contains(element)).toList();
                  setState(() {
                    totalSize = fileList.fold(0, (accumulator, currentValue) => accumulator + File(currentValue).lengthSync());
                    noUseSize = leftList.fold(0, (accumulator, currentValue) => accumulator + File(currentValue).lengthSync());
                  });
                  leftList.forEach((element) {
                    log('删除了:${element}');
                    File(element).deleteSync();
                  });
                },
                child: Text('清理无用缓存'),
              ),
              SizedBox(width:20),
              Text('已缓存:${byte2Txt(totalSize)}',style:TextStyle(fontSize: 14)),
              SizedBox(width:20),
              Text('无用缓存:${byte2Txt(noUseSize)}',style:TextStyle(fontSize: 14)),
            ],
          ),
          SizedBox(height:8),
          Row(
            children: [
              SizedBox(width:20),
              Text("白天模式",style:TextStyle(fontSize: 14)),
              Switch(
                value: context.watch<PlayStore>().isDarkMode,
                onChanged: (value) {
                  context.read<PlayStore>().toggleTheme();
                },
              ),
              Text("夜间模式",style:TextStyle(fontSize: 14)),

              SizedBox(width:10),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await _channel.invokeMethod('restartApp');
                  } catch (e) {
                    print('Failed to restart the app: $e');
                  }
                },
                child: Text('重启应用')
              ),
              SizedBox(width:10),
              ElevatedButton(
                  onPressed: () async {
                    try {
                      await _channel.invokeMethod('closeApp');
                    } catch (e) {
                      print('Failed to close the app: $e');
                    }
                  },
                  child: Text('退出应用')
              ),
            ],
          ),
          SizedBox(height:8),
          showCode?QrImageView(
            data: qrUrl,
            version: QrVersions.auto,
            backgroundColor:Colors.white,
            size: 100.0,
          ):SizedBox(),
          showCode?Text('请打开Bilibili客户端扫码登录,$limitSeconds秒过期',style:TextStyle(fontSize: 14)):SizedBox(),
          Row(
            children: [
              SizedBox(width:20),
              !context.watch<PlayStore>().isLogin?ElevatedButton(
                onPressed: () async {
                  handleScanCode();
                },
                child: Text('登录Bilibili'),
              ):SizedBox(),
              context.watch<PlayStore>().isLogin&&userInfo!=null?
              FadeInImage(
                  placeholder: AssetImage('assets/placeholder.png'),
                  image: NetworkImage(userInfo['face'],headers: {'host': _getHostFromUrl(userInfo['face'])!, 'Referer': 'https://bilibili.com'},),
                  fit: BoxFit.cover,
                  width: 40,
                  height: 40
              ) :
              SizedBox(),
              SizedBox(width:8),
              context.watch<PlayStore>().isLogin?Text(userInfo?['uname']??''):SizedBox(),
              SizedBox(width:8),
              context.watch<PlayStore>().isLogin?Text('已登录',style:TextStyle(fontSize: 14)):SizedBox(),
              SizedBox(width:8),
              context.watch<PlayStore>().isLogin?ElevatedButton(
                onPressed: () async {
                  context.read<PlayStore>().setLogin(false);
                  userInfo = null;
                  context.read<PlayStore>().setCookie('');
                },
                child: Text('注销登录'),
              ):SizedBox(),
            ],
          ),
          SizedBox(height:8),
          Text('声明:本软件数据都来自Bilibili,代码已开源,无信息泄露风险',style:TextStyle(fontSize: 14)),
          SizedBox(height:8),
        GestureDetector(
          onTap: () async {
            final url = "https://github.com/huxiaofan1223/bili_music_flutter";
            if (await canLaunchUrl(Uri.parse(url))) {
              await launchUrl(Uri.parse(url));
            } else {
              throw 'Could not launch $url';
            }
          },
          child: Text(
            '开源地址:https://github.com/huxiaofan1223/bili_music_flutter',
              style:TextStyle(fontSize: 14,color:Colors.blue)
          ),
        ),
        ],
      )
    );
  }
}