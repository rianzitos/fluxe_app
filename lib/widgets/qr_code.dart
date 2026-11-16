import 'package:flutter/material.dart';

/// QR Code desenhado a partir das linhas que o servidor manda ("1" = quadradinho escuro): o SystemFluxe gera o código
/// (app/helpers/QrCode.php) e o app só pinta, sem pacote extra. Sempre escuro sobre branco, com a margem branca de
/// 4 quadradinhos que as câmeras precisam, inclusive no tema escuro.
class QrCodeView extends StatelessWidget {
  final List<String> linhas;
  final double tamanho;
  final String rotulo;

  const QrCodeView(this.linhas, {super.key, this.tamanho = 200, this.rotulo = 'QR Code'});

  @override
  Widget build(BuildContext context) => Semantics(
        label: rotulo,
        image: true,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CustomPaint(size: Size.square(tamanho), painter: _QrPainter(linhas)),
        ),
      );
}

class _QrPainter extends CustomPainter {
  final List<String> linhas;
  _QrPainter(this.linhas);

  static const _margem = 4;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final n = linhas.length;
    if (n == 0) return;

    final modulo = size.width / (n + _margem * 2);
    final caminho = Path();
    for (var y = 0; y < n; y++) {
      final linha = linhas[y];
      for (var x = 0; x < linha.length; x++) {
        if (linha.codeUnitAt(x) == 0x31) {
          // Um pouco maior que o quadradinho: sem fresta branca entre os vizinhos depois do arredondamento
          caminho.addRect(Rect.fromLTWH((x + _margem) * modulo, (y + _margem) * modulo, modulo + 0.3, modulo + 0.3));
        }
      }
    }
    canvas.drawPath(caminho, Paint()
      ..color = Colors.black
      ..isAntiAlias = false);
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.linhas != linhas;
}
