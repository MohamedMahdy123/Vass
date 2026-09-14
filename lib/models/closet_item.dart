import 'package:flutter/material.dart';

/// A single garment. [a] and [b] are the gradient stops the design uses in
/// place of product photography.
class ClosetItem {
  const ClosetItem({
    required this.id,
    required this.name,
    required this.brand,
    required this.cat,
    required this.color,
    required this.season,
    required this.occ,
    required this.worn,
    required this.a,
    required this.b,
    this.fav = false,
  });

  final int id;
  final String name;
  final String brand;
  final String cat;
  final String color;
  final String season;
  final String occ;
  final String worn;
  final Color a;
  final Color b;
  final bool fav;

  ClosetItem copyWith({bool? fav}) => ClosetItem(
        id: id,
        name: name,
        brand: brand,
        cat: cat,
        color: color,
        season: season,
        occ: occ,
        worn: worn,
        a: a,
        b: b,
        fav: fav ?? this.fav,
      );

  /// True when the swatch is pale enough to need dark text on top of it.
  bool get isLight => a.computeLuminance() > 0.6;
}
