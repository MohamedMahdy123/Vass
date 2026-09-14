import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/closet_item.dart';

class ChatMessage {
  const ChatMessage(this.text, {required this.isAI});
  final String text;
  final bool isAI;
}

/// Single source of truth for the prototype. Mirrors the design doc's `state`
/// object: theme, closet, outfit builder and the stylist conversation.
class AppState extends ChangeNotifier {
  // ---- theme ----
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  void setDark(bool value) {
    _themeMode = value ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  // ---- closet ----
  final List<ClosetItem> _closet = List.of(kCloset);
  List<ClosetItem> get closet => List.unmodifiable(_closet);

  String _category = 'All';
  String get category => _category;

  void setCategory(String c) {
    _category = c;
    notifyListeners();
  }

  List<ClosetItem> get visibleCloset =>
      _category == 'All' ? closet : _closet.where((i) => i.cat == _category).toList();

  ClosetItem itemById(int id) => _closet.firstWhere((i) => i.id == id);

  void toggleFav(int id) {
    final i = _closet.indexWhere((e) => e.id == id);
    if (i == -1) return;
    _closet[i] = _closet[i].copyWith(fav: !_closet[i].fav);
    notifyListeners();
  }

  List<ClosetItem> get wishlist => _closet.where((i) => i.fav).toList();

  // ---- outfit builder ----
  /// Slot name -> chosen item. Slots match the design's builder screen.
  static const slots = ['Top', 'Bottom', 'Outerwear', 'Shoes'];
  static const _slotCat = {
    'Top': 'Tops',
    'Bottom': 'Bottoms',
    'Outerwear': 'Outerwear',
    'Shoes': 'Footwear',
  };

  final Map<String, ClosetItem> _outfit = {};
  Map<String, ClosetItem> get outfit => Map.unmodifiable(_outfit);
  int get outfitCount => _outfit.length;

  List<ClosetItem> optionsFor(String slot) =>
      _closet.where((i) => i.cat == _slotCat[slot]).toList();

  void pick(String slot, ClosetItem item) {
    _outfit[slot] = item;
    notifyListeners();
  }

  void clearOutfit() {
    _outfit.clear();
    notifyListeners();
  }

  /// Fills every empty slot with the first available piece — the design's
  /// "AI fill" affordance, without an actual model behind it.
  void aiFill() {
    for (final slot in slots) {
      if (_outfit.containsKey(slot)) continue;
      final options = optionsFor(slot);
      if (options.isNotEmpty) _outfit[slot] = options.first;
    }
    notifyListeners();
  }

  // ---- stylist ----
  final List<ChatMessage> _messages = [
    const ChatMessage(
      'Morning, Maya. It is 14° and overcast — I would lean into layers today.',
      isAI: true,
    ),
    const ChatMessage(
      'Your Wool Overcoat over the Emerald Knit, with the Tailored Trousers. Quiet, warm, and it photographs well.',
      isAI: true,
    ),
  ];
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get showPrompts => _messages.length <= 2;

  bool _typing = false;
  bool get typing => _typing;

  /// Canned replies — this prototype has no model behind it, and shouldn't
  /// pretend otherwise.
  static const _replies = [
    'Try the Cropped Trench over the Silk Blouse — it lifts the whole look without shouting.',
    'The Leather Loafers ground that outfit better than the sneakers for a dinner.',
    'You have not worn the Linen Dress in 20 days. Pair it with the Cashmere Scarf.',
  ];
  int _replyIndex = 0;

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _typing) return;

    _messages.add(ChatMessage(trimmed, isAI: false));
    _typing = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 900));

    _messages.add(ChatMessage(_replies[_replyIndex % _replies.length], isAI: true));
    _replyIndex++;
    _typing = false;
    notifyListeners();
  }
}
