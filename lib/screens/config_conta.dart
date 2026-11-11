import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/arquivos.dart';
import '../core/config_service.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/formularios.dart';
import 'app_shell.dart' show UserAvatar;

/// Abas Perfil e Segurança de Configurações: as mesmas regras e mensagens do site (o servidor usa o mesmo código).

final _emailValido = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

// ─── Perfil ────────────────────────────────────────────────────────────────

/// Nome, e-mail e cargo editáveis, foto do perfil e os dados da conta que só o administrador muda pelo site.
class PerfilTab extends StatefulWidget {
  const PerfilTab({super.key});

  @override
  State<PerfilTab> createState() => _PerfilTabState();
}

class _PerfilTabState extends State<PerfilTab> {
  late final AppController _app = AppScope.read(context);
  late final _nome = TextEditingController(text: _app.user?.nome ?? '');
  late final _email = TextEditingController(text: _app.user?.email ?? '');
  late final _cargo = TextEditingController(text: _app.user?.cargo ?? '');
  final _senhaAtual = TextEditingController();

  bool _enviando = false;
  bool _enviandoFoto = false;
  String? _erro;
  String? _sucesso;

  @override
  void initState() {
    super.initState();
    _email.addListener(() => setState(() {})); // mostra/esconde o campo da senha atual
  }

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _cargo.dispose();
    _senhaAtual.dispose();
    super.dispose();
  }

  ConfigService get _servico => ConfigService(_app.api);

  /// Trocar o e-mail muda o login: o servidor pede a senha atual (igual ao site).
  bool get _emailMudou => _email.text.trim().toLowerCase() != (_app.user?.email ?? '').toLowerCase();

  Future<void> _salvar() async {
    FocusScope.of(context).unfocus();
    final nome = _nome.text.trim();
    final email = _email.text.trim().toLowerCase();
    String? erro;
    if (nome.isEmpty || nome.length > 150) {
      erro = 'Informe um nome válido (até 150 caracteres).';
    } else if (!_emailValido.hasMatch(email)) {
      erro = 'Informe um e-mail válido.';
    } else if (_cargo.text.trim().length > 100) {
      erro = 'O cargo pode ter no máximo 100 caracteres.';
    } else if (_emailMudou && _senhaAtual.text.isEmpty) {
      erro = 'Para alterar o e-mail, informe sua senha atual.';
    }
    if (erro != null) {
      setState(() {
        _erro = erro;
        _sucesso = null;
      });
      return;
    }

    setState(() {
      _enviando = true;
      _erro = null;
      _sucesso = null;
    });
    try {
      final r = await _servico.atualizarPerfil(
        nome: nome,
        email: email,
        cargo: _cargo.text.trim(),
        senhaAtual: _emailMudou ? _senhaAtual.text : '',
      );
      await _app.atualizarUsuario(r.usuario);
      if (!mounted) return;
      _senhaAtual.clear();
      _email.text = r.usuario.email;
      setState(() => _sucesso = r.mensagem);
    } catch (e) {
      // Corpo em bloco: com "=>" o callback devolveria o Future, e o Flutter (em debug e nos testes) recusa.
      if (mounted) {
        setState(() {
          _erro = mensagemDoErro(e);
        });
      }
    } finally {
      // Corpo em bloco: com "=>" o callback devolveria o Future, e o Flutter (em debug e nos testes) recusa.
      if (mounted) {
        setState(() {
          _enviando = false;
        });
      }
    }
  }

  Future<void> _trocarFoto() async {
    final messenger = ScaffoldMessenger.of(context);
    final arquivo = await escolherArquivo(imagem: true);
    if (arquivo == null || !mounted) return;

    setState(() => _enviandoFoto = true);
    try {
      final foto = await prepararFotoDePerfil(arquivo.bytes);
      final r = await _servico.enviarFoto(foto);
      await _app.atualizarUsuario(r.usuario);
      messenger.showSnackBar(SnackBar(content: Text(r.mensagem)));
    } on Exception catch (e) {
      final texto = e is FormatException || e.toString().contains('decode') || e.toString().contains('Codec')
          ? 'Não foi possível abrir esta imagem. Escolha uma foto JPG ou PNG.'
          : mensagemDoErro(e);
      messenger.showSnackBar(SnackBar(content: Text(texto)));
    } finally {
      // Corpo em bloco: com "=>" o callback devolveria o Future, e o Flutter (em debug e nos testes) recusa.
      if (mounted) {
        setState(() {
          _enviandoFoto = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).user;
    if (user == null) return const SizedBox.shrink();
    final e = user.empresa;
    final local = [e.cidade, e.estado].where((s) => s != null && s.isNotEmpty).join(' - ');

    return PageList(children: [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CardTitle('Informações Pessoais'),
            const SizedBox(height: 16),
            Row(
              children: [
                Stack(
                  children: [
                    UserAvatar(user.nome, user.foto, radius: 34),
                    if (_enviandoFoto)
                      const Positioned.fill(
                        child: CircleAvatar(
                          backgroundColor: Color(0x99000000),
                          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.nome, style: AppText.title(context, size: 18), overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(user.email, style: AppText.muted(context, size: 13), overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        key: const Key('btn-alterar-foto'),
                        onPressed: _enviandoFoto ? null : _trocarFoto,
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: AppColors.accentText),
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: const Text('Alterar foto', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              key: const Key('perfil-nome'),
              controller: _nome,
              textCapitalization: TextCapitalization.words,
              maxLength: 150,
              decoration: decoracaoCampo(context, 'Nome completo', icone: Icons.person_outline_rounded).copyWith(counterText: ''),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('perfil-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              maxLength: 150,
              decoration: decoracaoCampo(context, 'E-mail', icone: Icons.mail_outline_rounded).copyWith(counterText: ''),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('perfil-cargo'),
              controller: _cargo,
              maxLength: 100,
              decoration: decoracaoCampo(context, 'Cargo', icone: Icons.badge_outlined).copyWith(counterText: ''),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: ValueKey('instituicao-${e.nome}'),
              initialValue: e.nome,
              enabled: false,
              decoration: decoracaoCampo(context, 'Instituição', icone: Icons.apartment_rounded),
            ),
            if (_emailMudou) ...[
              const SizedBox(height: 14),
              TextField(
                key: const Key('perfil-senha-atual'),
                controller: _senhaAtual,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: decoracaoCampo(context, 'Senha atual (para alterar o e-mail)', icone: Icons.lock_outline_rounded),
              ),
            ],
            if (_erro != null) ...[const SizedBox(height: 14), AvisoFormulario(_erro!)],
            if (_sucesso != null) ...[const SizedBox(height: 14), AvisoFormulario(_sucesso!, sucesso: true)],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: BotaoEnviar(
                key: const Key('btn-salvar-perfil'),
                rotulo: 'Salvar alterações',
                icone: Icons.save_outlined,
                enviando: _enviando,
                onPressed: _salvar,
              ),
            ),
          ],
        ),
      ),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CardTitle('Dados da conta'),
            _Linha(Icons.verified_user_outlined, 'Perfil de acesso', user.perfilRotulo),
            _Linha(Icons.phone_outlined, 'Telefone', user.telefone),
            _Linha(Icons.numbers_rounded, 'Matrícula', user.matricula),
            _Linha(Icons.location_on_outlined, 'Localidade', local),
            _Linha(Icons.schedule_rounded, 'Horário de funcionamento', e.horario),
          ],
        ),
      ),
    ]);
  }
}

class _Linha extends StatelessWidget {
  final IconData icone;
  final String rotulo;
  final String? valor;
  const _Linha(this.icone, this.rotulo, this.valor);

  @override
  Widget build(BuildContext context) {
    if (valor == null || valor!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Icon(icone, size: 19, color: context.pal.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rotulo, style: AppText.muted(context, size: 12)),
                Text(valor!, style: AppText.strong(context, size: 14.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Segurança ─────────────────────────────────────────────────────────────

/// Alterar senha, autenticação em duas etapas ("Em breve", como no site) e as sessões abertas no site.
class SegurancaTab extends StatefulWidget {
  const SegurancaTab({super.key});

  @override
  State<SegurancaTab> createState() => _SegurancaTabState();
}

class _SegurancaTabState extends State<SegurancaTab> {
  final _atual = TextEditingController();
  final _nova = TextEditingController();
  final _confirmar = TextEditingController();
  bool _mostrar = false;
  bool _enviando = false;
  String? _erro;
  String? _sucesso;

  late Future<List<SessaoWeb>?> _sessoes = _carregarSessoes();

  ConfigService get _servico => ConfigService(AppScope.read(context).api);

  Future<List<SessaoWeb>?> _carregarSessoes() => comAvisoDeServidorAntigo(() => _servico.sessoes());

  @override
  void dispose() {
    _atual.dispose();
    _nova.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _trocarSenha() async {
    FocusScope.of(context).unfocus();
    String? erro;
    if (_atual.text.isEmpty || _nova.text.isEmpty || _confirmar.text.isEmpty) {
      erro = 'Preencha todos os campos de senha.';
    } else if (_nova.text.length < 8) {
      erro = 'A nova senha deve ter pelo menos 8 caracteres.';
    } else if (_nova.text != _confirmar.text) {
      erro = 'As senhas não coincidem.';
    }
    if (erro != null) {
      setState(() {
        _erro = erro;
        _sucesso = null;
      });
      return;
    }

    setState(() {
      _enviando = true;
      _erro = null;
      _sucesso = null;
    });
    try {
      final mensagem = await _servico.atualizarSenha(atual: _atual.text, nova: _nova.text, confirmar: _confirmar.text);
      if (!mounted) return;
      _atual.clear();
      _nova.clear();
      _confirmar.clear();
      setState(() => _sucesso = mensagem);
    } catch (e) {
      // Corpo em bloco: com "=>" o callback devolveria o Future, e o Flutter (em debug e nos testes) recusa.
      if (mounted) {
        setState(() {
          _erro = mensagemDoErro(e);
        });
      }
    } finally {
      // Corpo em bloco: com "=>" o callback devolveria o Future, e o Flutter (em debug e nos testes) recusa.
      if (mounted) {
        setState(() {
          _enviando = false;
        });
      }
    }
  }

  Future<void> _encerrar(SessaoWeb? sessao) async {
    final ok = await confirmar(
      context,
      titulo: sessao == null ? 'Encerrar todas as sessões do site?' : 'Encerrar esta sessão?',
      texto: sessao == null
          ? 'Quem estiver usando sua conta pelo navegador precisará entrar de novo. O aplicativo continua conectado.'
          : '${sessao.dispositivo} precisará entrar de novo na próxima vez que usar o site.',
      acao: 'Encerrar',
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final mensagem = sessao == null ? await _servico.encerrarTodasAsSessoes() : await _servico.encerrarSessao(sessao.id);
      messenger.showSnackBar(SnackBar(content: Text(mensagem)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(mensagemDoErro(e))));
    }
    // Corpo em bloco: com "=>" o callback devolveria o Future, e o Flutter (em debug e nos testes) recusa.
    if (mounted) {
      setState(() {
        _sessoes = _carregarSessoes();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget campoSenha(Key key, TextEditingController c, String rotulo, List<String> dicas) => TextField(
          key: key,
          controller: c,
          obscureText: !_mostrar,
          maxLength: 72,
          autofillHints: dicas,
          decoration: decoracaoCampo(context, rotulo, icone: Icons.lock_outline_rounded).copyWith(counterText: ''),
        );

    return RefreshIndicator(
      color: Colors.black,
      backgroundColor: AppColors.accent,
      onRefresh: () async {
        final f = _carregarSessoes();
        setState(() {
          _sessoes = f;
        });
        try {
          await f;
        } catch (_) {}
      },
      child: PageList(children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CardTitle(
                'Alterar senha',
                trailing: IconButton(
                  tooltip: _mostrar ? 'Esconder senhas' : 'Mostrar senhas',
                  onPressed: () => setState(() => _mostrar = !_mostrar),
                  icon: Icon(_mostrar ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: context.pal.textMuted),
                ),
              ),
              const SizedBox(height: 12),
              campoSenha(const Key('senha-atual'), _atual, 'Senha atual', const [AutofillHints.password]),
              const SizedBox(height: 14),
              campoSenha(const Key('senha-nova'), _nova, 'Nova senha (mínimo 8 caracteres)', const [AutofillHints.newPassword]),
              const SizedBox(height: 14),
              campoSenha(const Key('senha-confirmar'), _confirmar, 'Confirmar nova senha', const [AutofillHints.newPassword]),
              if (_erro != null) ...[const SizedBox(height: 14), AvisoFormulario(_erro!)],
              if (_sucesso != null) ...[const SizedBox(height: 14), AvisoFormulario(_sucesso!, sucesso: true)],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: BotaoEnviar(
                  key: const Key('btn-trocar-senha'),
                  rotulo: 'Atualizar senha',
                  icone: Icons.shield_outlined,
                  enviando: _enviando,
                  onPressed: _trocarSenha,
                ),
              ),
            ],
          ),
        ),
        AppCard(
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
                        Text('Autenticação em duas etapas', style: AppText.strong(context, size: 14.5)),
                        const EtiquetaEmBreve(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Vai exigir um código adicional ao entrar na conta. Ainda não está ativa: por enquanto o login pede só e-mail e senha.',
                        style: AppText.muted(context, size: 12.5)),
                  ],
                ),
              ),
              const Switch(value: false, onChanged: null),
            ],
          ),
        ),
        AppCard(
          child: FutureBuilder<List<SessaoWeb>?>(
            future: _sessoes,
            builder: (context, snap) {
              final filhos = <Widget>[const CardTitle('Sessões ativas no site'), const SizedBox(height: 4)];
              if (snap.connectionState != ConnectionState.done) {
                filhos.add(const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
                ));
              } else if (snap.hasError) {
                filhos.add(EmptyNote(mensagemDoErro(snap.error!)));
              } else if (snap.data == null) {
                filhos.add(const EmptyNote('O controle de sessões ainda não está disponível neste servidor.'));
              } else if (snap.data!.isEmpty) {
                filhos.add(const EmptyNote('Sua conta não está aberta em nenhum navegador agora.'));
              } else {
                for (final s in snap.data!) {
                  filhos.add(_ItemSessao(s, onEncerrar: () => _encerrar(s)));
                }
                if (snap.data!.length > 1) {
                  filhos.add(Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: BotaoEnviar(
                      rotulo: 'Encerrar todas as sessões do site',
                      icone: Icons.logout_rounded,
                      enviando: false,
                      secundario: true,
                      onPressed: () => _encerrar(null),
                    ),
                  ));
                }
              }
              filhos.add(const SizedBox(height: 12));
              filhos.add(const NotaConfig(
                  'Mostra onde sua conta está aberta pelo site (navegador). O aplicativo entra com outro tipo de acesso e não aparece aqui.'));
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: filhos);
            },
          ),
        ),
      ]),
    );
  }
}

class _ItemSessao extends StatelessWidget {
  final SessaoWeb sessao;
  final VoidCallback onEncerrar;
  const _ItemSessao(this.sessao, {required this.onEncerrar});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: context.pal.chip, borderRadius: BorderRadius.circular(12)),
              child: Icon(sessao.celular ? Icons.smartphone_rounded : Icons.laptop_rounded, color: context.pal.text, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sessao.dispositivo, style: AppText.strong(context, size: 14)),
                  Text('IP ${sessao.ip} · ${sessao.ultimoAcesso}', style: AppText.muted(context, size: 12.5)),
                ],
              ),
            ),
            TextButton(onPressed: onEncerrar, child: const Text('Encerrar')),
          ],
        ),
      );
}
