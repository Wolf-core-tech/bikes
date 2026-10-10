import 'dart:io';

void main() {
  final dir = Directory('lib');
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      var content = entity.readAsStringSync();

      // Simple loop to iteratively remove const that is invalid.
      var regex = RegExp(
        r'const\s+([A-Z][a-zA-Z0-9_]*\([^)]*AppColors\.themed[a-zA-Z0-9_]*[^)]*\))',
      );
      var newContent = content.replaceAllMapped(regex, (m) => m.group(1)!);

      if (newContent != content) {
        entity.writeAsStringSync(newContent);
        stdout.writeln('Updated ${entity.path}');
      }
    }
  }
}
