import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'salvar_arquivo.dart';

/// Arquivo escolhido no aparelho (nome + conteúdo).
typedef ArquivoEscolhido = ({String nome, Uint8List bytes});

/// Abre o seletor de arquivos do sistema: uma imagem ([imagem] = true, para a foto do perfil) ou uma planilha CSV.
/// null = a pessoa desistiu. Trocável nos testes (não há seletor de arquivos num teste de widget).
Future<ArquivoEscolhido?> Function({required bool imagem}) escolherArquivo = _escolherArquivoDoSistema;

Future<ArquivoEscolhido?> _escolherArquivoDoSistema({required bool imagem}) async {
  final arquivo = imagem
      ? await FilePicker.pickFile(type: FileType.image, dialogTitle: 'Escolher foto do perfil')
      : await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: const ['csv', 'txt'],
          dialogTitle: 'Escolher a planilha (.csv)',
        );
  if (arquivo == null) return null;
  return (nome: arquivo.name, bytes: await arquivo.xFile.readAsBytes());
}

/// Texto de um CSV escolhido no aparelho. O Excel em português costuma salvar em Windows-1252 ("CSV (separado por
/// vírgulas)"): o servidor entende os dois, então aqui só não pode estragar os acentos ao virar texto.
String textoDoCsv(Uint8List bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    // Windows-1252/Latin-1: cada byte é um caractere; o servidor converte de novo e confere.
    return latin1.decode(bytes);
  }
}

/// Foto do perfil: recorta o centro em quadrado e reduz para [lado] px (PNG). Assim o envio fica pequeno
/// (a câmera do celular gera fotos de vários MB) e a foto aparece bem no círculo do avatar.
Future<Uint8List> prepararFotoDePerfil(Uint8List original, {int lado = 512}) async {
  final codec = await ui.instantiateImageCodec(original);
  final quadro = await codec.getNextFrame();
  final imagem = quadro.image;
  try {
    final menor = math.min(imagem.width, imagem.height).toDouble();
    final recorte = Rect.fromLTWH((imagem.width - menor) / 2, (imagem.height - menor) / 2, menor, menor);
    final destino = math.min(lado.toDouble(), menor);

    final gravador = ui.PictureRecorder();
    Canvas(gravador).drawImageRect(
      imagem,
      recorte,
      Rect.fromLTWH(0, 0, destino, destino),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final reduzida = await gravador.endRecording().toImage(destino.round(), destino.round());
    try {
      final png = await reduzida.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw const FormatException('Não foi possível ler a imagem.');
      return png.buffer.asUint8List();
    } finally {
      reduzida.dispose();
    }
  } finally {
    imagem.dispose();
    codec.dispose();
  }
}

/// Entrega um CSV para a pessoa: no Windows salva na pasta Downloads (e oferece abrir a pasta); no celular e no
/// navegador abre a folha de compartilhar/salvar do sistema. Usado no relatório exportado e no modelo da planilha.
Future<void> entregarCsv(BuildContext context, {required String nome, required String csv, required String assunto}) async {
  final messenger = ScaffoldMessenger.of(context);
  if (exportaParaPasta) {
    final caminho = await salvarCsvNosDownloads(nome, csv);
    messenger.showSnackBar(SnackBar(
      content: Text('$nome salvo na pasta Downloads.'),
      action: SnackBarAction(label: 'Abrir pasta', onPressed: () => mostrarNaPasta(caminho)),
    ));
    return;
  }
  await SharePlus.instance.share(ShareParams(
    files: [XFile.fromData(utf8.encode(csv), mimeType: 'text/csv', name: nome)],
    fileNameOverrides: [nome],
    subject: assunto,
  ));
}
