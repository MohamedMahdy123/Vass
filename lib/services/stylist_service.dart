import '../core/supabase_service.dart';
import '../data/models/item.dart';
import 'outfit_engine.dart';

/// One turn in the stylist conversation.
class ChatMessage {
  const ChatMessage(this.text, {required this.isAI});
  final String text;
  final bool isAI;
}

/// Answers styling questions over the user's *real* wardrobe. Live, it calls
/// the `stylist` Edge Function (Claude Sonnet with the closet as context); in
/// demo mode it reasons locally with [OutfitEngine] so replies are concrete and
/// grounded in the actual closet — never canned strings.
class StylistService {
  bool get isLive =>
      SupabaseService.isReady &&
      SupabaseService.client.auth.currentUser != null;

  Future<String> ask(
    String message,
    List<Item> wardrobe, {
    List<ChatMessage> history = const [],
    int seed = 0,
  }) async {
    if (isLive) {
      try {
        final res = await SupabaseService.client.functions.invoke(
          'stylist',
          body: {
            'message': message,
            'items': wardrobe.map((i) => {
                  'id': i.id,
                  'name': i.name,
                  'category': i.category,
                  'color': i.color,
                  'season': i.season,
                  'occasion': i.occasion,
                  'favorite': i.favorite,
                }).toList(),
            'history': history
                .map((m) => {'role': m.isAI ? 'assistant' : 'user', 'text': m.text})
                .toList(),
          },
        );
        final data = res.data;
        if (data is Map && data['reply'] is String) {
          return data['reply'] as String;
        }
      } catch (_) {
        // Fall through to the local responder.
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 700));
    return _localReply(message, wardrobe, seed: seed);
  }

  // --- Local (demo / fallback) reasoning ------------------------------------

  String _localReply(String message, List<Item> wardrobe, {int seed = 0}) {
    if (wardrobe.isEmpty) {
      return "Your closet's empty right now — add a few pieces and I'll start "
          "putting looks together for you.";
    }
    final m = message.toLowerCase();

    // Favourites / wishlist.
    if (m.contains('favou') || m.contains('favor') || m.contains('wishlist') ||
        m.contains('love')) {
      final favs = wardrobe.where((i) => i.favorite).map((i) => i.name).toList();
      if (favs.isEmpty) {
        return "You haven't starred anything yet. Tap the heart on pieces you "
            "love and I'll lean into them.";
      }
      return "Your favourites right now: ${_list(favs)}. Want me to build a "
          "look around one of them?";
    }

    final occasion = _occasion(m);
    final weather = _weather(m);
    final wantsOutfit = occasion != null ||
        weather != null ||
        _mentionsAny(m, const [
          'wear', 'outfit', 'look', 'dress', 'style', 'suggest', 'today',
          'tomorrow', 'put together', 'what should',
        ]);

    if (wantsOutfit) {
      final outfit = OutfitEngine.build(
        wardrobe,
        occasion: occasion ?? 'Everyday',
        weather: weather,
        seed: seed,
      );
      if (outfit == null) {
        return "I tried to pull a full look together but came up short — you "
            "might be missing a bottom or shoes for that. Add a piece or two "
            "and ask me again.";
      }
      final lead = occasion != null ? "For ${occasion.toLowerCase()}: " : '';
      return "$lead${outfit.title}. ${outfit.reason}";
    }

    // Default — orient them, grounded in the real closet.
    final n = wardrobe.length;
    return "You've got $n pieces to work with. Ask me what to wear for work, a "
        "dinner, or an easy day — or say the weather — and I'll build a look "
        "from your closet.";
  }

  String? _occasion(String m) {
    if (_mentionsAny(m, const ['formal', 'gala', 'wedding', 'black tie'])) return 'Formal';
    if (_mentionsAny(m, const ['work', 'office', 'meeting', 'interview', 'business'])) return 'Work';
    if (_mentionsAny(m, const ['dinner', 'date', 'evening', 'party', 'drinks', 'smart'])) return 'Smart';
    if (_mentionsAny(m, const ['casual', 'weekend', 'errand', 'relax', 'chill', 'everyday'])) return 'Casual';
    return null;
  }

  String? _weather(String m) {
    if (_mentionsAny(m, const ['cold', 'snow', 'freezing', 'chilly', 'winter'])) return 'Cold';
    if (_mentionsAny(m, const ['hot', 'warm', 'sunny', 'summer'])) return 'Warm';
    return null;
  }

  bool _mentionsAny(String m, List<String> words) => words.any(m.contains);

  String _list(List<String> items) {
    if (items.length == 1) return items.first;
    if (items.length == 2) return '${items[0]} and ${items[1]}';
    final head = items.take(items.length - 1).join(', ');
    return '$head, and ${items.last}';
  }
}
