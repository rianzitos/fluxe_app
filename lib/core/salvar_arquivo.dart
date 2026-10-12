import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

/// No Windows não há "folha de compartilhamento" como no celular: o relatório é salvo direto na pasta
/// Downloads do usuário (e o app oferece abrir a pasta com o arquivo selecionado).
bool get exportaParaPasta => !kIsWeb && Platform.isWindows;

/// Salva o CSV em Downloads sem sobrescrever arquivos existentes ("nome (1).csv"...).
/// Escreve com BOM UTF-8 para o Excel abrir os acentos corretamente.
Future<String> salvarCsvNosDownloads(String nome, String csv, {Directory? pasta}) async {
  if (pasta == null) {
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    if (home == null || home.isEmpty) throw const FileSystemException('Pasta do usuário não encontrada');
    pasta = Directory('$home${Platform.pathSeparator}Downloads');
  }
  if (!pasta.existsSync()) pasta.createSync(recursive: true);

  final ponto = nome.lastIndexOf('.');
  final base = ponto > 0 ? nome.substring(0, ponto) : nome;
  final ext = ponto > 0 ? nome.substring(ponto) : '';
  var arquivo = File('${pasta.path}${Platform.pathSeparator}$nome');
  for (var i = 1; arquivo.existsSync() && i < 1000; i++) {
    arquivo = File('${pasta.path}${Platform.pathSeparator}$base ($i)$ext');
  }

  final semBom = csv.startsWith('﻿') ? csv.substring(1) : csv;
  await arquivo.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(semBom)]);
  return arquivo.path;
}

/// Abre o Explorer com o arquivo selecionado. Falhas são ignoradas (é só uma conveniência).
Future<void> mostrarNaPasta(String caminho) async {
  try {
    if (Platform.isWindows) {
      await Process.run('explorer.exe', ['/select,', caminho]);
    }
  } catch (_) {}
}
