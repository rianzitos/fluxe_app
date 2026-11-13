import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'salvar_arquivo.dart';

/// Arquivo escolhido no aparelho (nome + conteúdo).
typedef ArquivoEscolhido = ({String nome, Uint8List bytes});

/// Abre o seletor de arquivos do sistema: uma imagem ([imagem] = true, para a foto do perfil) ou uma planilha CSV.
/// null = a pessoa desistiu. Trocável nos testes (não há seletor de arquivos num teste de widget).
Future<ArquivoEscolhido?> Function({required bool imagem}) escolherArquivo = _escolherArquivoDoSistema;

Future<ArquivoEscolhido?> _escolherArquivoDoSistema({required bool imagem}) async {
  // No Android o filtro por extensão vira um filtro por tipo (MIME), e cada app de arquivos chama o CSV de um jeito
  // (text/csv, text/comma-separated-values, text/plain...): com filtro, planilhas válidas podem aparecer apagadas.
  // Lá o seletor abre sem filtro e quem confere a extensão é o app ([extensaoDePlanilha]).
  final semFiltro = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final arquivo = imagem
      ? await FilePicker.pickFile(type: FileType.image, dialogTitle: 'Escolher foto do perfil')
      : await FilePicker.pickFile(
          type: semFiltro ? FileType.any : FileType.custom,
          allowedExtensions: semFiltro ? null : const ['csv', 'txt'],
          dialogTitle: 'Escolher a planilha (.csv)',
        );
  if (arquivo == null) return null;
  return (nome: arquivo.name, bytes: await arquivo.xFile.readAsBytes());
}

/// A planilha precisa ser um texto separado por ";" ou "," (.csv, ou .txt exportado do Excel).
bool extensaoDePlanilha(String nome) {
  final n = nome.toLowerCase();
  return n.endsWith('.csv') || n.endsWith('.txt');
}

/// Texto de um CSV escolhido no aparelho. O Excel em português costuma salvar em Windows-1252 ("CSV (separado por
/// vírgulas)"): o servidor entende os dois, então aqui só não pode estragar os acentos ao virar texto.
String textoDoCsv(Uint8List bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    // Windows-1252: igual ao Latin-1, menos a faixa 0x80–0x9F (aspas curvas, travessão, €...).
    return String.fromCharCodes(bytes.map((b) => b >= 0x80 && b <= 0x9F ? _cp1252[b - 0x80] : b));
  }
}

/// Caracteres do Windows-1252 de 0x80 a 0x9F (os indefinidos ficam como no Latin-1).
const _cp1252 = [
  0x20AC, 0x81, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x8D, 0x017D, 0x8F, //
  0x90, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, 0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x9D, 0x017E, 0x0178,
];

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

/// Entrega um CSV para a pessoa (o modelo da planilha de importação). Veja [entregarArquivo].
Future<void> entregarCsv(BuildContext context, {required String nome, required String csv, required String assunto}) {
  final semBom = csv.startsWith('\uFEFF') ? csv.substring(1) : csv;
  return entregarArquivo(context,
      nome: nome, bytes: Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(semBom)]), mimeType: 'text/csv', assunto: assunto);
}

/// Entrega um arquivo para a pessoa: no Windows salva na pasta Downloads (e oferece abrir a pasta); no celular e no
/// navegador abre a folha de compartilhar/salvar do sistema. Usado no relatório exportado e no modelo da planilha.
Future<void> entregarArquivo(BuildContext context,
    {required String nome, required Uint8List bytes, required String mimeType, required String assunto}) async {
  final messenger = ScaffoldMessenger.of(context);
  if (exportaParaPasta) {
    final caminho = await salvarNosDownloads(nome, bytes);
    messenger.showSnackBar(SnackBar(
      content: Text('$nome salvo na pasta Downloads.'),
      action: SnackBarAction(label: 'Abrir pasta', onPressed: () => mostrarNaPasta(caminho)),
    ));
    return;
  }
  await compartilharArquivo(ShareParams(
    files: [XFile.fromData(bytes, mimeType: mimeType, name: nome)],
    fileNameOverrides: [nome],
    subject: assunto,
  ));
}

/// Abre a folha de compartilhar/salvar do sistema. Trocável nos testes (não existe essa folha num teste de widget).
Future<void> Function(ShareParams params) compartilharArquivo = (params) => SharePlus.instance.share(params);

const mimeXlsx = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// Nome e tipo do relatório baixado. O servidor manda a planilha do Excel (.xlsx, um arquivo zip: começa com "PK");
/// um SystemFluxe antigo, sem essa opção, responde CSV, que então é salvo como .csv para abrir certo.
({String nome, String mimeType}) tipoDoRelatorio(Uint8List bytes, String nomeBase) =>
    bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B
        ? (nome: '$nomeBase.xlsx', mimeType: mimeXlsx)
        : (nome: '$nomeBase.csv', mimeType: 'text/csv');
