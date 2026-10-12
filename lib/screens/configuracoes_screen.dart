import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_state.dart';
import '../core/layout.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/page_header.dart';
import 'app_shell.dart';

/// Configurações: perfil (somente leitura), aparência, servidor e sair.
class ConfiguracoesScreen extends StatelessWidget {
  const ConfiguracoesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final user = app.user;

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
            child: Column(
              children: [
                const PageHeader(title: 'Configurações', subtitle: 'Perfil, aparência e conexão', showBell: false),
                Expanded(
                  child: PageList(children: [
                    if (user != null) _PerfilCard(app),
                    _TemaCard(app),
                    _ServidorCard(app),
                    _SobreCard(),
                    FilledButton.icon(
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
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PerfilCard extends StatelessWidget {
  final AppController app;
  const _PerfilCard(this.app);

  @override
  Widget build(BuildContext context) {
    final u = app.user!;
    final e = u.empresa;
    final local = [e.cidade, e.estado].where((s) => s != null && s.isNotEmpty).join(' - ');

    Widget linha(IconData icon, String label, String? valor) => (valor == null || valor.isEmpty)
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Icon(icon, size: 19, color: context.pal.textMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: AppText.muted(context, size: 12)),
                      Text(valor, style: AppText.strong(context, size: 14.5)),
                    ],
                  ),
                ),
              ],
            ),
          );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle('Informações Pessoais'),
          const SizedBox(height: 16),
          Row(
            children: [
              UserAvatar(u.nome, u.foto, radius: 30),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.nome, style: AppText.title(context, size: 18)),
                    const SizedBox(height: 4),
                    Pill(u.perfilRotulo, background: context.pal.accentSoft, foreground: AppColors.accentText),
                  ],
                ),
              ),
            ],
          ),
          linha(Icons.mail_outline_rounded, 'E-mail', u.email),
          linha(Icons.badge_outlined, 'Cargo', u.cargo),
          linha(Icons.phone_outlined, 'Telefone', u.telefone),
          linha(Icons.numbers_rounded, 'Matrícula', u.matricula),
          linha(Icons.apartment_rounded, 'Instituição', e.nome),
          linha(Icons.location_on_outlined, 'Localidade', local),
          linha(Icons.schedule_rounded, 'Horário de funcionamento', e.horario),
        ],
      ),
    );
  }
}

class _TemaCard extends StatelessWidget {
  final AppController app;
  const _TemaCard(this.app);

  @override
  Widget build(BuildContext context) {
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

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle('Aparência'),
          const SizedBox(height: 4),
          Text('Tema', style: AppText.muted(context)),
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
    );
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
                  Text('Sistema Inteligente de Controle de Acesso e Previsão de Demanda Alimentar · v1.0.0',
                      style: AppText.muted(context, size: 12.5)),
                ],
              ),
            ),
          ],
        ),
      );
}
