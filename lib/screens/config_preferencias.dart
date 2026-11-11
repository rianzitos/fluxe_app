import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/config_service.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/formularios.dart';

/// Abas Aparência, Notificações e Sistema de Configurações.

// ─── Aparência ─────────────────────────────────────────────────────────────

class AparenciaTab extends StatelessWidget {
  const AparenciaTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final pal = context.pal;
    Widget opcao(ThemeMode mode, String label, IconData icon) {
      final ativo = app.themeMode == mode;
      return Expanded(
        child: GestureDetector(
          onTap: () => app.setThemeMode(mode),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: ativo ? pal.accentSoft : pal.chip,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ativo ? AppColors.accent : pal.border, width: ativo ? 1.6 : 1),
            ),
            child: Column(
              children: [
                Icon(icon, color: ativo ? AppColors.accent : pal.textMuted),
                const SizedBox(height: 6),
                Text(label, style: AppText.strong(context, size: 13)),
              ],
            ),
          ),
        ),
      );
    }

    return PageList(children: [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CardTitle('Aparência'),
            const SizedBox(height: 4),
            Text('Tema do aplicativo neste aparelho.', style: AppText.muted(context)),
            const SizedBox(height: 12),
            Row(
              children: [
                opcao(ThemeMode.light, 'Claro', Icons.light_mode_rounded),
                opcao(ThemeMode.dark, 'Escuro', Icons.dark_mode_rounded),
                opcao(ThemeMode.system, 'Sistema', Icons.brightness_auto_rounded),
              ],
            ),
          ],
        ),
      ),
    ]);
  }
}

// ─── Notificações e Sistema (preferências da conta, guardadas no servidor) ─

/// Carrega as preferências uma vez para as duas abas (Notificações e Sistema).
mixin _CarregaPreferencias<T extends StatefulWidget> on State<T> {
  late Future<PreferenciasData> preferencias = carregar();

  ConfigService get servico => ConfigService(AppScope.read(context).api);

  Future<PreferenciasData> carregar() => comAvisoDeServidorAntigo(() => servico.preferencias());

  void recarregar() {
    setState(() {
      preferencias = carregar();
    });
  }

  Future<void> puxarParaAtualizar() async {
    final f = carregar();
    setState(() {
      preferencias = f;
    });
    try {
      await f;
    } catch (_) {}
  }
}

/// Quais alertas aparecem no sino e no Painel (a escolha é da conta e vale também no site).
class NotificacoesTab extends StatefulWidget {
  const NotificacoesTab({super.key});

  @override
  State<NotificacoesTab> createState() => _NotificacoesTabState();
}

class _NotificacoesTabState extends State<NotificacoesTab> with _CarregaPreferencias {
  /// Estado mostrado na hora (antes da resposta do servidor); volta atrás se o servidor recusar.
  final _ligadas = <String, bool>{};
  final _salvando = <String>{};

  Future<void> _alternar(PreferenciaNotificacao n, bool ativo) async {
    final app = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _ligadas[n.chave] = ativo;
      _salvando.add(n.chave);
    });
    try {
      await servico.salvarNotificacao(n.chave, ativo);
      await app.atualizarAlertas(); // o número do sino muda na hora
    } catch (e) {
      if (mounted) setState(() => _ligadas[n.chave] = !ativo);
      messenger.showSnackBar(SnackBar(content: Text(mensagemDoErro(e))));
    } finally {
      if (mounted) setState(() => _salvando.remove(n.chave));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncBody<PreferenciasData>(
      future: preferencias,
      onRefresh: puxarParaAtualizar,
      onRetry: recarregar,
      builder: (context, d) => PageList(children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CardTitle('Notificações'),
              const SizedBox(height: 4),
              Text('Escolha quais eventos aparecem no sino e na lista de alertas do Painel. Vale só para a sua conta, no '
                  'aplicativo e no site.', style: AppText.muted(context)),
              const SizedBox(height: 6),
              for (final n in d.notificacoes)
                _ItemNotificacao(
                  n,
                  ativo: n.disponivel && (_ligadas[n.chave] ?? n.ativo),
                  salvando: _salvando.contains(n.chave),
                  onChanged: n.disponivel ? (v) => _alternar(n, v) : null,
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _ItemNotificacao extends StatelessWidget {
  final PreferenciaNotificacao n;
  final bool ativo;
  final bool salvando;
  final ValueChanged<bool>? onChanged;
  const _ItemNotificacao(this.n, {required this.ativo, required this.salvando, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(n.label, style: AppText.strong(context, size: 14.5)),
                      if (!n.disponivel) const EtiquetaEmBreve(),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(n.descricao, style: AppText.muted(context, size: 12.5)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Switch(
              key: Key('notificacao-${n.chave}'),
              value: ativo,
              activeTrackColor: AppColors.accent,
              onChanged: salvando ? null : onChanged,
            ),
          ],
        ),
      );
}

/// Período padrão e itens por página dos Relatórios (da conta, iguais no site e no app), o fuso (fixo) e o
/// tempo real deste aparelho.
class SistemaTab extends StatefulWidget {
  const SistemaTab({super.key});

  @override
  State<SistemaTab> createState() => _SistemaTabState();
}

class _SistemaTabState extends State<SistemaTab> with _CarregaPreferencias {
  String? _periodo;
  int? _itens;
  bool _enviando = false;
  String? _erro;
  String? _sucesso;

  Future<void> _salvar(PreferenciasData d) async {
    setState(() {
      _enviando = true;
      _erro = null;
      _sucesso = null;
    });
    try {
      final mensagem = await servico.salvarSistema(periodoPadrao: _periodo ?? d.periodoPadrao, itensPagina: _itens ?? d.itensPagina);
      if (mounted) setState(() => _sucesso = mensagem);
    } catch (e) {
      if (mounted) setState(() => _erro = mensagemDoErro(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final tempoReal = AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Atualizar em tempo real', style: AppText.strong(context, size: 14.5)),
                const SizedBox(height: 2),
                Text('As telas se atualizam sozinhas quando alguém passa na catraca, chega uma pesagem ou um cadastro muda, '
                    'e os acessos novos aparecem num aviso rápido. Vale para este aparelho.', style: AppText.muted(context, size: 12.5)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch(
            key: const Key('switch-tempo-real'),
            value: app.aoVivoAtivo,
            activeTrackColor: AppColors.accent,
            onChanged: app.setAoVivoAtivo,
          ),
        ],
      ),
    );

    return AsyncBody<PreferenciasData>(
      future: preferencias,
      onRefresh: puxarParaAtualizar,
      onRetry: recarregar,
      builder: (context, d) {
        final periodo = _periodo ?? d.periodoPadrao;
        final itens = _itens ?? d.itensPagina;
        return PageList(children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CardTitle('Relatórios'),
                const SizedBox(height: 4),
                Text('Como os Relatórios abrem para você, no aplicativo e no site.', style: AppText.muted(context)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: const Key('periodo-padrao'),
                  initialValue: d.periodos.any((p) => p.valor == periodo) ? periodo : d.periodos.first.valor,
                  decoration: decoracaoCampo(context, 'Período padrão dos relatórios', icone: Icons.date_range_rounded),
                  items: [for (final p in d.periodos) DropdownMenuItem(value: p.valor, child: Text(p.rotulo))],
                  onChanged: (v) => setState(() {
                    _periodo = v;
                    _sucesso = null;
                  }),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  key: const Key('itens-pagina'),
                  initialValue: d.opcoesItens.contains(itens) ? itens : d.opcoesItens.first,
                  decoration: decoracaoCampo(context, 'Itens por página nos relatórios', icone: Icons.format_list_numbered_rounded),
                  items: [for (final n in d.opcoesItens) DropdownMenuItem(value: n, child: Text('$n'))],
                  onChanged: (v) => setState(() {
                    _itens = v;
                    _sucesso = null;
                  }),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: d.fuso,
                  enabled: false,
                  decoration: decoracaoCampo(context, 'Fuso horário', icone: Icons.public_rounded),
                ),
                if (_erro != null) ...[const SizedBox(height: 14), AvisoFormulario(_erro!)],
                if (_sucesso != null) ...[const SizedBox(height: 14), AvisoFormulario(_sucesso!, sucesso: true)],
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: BotaoEnviar(
                    key: const Key('btn-salvar-sistema'),
                    rotulo: 'Salvar alterações',
                    icone: Icons.save_outlined,
                    enviando: _enviando,
                    onPressed: () => _salvar(d),
                  ),
                ),
                const SizedBox(height: 12),
                const NotaConfig('O fuso é fixo: as catracas gravam os horários dos acessos no horário de Brasília, e os '
                    'relatórios e a previsão leem no mesmo horário.'),
              ],
            ),
          ),
          tempoReal,
        ]);
      },
    );
  }
}
