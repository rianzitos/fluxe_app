import 'package:flutter/material.dart';

/// Logo oficial do SICAPDA (emblema + "SICAPDA by FLUXE").
///
/// O "SICA" da logo é branco: use sempre sobre fundo escuro (login, menu lateral e tela de abertura).
class SicapdaLogo extends StatelessWidget {
  static const asset = 'assets/logo/sicapda_logo.png';

  final double width;
  const SicapdaLogo({super.key, this.width = 220});

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    width: width,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
    semanticLabel: 'SICAPDA by Fluxe',
  );
}
