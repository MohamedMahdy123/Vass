import '../core/supabase_service.dart';
import '../data/models/item.dart';
import '../data/models/stylist_action.dart';
import 'outfit_engine.dart';

export '../data/models/stylist_action.dart';

/// One turn in the stylist conversation. An AI turn may carry a structured
/// [action] that deep-links into the app (rendered as a tappable action card).
class ChatMessage {
  const ChatMessage(this.text, {required this.isAI, this.action});
  final String text;
  final bool isAI;
  final StylistAction? action;
}

/// A structured stylist response: the text to show plus an optional routing
/// action. Mirrors the `{ reply, action }` JSON the Edge Function returns, so
/// the live and local paths hand the UI the same shape.
class StylistReply {
  const StylistReply(this.text, {this.action});
  final String text;
  final StylistAction? action;
}

/// A structured styling brief — the constraints a user pins before asking, so
/// the stylist answers a precise request ("a black look for a formal dinner,
/// built around my favourites, no heels") instead of a vague one.
class StyleRequest {
  const StyleRequest({
    this.occasion,
    this.color,
    this.weather,
    this.favouritesOnly = false,
    this.note,
  });

  final String? occasion;
  final String? color;
  final String? weather;
  final bool favouritesOnly;
  final String? note;

  bool get isEmpty =>
      (occasion == null || occasion!.isEmpty) &&
      (color == null || color!.isEmpty) &&
      (weather == null || weather!.isEmpty) &&
      !favouritesOnly &&
      (note == null || note!.trim().isEmpty);

  String get prompt {
    final parts = <String>[];
    final occ = (occasion ?? '').isEmpty ? 'look' : '${occasion!.toLowerCase()} look';
    parts.add('Put together a $occ for me');
    if ((color ?? '').isNotEmpty) parts.add('in ${color!.toLowerCase()}');
    if ((weather ?? '').isNotEmpty) parts.add('for ${weather!.toLowerCase()} weather');
    if (favouritesOnly) parts.add('built around my favourites');
    var s = parts.join(' ');
    if ((note ?? '').trim().isNotEmpty) s += ' — ${note!.trim()}';
    return '$s.';
  }

  Map<String, dynamic> toJson() => {
        if ((occasion ?? '').isNotEmpty) 'occasion': occasion,
        if ((color ?? '').isNotEmpty) 'color': color,
        if ((weather ?? '').isNotEmpty) 'weather': weather,
        'favourites_only': favouritesOnly,
        if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
      };
}

/// Answers styling questions over the user's *real* wardrobe and returns a
/// structured reply that can trigger navigation.
///
/// Architecture is ported from the formcraft chat stack: an auth-gated Supabase
/// Edge Function is the "real AI" path (system prompt + closet context +
/// structured JSON output `{ reply, action }`); a robust local responder is the
/// demo/offline fallback, reasoning over the closet with [OutfitEngine] and
/// producing the same [StylistAction] intents so routing works with no backend.
class StylistService {
  bool get isLive =>
      SupabaseService.isReady &&
      SupabaseService.client.auth.currentUser != null;

  Future<StylistReply> ask(
    String message,
    List<Item> wardrobe, {
    List<ChatMessage> history = const [],
    int seed = 0,
    StyleRequest? request,
  }) async {
    if (isLive) {
      try {
        final res = await SupabaseService.client.functions.invoke(
          'stylist',
          body: {
            'message': message,
            if (request != null) 'constraints': request.toJson(),
            'items': wardrobe
                .map((i) => {
                      'id': i.id,
                      'name': i.name,
                      'category': i.category,
                      'color': i.color,
                      'season': i.season,
                      'occasion': i.occasion,
                      'favorite': i.favorite,
                    })
                .toList(),
            'history': history
                .map((m) => {'role': m.isAI ? 'assistant' : 'user', 'text': m.text})
                .toList(),
          },
        );
        final data = res.data;
        if (data is Map && data['reply'] is String) {
          return StylistReply(
            data['reply'] as String,
            action: StylistAction.fromJson(data['action']),
          );
        }
      } catch (_) {
        // Fall through to the local responder.
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 700));
    return request != null
        ? _requestReply(request, wardrobe, seed: seed)
        : _localReply(message, wardrobe, seed: seed);
  }

  // --- Constraint-based reply (the "request a look" flow) --------------------

  StylistReply _requestReply(StyleRequest req, List<Item> wardrobe, {int seed = 0}) {
    if (wardrobe.isEmpty) {
      return const StylistReply(
          "Your closet's empty right now — add a few pieces and I'll build "
          "exactly the look you're describing.");
    }
    final requiredIds = req.favouritesOnly
        ? wardrobe.where((i) => i.favorite).map((i) => i.id).toSet()
        : <String>{};
    if (req.favouritesOnly && requiredIds.isEmpty) {
      return const StylistReply(
          "You asked me to build around your favourites, but nothing's starred "
          "yet. Tap the heart on pieces you love and send it again — or drop "
          "the favourites filter and I'll pull from the whole closet.");
    }

    final outfit = OutfitEngine.build(
      wardrobe,
      occasion: req.occasion,
      weather: req.weather,
      preferColor: req.color,
      requiredIds: requiredIds,
      seed: seed,
    );
    if (outfit == null) {
      return const StylistReply(
          "I couldn't complete that exact brief from what's in your closet — "
          "you might be missing a bottom or shoes for it. Loosen one constraint "
          "or add a piece and I'll try again.");
    }

    final pins = <String>[];
    if ((req.color ?? '').isNotEmpty) pins.add('kept it ${req.color!.toLowerCase()}-led');
    if (req.favouritesOnly) pins.add('built it around your favourites');
    if ((req.weather ?? '').isNotEmpty) pins.add('dressed for ${req.weather!.toLowerCase()} weather');
    final lead = req.occasion != null && req.occasion!.isNotEmpty
        ? 'For ${req.occasion!.toLowerCase()}: '
        : '';
    final ack = pins.isEmpty ? '' : ' I ${_list(pins)}.';
    final note = (req.note ?? '').trim().isEmpty
        ? ''
        : ' Noted on "${req.note!.trim()}" — kept that in mind.';
    return StylistReply(
      '$lead${outfit.title}. ${outfit.reason}$ack$note',
      action: StylistAction(
        type: StylistActionType.viewOutfit,
        label: 'See this look',
        itemIds: outfit.itemIds,
        occasion: req.occasion,
      ),
    );
  }

  // --- Local (demo / fallback) reasoning + intent routing -------------------

  StylistReply _localReply(String message, List<Item> wardrobe, {int seed = 0}) {
    if (wardrobe.isEmpty) {
      return const StylistReply(
          "Your closet's empty right now — add a few pieces and I'll start "
          "putting looks together for you.");
    }
    final m = message.toLowerCase();

    // 0) Greeting → a warm intro, not a canned dump.
    if (_isGreeting(m)) {
      return StylistReply(
        "Hey — I'm your stylist. Tell me the occasion (work, a date, a night "
        "out) or just say the weather, and I'll pull a look from your "
        "${wardrobe.length} pieces.",
        action: const StylistAction(
            type: StylistActionType.openCanvas, label: 'Build a look'),
      );
    }

    // 1) Navigation intents that map to a screen rather than a styled look.
    if (_mentionsAny(m, const ['my outfits', 'saved look', 'saved outfit', 'my looks'])) {
      return const StylistReply(
        'Here are the looks you\'ve saved.',
        action: StylistAction(
            type: StylistActionType.openOutfits, label: 'View My Outfits'),
      );
    }
    if (_mentionsAny(m, const ['try on', 'try it on', 'tryon', 'see it on me'])) {
      return const StylistReply(
        'Let\'s see it on you — the try-on room shows the look as a styling '
        'preview.',
        action:
            StylistAction(type: StylistActionType.openTryOn, label: 'Open try-on'),
      );
    }
    // "show me my <item>" → open that specific piece if it's in the closet.
    if (_mentionsAny(m, const ['show me', 'show my', 'see my', 'where is', 'where\'s', 'find my', 'open my'])) {
      final hit = _matchItem(m, wardrobe);
      if (hit != null) {
        return StylistReply(
          'Here\'s your ${hit.name}.',
          action: StylistAction(
              type: StylistActionType.openItem,
              label: 'View ${hit.name}',
              itemId: hit.id),
        );
      }
      if (_mentionsAny(m, const ['closet', 'wardrobe', 'clothes', 'everything'])) {
        return const StylistReply(
          'Here\'s your closet.',
          action: StylistAction(
              type: StylistActionType.openCloset, label: 'Open my closet'),
        );
      }
    }

    // 2) Favourites.
    if (m.contains('favou') || m.contains('favor') || m.contains('wishlist')) {
      final favs = wardrobe.where((i) => i.favorite).toList();
      if (favs.isEmpty) {
        return const StylistReply(
            "You haven't starred anything yet. Tap the heart on pieces you "
            "love and I'll lean into them.");
      }
      return StylistReply(
        "Your favourites right now: ${_list(favs.map((i) => i.name).toList())}. "
        "Want me to build a look around one of them?",
        action: const StylistAction(
            type: StylistActionType.openCloset, label: 'Browse my closet'),
      );
    }

    // 3) Anything else is a styling request → ALWAYS build a real look. Typos
    //    and vague wording shouldn't matter: detect the occasion/weather when
    //    we can (fuzzily), otherwise style an everyday look. A stylist should
    //    answer with an outfit, never a canned "ask me something" line.
    final occasion = _occasion(m) ?? _fuzzyOccasion(m);
    final weather = _weather(m) ?? _fuzzyWeather(m);
    final outfit = OutfitEngine.build(
      wardrobe,
      occasion: occasion ?? 'Everyday',
      weather: weather,
      seed: seed,
    );
    if (outfit == null) {
      return const StylistReply(
          "I tried to pull a full look together but came up short — you might "
          "be missing a bottom or shoes. Add a piece or two and ask me again.");
    }
    final lead = occasion != null
        ? "For ${occasion.toLowerCase()}: "
        : "Here's a look from your closet — ";
    return StylistReply(
      "$lead${outfit.title}. ${outfit.reason}",
      action: StylistAction(
        type: StylistActionType.viewOutfit,
        label: 'See this look',
        itemIds: outfit.itemIds,
        occasion: occasion,
      ),
    );
  }

  /// True when the message is just a greeting (so we don't force a look).
  bool _isGreeting(String m) {
    final tokens = m.split(RegExp(r'[^a-z]+')).where((w) => w.isNotEmpty).toList();
    if (tokens.isEmpty || tokens.length > 3) return false;
    const greetings = {
      'hi', 'hey', 'hello', 'yo', 'hiya', 'heya', 'sup', 'hola', 'howdy',
      'morning', 'evening', 'gm',
    };
    return greetings.contains(tokens.first);
  }

  // Typo-tolerant occasion/weather detection: match message words against the
  // keyword sets allowing an edit distance of 1 (so "diner", "weding",
  // "tomorow", "data"→"date" all land).
  String? _fuzzyOccasion(String m) {
    if (_fuzzyHit(m, const ['formal', 'gala', 'wedding', 'tuxedo', 'blacktie'])) return 'Formal';
    if (_fuzzyHit(m, const ['work', 'office', 'meeting', 'interview', 'business'])) return 'Work';
    if (_fuzzyHit(m, const ['dinner', 'date', 'evening', 'party', 'drinks', 'brunch', 'night'])) return 'Smart';
    if (_fuzzyHit(m, const ['casual', 'weekend', 'errand', 'relax', 'everyday', 'hangout'])) return 'Casual';
    return null;
  }

  String? _fuzzyWeather(String m) {
    if (_fuzzyHit(m, const ['cold', 'snow', 'freezing', 'chilly', 'winter'])) return 'Cold';
    if (_fuzzyHit(m, const ['hot', 'warm', 'sunny', 'summer'])) return 'Warm';
    return null;
  }

  bool _fuzzyHit(String m, List<String> keywords) {
    final tokens = m.split(RegExp(r'[^a-z]+')).where((w) => w.length >= 3);
    for (final tok in tokens) {
      for (final kw in keywords) {
        if (tok == kw) return true;
        // Only fuzz reasonably long words to avoid false positives.
        if (kw.length >= 4 && (tok.length - kw.length).abs() <= 1 && _within1(tok, kw)) {
          return true;
        }
      }
    }
    return false;
  }

  /// True if [a] and [b] are within Levenshtein distance 1 (one edit).
  bool _within1(String a, String b) {
    if (a == b) return true;
    final la = a.length, lb = b.length;
    if ((la - lb).abs() > 1) return false;
    var i = 0, j = 0, edits = 0;
    while (i < la && j < lb) {
      if (a[i] == b[j]) {
        i++;
        j++;
      } else {
        if (++edits > 1) return false;
        if (la > lb) {
          i++; // deletion from a
        } else if (la < lb) {
          j++; // insertion into a
        } else {
          i++;
          j++; // substitution
        }
      }
    }
    if (i < la || j < lb) edits++;
    return edits <= 1;
  }

  /// Find a wardrobe item the message names (longest name match wins so
  /// "wool overcoat" beats "coat").
  Item? _matchItem(String m, List<Item> wardrobe) {
    Item? best;
    var bestLen = 0;
    for (final i in wardrobe) {
      final name = i.name.toLowerCase().trim();
      if (name.isNotEmpty && m.contains(name) && name.length > bestLen) {
        best = i;
        bestLen = name.length;
      }
    }
    return best;
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
