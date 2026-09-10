import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

/// Decode the actual lockfile syntax using the existing pinned YAML parser.
/// Python's inventory consumes JSON; it must not guess registry identities from
/// indentation or the resolver's generic `hosted` label.
void main(List<String> arguments) {
  if (arguments.length != 1) {
    stderr.writeln('usage: lockfile_metadata.dart PATH');
    exitCode = 64;
    return;
  }
  try {
    final file = File(arguments.single);
    if (file.lengthSync() > 2 * 1024 * 1024) {
      throw const FormatException('lockfile exceeds size limit');
    }
    final document = loadYaml(file.readAsStringSync());
    if (document is! Map || document['packages'] is! Map) {
      throw const FormatException('lockfile packages must be a map');
    }
    stdout.writeln(jsonEncode(document));
  } on Object catch (error) {
    stderr.writeln('Invalid dependency lockfile: $error');
    exitCode = 1;
  }
}
