import 'dart:html';

import 'package:eventsource/eventsource.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/browser_client.dart';
import 'dart:math';
import 'package:http/http.dart' as http;

class newChat extends StatefulWidget {
  const newChat({Key? key}) : super(key: key);

  @override
  _newChatState createState() => _newChatState();
}

Future<MediaStream> createStream(String media, bool userScreen) async {
  final Map<String, dynamic> mediaConstraints = {
    'audio': userScreen ? false : true,
    'video': userScreen
        ? true
        : {
            'mandatory': {
              'minWidth':
                  '640', // Provide your own width, height and frame rate here
              'minHeight': '480',
              'minFrameRate': '30',
            },
            'facingMode': 'user',
            'optional': [],
          }
  };
  Function(MediaStream stream)? onLocalStream;
//var unique = Random()(100000 + Math.random() * 900000);
  Random random = new Random();
  var unique = random.nextInt(900000) + 100000;
  MediaStream stream = userScreen
      ? await navigator.mediaDevices.getDisplayMedia(mediaConstraints)
      : await navigator.mediaDevices.getUserMedia(mediaConstraints);
  onLocalStream?.call(stream);

  EventSource eventSource;

  // navigator.mediaDevices.getUserMedia(mediaConstraints).then((value) async {

  eventSource = await EventSource.connect(
      'serverGet.php?unique=' + unique.toString(),
      client: new BrowserClient());
  // listen for events
  eventSource.listen((Event event) async {
    var url = Uri.parse(
        'https://luckytransportca.cafe24.com/webrtc/serverPost.php?unique=' +
            unique.toString());

    var response = await http.post(url,
        headers: {"Content-Type": "Application/X-Www-Form-Urlencoded"},
        body: event.data);
    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    print("New event:");
    print("  event: ${event.event}");
    print("  data: ${event.data}");
  });

  //});
  return stream;
}

class _newChatState extends State<newChat> {
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  @override
  initState() {
    super.initState();
    initRenderers();
    //  _connect();
  }

  initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Stack(children: <Widget>[
        Positioned(
            left: 0.0,
            right: 0.0,
            top: 0.0,
            bottom: 0.0,
            child: Container(
              margin: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: RTCVideoView(_remoteRenderer),
              decoration: BoxDecoration(color: Colors.black54),
            )),
        Positioned(
          left: 20.0,
          top: 20.0,
          child: Container(
            width: 90,
            height: 120,
            child: RTCVideoView(_localRenderer, mirror: true),
            decoration: BoxDecoration(color: Colors.black54),
          ),
        ),
      ]),
    );
  }
}
