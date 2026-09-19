import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/stylist_state.dart';
import '../state/wardrobe_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/item_image.dart' show swatchColor;
import 'item_detail_screen.dart';
import 'outfit_analysis_screen.dart';
import 'outfit_canvas_screen.dart';
import 'outfits_screen.dart';
import 'shell.dart';

/// Starter prompts, grounded in real styling questions.
const _kQuickPrompts = [
  'What should I wear to work?',
  'Something for a dinner tonight',
  "It's cold out today",
  'Style around my favourites',
];

/// AI stylist chat over the user's real wardrobe — see [StylistState].
class StylistScreen extends StatefulWidget {
  const StylistScreen({super.key});

  @override
  State<StylistScreen> createState() => _StylistScreenState();
}

class _StylistScreenState extends State<StylistScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Repaint the send button as the field goes empty <-> non-empty.
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<WardrobeState>().load());
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = preset ?? _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    final wardrobe = context.read<WardrobeState>().items;
    await context.read<StylistState>().send(text, wardrobe);
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

  /// Open the constraint composer and, if the user submits a real brief, send
  /// it as a structured styling request.
  Future<void> _openRequest() async {
    final req = await showModalBottomSheet<StyleRequest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RequestSheet(),
    );
    if (req == null || req.isEmpty || !mounted) return;
    final wardrobe = context.read<WardrobeState>().items;
    await context.read<StylistState>().sendRequest(req, wardrobe);
    if (!mounted) return;
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// Deep-link from a chat action card into the matching screen.
  void _runAction(BuildContext context, StylistAction a) {
    final nav = Navigator.of(context);
    switch (a.type) {
      case StylistActionType.viewOutfit:
        final ids = a.itemIds.toSet();
        final items = context
            .read<WardrobeState>()
            .items
            .where((i) => ids.contains(i.id))
            .toList();
        if (items.isEmpty) {
          Shell.of(context)?.goTo(1);
          return;
        }
        nav.push(MaterialPageRoute<void>(
          builder: (_) => OutfitAnalysisScreen(
            items: items,
            title: (a.occasion ?? '').isNotEmpty ? '${a.occasion} look' : 'Your look',
          ),
        ));
        break;
      case StylistActionType.openCanvas:
        nav.push(MaterialPageRoute<void>(
            builder: (_) => const OutfitCanvasScreen()));
        break;
      case StylistActionType.openOutfits:
        nav.push(
            MaterialPageRoute<void>(builder: (_) => const OutfitsScreen()));
        break;
      case StylistActionType.openItem:
        final id = a.itemId;
        if (id != null) {
          nav.push(MaterialPageRoute<void>(
              builder: (_) => ItemDetailScreen(itemId: id)));
        }
        break;
      case StylistActionType.openTryOn:
        Shell.of(context)?.goTo(2);
        break;
      case StylistActionType.openCloset:
        Shell.of(context)?.goTo(1);
        break;
    }
  }

  /// The accented entry point that sells the precise, constraint-based request.
  Widget _requestCta(BuildContext context) {
    final t = context.vess;
    return Semantics(
      button: true,
      label: 'Request a precise look',
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: t.accentSoft,
          border: Border.all(color: t.accent.withOpacity(0.35)),
          borderRadius: BorderRadius.circular(VessRadius.md),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _openRequest,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.tune, size: 18, color: t.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Request a precise look',
                            style: TextStyle(
                                fontFamily: kSans,
                                fontSize: VessType.body,
                                fontWeight: FontWeight.w700,
                                color: t.ink)),
                        const SizedBox(height: 2),
                        Text('Pin the occasion, colour, weather & favourites',
                            style: TextStyle(
                                fontFamily: kSans,
                                fontSize: VessType.caption,
                                color: t.ink3)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward, size: 16, color: t.accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Compact accent affordance to the precise-request flow, shown above the
  /// composer once the chat is active (the empty-state hero is gone by then).
  Widget _requestBar(BuildContext context) {
    final t = context.vess;
    return Semantics(
      button: true,
      label: 'Request a precise look',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(VessRadius.sm),
            onTap: _openRequest,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: t.accentSoft,
                border: Border.all(color: t.accent.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(VessRadius.sm),
              ),
              child: Row(
                children: [
                  Icon(Icons.tune, size: 15, color: t.accent),
                  const SizedBox(width: 9),
                  Text('Request a precise look',
                      style: TextStyle(
                          fontFamily: kSans,
                          fontSize: VessType.label,
                          fontWeight: FontWeight.w600,
                          color: t.accent)),
                  const Spacer(),
                  Icon(Icons.arrow_forward, size: 14, color: t.accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _promptTile(BuildContext context, String p) {
    final t = context.vess;
    return Semantics(
      button: true,
      label: p,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: t.card,
          border: Border.all(color: t.line),
          borderRadius: BorderRadius.circular(VessRadius.sm),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _send(p),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Text(p,
                  style: TextStyle(
                      fontFamily: kSans,
                      fontSize: VessType.bodySm,
                      color: t.ink2)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    final state = context.watch<StylistState>();

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
                    borderRadius: BorderRadius.circular(VessRadius.sm),
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
                              fontFamily: kSans, fontSize: VessType.label, color: t.ink3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(color: t.line, height: 1),
          Expanded(
            child: state.showPrompts
                // Fresh chat: centre the greeting + starter prompts vertically
                // so they don't sit top-stuck above a big empty gap.
                ? LayoutBuilder(
                    builder: (context, cons) => SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: cons.maxHeight - 38),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final m in state.messages) ...[
                              _Bubble(
                                  message: m,
                                  onAction: (a) => _runAction(context, a)),
                              const SizedBox(height: 12),
                            ],
                            const SizedBox(height: 12),
                            _requestCta(context),
                            const SizedBox(height: 20),
                            Text('OR JUST ASK',
                                style: eyebrow(t.ink3, size: 11)
                                    .copyWith(letterSpacing: 1.2)),
                            const SizedBox(height: 10),
                            for (final p in _kQuickPrompts) _promptTile(context, p),
                          ],
                        ),
                      ),
                    ),
                  )
                : ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    children: [
                      for (final m in state.messages) ...[
                        _Bubble(
                            message: m,
                            onAction: (a) => _runAction(context, a)),
                        const SizedBox(height: 12),
                      ],
                      if (state.typing) const _TypingBubble(),
                    ],
                  ),
          ),
          // Once the conversation is underway the empty-state hero is gone, so
          // keep one compact accent affordance to the precise-request flow
          // pinned above the composer — discoverable in every state.
          if (!state.showPrompts) _requestBar(context),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 108),
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
                        fontFamily: kSans, fontSize: VessType.body, color: t.ink),
                    decoration: InputDecoration(
                      hintText: 'Ask your stylist anything…',
                      hintStyle: TextStyle(
                          fontFamily: kSans, fontSize: VessType.body, color: t.ink3),
                      filled: true,
                      fillColor: t.card,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(VessRadius.md),
                        borderSide: BorderSide(color: t.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(VessRadius.md),
                        borderSide: BorderSide(color: t.accent),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _SendButton(
                  enabled: _controller.text.trim().isNotEmpty,
                  onTap: () => _send(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The composer send button — circular accent control on the app's pill
/// language, with ink feedback, an accessible label, and an empty-state dim so
/// "nothing to send" reads as inactive.
class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Send message',
      child: Material(
        color: enabled ? t.accent : t.accent.withOpacity(0.4),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: const SizedBox(
            width: 50,
            height: 50,
            child: Icon(Icons.arrow_upward, color: Colors.white, size: 21),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.onAction});
  final ChatMessage message;
  final ValueChanged<StylistAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    final ai = message.isAI;
    final action = ai ? message.action : null;

    final bubble = Row(
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
                fontSize: VessType.body,
                height: 1.46,
                color: ai ? t.ink : Colors.white,
              ),
            ),
          ),
        ),
      ],
    );

    if (action == null) return bubble;

    // AI turn with a routing intent → show a tappable action card under it.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        bubble,
        const SizedBox(height: 8),
        _ActionCard(action: action, onTap: () => onAction?.call(action)),
      ],
    );
  }
}

/// The tappable deep-link card the stylist renders for an actionable reply.
class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action, required this.onTap});
  final StylistAction action;
  final VoidCallback onTap;

  IconData get _icon {
    switch (action.type) {
      case StylistActionType.viewOutfit:
        return Icons.checkroom_outlined;
      case StylistActionType.openCanvas:
        return Icons.dashboard_customize_outlined;
      case StylistActionType.openOutfits:
        return Icons.style_outlined;
      case StylistActionType.openItem:
        return Icons.local_mall_outlined;
      case StylistActionType.openTryOn:
        return Icons.camera_alt_outlined;
      case StylistActionType.openCloset:
        return Icons.grid_view_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      child: Semantics(
        button: true,
        label: action.label,
        child: Container(
          decoration: BoxDecoration(
            color: t.accentSoft,
            border: Border.all(color: t.accent.withOpacity(0.35)),
            borderRadius: BorderRadius.circular(VessRadius.sm),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_icon, size: 18, color: t.accent),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(action.label,
                          style: TextStyle(
                              fontFamily: kSans,
                              fontSize: VessType.label,
                              fontWeight: FontWeight.w700,
                              color: t.accent)),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 15, color: t.accent),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The constraint composer — a bottom sheet where the user pins the occasion,
/// colour, weather, and whether to build around favourites before asking. This
/// is the "control + credibility" flow: a precise brief instead of a vague one.
class _RequestSheet extends StatefulWidget {
  const _RequestSheet();

  @override
  State<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<_RequestSheet> {
  static const _occasions = ['Work', 'Smart', 'Casual', 'Formal'];
  static const _colors = [
    'Black', 'White', 'Navy', 'Grey', 'Beige', 'Brown', 'Green', 'Blue', 'Red',
  ];
  static const _weathers = ['Warm', 'Cold'];

  String? _occasion;
  String? _color;
  String? _weather;
  bool _favouritesOnly = false;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  StyleRequest get _request => StyleRequest(
        occasion: _occasion,
        color: _color,
        weather: _weather,
        favouritesOnly: _favouritesOnly,
        note: _note.text,
      );

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: t.bg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(VessRadius.lg)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Request a look', style: serif(context, 24)),
              const SizedBox(height: 4),
              Text("Pin what matters — I'll style to it, not around it.",
                  style: TextStyle(fontFamily: kSans, fontSize: VessType.bodySm, color: t.ink3)),
              const SizedBox(height: 20),
              _label(t, 'OCCASION'),
              _chips(_occasions, _occasion, (v) => setState(() => _occasion = v)),
              const SizedBox(height: 18),
              _label(t, 'COLOUR'),
              // Swatch chips, not grey text — a wardrobe app's colour picker
              // should speak Vess's own colour language.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in _colors)
                    _ColorChip(
                      label: c,
                      active: _color == c,
                      onTap: () =>
                          setState(() => _color = _color == c ? null : c),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _label(t, 'WEATHER'),
              _chips(_weathers, _weather, (v) => setState(() => _weather = v)),
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                  color: t.card,
                  border: Border.all(color: t.line),
                  borderRadius: BorderRadius.circular(VessRadius.sm),
                ),
                clipBehavior: Clip.antiAlias,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () =>
                        setState(() => _favouritesOnly = !_favouritesOnly),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.favorite_border, size: 18, color: t.accent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('Build around my favourites',
                                style: TextStyle(
                                    fontFamily: kSans,
                                    fontSize: VessType.body,
                                    color: t.ink)),
                          ),
                          Switch.adaptive(
                            value: _favouritesOnly,
                            activeColor: t.accent,
                            onChanged: (v) =>
                                setState(() => _favouritesOnly = v),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _label(t, 'ANYTHING ELSE'),
              TextField(
                controller: _note,
                style: TextStyle(fontFamily: kSans, fontSize: VessType.body, color: t.ink),
                decoration: InputDecoration(
                  hintText: 'e.g. no heels, keep it minimal',
                  hintStyle: TextStyle(
                      fontFamily: kSans, fontSize: VessType.bodySm, color: t.ink3),
                  filled: true,
                  fillColor: t.card,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(VessRadius.sm),
                    borderSide: BorderSide(color: t.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(VessRadius.sm),
                    borderSide: BorderSide(color: t.accent),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              AccentButton(
                label: 'Ask for this look',
                expand: true,
                trailing: Icons.auto_awesome,
                onTap: _request.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(_request),
              ),
              if (_request.isEmpty) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text('Pick at least one constraint',
                      style: TextStyle(
                          fontFamily: kSans, fontSize: VessType.label, color: t.ink3)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(dynamic t, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: eyebrow(t.ink3, size: 10.5).copyWith(letterSpacing: 1.2)),
      );

  Widget _chips(List<String> options, String? selected, ValueChanged<String?> onPick) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          VessChip(
            label: o,
            active: selected == o,
            // Tapping the active chip clears it — every constraint is optional.
            onTap: () => onPick(selected == o ? null : o),
          ),
      ],
    );
  }
}

/// A colour chip that leads with a real swatch dot (Vess's colour language),
/// so the composer's colour picker reads as a styling control, not a form.
class _ColorChip extends StatelessWidget {
  const _ColorChip(
      {required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(VessRadius.pill),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.fromLTRB(7, 7, 14, 7),
          decoration: BoxDecoration(
            color: active ? t.ink : t.card,
            border: Border.all(color: active ? t.ink : t.line),
            borderRadius: BorderRadius.circular(VessRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: swatchColor(label),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black.withOpacity(0.12)),
                ),
              ),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: VessType.label,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active ? t.bg : t.ink2,
                  )),
            ],
          ),
        ),
      ),
    ),
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
