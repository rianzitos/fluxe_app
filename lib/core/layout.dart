import 'package:flutter/material.dart';

/// A partir desta largura (PC, tablet deitado) o app mostra o menu lateral fixo, como o painel web.
const double kWideBreakpoint = 900;

/// Largura do menu lateral fixo.
const double kSidebarWidth = 272;

/// Largura máxima do conteúdo em janelas largas (evita cartões esticados em monitores grandes).
const double kContentMaxWidth = 1040;

bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kWideBreakpoint;
