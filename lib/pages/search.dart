import 'dart:developer';
import 'dart:convert';
import 'package:html_unescape/html_unescape.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../store/PlayStore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

final String USER_AGENT =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

// 定义页面状态
class _SearchPageState extends State<SearchPage>
    with AutomaticKeepAliveClientMixin {
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

  Future<dynamic> _getSearchResult(String keyword, int page) async {
    if(!context.read<PlayStore>().isLogin){
      Fluttertoast.showToast(
          msg: "请前往设置界面登录",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.grey,
          textColor: Colors.white,
          fontSize: 16.0
      );
      return;
    }
    const url = 'https://api.bilibili.com/x/web-interface/wbi/search/type';
    final dio = Dio();
    dio.options.headers = {
      'user-agent': USER_AGENT,
      'cookie': context.read<PlayStore>().cookie,
    };
    final response = await dio.get(url, queryParameters: {
      'keyword': keyword,
      'search_type': 'video',
      'order': 'totalrank',
      'duration': '0',
      'tids': '0',
      'page': page,
    });
    if (response.data['code'] == 0) {
      // log(response.data);
      setState(() {
        _tableData = response.data['data']['result'];
        _total = response.data['data']['numResults'];
      });
    } else {
      return '';
    }
  }

  // 执行搜索操作
  Future<void> _performSearch() async {
    final searchText = _searchController.text;
    if (searchText.isNotEmpty) {
      await _getSearchResult(searchText, 1);
      // 在这里执行搜索操作，例如调用API
      // print('Searching for: $t');
    }
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
    return Container(
      padding:EdgeInsets.only(bottom:50),
      child:Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _handleSearchTextChanged,
                    onSubmitted: (String text) async {
                      await _performSearch();
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 0.0),
                  child: IconButton(
                      onPressed: _performSearch, icon: Icon(Icons.search)),
                ),
              ],
            ),
          ),
          Expanded(
            child: _tableData.isNotEmpty
                ? ListView.builder(
              itemCount: _tableData.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                    onTap: () async {
                      var bid = _tableData[index]['bvid'];
                      String audioURL = await _getAudioUrl(bid);
                      _tableData[index]['path'] = audioURL;
                      _tableData[index]['isLocal'] = false;
                      _tableData[index]['expireTime'] =
                          new DateTime.now().millisecondsSinceEpoch +
                              120 * 60 * 1000;
                      context
                          .read<PlayStore>()
                          .appendMusic(_tableData[index]);
                      // log(audioURL);
                    },
                    child: Padding(
                        padding: EdgeInsets.only(
                            top: 5, bottom: 5, left: 10, right: 10),
                        child: Row(
                          children: [
                            Padding(
                              padding: EdgeInsets.only(right: 10),
                              child: CachedNetworkImage(
                                imageUrl: _tableData[index]['pic'].startsWith('http')
                                    ? _tableData[index]['pic']
                                    : 'https:' + _tableData[index]['pic'],
                                placeholder: (context, url) => Image.asset(
                                  'assets/placeholder.png',
                                  width: 30,
                                  height: 30,
                                ),
                                errorWidget: (context, url, error) => Image.asset(
                                  'assets/placeholder.png',
                                  width: 40,
                                  height: 40,
                                ),
                                fit: BoxFit.cover,
                                width: 40,
                                height: 40,
                              ),
                            ),
                            Expanded(
                                child: Container(
                                    width: 200, // 设置一个合适的宽度
                                    child: Text(
                                      _removeHtmlTags(
                                          _tableData[index]['title']),
                                      style: TextStyle(
                                          overflow: TextOverflow.ellipsis),
                                      // 设置文本溢出时的样式
                                      maxLines: 1, // 限制文本只显示一行
                                    ))),
                            Text(_tableData[index]['duration']),
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


