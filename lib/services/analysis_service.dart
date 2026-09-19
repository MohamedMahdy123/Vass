import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/supabase_service.dart';

/// Sends a garment photo to the `analyze-item` Edge Function (Claude Haiku) and
/// returns detected attributes. In demo mode — or before the function is
/// deployed and the Anthropic key is set — it returns a plausible stub so the
/// capture → review flow is fully walkable.
class AnalysisService {
  bool get isLive =>
      SupabaseService.isReady &&
      SupabaseService.client.auth.currentUser != null;

  /// Diagnostics from the most recent [analyze] call — read by the capture UI
  /// so we can show the user exactly why tags are real vs. stubbed.
  bool lastLive = false;
  String? lastError;

  Future<Map<String, dynamic>> analyze(
    Uint8List bytes, {
    String mediaType = 'image/jpeg',
  }) async {
    lastLive = isLive;
    lastError = null;

    if (!isLive) {
      // Explain WHY we're not live, so the stub isn't mistaken for real AI.
      final why = !SupabaseService.isReady
          ? 'Supabase not configured (build without SUPABASE_URL/ANON_KEY)'
          : 'not signed in';
      lastError = 'demo mode: $why';
      debugPrint('[analyze-item] $lastError — returning stub tags');
      // Demo: pretend to analyze, rotating through a few plausible pieces.
      await Future.delayed(const Duration(milliseconds: 650));
      final stub = _demoStubs[_demoSeq++ % _demoStubs.length];
      return Map<String, dynamic>.from(stub);
    }

    try {
      final res = await SupabaseService.client.functions.invoke(
        'analyze-item',
        body: {'imageBase64': base64Encode(bytes), 'mediaType': mediaType},
      );
      final data = res.data;
      if (data is Map && data['attributes'] is Map) {
        debugPrint('[analyze-item] live tags received');
        return Map<String, dynamic>.from(data['attributes'] as Map);
      }
      // Function reachable but returned an error shape — surface it, then fall
      // through to a neutral draft rather than blocking the save.
      lastError = 'edge function error: ${data is Map ? (data['error'] ?? data) : data}';
      debugPrint('[analyze-item] $lastError');
      return _neutral();
    } catch (e) {
      lastError = e.toString();
      debugPrint('[analyze-item] invoke failed: $e');
      return _neutral();
    }
  }

  int _demoSeq = 0;

  Map<String, dynamic> _neutral() => {
        'name': 'New piece',
        'category': 'Tops',
        'sub_category': null,
        'color_primary': null,
        'color_secondary': null,
        'fabric_type': null,
        'pattern': null,
        'occasions': <String>[],
        'seasons': <String>[],
        'weather_tags': <String>[],
        'brand': null,
      };

  // Rich, structured tags — the shape the Haiku vision model returns live. The
  // capture flow reads both the rich lists and the legacy single keys.
  static const _demoStubs = <Map<String, dynamic>>[
    {'name': 'White Tee', 'category': 'Tops', 'sub_category': 'T-shirt', 'color_primary': 'White', 'color_secondary': null, 'fabric_type': 'Cotton', 'pattern': 'Solid', 'occasions': ['Casual'], 'seasons': ['Spring', 'Summer'], 'weather_tags': ['Warm', 'Hot'], 'brand': null},
    {'name': 'Straight Jeans', 'category': 'Bottoms', 'sub_category': 'Jeans', 'color_primary': 'Indigo', 'color_secondary': null, 'fabric_type': 'Denim', 'pattern': 'Solid', 'occasions': ['Casual', 'Work'], 'seasons': ['All'], 'weather_tags': ['Mild', 'Cold'], 'brand': null},
    {'name': 'Wool Coat', 'category': 'Outerwear', 'sub_category': 'Overcoat', 'color_primary': 'Camel', 'color_secondary': null, 'fabric_type': 'Wool', 'pattern': 'Solid', 'occasions': ['Smart', 'Work'], 'seasons': ['Winter'], 'weather_tags': ['Cold'], 'brand': null},
    {'name': 'Leather Boots', 'category': 'Footwear', 'sub_category': 'Chelsea boot', 'color_primary': 'Brown', 'color_secondary': null, 'fabric_type': 'Leather', 'pattern': 'Solid', 'occasions': ['Casual', 'Smart'], 'seasons': ['Autumn', 'Winter'], 'weather_tags': ['Cold', 'Rain'], 'brand': null},
    {'name': 'Silk Scarf', 'category': 'Accessories', 'sub_category': 'Scarf', 'color_primary': 'Sage', 'color_secondary': 'Ivory', 'fabric_type': 'Silk', 'pattern': 'Solid', 'occasions': ['Smart', 'Party'], 'seasons': ['All'], 'weather_tags': ['Mild'], 'brand': null},
  ];
}
