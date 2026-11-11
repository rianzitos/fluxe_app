import 'package:flutter/material.dart';

import '../core/arquivos.dart';
import '../core/config_service.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/formularios.dart';

/// Tamanho máximo da planilha (o mesmo limite do servidor).
const kTamanhoMaxPlanilha = 1024 * 1024;

/// "Importar planilha" da aba Cadastro (só administrador): cadastra várias pessoas de uma vez a partir de um CSV,
/// com as mesmas regras do site (o servidor usa o mesmo código). [onImportado] é chamado se alguém entrou.
Future<void> abrirImportarPlanilha(
  BuildContext context, {
  required ConfigService servico,
  required void Function(String mensagem) onImportado,
}) =>
    mostrarFolha<void>(context, (_) => _ImportarPlanilha(servico: servico, onImportado: onImportado));

class _ImportarPlanilha extends StatefulWidget {
  final ConfigService servico;
  final void Function(String mensagem) onImportado;
  const _ImportarPlanilha({required this.servico, required this.onImportado});

  @override
  State<_ImportarPlanilha> createState() => _ImportarPlanilhaState();
}

class _ImportarPlanilhaState extends State<_ImportarPlanilha> {
  ArquivoEscolhido? _arquivo;
  bool _enviando = false;
  bool _baixandoModelo = false;
  String? _erro;
  ResultadoImportacao? _resultado;

  Future<void> _baixarModelo() async {
    setState(() => _baixandoModelo = true);
    try {
      final csv = await widget.servico.modeloPlanilha();
      if (mounted) {
        await entregarCsv(context, nome: 'modelo-importacao-pessoas.csv', csv: csv, assunto: 'Modelo da planilha de pessoas');
      }
    } catch (e) {
      if (mounted) setState(() => _erro = mensagemDoErro(e));
    } finally {
      if (mounted) setState(() => _baixandoModelo = false);
    }
  }

  Future<void> _escolher() async {
    final arquivo = await escolherArquivo(imagem: false);
    if (arquivo == null || !mounted) return;
    setState(() {
      _resultado = null;
      if (arquivo.bytes.length > kTamanhoMaxPlanilha) {
        _arquivo = null;
        _erro = 'O arquivo passa de 1 MB. Divida a planilha em partes menores.';
      } else if (arquivo.bytes.isEmpty) {
        _arquivo = null;
        _erro = 'O arquivo está vazio.';
      } else {
        _arquivo = arquivo;
        _erro = null;
      }
    });
  }

  Future<void> _importar() async {
    final arquivo = _arquivo;
    if (arquivo == null) return;
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      final r = await widget.servico.importarPlanilha(textoDoCsv(arquivo.bytes));
      if (!mounted) return;
      setState(() {
        _resultado = r;
        _arquivo = null;
      });
      if (r.pessoas > 0) widget.onImportado(_resumo(r));
    } catch (e) {
      if (mounted) setState(() => _erro = mensagemDoErro(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  static String _plural(int n, String um, String varios) => '${fmtNum(n)} ${n == 1 ? um : varios}';

  static String _resumo(ResultadoImportacao r) =>
      '${_plural(r.pessoas, 'pessoa cadastrada', 'pessoas cadastradas')} e ${_plural(r.cartoes, 'cartão vinculado', 'cartões vinculados')}.';

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final r = _resultado;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Importar planilha', style: AppText.title(context, size: 18)),
          const SizedBox(height: 6),
          Text('Cadastre várias pessoas de uma vez com um arquivo .csv (no Excel: Salvar como → CSV).',
              style: AppText.muted(context, size: 13.5)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: pal.chip, borderRadius: BorderRadius.circular(12)),
            child: Text.rich(
              TextSpan(style: AppText.muted(context, size: 12.5), children: [
                const TextSpan(text: 'Colunas: '),
                TextSpan(text: 'nome', style: AppText.strong(context, size: 12.5)),
                const TextSpan(text: ' e '),
                TextSpan(text: 'cargo', style: AppText.strong(context, size: 12.5)),
                const TextSpan(text: ' (obrigatórias); categoria (operador, supervisor ou prestador), matrícula e cartão (UID), '
                    'opcionais. Até 1.000 linhas e 1 MB. Linhas com problema são ignoradas e listadas no fim; as outras entram.'),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('btn-baixar-modelo'),
              onPressed: _baixandoModelo ? null : _baixarModelo,
              icon: _baixandoModelo
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_rounded, size: 18),
              label: const Text('Baixar o modelo da planilha'),
            ),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            key: const Key('btn-escolher-planilha'),
            onPressed: _enviando ? null : _escolher,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              side: BorderSide(color: pal.border),
              foregroundColor: pal.text,
            ),
            icon: const Icon(Icons.upload_file_rounded),
            label: Text(
              _arquivo == null ? 'Escolher arquivo (.csv)' : '${_arquivo!.nome} · ${fmtNum(_arquivo!.bytes.length / 1024, decimals: 1)} KB',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_erro != null) ...[const SizedBox(height: 14), AvisoFormulario(_erro!)],
          if (r != null) ...[
            const SizedBox(height: 14),
            AvisoFormulario(
              '${_resumo(r)}${r.ignoradas > 0 ? ' ${_plural(r.ignoradas, 'linha ignorada', 'linhas ignoradas')}.' : ''}',
              sucesso: r.pessoas > 0,
            ),
            if (r.erros.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Linhas que ficaram de fora', style: AppText.strong(context, size: 13.5)),
              const SizedBox(height: 4),
              for (final e in r.erros.take(30))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text('Linha ${e.linha}: ${e.motivo}', style: AppText.muted(context, size: 12.5)),
                ),
              if (r.erros.length > 30) Text('… e mais ${r.erros.length - 30}.', style: AppText.muted(context, size: 12.5)),
            ],
          ],
          const SizedBox(height: 18),
          if (r == null)
            BotaoEnviar(
              key: const Key('btn-importar'),
              rotulo: 'Importar',
              icone: Icons.cloud_upload_outlined,
              enviando: _enviando,
              onPressed: _arquivo == null ? null : _importar,
            )
          else
            BotaoEnviar(
              key: const Key('btn-concluir-importacao'),
              rotulo: 'Concluir',
              icone: Icons.check_rounded,
              enviando: false,
              onPressed: () => Navigator.pop(context),
            ),
        ],
      ),
    );
  }
}
