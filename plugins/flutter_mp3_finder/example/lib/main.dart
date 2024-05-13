import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_mp3_finder/flutter_mp3_finder.dart';

import 'data_model.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  var _models;

  @override
  void initState() {
    super.initState();
    getMp3sData();
  }

  Future<void> getMp3sData() async {
    try {
      var mp3String = await FlutterMp3Finder.scanDeviceForMp3Files;
      // _models = DataModel.fromJson(json.decode(mp3String));
      _models = json.decode(mp3String);
      print(mp3String);
    } on Exception catch (e) {
      print(e);
    }
    if (!mounted) return;
    setState(() {});
  }

  _mp3Item(Mp3Model mp3File) {
    return Card(
      child: ListTile(
        leading: Image.memory(
          base64Decode(mp3File.albumImage),
          width: 100,
          fit: BoxFit.scaleDown,
        ),
        title: Text(
          mp3File.artist,
          style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          mp3File.displayName,
          style: TextStyle(fontSize: 20.0),
        ),
        trailing: Builder(
          builder: (ctx) => InkWell(
            child: Icon(Icons.send),
            onTap: () => _showSnak(ctx,mp3File.path),
          ),
        ),
      ),
    );
  }

  _showSnak(BuildContext ctx, String path) {
    // Scaffold.of(ctx).showSnackBar(SnackBar(content: Text(path)));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          appBar: AppBar(
            title: const Text('Mp3 finder plugin'),
          ),
          body: Container(
            padding: EdgeInsets.all(8.0),
            child: _models == null
                ? Center()
                : ListView.builder(
                    itemCount: _models['mp3Files'].length,
                    itemBuilder: (_, index) =>
                        _mp3Item(_models['mp3Files'][index])),
          )),
    );
  }
}
