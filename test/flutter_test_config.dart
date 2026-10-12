import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Carrega Inter e Sora nos testes; sem isso o Flutter usa a fonte de teste (Ahem),
/// com letras quadradas, e os testes de layout dão overflow que não existe no app.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final f in {'Inter': 'assets/fonts/Inter.ttf', 'Sora': 'assets/fonts/Sora.ttf'}.entries) {
    final bytes = File(f.value).readAsBytesSync();
    final loader = FontLoader(f.key)..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
    await loader.load();
  }
  await testMain();
}
