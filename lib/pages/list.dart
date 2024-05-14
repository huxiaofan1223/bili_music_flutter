import 'dart:developer';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../store/PlayStore.dart';

class ListPage extends StatefulWidget {
  @override
  _ListPageState createState() => _ListPageState();
}

final String USER_AGENT =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

// 定义页面状态
class _ListPageState extends State<ListPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  var _tableData = [];
  var _total = 0;
  TextEditingController _searchController = TextEditingController();

  // 处理搜索框文本变化
  void _handleSearchTextChanged(String text) {
    // 在这里可以添加搜索逻辑，例如调用API
    print('Search text changed: $text');
  }

  Future<String> _getAudioUrl(String bid) async {
    const String url = "https://api.bilibili.com/x/web-interface/view";
    final cidResponse = await http.get(Uri.parse('$url?bvid=$bid'), headers: {
      'user-agent': USER_AGENT,
      'cookie': context.read<PlayStore>().cookie,
    });

    final cidJson = jsonDecode(cidResponse.body);
    // log(cidJson.toString());
    // _mp3Title = cidJson['data']['title'].replaceAll(RegExp(r'(?:[^\u4e00-\u9fa5a-zA-Z0-9\s]| |丨)'), '');
    final String cid = cidJson['data']['cid'].toString();

    const String url2 = "https://api.bilibili.com/x/player/wbi/playurl";
    final response = await http.get(
        Uri.parse('$url2?bvid=$bid&qn=80&cid=$cid&fnval=16'),
        headers: {'user-agent': USER_AGENT, 'cookie': context.read<PlayStore>().cookie});

    final jsonResult = jsonDecode(response.body);
    log(jsonResult.toString());
    if (jsonResult['code'] == 0) {
      return jsonResult['data']['dash']['audio'][0]['base_url'];
    } else {
      return '';
    }
  }

  String _removeHtmlTags(String htmlText) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: false);
    var unescape = HtmlUnescape();
    // print(unescape.convert(htmlText.replaceAll(exp, '')));
    return unescape.convert(htmlText.replaceAll(exp, ''));
  }

  @override
  Widget build(BuildContext context) {
    // 构建页面内容
    return Container(
      padding:EdgeInsets.only(bottom:50),
      child: Column(
        children: [
          Expanded(
            child: context.watch<PlayStore>().musicList.isNotEmpty
                ? ListView.builder(
              itemCount: context.watch<PlayStore>().musicList.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                    onTap: () async {
                      context.read<PlayStore>().playCurrentMusic(index);
                      // log(audioURL);
                    },
                    onLongPress: () {
                      showCupertinoModalPopup(
                          context: context,
                          builder: (BuildContext context) {
                            return CupertinoActionSheet(
                              title: Text('提示'),
                              message: Text('是否要删除当前项？'),
                              actions: <Widget>[
                                CupertinoActionSheetAction(
                                  child: Text('删除'),
                                  onPressed: () {
                                    context.read<PlayStore>().removeMusic(index);
                                    Navigator.of(context).pop();
                                  },
                                  isDestructiveAction: true,
                                ),
                                CupertinoActionSheetAction(
                                  child: Text('取消'),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  isDefaultAction: true,
                                ),
                              ],
                            );
                          }
                      );
                    },
                    child: Container(
                        padding: EdgeInsets.only(
                            top: 10, bottom: 10, left: 10, right: 10),
                        child: Row(
                          children: [
                            Container(
                                width:30,
                                child:Text((index + 1).toString(),
                                    style: TextStyle(
                                        color: context
                                            .watch<PlayStore>()
                                            .current ==
                                            index
                                            ? Colors.blue
                                            : null))
                            ),
                            Padding(
                                padding:
                                EdgeInsets.only(right: 10, left: 10),
                                child: !context
                                    .watch<PlayStore>()
                                    .musicList[index]['isLocal']
                                    ? FadeInImage(
                                    imageErrorBuilder:
                                        (context, error, stackTrace) {
                                      return Image.asset(
                                          'assets/placeholder.png',width: 30,
                                          height: 30);
                                    },
                                    placeholder: AssetImage(
                                        'assets/placeholder.png'),
                                    image: NetworkImage(context
                                        .watch<PlayStore>()
                                        .musicList[index]['pic']
                                        .startsWith('http')
                                        ? context
                                        .watch<PlayStore>()
                                        .musicList[index]['pic']
                                        : 'https:' +
                                        context
                                            .watch<PlayStore>()
                                            .musicList[index]
                                        ['pic']),
                                    // 网络图片
                                    fit: BoxFit.cover,
                                    // 图片填充方式
                                    width: 30,
                                    height: 30)
                                    : Consumer<PlayStore>(
                                  builder:
                                      (context, playStore, child) {
                                    final music = playStore
                                        .getMusicByIndex(index);
                                    return Base64Image(
                                        music['albumImage']);
                                  },
                                )),
                            Expanded(
                                child: Container(
                                  // width: 200, // 设置一个合适的宽度
                                    child: Text(
                                      _removeHtmlTags(context
                                          .watch<PlayStore>()
                                          .musicList[index]['title']),
                                      style: TextStyle(
                                          color:
                                          context.watch<PlayStore>().current ==
                                              index
                                              ? Colors.blue
                                              : null,
                                          overflow: TextOverflow.ellipsis),
                                      // 设置文本溢出时的样式
                                      maxLines: 1, // 限制文本只显示一行
                                    ))),
                            Text(
                                context.watch<PlayStore>().musicList[index]
                                ['duration'],
                                style: TextStyle(
                                    color: context
                                        .watch<PlayStore>()
                                        .current ==
                                        index
                                        ? Colors.blue
                                        : null)),
                          ],
                        )));
              },
            )
                : Center(child: Text('暂无数据')),
          )
        ],
      )
    );
  }
}

class Base64Image extends StatefulWidget {
  final String base64String;

  Base64Image(this.base64String);

  @override
  _Base64ImageState createState() => _Base64ImageState();
}

class _Base64ImageState extends State<Base64Image> {
  @override
  Widget build(BuildContext context) {
    final decodedBytes = base64Decode(widget.base64String);
    return Image.asset('assets/placeholder.png', width: 30, height: 30);
    if (widget.base64String.isEmpty) {
      return Image.asset('assets/placeholder.png', width: 30, height: 30);
    } else {
      return Image.memory(decodedBytes, width: 30, height: 30);
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
