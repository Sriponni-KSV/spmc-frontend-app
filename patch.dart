import 'dart:io';

void main() {
  final file = File('lib/screens/signup_page.dart');
  final lines = file.readAsLinesSync();
  
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains('// if (isDesktop) {')) {
      lines[i] = lines[i].replaceAll('// if (isDesktop) {', 'if (isDesktop) {');
    }
    else if (lines[i].contains('//return ')) {
      lines[i] = lines[i].replaceAll('//return ', '');
    }
    else if (i >= 165 && i <= 196) {
      if (lines[i].contains('// }')) {
        lines[i] = lines[i].replaceAll('// }', '}');
      } else if (lines[i].contains('// return Column(')) {
        lines[i] = lines[i].replaceAll('// return Column(', 'return Column(');
      } else if (lines[i].contains('//   children: [')) {
        lines[i] = lines[i].replaceAll('//   children: [', '  children: [');
      } else if (lines[i].contains('//     const CustomAppBar(title: \'Register\', showShadow: false),')) {
        lines[i] = lines[i].replaceAll('//     const CustomAppBar(title: \'Register\', showShadow: false),', '    const CustomAppBar(title: \'\', showShadow: false),');
      } else if (lines[i].startsWith('          // ')) {
        lines[i] = lines[i].replaceFirst('          // ', '          ');
      }
    }
  }
  
  file.writeAsStringSync(lines.join('\n') + '\n');
}
