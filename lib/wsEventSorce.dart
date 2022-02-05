import 'dart:convert';

import 'package:universal_html/html.dart' as html;
import 'package:http/http.dart' as http2;

class WsEventSorce {
  WsEventSorce(this.unique);
  final unique;

  html.EventSource eventSource() {
    final eventSource = html.EventSource(
        'https://luckytransportca.cafe24.com/webrtc/serverGet.php?unique=' +
            unique.toString(),
        withCredentials: false);
    return eventSource;
  }

  send(event, data) async {
    print(
        "==================       ================================================>");
    print(jsonEncode(<String, String>{'event': event, 'data': data}));
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
  }
}
