import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_state.dart';
import '../core/cadastro_service.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'cadastro_formularios.dart';

/// Aba Cadastro de Pessoas: quem está cadastrado e com quais cartões. O administrador da empresa adiciona e edita
/// pessoas, vincula cartões (passando o cartão numa catraca, ele aparece na lista para escolher), ativa/desativa
/// pessoas e cartões e remove cartões; os demais usuários só consultam. As regras são as do site, no servidor.
class CadastroPessoasTab extends StatefulWidget {
  final ValueListenable<int> tabRefresh;

  /// De quanto em quanto tempo a lista de cartões lidos nas catracas é atualizada nos formulários.
  final Duration intervaloLeituras;

  const CadastroPessoasTab({super.key, required this.tabRefresh, this.intervaloLeituras = const Duration(seconds: 3)});

  @override
  State<CadastroPessoasTab> createState() => _CadastroPessoasTabState();
}

class _CadastroPessoasTabState extends State<CadastroPessoasTab> with TabRefresh {
  late Future<CadastroData> _future;
  final _busca = TextEditingController();

  @override
  ValueListenable<int> get tabRefresh => widget.tabRefresh;

  // Lido na hora de usar: se a pessoa trocar o servidor nas Configurações, a API muda.
  CadastroService get _servico => CadastroService(AppScope.read(context).api);

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<CadastroData> _load() async {
    try {
      return await _servico.carregar();
    } on ApiException catch (e) {
      // O app foi atualizado antes do SystemFluxe do servidor: as rotas novas ainda não existem lá.
      if (e.status == 404) {
        throw const ApiException(
          'O servidor ainda não tem o cadastro pelo aplicativo. Atualize o SystemFluxe e tente de novo.',
          status: 404,
        );
      }
      rethrow;
    }
  }

  // setState com corpo em bloco: com "=>" o callback devolveria o Future, e o Flutter (em debug e nos testes) recusa.
  @override
  void reload() {
    if (mounted) {
      setState(() {
        _future = _load();
      });
    }
  }

  Future<void> _refresh() async {
    final f = _load();
    setState(() {
      _future = f;
    });
    try {
      await f;
    } catch (_) {}
  }

  // ─── Ações ─────────────────────────────────────────────────────────────

  /// Chamado pelos formulários quando o servidor aceitou: avisa e atualiza a lista.
  void _salvo(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem)));
    reload();
  }

  /// Ações rápidas (ativar/desativar/remover): avisa com a mensagem do servidor, ou com o motivo da recusa.
  Future<void> _executar(Future<String> Function() acao) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final mensagem = await acao();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(mensagem)));
      reload();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Não foi possível concluir. Tente novamente.')));
    }
  }

  Future<bool> _confirmar({required String titulo, required String texto, required String acao}) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
            child: Text(acao),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  void _adicionar(CadastroData d) => abrirFormularioPessoa(
        context,
        servico: _servico,
        categorias: d.categorias,
        onSalvo: _salvo,
        intervaloLeituras: widget.intervaloLeituras,
      );

  void _editar(CadastroData d, PessoaCadastro p) => abrirFormularioPessoa(
        context,
        servico: _servico,
        categorias: d.categorias,
        pessoa: p,
        onSalvo: _salvo,
      );

  void _vincular(PessoaCadastro p) => abrirVincularCartao(
        context,
        servico: _servico,
        pessoa: p,
        onSalvo: _salvo,
        intervaloLeituras: widget.intervaloLeituras,
      );

  Future<void> _alternarPessoa(PessoaCadastro p) async {
    if (p.ativo) {
      final ok = await _confirmar(
        titulo: 'Desativar ${p.nome}?',
        texto: 'Ela deixa de passar na catraca e sai das contagens, mas o histórico de acessos fica guardado. '
            'Dá para reativar quando quiser.',
        acao: 'Desativar',
      );
      if (!ok) return;
    }
    await _executar(() => _servico.definirPessoaAtiva(p.id, !p.ativo));
  }

  Future<void> _acoesDoCartao(PessoaCadastro p, CartaoPessoa c) async {
    final acao = await mostrarFolha<_AcaoCartao>(context, (_) => _FolhaCartao(pessoa: p, cartao: c));
    if (acao == null || !mounted) return;

    switch (acao) {
      case _AcaoCartao.alternar:
        await _executar(() => _servico.definirCartaoAtivo(c.id, !c.ativo));
      case _AcaoCartao.remover:
        final ok = await _confirmar(
          titulo: 'Remover o cartão ${c.uid}?',
          texto: 'Ele deixa de funcionar para ${p.nome} e o UID fica livre para outra pessoa.',
          acao: 'Remover',
        );
        if (ok) await _executar(() => _servico.removerCartao(c.id));
    }
  }

  // ─── Tela ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AsyncBody<CadastroData>(
      future: _future,
      onRefresh: _refresh,
      onRetry: reload,
      builder: (context, d) => Column(
        children: [
          _Topo(data: d, busca: _busca, onAdicionar: () => _adicionar(d)),
          Expanded(
            child: ListenableBuilder(
              listenable: _busca,
              builder: (context, _) {
                final termo = _busca.text.trim().toLowerCase();
                final lista = termo.isEmpty ? d.pessoas : d.pessoas.where((p) => p.textoBusca.contains(termo)).toList();

                if (lista.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [_SemPessoas(temCadastro: d.pessoas.isNotEmpty, podeEditar: d.podeEditar)],
                  );
                }
                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: lista.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final p = lista[i];
                    return _PessoaCard(
                      key: ValueKey('pessoa-${p.id}'),
                      pessoa: p,
                      cor: kAvatarColors[p.id % kAvatarColors.length],
                      podeEditar: d.podeEditar,
                      onVincular: () => _vincular(p),
                      onEditar: () => _editar(d, p),
                      onAlternarAtivo: () => _alternarPessoa(p),
                      onCartao: (c) => _acoesDoCartao(p, c),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Busca, resumo e o botão de adicionar (fixos no topo, a lista rola embaixo).
class _Topo extends StatelessWidget {
  final CadastroData data;
  final TextEditingController busca;
  final VoidCallback onAdicionar;
  const _Topo({required this.data, required this.busca, required this.onAdicionar});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final forte = AppText.strong(context, size: 13);
    final resumo = Text.rich(
      TextSpan(style: AppText.muted(context, size: 13), children: [
        TextSpan(text: fmtNum(data.ativas), style: forte),
        TextSpan(text: data.ativas == 1 ? ' pessoa ativa' : ' pessoas ativas'),
        const TextSpan(text: ' · '),
        TextSpan(text: fmtNum(data.semCartaoAtivo), style: forte),
        const TextSpan(text: ' sem cartão ativo'),
      ]),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SearchField(controller: busca, hint: 'Buscar por nome, função ou cartão...'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: resumo),
              if (data.podeEditar) ...[
                const SizedBox(width: 12),
                FilledButton.icon(
                  key: const Key('btn-adicionar-pessoa'),
                  onPressed: onAdicionar,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 19),
                  label: const Text('Adicionar pessoa', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
          if (!data.podeEditar) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline_rounded, size: 15, color: pal.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Somente o administrador da empresa altera o cadastro.',
                      key: const Key('aviso-somente-leitura'), style: AppText.muted(context, size: 12.5)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SemPessoas extends StatelessWidget {
  final bool temCadastro; // true = a busca não achou ninguém; false = ainda não há ninguém cadastrado
  final bool podeEditar;
  const _SemPessoas({required this.temCadastro, required this.podeEditar});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Column(
        children: [
          Icon(temCadastro ? Icons.search_off_rounded : Icons.group_add_outlined, size: 40, color: context.pal.textMuted),
          const SizedBox(height: 10),
          Text(temCadastro ? 'Nenhuma pessoa encontrada' : 'Nenhuma pessoa cadastrada ainda',
              textAlign: TextAlign.center, style: AppText.strong(context, size: 15)),
          const SizedBox(height: 4),
          Text(
            temCadastro
                ? 'Confira o que foi digitado na busca.'
                : (podeEditar ? 'Use “Adicionar pessoa” para começar.' : 'O administrador da empresa cadastra as pessoas.'),
            textAlign: TextAlign.center,
            style: AppText.muted(context),
          ),
        ],
      ),
    );
  }
}

// ─── Uma pessoa ────────────────────────────────────────────────────────────

enum _AcaoPessoa { editar, alternarAtivo }

class _PessoaCard extends StatelessWidget {
  final PessoaCadastro pessoa;
  final Color cor;
  final bool podeEditar;
  final VoidCallback onVincular;
  final VoidCallback onEditar;
  final VoidCallback onAlternarAtivo;
  final void Function(CartaoPessoa) onCartao;

  const _PessoaCard({
    super.key,
    required this.pessoa,
    required this.cor,
    required this.podeEditar,
    required this.onVincular,
    required this.onEditar,
    required this.onAlternarAtivo,
    required this.onCartao,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final p = pessoa;
    final detalhe = [p.cargo, p.categoriaRotulo, if (p.matricula != null) 'Matrícula ${p.matricula}'].join(' · ');

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: p.ativo ? cor : pal.textMuted,
                child: Text(p.nome.trim().isEmpty ? '?' : p.nome.trim()[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(p.nome,
                            style: AppText.strong(context, size: 15).copyWith(color: p.ativo ? pal.text : pal.textMuted)),
                        if (!p.ativo)
                          Pill('Desativada', background: pal.chip, foreground: pal.textMuted)
                        else if (p.presente)
                          const Pill('Presente agora', background: Color(0x2922C55E), foreground: AppColors.success),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(detalhe, style: AppText.muted(context, size: 12.5)),
                  ],
                ),
              ),
              if (podeEditar)
                PopupMenuButton<_AcaoPessoa>(
                  key: Key('menu-pessoa-${p.id}'),
                  tooltip: 'Mais ações',
                  icon: Icon(Icons.more_vert_rounded, color: pal.textMuted),
                  color: pal.card,
                  onSelected: (a) => switch (a) {
                    _AcaoPessoa.editar => onEditar(),
                    _AcaoPessoa.alternarAtivo => onAlternarAtivo(),
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: _AcaoPessoa.editar, child: _ItemMenu(Icons.edit_outlined, 'Editar')),
                    PopupMenuItem(
                      value: _AcaoPessoa.alternarAtivo,
                      child: p.ativo
                          ? const _ItemMenu(Icons.person_off_outlined, 'Desativar')
                          : const _ItemMenu(Icons.person_outline_rounded, 'Reativar'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final c in p.cartoes) _CartaoChip(c, onTap: podeEditar ? () => onCartao(c) : null),
              if (p.cartoes.isEmpty) Text('Sem cartão', style: AppText.muted(context, size: 13)),
              if (podeEditar) _VincularChip(key: Key('btn-vincular-${p.id}'), onTap: onVincular),
            ],
          ),
        ],
      ),
    );
  }
}

/// "+ Vincular cartão", ao lado dos cartões da pessoa.
class _VincularChip extends StatelessWidget {
  final VoidCallback onTap;
  const _VincularChip({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Material(
      color: pal.accentSoft,
      shape: const StadiumBorder(side: BorderSide(color: AppColors.accent, width: 1.2)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_card_rounded, size: 16, color: pal.text),
              const SizedBox(width: 6),
              Text('Vincular cartão', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: pal.text)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemMenu extends StatelessWidget {
  final IconData icone;
  final String texto;
  const _ItemMenu(this.icone, this.texto);

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icone, size: 20, color: context.pal.textMuted),
          const SizedBox(width: 12),
          Text(texto, style: AppText.strong(context, size: 14.5)),
        ],
      );
}

class _CartaoChip extends StatelessWidget {
  final CartaoPessoa cartao;
  final VoidCallback? onTap; // null = só leitura (não é administrador)
  const _CartaoChip(this.cartao, {this.onTap});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final c = cartao;
    return Semantics(
      button: onTap != null,
      label: 'Cartão ${c.uid}, ${c.ativo ? 'ativo' : 'desativado'}',
      excludeSemantics: true,
      child: Material(
        color: pal.chip,
        shape: StadiumBorder(side: BorderSide(color: pal.border)),
        child: InkWell(
          key: Key('cartao-${c.id}'),
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.credit_card_rounded, size: 16, color: c.ativo ? pal.textMuted : AppColors.red),
                const SizedBox(width: 6),
                Text(
                  c.uid,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: c.ativo ? pal.text : pal.textMuted,
                    decoration: c.ativo ? null : TextDecoration.lineThrough,
                  ),
                ),
                if (!c.ativo) ...[
                  const SizedBox(width: 6),
                  Text('desativado', style: AppText.muted(context, size: 11.5)),
                ],
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.more_horiz_rounded, size: 16, color: pal.textMuted),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Ações de um cartão ────────────────────────────────────────────────────

enum _AcaoCartao { alternar, remover }

class _FolhaCartao extends StatelessWidget {
  final PessoaCadastro pessoa;
  final CartaoPessoa cartao;
  const _FolhaCartao({required this.pessoa, required this.cartao});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cartão ${cartao.uid}', style: AppText.title(context, size: 18)),
                const SizedBox(height: 2),
                Text('de ${pessoa.nome} · ${cartao.ativo ? 'ativo' : 'desativado'}', style: AppText.muted(context, size: 13.5)),
              ],
            ),
          ),
          ListTile(
            key: const Key('acao-cartao-alternar'),
            leading: Icon(cartao.ativo ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded, color: pal.text),
            title: Text(cartao.ativo ? 'Desativar cartão' : 'Ativar cartão', style: AppText.strong(context, size: 15)),
            subtitle: Text(
              cartao.ativo ? 'Deixa de abrir a catraca, mas continua cadastrado.' : 'Volta a abrir a catraca.',
              style: AppText.muted(context, size: 12.5),
            ),
            onTap: () => Navigator.of(context).pop(_AcaoCartao.alternar),
          ),
          ListTile(
            key: const Key('acao-cartao-remover'),
            leading: const Icon(Icons.delete_outline_rounded, color: AppColors.red),
            title: Text('Remover cartão', style: AppText.strong(context, size: 15).copyWith(color: AppColors.red)),
            subtitle: Text('O UID fica livre para outra pessoa.', style: AppText.muted(context, size: 12.5)),
            onTap: () => Navigator.of(context).pop(_AcaoCartao.remover),
          ),
        ],
      ),
    );
  }
}
