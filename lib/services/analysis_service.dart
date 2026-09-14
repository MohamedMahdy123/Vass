import 'dart:convert';
import 'dart:typed_data';

import '../core/supabase_service.dart';

/// Sends a garment photo to the `analyze-item` Edge Function (Claude Haiku) and
/// returns detected attributes. In demo mode — or before the function is
/// deployed and the Anthropic key is set — it returns a plausible stub so the
/// capture → review flow is fully walkable.
class AnalysisService {
  bool get isLive =>
      SupabaseService.isReady &&
      SupabaseService.client.auth.currentUser != null;

  Future<Map<String, dynamic>> analyze(Uint8List bytes) async {
    if (isLive) {
      final res = await SupabaseService.client.functions.invoke(
        'analyze-item',
        body: {'imageBase64': base64Encode(bytes), 'mediaType': 'image/jpeg'},
      );
      final data = res.data;
      if (data is Map && data['attributes'] is Map) {
        return Map<String, dynamic>.from(data['attributes'] as Map);
      }
      // Function reachable but returned an error shape — fall through to a
      // neutral draft the user can fill in rather than blocking the save.
      return _neutral();
    }

    // Demo: pretend to analyze, rotating through a few plausible pieces.
    await Future.delayed(const Duration(milliseconds: 650));
    final stub = _demoStubs[_demoSeq++ % _demoStubs.length];
    return Map<String, dynamic>.from(stub);
  }

  int _demoSeq = 0;

  Map<String, dynamic> _neutral() => {
        'name': 'New piece',
        'category': 'Tops',
        'color': null,
        'material': null,
        'pattern': null,
        'season': null,
        'occasion': null,
        'brand': null,
      };

  static const _demoStubs = <Map<String, dynamic>>[
    {'name': 'White Tee', 'category': 'Tops', 'color': 'White', 'material': 'Cotton', 'pattern': 'Solid', 'season': 'Summer', 'occasion': 'Casual', 'brand': null},
    {'name': 'Straight Jeans', 'category': 'Bottoms', 'color': 'Indigo', 'material': 'Denim', 'pattern': 'Solid', 'season': 'All', 'occasion': 'Casual', 'brand': null},
    {'name': 'Wool Coat', 'category': 'Outerwear', 'color': 'Camel', 'material': 'Wool', 'pattern': 'Solid', 'season': 'Winter', 'occasion': 'Smart', 'brand': null},
    {'name': 'Leather Boots', 'category': 'Footwear', 'color': 'Brown', 'material': 'Leather', 'pattern': 'Solid', 'season': 'Autumn', 'occasion': 'Casual', 'brand': null},
    {'name': 'Silk Scarf', 'category': 'Accessories', 'color': 'Sage', 'material': 'Silk', 'pattern': 'Solid', 'season': 'All', 'occasion': 'Smart', 'brand': null},
  ];
}
