// Manual check: runs FreeTryOnService against the real IDM-VTON Space with the
// sample images and writes the result. Not a unit test (hits the network).
//
//   dart run tool/free_tryon_check.dart <person> <garment> <out>
import 'dart:io';
import 'package:vess/services/free_tryon_service.dart';

Future<void> main(List<String> args) async {
  if (args.length < 3) {
    stderr.writeln('usage: dart run tool/free_tryon_check.dart <person> <garment> <out>');
    exit(2);
  }
  final person = await File(args[0]).readAsBytes();
  final garment = await File(args[1]).readAsBytes();
  final hfToken = args.length > 3 ? args[3] : ''; // optional HF token
  stdout.writeln('rendering (free GPU, may take a minute)…');
  final sw = Stopwatch()..start();
  final bytes = await FreeTryOnService(hfToken: hfToken).render(
    personBytes: person,
    garmentBytes: garment,
    garmentDescription: 'a short sleeve top',
  );
  await File(args[2]).writeAsBytes(bytes);
  stdout.writeln('done in ${sw.elapsed.inSeconds}s — wrote ${bytes.length} bytes to ${args[2]}');
}
