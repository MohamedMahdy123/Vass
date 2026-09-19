import 'package:flutter/foundation.dart';

import '../data/models/item.dart';
import '../services/stylist_service.dart';

export '../services/stylist_service.dart'
    show ChatMessage, StyleRequest, StylistReply;
export '../data/models/stylist_action.dart';

/// The stylist conversation, grounded in the user's real wardrobe. Replaces the
/// prototype's canned chat in [AppState].
class StylistState extends ChangeNotifier {
  final _service = StylistService();

  final List<ChatMessage> _messages = [
    const ChatMessage(
      "Hi — I'm your stylist. Tell me the occasion or the weather and I'll put "
      "a look together from your own closet.",
      isAI: true,
    ),
  ];

  bool _typing = false;
  int _seq = 0;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get typing => _typing;

  /// Show the starter prompts until the user has actually asked something.
  bool get showPrompts => _messages.where((m) => !m.isAI).isEmpty;

  bool get isLive => _service.isLive;

  Future<void> send(String text, List<Item> wardrobe) => _ask(text, wardrobe);

  /// Send a structured styling brief (the "request a look" composer). The
  /// user's bubble shows the request in plain language; the stylist honours the
  /// pinned constraints.
  Future<void> sendRequest(StyleRequest request, List<Item> wardrobe) =>
      _ask(request.prompt, wardrobe, request: request);

  Future<void> _ask(String text, List<Item> wardrobe,
      {StyleRequest? request}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _typing) return;

    _messages.add(ChatMessage(trimmed, isAI: false));
    _typing = true;
    notifyListeners();

    try {
      final reply = await _service.ask(
        trimmed,
        wardrobe,
        history: _messages,
        seed: _seq++,
        request: request,
      );
      _messages.add(ChatMessage(reply.text, isAI: true, action: reply.action));
    } catch (_) {
      _messages.add(const ChatMessage(
        "Sorry — I couldn't think straight just now. Try me again?",
        isAI: true,
      ));
    } finally {
      _typing = false;
      notifyListeners();
    }
  }
}
