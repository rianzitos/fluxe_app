import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_state.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/page_header.dart';

class _Msg {
  final String texto;
  final bool doUsuario;
  final String hora;
  final bool erro;
  _Msg(this.texto, {required this.doUsuario, required this.hora, this.erro = false});
}

String _agora() {
  final n = DateTime.now();
  return '${two(n.hour)}:${two(n.minute)}';
}

/// Assistente IA: chat com previsões calculadas pelo servidor.
class AssistenteScreen extends StatefulWidget {
  final VoidCallback onMenu;
  const AssistenteScreen({super.key, required this.onMenu});

  @override
  State<AssistenteScreen> createState() => _AssistenteScreenState();
}

class _AssistenteScreenState extends State<AssistenteScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _msgs = <_Msg>[];
  AssistenteInfo? _info;
  Object? _infoError;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadInfo() async {
    setState(() => _infoError = null);
    try {
      final res = await AppScope.read(context).api.get('/assistente');
      final info = AssistenteInfo.fromJson(res);
      if (!mounted) return;
      setState(() {
        _info = info;
        if (_msgs.isEmpty) _msgs.add(_Msg(info.boasVindas, doUsuario: false, hora: _agora()));
      });
    } catch (e) {
      if (mounted) setState(() => _infoError = e);
    }
  }

  Future<void> _send(String texto) async {
    final t = texto.trim();
    if (t.isEmpty || _sending) return;
    _input.clear();
    setState(() {
      _msgs.add(_Msg(t, doUsuario: true, hora: _agora()));
      _sending = true;
    });
    _toBottom();

    try {
      final res = await AppScope.read(context).api.post('/assistente', {'mensagem': t});
      if (!mounted) return;
      setState(() => _msgs.add(_Msg(res['resposta'] as String? ?? '', doUsuario: false, hora: res['hora'] as String? ?? _agora())));
    } on ApiException catch (e) {
      if (mounted) setState(() => _msgs.add(_Msg(e.message, doUsuario: false, hora: _agora(), erro: true)));
    } finally {
      if (mounted) setState(() => _sending = false);
      _toBottom();
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 80,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    return Column(
      children: [
        PageHeader(
          title: 'Assistente IA',
          subtitle: 'Previsões de pessoas e alimentos',
          onMenu: widget.onMenu,
        ),
        if (_infoError != null && info == null)
          Expanded(child: ErrorState(error: _infoError!, onRetry: _loadInfo))
        else if (info == null)
          const Expanded(child: LoadingState())
        else ...[
          _TopStrip(info: info, onAsk: _send),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: _msgs.length + (_sending ? 1 : 0),
              itemBuilder: (context, i) => i == _msgs.length ? const _Typing() : _Bubble(_msgs[i]),
            ),
          ),
          _InputBar(controller: _input, sending: _sending, onSend: () => _send(_input.text)),
        ],
      ],
    );
  }
}

class _TopStrip extends StatelessWidget {
  final AssistenteInfo info;
  final ValueChanged<String> onAsk;
  const _TopStrip({required this.info, required this.onAsk});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final p = info.precisao;

    Widget chip(String text, IconData icon, {Color? bg, Color? fg}) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            onPressed: () => onAsk(text),
            avatar: Icon(icon, size: 16, color: fg ?? AppColors.accentText),
            label: Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: pal.text)),
            backgroundColor: bg ?? pal.card,
            side: BorderSide(color: pal.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: AppColors.black, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                const Icon(Icons.track_changes_rounded, color: AppColors.accent, size: 22),
                const SizedBox(width: 10),
                const Text('Precisão da IA',
                    style: TextStyle(color: Color(0xFFD4D4D8), fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(p == null ? '—' : '${fmtNum(p.precisao, decimals: 1)}%',
                    style: const TextStyle(
                        color: AppColors.accent, fontFamily: AppText.heading, fontSize: 20, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
        if (p == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 16, 0),
            child: Text('Dados insuficientes: são necessários ao menos 5 dias com movimento.',
                style: AppText.muted(context, size: 11.5)),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 16, 0),
            child: Text('Baseado nos últimos 30 dias (${p.dias} dias avaliados)',
                style: AppText.muted(context, size: 11.5)),
          ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final q in info.perguntasRapidas) chip(q, Icons.bolt_rounded),
              for (final e in info.eventos)
                chip('Previsão para ${e.data ?? ''}', e.tipo == 'aviso' ? Icons.warning_amber_rounded : Icons.event_rounded,
                    fg: e.tipo == 'aviso' ? AppColors.warning : AppColors.info),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  final _Msg m;
  const _Bubble(this.m);

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final user = m.doUsuario;
    final bg = user ? AppColors.accent : (m.erro ? pal.warningBg : pal.card);
    final fg = user ? Colors.black : pal.text;

    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 8),
        decoration: BoxDecoration(
          color: bg,
          border: user ? null : Border.all(color: pal.border),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(user ? 16 : 4),
            bottomRight: Radius.circular(user ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SelectableText(m.texto, style: TextStyle(color: fg, fontSize: 14.5, height: 1.4)),
            const SizedBox(height: 4),
            Text(m.hora, style: TextStyle(color: fg.withValues(alpha: 0.55), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: pal.card,
          border: Border.all(color: pal.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.accent),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  const _InputBar({required this.controller, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(color: pal.background, border: Border(top: BorderSide(color: pal.border))),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !sending,
              maxLength: 300,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: TextStyle(color: pal.text, fontSize: 14.5),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Digite sua pergunta...',
                hintStyle: TextStyle(color: pal.textMuted),
                filled: true,
                fillColor: pal.card,
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide(color: pal.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide(color: pal.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: const BorderSide(color: AppColors.accent, width: 1.4)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: AppColors.accent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: sending ? null : onSend,
              child: const SizedBox(width: 50, height: 50, child: Icon(Icons.send_rounded, color: Colors.black, size: 22)),
            ),
          ),
        ],
      ),
    );
  }
}
