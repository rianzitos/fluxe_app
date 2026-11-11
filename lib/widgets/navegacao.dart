import 'package:flutter/widgets.dart';

/// Abas de Configurações, na ordem em que aparecem (as mesmas do site).
enum AbaConfig { perfil, aparencia, notificacoes, sistema, integracoes, seguranca, aplicativo }

/// Navegação oferecida pela estrutura principal do app (AppShell) às telas e ao cabeçalho:
/// trocar de aba (pelo destino de um alerta, como no sino do site) e abrir Configurações numa aba.
class ShellNavegacao extends InheritedWidget {
  /// Destino no formato do site: "/painel", "/acessos", "/pessoas", "/assistente", "/relatorios",
  /// "/configuracoes#integracoes"...
  final void Function(String link) abrirLink;
  final void Function(AbaConfig aba) abrirConfiguracoes;

  const ShellNavegacao({super.key, required this.abrirLink, required this.abrirConfiguracoes, required super.child});

  static ShellNavegacao? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<ShellNavegacao>();

  @override
  bool updateShouldNotify(ShellNavegacao oldWidget) => false;
}

/// Aba de Configurações de um destino "/configuracoes#aba" do site ("#iot" é a de Integrações).
AbaConfig abaDoLink(String link) {
  final ancora = link.contains('#') ? link.substring(link.indexOf('#') + 1) : '';
  return switch (ancora) {
    'perfil' => AbaConfig.perfil,
    'aparencia' => AbaConfig.aparencia,
    'notificacoes' => AbaConfig.notificacoes,
    'sistema' => AbaConfig.sistema,
    'integracoes' || 'iot' => AbaConfig.integracoes,
    'seguranca' => AbaConfig.seguranca,
    _ => AbaConfig.perfil,
  };
}
