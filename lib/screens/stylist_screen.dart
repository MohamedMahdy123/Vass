import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/mock_data.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// AI stylist chat. Replies are canned — see [AppState].
class StylistScreen extends StatefulWidget {
  const StylistScreen({super.key});

  @override
  State<StylistScreen> createState() => _StylistScreenState();
}

class _StylistScreenState extends State<StylistScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = preset ?? _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    await context.read<AppState>().send(text);
    if (!mounted) return;
    // Jump to the newest message once the reply lands.
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    final state = context.watch<AppState>();

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: t.accentSoft,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(Icons.auto_awesome, size: 20, color: t.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your stylist', style: serif(context, 24)),
                      Text('Always on · knows your closet',
                          style: TextStyle(
                              fontFamily: kSans, fontSize: 12, color: t.ink3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(color: t.line, height: 1),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              children: [
                for (final m in state.messages) ...[
                  _Bubble(message: m),
                  const SizedBox(height: 12),
                ],
                if (state.typing) const _TypingBubble(),
                if (state.showPrompts) ...[
                  const SizedBox(height: 8),
                  Text('TRY ASKING',
                      style: eyebrow(t.ink3, size: 11)
                          .copyWith(letterSpacing: 1.2)),
                  const SizedBox(height: 10),
                  for (final p in kQuickPrompts) ...[
                    GestureDetector(
                      onTap: () => _send(p),
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: t.card,
                          border: Border.all(color: t.line),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(p,
                            style: TextStyle(
                                fontFamily: kSans,
                                fontSize: 13.5,
                                color: t.ink2)),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 108),
            decoration: BoxDecoration(
              color: t.bg,
              border: Border(top: BorderSide(color: t.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _send(),
                    style: TextStyle(
                        fontFamily: kSans, fontSize: 14.5, color: t.ink),
                    decoration: InputDecoration(
                      hintText: 'Ask your stylist anything…',
                      hintStyle: TextStyle(
                          fontFamily: kSans, fontSize: 14.5, color: t.ink3),
                      filled: true,
                      fillColor: t.card,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: t.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: t.accent),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _send(),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: t.accent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.arrow_upward,
                        color: Colors.white, size: 21),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    final ai = message.isAI;

    return Row(
      mainAxisAlignment: ai ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: ai ? t.card : t.accent,
              border: ai ? Border.all(color: t.line) : null,
              // Tail corner flips depending on the speaker.
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(ai ? 8 : 20),
                topRight: Radius.circular(ai ? 20 : 8),
                bottomLeft: const Radius.circular(20),
                bottomRight: const Radius.circular(20),
              ),
            ),
            child: Text(
              message.text,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 14.5,
                height: 1.46,
                color: ai ? t.ink : Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(
          color: t.card,
          border: Border.all(color: t.line),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return Container(
              margin: EdgeInsets.only(right: i == 2 ? 0 : 5),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: t.ink3,
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
      ),
    );
  }
}
