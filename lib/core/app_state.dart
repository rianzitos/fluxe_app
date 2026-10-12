import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'api_client.dart';

/// Servidor de produção do SystemFluxe.
const String kProductionBaseUrl = 'https://fluxeteam.com.br';

/// Servidor fixado na compilação, se houver:
///   flutter build apk --dart-define=SICAPDA_SERVER_URL=https://meu-servidor.com.br
const String _kServerFromBuild = String.fromEnvironment('SICAPDA_SERVER_URL');

/// Pasta (dentro do site) onde o SystemFluxe publica a versão web do aplicativo.
const String kWebAppFolder = 'aplicativo';

/// Endereço do SystemFluxe usado enquanto a pessoa não escolher outro (tela de login → "Servidor").
///
///  • compilado com SICAPDA_SERVER_URL → esse endereço;
///  • versão web publicada (release) → o próprio site de onde a página foi aberta
///    (`https://site/aplicativo/` → `https://site`; vale também para uma subpasta, como
///    `http://localhost/SystemFluxe/public/aplicativo/`). Assim o app web funciona em qualquer
///    domínio, sem CORS e sem configurar nada;
///  • celular, PC e `flutter run` → o servidor de produção.
String resolveDefaultBaseUrl({Uri? page, bool web = kIsWeb, bool release = kReleaseMode}) {
  if (_kServerFromBuild.isNotEmpty) return _kServerFromBuild;
  if (web && release) {
    final uri = page ?? Uri.base;
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      final i = uri.path.indexOf('/$kWebAppFolder');
      final prefix = i > 0 ? uri.path.substring(0, i) : '';
      return '${uri.origin}$prefix';
    }
  }
  return kProductionBaseUrl;
}

/// Onde o token de acesso fica guardado (abstraído para facilitar testes).
abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// Celular e PC: cofre do sistema (Keystore do Android, Credential Locker do Windows...).
class SecureTokenStore implements TokenStore {
  static const _key = 'sicapda_token';
  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// Navegador: não existe cofre. O armazenamento "seguro" da web exige HTTPS e falha em http://
/// (por exemplo numa demonstração na rede local), então o token fica no armazenamento do próprio
/// navegador (localStorage), que protege tanto quanto: só este site consegue ler.
class BrowserTokenStore implements TokenStore {
  static const _key = 'sicapda_token';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<String?> read() async => (await _prefs).getString(_key);

  @override
  Future<void> write(String token) async => (await _prefs).setString(_key, token);

  @override
  Future<void> clear() async => (await _prefs).remove(_key);
}

class MemoryTokenStore implements TokenStore {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}

/// Estado global: sessão do usuário, servidor, tema e alertas do sino.
class AppController extends ChangeNotifier {
  AppController({
    SharedPreferences? prefs,
    TokenStore? tokenStore,
    http.Client? httpClient,
    String? defaultServer,
  })
      : _prefsOverride = prefs,
        _httpClient = httpClient ?? http.Client(),
        _tokens = tokenStore ?? (kIsWeb ? BrowserTokenStore() : SecureTokenStore()),
        defaultBaseUrl = defaultServer ?? resolveDefaultBaseUrl();

  final SharedPreferences? _prefsOverride;
  final http.Client _httpClient;
  final TokenStore _tokens;
  late SharedPreferences _prefs;

  /// Servidor usado quando a pessoa ainda não escolheu outro.
  final String defaultBaseUrl;

  bool ready = false;
  late String baseUrl = defaultBaseUrl;
  String? _token;
  Usuario? user;
  ThemeMode themeMode = ThemeMode.light;

  /// Alertas atuais (badge do sino). Atualizados pela tela Painel.
  List<Alerta> alertas = const [];

  bool get isLoggedIn => _token != null && user != null;

  late ApiClient _api = _buildApi();

  ApiClient get api => _api;

  ApiClient _buildApi() => ApiClient(
        baseUrl: baseUrl,
        token: _token,
        onUnauthorized: _sessionExpired,
        client: _httpClient,
      );

  void _sessionExpired() {
    if (_token == null) return;
    // Evita notificar no meio de um build: a UI reage ao próximo frame.
    Future.microtask(logout);
  }

  Future<void> init() async {
    _prefs = _prefsOverride ?? await SharedPreferences.getInstance();

    baseUrl = _prefs.getString('base_url') ?? defaultBaseUrl;
    themeMode = _themeFromName(_prefs.getString('tema'));

    try {
      _token = await _tokens.read();
    } catch (_) {
      _token = null; // keystore indisponível: pede login de novo
    }
    final cached = _prefs.getString('usuario');
    if (_token != null && cached != null) {
      try {
        user = Usuario.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      } catch (_) {
        user = null;
      }
    }
    _api = _buildApi();
    ready = true;
    notifyListeners();

    if (isLoggedIn) {
      // Atualiza os dados do perfil em segundo plano; erro de rede não derruba a sessão.
      try {
        final res = await _api.get('/me');
        await _saveUser(Usuario.fromJson(res['usuario'] as Map<String, dynamic>));
        notifyListeners();
      } on ApiException {
        // 401 já dispara logout via onUnauthorized
      }
    }
  }

  Future<void> login(String email, String senha, {String? serverUrl}) async {
    if (serverUrl != null && serverUrl.trim().isNotEmpty) {
      await setBaseUrl(serverUrl);
    }
    final client = ApiClient(baseUrl: baseUrl, client: _httpClient);
    final res = await client.post('/login', {'email': email.trim(), 'senha': senha});

    _token = res['token'] as String;
    try {
      await _tokens.write(_token!);
    } catch (_) {
      // O cofre do aparelho recusou gravar: a sessão vale até fechar o app, mas o login não falha.
    }
    await _saveUser(Usuario.fromJson(res['usuario'] as Map<String, dynamic>));
    _api = _buildApi();
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    user = null;
    alertas = const [];
    _api = _buildApi();
    try {
      await _tokens.clear();
    } catch (_) {
      // Sair nunca pode falhar por causa do cofre: o token em memória já foi descartado.
    }
    await _prefs.remove('usuario');
    notifyListeners();
  }

  Future<void> _saveUser(Usuario u) async {
    user = u;
    await _prefs.setString('usuario', jsonEncode(u.toJson()));
  }

  Future<void> setBaseUrl(String raw) async {
    final url = ApiClient.normalizeBaseUrl(raw);
    if (url.isEmpty || url == baseUrl) return;
    baseUrl = url;
    await _prefs.setString('base_url', url);
    _api = _buildApi();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    await _prefs.setString('tema', mode.name);
    notifyListeners();
  }

  void setAlertas(List<Alerta> list) {
    alertas = list;
    notifyListeners();
  }

  static ThemeMode _themeFromName(String? name) =>
      ThemeMode.values.where((m) => m.name == name).firstOrNull ?? ThemeMode.light;
}

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController controller, required super.child})
      : super(notifier: controller);

  /// Escuta mudanças (rebuild quando o estado muda).
  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Só lê, sem rebuild (use em initState / callbacks).
  static AppController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
