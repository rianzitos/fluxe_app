import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_state.dart';
import '../core/layout.dart';
import '../core/theme.dart';
import '../core/versao.dart';
import '../widgets/common.dart';
import '../widgets/navegacao.dart';
import '../widgets/page_header.dart';
import 'app_shell.dart';
import 'config_conta.dart';
import 'config_integracoes.dart';
import 'config_preferencias.dart';

/// Configurações, com as mesmas abas do site: Perfil, Aparência, Notificações, Sistema, Integrações (dispositivos
/// IoT) e Segurança, mais a aba Aplicativo (servidor, versão e sair). Tudo fala com o mesmo banco do site.
class ConfiguracoesScreen extends StatelessWidget {
  final AbaConfig abaInicial;
  const ConfiguracoesScreen({super.key, this.abaInicial = AbaConfig.perfil});

  static const _abas = [
    (AbaConfig.perfil, 'Perfil', Icons.person_outline_rounded),
    (AbaConfig.aparencia, 'Aparência', Icons.palette_outlined),
    (AbaConfig.notificacoes, 'Notificações', Icons.notifications_none_rounded),
    (AbaConfig.sistema, 'Sistema', Icons.tune_rounded),
    (AbaConfig.integracoes, 'Integrações', Icons.sensors_rounded),
    (AbaConfig.seguranca, 'Segurança', Icons.shield_outlined),
    (AbaConfig.aplicativo, 'Aplicativo', Icons.phone_android_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return DefaultTabController(
      length: _abas.length,
      initialIndex: abaInicial.index,
      child: Scaffold(
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
              child: Column(
                children: [
                  const PageHeader(
                    title: 'Configurações',
                    subtitle: 'Preferências, integrações e segurança',
                    showBell: false,
                  ),
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    labelColor: pal.text,
                    unselectedLabelColor: pal.textMuted,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
                    indicatorColor: AppColors.accent,
                    indicatorWeight: 3,
                    dividerColor: pal.border,
                    tabs: [
                      for (final (aba, rotulo, icone) in _abas)
                        Tab(key: Key('aba-${aba.name}'), height: 46, icon: null, child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [Icon(icone, size: 18), const SizedBox(width: 6), Text(rotulo)],
                        )),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Expanded(
                    child: TabBarView(
                      children: [
                        PerfilTab(),
                        AparenciaTab(),
                        NotificacoesTab(),
                        SistemaTab(),
                        IntegracoesTab(),
                        SegurancaTab(),
                        _AplicativoTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Servidor, versão do app e sair da conta.
class _AplicativoTab extends StatelessWidget {
  const _AplicativoTab();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return PageList(children: [
      _ServidorCard(app),
      _SobreCard(),
      FilledButton.icon(
        key: const Key('btn-sair-config'),
        onPressed: () async {
          final ok = await confirmLogout(context);
          if (ok && context.mounted) {
            Navigator.of(context).popUntil((r) => r.isFirst);
            await app.logout();
          }
        },
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.black,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.logout_rounded, color: AppColors.accent),
        label: const Text('Sair da conta', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    ]);
  }
}

class _ServidorCard extends StatefulWidget {
  final AppController app;
  const _ServidorCard(this.app);

  @override
  State<_ServidorCard> createState() => _ServidorCardState();
}

class _ServidorCardState extends State<_ServidorCard> {
  late final _url = TextEditingController(text: widget.app.baseUrl);
  bool _testing = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final messenger = ScaffoldMessenger.of(context);
    final novo = ApiClient.normalizeBaseUrl(_url.text);
    if (novo.isEmpty) return;

    setState(() => _testing = true);
    try {
      // Testa o endereço novo com o mesmo token antes de trocar.
      final teste = ApiClient(baseUrl: novo, token: widget.app.api.token);
      try {
        await teste.get('/me');
      } finally {
        teste.close();
      }
      await widget.app.setBaseUrl(novo);
      _url.text = novo;
      messenger.showSnackBar(const SnackBar(content: Text('Servidor atualizado.')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e.isUnauthorized
            ? 'Esse servidor não reconhece sua sessão. Saia e entre novamente nele.'
            : e.message),
      ));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle('Servidor'),
          const SizedBox(height: 4),
          Text('Endereço do SystemFluxe (mesmo banco de dados da versão web).', style: AppText.muted(context)),
          const SizedBox(height: 12),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            style: TextStyle(color: pal.text, fontSize: 14.5),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.link_rounded, color: pal.textMuted),
              filled: true,
              fillColor: pal.chip,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: pal.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: pal.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.accent, width: 1.4)),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _testing ? null : _salvar,
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
              child: _testing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Testar e salvar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SobreCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => AppCard(
        child: Row(
          children: [
            // emblema do SICAPDA sobre o preto da marca
            Container(
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: AppColors.black, borderRadius: BorderRadius.circular(12)),
              child: Image.asset('images/logo_sicapda.png', fit: BoxFit.contain, semanticLabel: 'Logo do SICAPDA'),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SICAPDA by Fluxe', style: AppText.strong(context, size: 15)),
                  const SizedBox(height: 2),
                  Text('Sistema Inteligente de Controle de Acesso e Previsão de Demanda Alimentar · versão $kVersaoApp',
                      key: const Key('versao-app'), style: AppText.muted(context, size: 12.5)),
                ],
              ),
            ),
          ],
        ),
      );
}
