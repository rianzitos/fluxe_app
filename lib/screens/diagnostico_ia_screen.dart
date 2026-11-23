import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_state.dart';
import '../core/layout.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/page_header.dart';

/// Diagnóstico da IA do assistente (o mesmo de /assistente/diagnostico do site), só para o administrador:
/// a configuração lida do servidor e um teste passo a passo que diz onde a IA falha. Útil quando o chat avisa
/// que "a IA não respondeu agora" e respondeu pelo modo básico.
class DiagnosticoIAScreen extends StatefulWidget {
  const DiagnosticoIAScreen({super.key});

  /// O teste faz de 3 a 5 chamadas reais à IA; o servidor dá até 40 s para cada uma.
  static const timeoutTeste = Duration(seconds: 180);

  @override
  State<DiagnosticoIAScreen> createState() => _DiagnosticoIAScreenState();
}

class _DiagnosticoIAScreenState extends State<DiagnosticoIAScreen> {
  DiagnosticoIA? _dados;
  Object? _erro;
  bool _testando = false;
  String? _erroTeste;

  ApiClient get _api => AppScope.read(context).api;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _erro = null);
    try {
      final d = DiagnosticoIA.fromJson(await _api.get('/assistente/diagnostico'));
      if (mounted) setState(() => _dados = d);
    } catch (e) {
      if (mounted) setState(() => _erro = _explicar(e));
    }
  }

  Future<void> _testar() async {
    setState(() {
      _testando = true;
      _erroTeste = null;
    });
    try {
      final d = DiagnosticoIA.fromJson(
          await _api.post('/assistente/diagnostico', const {}, timeout: DiagnosticoIAScreen.timeoutTeste));
      if (mounted) setState(() => _dados = d);
    } catch (e) {
      final erro = _explicar(e);
      if (mounted) setState(() => _erroTeste = erro is ApiException ? erro.message : 'Não foi possível testar agora.');
    } finally {
      if (mounted) setState(() => _testando = false);
    }
  }

  /// SystemFluxe anterior à 1.4 não tem a rota: explica em vez de mostrar "Rota não encontrada".
  Object _explicar(Object e) => e is ApiException && e.status == 404
      ? const ApiException('O servidor ainda não oferece o diagnóstico pelo aplicativo. Atualize o SystemFluxe '
          'ou abra /assistente/diagnostico no site.')
      : e;

  @override
  Widget build(BuildContext context) {
    final d = _dados;
    final Widget corpo;
    if (d == null && _erro != null) {
      corpo = ErrorState(error: _erro!, onRetry: _carregar);
    } else if (d == null) {
      corpo = const LoadingState();
    } else {
      corpo = PageList(children: [
        Text('Mostra como a IA está configurada neste servidor e onde ela falha. A chave nunca aparece inteira.',
            style: AppText.muted(context, size: 13.5)),
        _configuracao(d),
        _teste(d),
      ]);
    }

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
            child: Column(
              children: [
                const PageHeader(title: 'Diagnóstico da IA', subtitle: 'Só para administradores', showBell: false),
                Expanded(child: corpo),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Color _cor(String estado) => switch (estado) {
        'erro' => AppColors.red,
        'aviso' => AppColors.warning,
        _ => AppColors.success,
      };

  Widget _configuracao(DiagnosticoIA d) {
    final pal = context.pal;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CardTitle('Configuração lida do servidor'),
          const SizedBox(height: 6),
          for (var i = 0; i < d.configuracao.length; i++) ...[
            if (i > 0) Divider(color: pal.border, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: Text(d.configuracao[i].rotulo, style: AppText.muted(context, size: 13))),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: Text(
                      d.configuracao[i].valor,
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13.5, color: _cor(d.configuracao[i].estado)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _teste(DiagnosticoIA d) {
    final pal = context.pal;
    final etapas = d.etapas;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CardTitle('Teste'),
          const SizedBox(height: 8),
          if (etapas == null)
            Text('O teste faz de 3 a 5 chamadas reais à IA (usa um pouco da cota gratuita) e leva alguns segundos.',
                style: AppText.muted(context, size: 13))
          else ...[
            for (final (i, e) in etapas.indexed)
              Container(
                key: Key('etapa-${i + 1}-${e.ok ? 'ok' : 'falhou'}'),
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(TextSpan(children: [
                      TextSpan(
                        text: e.ok ? '✔ Passou' : '✖ Falhou',
                        style: TextStyle(fontWeight: FontWeight.w700, color: e.ok ? AppColors.success : AppColors.red),
                      ),
                      TextSpan(text: ' · ${e.titulo} ', style: TextStyle(color: pal.text)),
                      TextSpan(text: '(${e.ms} ms)', style: TextStyle(color: pal.textMuted, fontSize: 12)),
                    ]), style: const TextStyle(fontSize: 13.5)),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: pal.background, borderRadius: BorderRadius.circular(8)),
                      // Selecionável: dá para copiar o motivo e mandar para quem cuida do servidor.
                      child: SelectableText(e.detalhe, style: TextStyle(fontSize: 12.5, color: pal.text)),
                    ),
                  ],
                ),
              ),
            Text(
              d.tudoCerto
                  ? 'Tudo certo: a IA está funcionando. Confira se a etapa 4 recusou a pergunta fora do assunto.'
                  : 'O teste parou na primeira etapa que falhou. Siga o que está escrito nela. Se não resolver, copie '
                      'o motivo e envie para quem cuida do servidor.',
              key: const Key('resultado-diagnostico'),
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13.5, color: d.tudoCerto ? AppColors.success : AppColors.red),
            ),
          ],
          if (_erroTeste != null) ...[
            const SizedBox(height: 10),
            Text(_erroTeste!, style: const TextStyle(color: AppColors.red, fontSize: 13.5)),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const Key('testar-ia'),
            onPressed: _testando ? null : _testar,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            icon: _testando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.play_arrow_rounded),
            label: Text(_testando
                ? 'Testando… pode levar até um minuto'
                : (etapas == null ? 'Testar a IA agora' : 'Testar de novo')),
          ),
        ],
      ),
    );
  }
}
