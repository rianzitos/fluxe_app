import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Peças comuns dos formulários de Configurações (perfil, senha, dispositivos, simulação...), com o mesmo visual
/// dos formulários do Cadastro de pessoas.

InputDecoration decoracaoCampo(BuildContext context, String rotulo, {String? dica, IconData? icone, Widget? sufixo}) {
  final pal = context.pal;
  OutlineInputBorder borda(Color cor, [double largura = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cor, width: largura));

  return InputDecoration(
    labelText: rotulo,
    hintText: dica,
    hintStyle: TextStyle(color: pal.textMuted, fontSize: 14),
    labelStyle: TextStyle(color: pal.textMuted),
    floatingLabelStyle: TextStyle(color: pal.text, fontWeight: FontWeight.w600),
    prefixIcon: icone == null ? null : Icon(icone, color: pal.textMuted),
    suffixIcon: sufixo,
    filled: true,
    fillColor: pal.card,
    border: borda(pal.border),
    enabledBorder: borda(pal.border),
    disabledBorder: borda(pal.border),
    focusedBorder: borda(AppColors.accent, 1.6),
    errorBorder: borda(AppColors.red),
    focusedErrorBorder: borda(AppColors.red, 1.6),
  );
}

/// Botão amarelo de enviar, com "carregando" enquanto o pedido está no servidor.
class BotaoEnviar extends StatelessWidget {
  final String rotulo;
  final IconData icone;
  final bool enviando;
  final VoidCallback? onPressed;
  final bool secundario;

  const BotaoEnviar({
    super.key,
    required this.rotulo,
    required this.icone,
    required this.enviando,
    required this.onPressed,
    this.secundario = false,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final fundo = secundario ? pal.chip : AppColors.accent;
    final texto = secundario ? pal.text : Colors.black;
    return FilledButton.icon(
      onPressed: enviando ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: fundo,
        foregroundColor: texto,
        disabledBackgroundColor: fundo.withValues(alpha: 0.6),
        disabledForegroundColor: texto.withValues(alpha: 0.7),
        side: secundario ? BorderSide(color: pal.border) : null,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: enviando
          ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: texto))
          : Icon(icone, size: 19),
      label: Text(rotulo, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

/// Mensagem de erro (ou de sucesso) abaixo de um formulário, como o "campo-erro" do site.
class AvisoFormulario extends StatelessWidget {
  final String texto;
  final bool sucesso;
  const AvisoFormulario(this.texto, {super.key, this.sucesso = false});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final cor = sucesso ? AppColors.success : AppColors.red;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: sucesso ? pal.successBg : AppColors.red.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(sucesso ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: cor, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: TextStyle(color: pal.text, fontSize: 13.5, height: 1.35))),
        ],
      ),
    );
  }
}

/// Etiqueta "Em breve" (funções que ainda não existem no sistema, como no site).
class EtiquetaEmBreve extends StatelessWidget {
  const EtiquetaEmBreve({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: context.pal.chip, borderRadius: BorderRadius.circular(20)),
        child: Text('Em breve', style: AppText.muted(context, size: 11)),
      );
}

/// Nota pequena em cinza no fim de um card ("config-nota" do site).
class NotaConfig extends StatelessWidget {
  final String texto;
  final IconData icone;
  const NotaConfig(this.texto, {super.key, this.icone = Icons.info_outline_rounded});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 15, color: context.pal.textMuted),
          const SizedBox(width: 6),
          Expanded(child: Text(texto, style: AppText.muted(context, size: 12.5))),
        ],
      );
}

/// Confirmação simples (Cancelar / ação).
Future<bool> confirmar(BuildContext context, {required String titulo, required String texto, required String acao}) async {
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
