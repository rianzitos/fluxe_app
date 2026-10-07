import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? status;
  const ApiException(this.message, {this.status});

  bool get isUnauthorized => status == 401;

  @override
  String toString() => message;
}

/// Cliente da API JSON do SICAPDA (SystemFluxe: /api/*), autenticado por Bearer token.
class ApiClient {
  final String baseUrl;
  final String? token;
  final void Function()? onUnauthorized;
  final http.Client _http;

  ApiClient({
    required this.baseUrl,
    this.token,
    this.onUnauthorized,
    http.Client? client,
  }) : _http = client ?? http.Client();

  static const _timeout = Duration(seconds: 25);

  /// Aceita "meuservidor.com", "http://192.168.0.10:8000/" etc.
  static String normalizeBaseUrl(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return url;
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(url)) {
      url = 'https://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final clean = query == null
        ? null
        : (Map.of(query)..removeWhere((_, v) => v.isEmpty));
    return Uri.parse('$baseUrl/api$path')
        .replace(queryParameters: clean == null || clean.isEmpty ? null : clean);
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) =>
      _send(() => _http.get(_uri(path, query), headers: _headers));

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) =>
      _send(() => _http.post(_uri(path), headers: _headers, body: jsonEncode(body)));

  /// Baixa texto puro (usado no CSV de relatórios).
  Future<String> getText(String path, {Map<String, String>? query}) async {
    final res = await _run(() => _http.get(_uri(path, query), headers: _headers));
    if (res.statusCode >= 400) _throwFrom(res);
    return utf8.decode(res.bodyBytes);
  }

  Future<http.Response> _run(Future<http.Response> Function() call) async {
    try {
      return await call().timeout(_timeout);
    } on TimeoutException {
      throw const ApiException('O servidor demorou para responder. Tente novamente.');
    } on http.ClientException {
      throw const ApiException('Não foi possível conectar ao servidor. Verifique sua internet e o endereço do servidor.');
    }
  }

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() call) async {
    final res = await _run(call);

    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) json = decoded;
    } on FormatException {
      json = null;
    }

    if (res.statusCode >= 400 || json == null || json['sucesso'] == false) {
      if (res.statusCode == 401) onUnauthorized?.call();
      throw ApiException(
        (json?['mensagem'] as String?) ??
            'Resposta inesperada do servidor (HTTP ${res.statusCode}).',
        status: res.statusCode,
      );
    }
    return json;
  }

  Never _throwFrom(http.Response res) {
    if (res.statusCode == 401) onUnauthorized?.call();
    throw ApiException('Falha ao baixar (HTTP ${res.statusCode}).', status: res.statusCode);
  }

  void close() => _http.close();
}

