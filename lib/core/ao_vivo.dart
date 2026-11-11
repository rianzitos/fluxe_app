import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'api_client.dart';

/// Tempo real, como o "Ao vivo" das telas do site: de poucos em poucos segundos pergunta ao servidor
/// (GET /api/aovivo) se algo mudou na empresa (alguém passou na catraca, chegou uma pesagem, uma pessoa ou um
/// cartão foi alterado, um dispositivo caiu...). Quando muda, [mudancas] aumenta e a tela aberta se atualiza
/// sozinha; os acessos novos chegam em [eventos] para virar um aviso rápido.
///
/// Só consulta enquanto o app está aberto na tela ([retomar]/[pausar] acompanham o ciclo de vida do app) e para
/// de vez se o servidor ainda não tiver a rota (SystemFluxe antigo). Sem internet, espera cada vez mais entre as
/// tentativas (até 1 minuto) e volta ao normal na primeira resposta.
class AoVivo extends ChangeNotifier {
  AoVivo(this._api, {this.intervalo = const Duration(seconds: 8)});

  /// Lido a cada consulta: se a pessoa trocar o servidor nas Configurações, a próxima já vai para o novo.
  final ApiClient Function() _api;
  final Duration intervalo;
  static const _intervaloMaximo = Duration(seconds: 60);

  /// Aumenta toda vez que a assinatura do servidor muda (as telas escutam e recarregam).
  final ValueNotifier<int> mudancas = ValueNotifier<int>(0);

  final _eventos = StreamController<({List<EventoAcesso> eventos, int total})>.broadcast();

  /// Acessos novos desde a consulta anterior: até 5 detalhados e o [total] (pode ser maior).
  Stream<({List<EventoAcesso> eventos, int total})> get eventos => _eventos.stream;

  Timer? _timer;
  bool _rodando = false;
  bool _consultando = false;
  int _falhas = 0;
  String? _assinatura;
  int? _ultimoLog;

  /// false = sem resposta do servidor nas últimas tentativas ("Reconectando…").
  bool conectado = true;

  /// false = o servidor não tem a rota /api/aovivo (SystemFluxe antigo): o app funciona, só não se atualiza sozinho.
  bool disponivel = true;

  bool get rodando => _rodando;

  /// Começa (ou volta) a consultar, já com uma consulta imediata.
  void retomar() {
    if (_rodando || !disponivel) return;
    _rodando = true;
    _agendar(Duration.zero);
  }

  void pausar() {
    _rodando = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Esquece o que sabia (ao sair da conta ou trocar de servidor): a próxima consulta só reaprende o estado.
  /// Se estava consultando e [continuar] for true, continua (já no servidor novo).
  void reiniciar({bool continuar = true}) {
    final estava = _rodando;
    pausar();
    _assinatura = null;
    _ultimoLog = null;
    _falhas = 0;
    disponivel = true;
    if (!conectado) {
      conectado = true;
      notifyListeners();
    }
    if (estava && continuar) retomar();
  }

  void _agendar(Duration espera) {
    _timer?.cancel();
    if (!_rodando) return;
    _timer = Timer(espera, consultarAgora);
  }

  /// Uma consulta fora de hora (ex.: logo depois de uma ação que muda dados). Também usada pelo timer.
  Future<void> consultarAgora() async {
    if (_consultando || !disponivel) return;
    _consultando = true;
    try {
      final res = await _api().get('/aovivo', query: {if (_ultimoLog != null) 'ultimo': '$_ultimoLog'});
      _aplicar(EstadoAoVivo.fromJson(res));
      _falhas = 0;
      _marcarConectado(true);
    } on ApiException catch (e) {
      if (e.status == 404) {
        disponivel = false; // servidor antigo: não adianta insistir
        pausar();
        notifyListeners();
        return;
      }
      _falhas++;
      if (e.status == null) _marcarConectado(false); // sem resposta (rede); um erro do servidor não muda o indicador
    } catch (_) {
      _falhas++;
    } finally {
      _consultando = false;
    }
    if (!_rodando) return;
    // 8 s, 16 s, 32 s, 60 s... enquanto falhar
    final espera = _falhas == 0 ? intervalo : intervalo * (1 << _falhas.clamp(0, 4));
    _agendar(espera > _intervaloMaximo ? _intervaloMaximo : espera);
  }

  void _aplicar(EstadoAoVivo estado) {
    final primeira = _assinatura == null;
    final mudou = !primeira && estado.assinatura.isNotEmpty && estado.assinatura != _assinatura;
    _assinatura = estado.assinatura;
    final ultimo = _ultimoLog;
    _ultimoLog = estado.ultimoLog;

    if (ultimo != null && estado.novosAcessos > 0 && !_eventos.isClosed) {
      _eventos.add((eventos: estado.eventos, total: estado.novosAcessos));
    }
    if (mudou) mudancas.value++;
  }

  void _marcarConectado(bool valor) {
    if (conectado == valor) return;
    conectado = valor;
    notifyListeners();
  }

  @override
  void dispose() {
    pausar();
    _eventos.close();
    mudancas.dispose();
    super.dispose();
  }
}
