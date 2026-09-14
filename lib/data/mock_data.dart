import 'package:flutter/material.dart';

import '../models/closet_item.dart';

/// The 15-piece wardrobe from the design doc, kept in the same order so screen
/// compositions that index into it (today's outfit, "recent") still line up.
const kCloset = <ClosetItem>[
  ClosetItem(id: 1, name: 'Ribbed Wool Sweater', brand: 'Halden', cat: 'Tops', color: 'Ash', season: 'Winter', occ: 'Casual', fav: true, worn: '2 days ago', a: Color(0xFF8A857B), b: Color(0xFF67635B)),
  ClosetItem(id: 2, name: 'Oxford Shirt', brand: 'Nord', cat: 'Tops', color: 'Ivory', season: 'All', occ: 'Work', worn: '5 days ago', a: Color(0xFFF2EDE3), b: Color(0xFFDAD3C6)),
  ClosetItem(id: 3, name: 'Silk Blouse', brand: 'Lune', cat: 'Tops', color: 'Sand', season: 'Spring', occ: 'Work', fav: true, worn: '8 days ago', a: Color(0xFFD3C3AE), b: Color(0xFFB7A48B)),
  ClosetItem(id: 4, name: 'Tailored Trousers', brand: 'Atelier', cat: 'Bottoms', color: 'Charcoal', season: 'All', occ: 'Work', worn: '1 day ago', a: Color(0xFF33343A), b: Color(0xFF212228)),
  ClosetItem(id: 5, name: 'Straight Jeans', brand: 'Beau', cat: 'Bottoms', color: 'Indigo', season: 'All', occ: 'Casual', fav: true, worn: '3 days ago', a: Color(0xFF41506B), b: Color(0xFF2C384F)),
  ClosetItem(id: 6, name: 'Pleated Skirt', brand: 'Maison K', cat: 'Bottoms', color: 'Espresso', season: 'Autumn', occ: 'Smart', worn: '12 days ago', a: Color(0xFF3A342E), b: Color(0xFF26221D)),
  ClosetItem(id: 7, name: 'Wool Overcoat', brand: 'Kestrel', cat: 'Outerwear', color: 'Taupe', season: 'Winter', occ: 'Work', fav: true, worn: '4 days ago', a: Color(0xFF57524A), b: Color(0xFF3D3932)),
  ClosetItem(id: 8, name: 'Cropped Trench', brand: 'Lune', cat: 'Outerwear', color: 'Camel', season: 'Spring', occ: 'Smart', worn: '6 days ago', a: Color(0xFFCDB999), b: Color(0xFFB29B77)),
  ClosetItem(id: 9, name: 'Leather Jacket', brand: 'Nord', cat: 'Outerwear', color: 'Onyx', season: 'Autumn', occ: 'Casual', worn: '16 days ago', a: Color(0xFF2A2724), b: Color(0xFF171512)),
  ClosetItem(id: 10, name: 'Minimal Sneakers', brand: 'Beau', cat: 'Footwear', color: 'Chalk', season: 'All', occ: 'Casual', fav: true, worn: '1 day ago', a: Color(0xFFF0EDE6), b: Color(0xFFDCD6CA)),
  ClosetItem(id: 11, name: 'Leather Loafers', brand: 'Atelier', cat: 'Footwear', color: 'Cognac', season: 'All', occ: 'Work', worn: '4 days ago', a: Color(0xFF5A4636), b: Color(0xFF3D2E22)),
  ClosetItem(id: 12, name: 'Emerald Knit', brand: 'Halden', cat: 'Tops', color: 'Emerald', season: 'Winter', occ: 'Casual', fav: true, worn: '9 days ago', a: Color(0xFF178C64), b: Color(0xFF0C5E43)),
  ClosetItem(id: 13, name: 'Structured Tote', brand: 'Maison K', cat: 'Accessories', color: 'Mocha', season: 'All', occ: 'Work', worn: '2 days ago', a: Color(0xFF7A6A58), b: Color(0xFF59493A)),
  ClosetItem(id: 14, name: 'Cashmere Scarf', brand: 'Lune', cat: 'Accessories', color: 'Sage', season: 'Winter', occ: 'Casual', fav: true, worn: '7 days ago', a: Color(0xFFBCC6BA), b: Color(0xFF9BA898)),
  ClosetItem(id: 15, name: 'Linen Dress', brand: 'Lune', cat: 'Dresses', color: 'Bone', season: 'Summer', occ: 'Smart', fav: true, worn: '20 days ago', a: Color(0xFFEAE2D3), b: Color(0xFFD6CBB6)),
];

const kCategories = ['All', 'Tops', 'Bottoms', 'Outerwear', 'Footwear', 'Accessories', 'Dresses'];

class OnboPage {
  const OnboPage(this.tag, this.title, this.body);
  final String tag;
  final String title;
  final String body;
}

const kOnboarding = <OnboPage>[
  OnboPage('01 · Catalogue', 'Your wardrobe, remembered.',
      'Snap each piece once. Vess tags fabric, colour, season and fit — then never forgets what you own.'),
  OnboPage('02 · Daily look', 'A look for every morning.',
      'Wake to an outfit chosen for your calendar, the weather and your taste. Swipe to see three more.'),
  OnboPage('03 · It learns', 'Style that studies you.',
      'Rate looks, chat with your stylist, and watch every suggestion get quietly sharper over time.'),
];

class Insight {
  const Insight(this.stat, this.title, this.sub);
  final String stat;
  final String title;
  final String sub;
}

const kInsights = <Insight>[
  Insight('×4', 'Tailored Trousers — most worn', 'Your reliable base this week'),
  Insight('3', 'Pieces unworn in 30 days', 'Tap to restyle or archive'),
  Insight('72%', 'Neutral palette balance', 'One accent piece would lift it'),
];

const kQuickPrompts = [
  'What should I wear to the client dinner?',
  'Will it rain — adjust my look',
  'Pack me for a 3-day trip',
];
