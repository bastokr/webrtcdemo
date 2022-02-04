import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:math';
import 'package:universal_html/html.dart' as html;
import 'package:http/http.dart' as http2;

class NewChat extends StatefulWidget {
  const NewChat({Key? key}) : super(key: key);

  @override
  _newChatState createState() => _newChatState();
}

class _newChatState extends State<NewChat> {
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  Random random = new Random();
  MediaStream? _localStream;
  RTCPeerConnection? pc;
  var answer = false;
  var unique;
  late Stream myStream;

  @override
  initState() {
    unique = random.nextInt(900000) + 100000;
    initRenderers();
    super.initState();

    //  _connect();
  }

  initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    switchCamera();
    await createStream(true, _localRenderer);
    testSse(unique);
    publish('client-call', '');
    // setState(() {});
  }

  void switchCamera() {
    if (_localStream != null) {
      Helper.switchCamera(_localStream!.getVideoTracks()[0]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
      appBar: AppBar(
        title: Text('P2P Call Sample '),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: null,
            tooltip: 'setup',
          ),
        ],
      ),
      body: OrientationBuilder(builder: (context, orientation) {
        return Container(
          child: Row(children: <Widget>[
            Container(
              margin: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
              width: 120.0,
              height: 90.0,
              child: RTCVideoView(_remoteRenderer),
              decoration: BoxDecoration(color: Colors.black54),
            ),
            Container(
              width: 120.0,
              height: 90.0,
              child: RTCVideoView(_localRenderer, mirror: true),
              decoration: BoxDecoration(color: Colors.black54),
            ),
          ]),
        );
      }),
    ));
  }

  Future<void> testSse(unique) async {
    final eventSource = html.EventSource(
        'https://luckytransportca.cafe24.com/webrtc/serverGet.php?unique=' +
            unique.toString(),
        withCredentials: false);

    eventSource.onMessage.listen((event) {
      if (event.data.indexOf("_MULTIPLEVENTS_") > -1) {
        var multiple = event.data.split("_MULTIPLEVENTS_");
        for (var x = 0; x < multiple.length; x++) {
          onsinglemessage(multiple[x]);

          print(multiple[x]);
        }
      } else {
        print(event.data);
        onsinglemessage(event.data);
      }
    });
  }

  onsinglemessage(message) {
    var package = json.decode(message);
    var data = package['data'];
    var candidateMap = data?['candidate'];
    var description = data?['description'];
    print("received single message: " + package['event']);

    switch (package['event']) {
      case 'client-call':
        icecandidate(_localStream);
        pc?.createOffer({}).then((desc) {
          pc?.setLocalDescription(desc).then((value) => {
                print(pc?.getLocalDescription()),
                publish('client-offer', pc?.getLocalDescription())
              });
        }).onError((error, stackTrace) => null);
        break;
      case 'client-answer':
        if (pc == null) {
          print('Before processing the client-answer, I need a client-offer');
          break;
        }
        pc?.setRemoteDescription(
            new RTCSessionDescription(description['sdp'], description['type']));
        break;
      case 'client-offer':
        icecandidate(_localStream);
        pc
            ?.setRemoteDescription(new RTCSessionDescription(
                description['sdp'], description['type']))
            .then((value) {
          if (!answer) {
            pc?.createAnswer().then((description) {
              pc
                  ?.setLocalDescription(description)
                  .then((value) =>
                      {publish('client-answer', pc?.getLocalDescription())})
                  .onError((error, stackTrace) => {});
            }).onError((error, stackTrace) {});

            answer = true;
          }
        });
        break;
      case 'client-candidate':
        if (pc == null) {
          print('Before processing the client-answer, I need a client-offer');
          break;
        }

        pc?.addCandidate(RTCIceCandidate(candidateMap['candidate'],
            candidateMap['sdpMid'], int.parse(candidateMap['sdpMLineIndex'])));
        break;
    }
  }

  String get sdpSemantics =>
      WebRTC.platformIsWindows ? 'plan-b' : 'unified-plan';

  Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.stunprotocol.org:3478'},
      {'urls': 'stun:stun.l.google.com:19302'},
      /*
       * turn server configuration example.
      {
        'url': 'turn:123.45.67.89:3478',
        'username': 'change_to_real_user',
        'credential': 'change_to_real_secret'
      },
      */
    ]
  };

  final Map<String, dynamic> _config = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ]
  };

  icecandidate(localStream) async {
    pc = await createPeerConnection({
      ..._iceServers,
      ...{'sdpSemantics': {}}
    }, _config);

    pc?.onIceCandidate = (candidate) async {
      if (candidate == null) {
        print('onIceCandidate: complete!');
        return;
      }
      // This delay is needed to allow enough time to try an ICE candidate
      // before skipping to the next one. 1 second is just an heuristic value
      // and should be thoroughly tested in your own environment.
      publish('client-candidate', candidate.toString());
    };

    try {
      pc?.addStream(localStream);
    } catch (e) {
      var tracks = localStream.getTracks();
      for (var i = 0; i < tracks.length; i++) {
        pc?.addTrack(tracks[i], localStream);
      }
    }
    pc?.onTrack = (event) {
      //  document.getElementById('remoteVideo').style.display="block";
      // document.getElementById('localVideo').style.display="none";
      //   _remoteRenderer.srcObject = event.streams[0];
    };
  }

  publish(event, data) async {
    print(
        "==================================================================================================>");
    print(jsonEncode(<String, String>{event: event, data: data}));
    final response = await http2.post(
      Uri.parse(
          'https://luckytransportca.cafe24.com/webrtc/serverPost.php?unique=' +
              unique.toString()),
      headers: <String, String>{
        'Content-Type': 'Application/X-Www-Form-Urlencoded',
      },
      body: jsonEncode(<String, String>{event: event, data: data}),
    );
    print(response.statusCode);
    print(response.body);
    /*
        console.log("sending ws.send: " + event);
        ws.send(JSON.stringify({
            event:event,
            data:data 
        })); 
        */
  }

  createStream(bool userScreen, RTCVideoRenderer localRenderer) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': true
    };

    var stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

    localRenderer.srcObject = stream;
    _localStream = stream;
    return stream;
  }
}
