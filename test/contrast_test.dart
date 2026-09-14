import 'package:flutter_test/flutter_test.dart';
import 'package:vess/data/mock_data.dart';

void main() {
  // The design doc chooses dark-on-swatch text via a hardcoded list of three
  // colours (#F2EDE3, #F0EDE6, #EAE2D3). We derive the same decision from
  // luminance, so this pins the two approaches together — if someone retunes
  // the threshold, this catches the drift from the design.
  test('isLight selects exactly the three swatches the design treats as pale',
      () {
    final light = kCloset.where((i) => i.isLight).map((i) => i.name).toList();

    expect(light, ['Oxford Shirt', 'Minimal Sneakers', 'Linen Dress']);
  });
}
