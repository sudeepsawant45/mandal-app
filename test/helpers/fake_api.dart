import 'dart:async';
import 'dart:convert';

import 'package:ganpati_mandal/services/api_client.dart';
import 'package:ganpati_mandal/services/token_store.dart';

/// One recorded request.
class Call {
  Call(this.method, this.url, this.headers, this.body);

  final String method;
  final Uri url;
  final Map<String, String> headers;
  final String? body;

  Map<String, dynamic>? get json => body == null ? null : jsonDecode(body!) as Map<String, dynamic>;
}

typedef Responder = FutureOr<ApiResponse> Function(Call call);

/// An [ApiClient] wired to a fake transport and an in-memory token store.
class FakeApi {
  FakeApi(this.responder, {String? token, String base = 'https://api.example.test', this.onUnauthorized, bool? allowInsecureHttp}) {
    tokens = MemoryTokenStore(token);
    client = ApiClient(
      tokens: tokens,
      baseUrl: base,
      onUnauthorized: onUnauthorized,
      allowInsecureHttp: allowInsecureHttp ?? false, // tests run in debug mode; keep the release rule
      transport: (method, url, headers, body) async {
        final call = Call(method, url, headers, body);
        calls.add(call);
        return responder(call);
      },
    );
  }

  final Responder responder;
  final void Function()? onUnauthorized;
  late final MemoryTokenStore tokens;
  late final ApiClient client;
  final List<Call> calls = [];
}

ApiResponse ok(Map<String, dynamic> json, [int status = 200]) =>
    ApiResponse(status, {'ok': true, ...json});

ApiResponse errJson(int status, [String code = 'x', Map<String, dynamic> extra = const {}]) =>
    ApiResponse(status, {'ok': false, 'code': code, ...extra});
