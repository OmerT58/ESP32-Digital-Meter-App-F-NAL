import 'dart:io';

void resolve(String filename) {
  final file = File(filename);
  final lines = file.readAsLinesSync();
  final out = <String>[];
  
  int i = 0;
  while (i < lines.length) {
    final line = lines[i];
    if (line.startsWith('<<<<<<< HEAD')) {
      i++;
      while (i < lines.length && !lines[i].startsWith('=======')) {
        out.add(lines[i]);
        i++;
      }
      i++; // skip =======
      while (i < lines.length && !lines[i].startsWith('>>>>>>>')) {
        i++;
      }
      i++; // skip >>>>>>>
    } else {
      out.add(line);
      i++;
    }
  }
  
  file.writeAsStringSync(out.join('\n') + '\n');
}

void main() {
  resolve('lib/screens/home_screen.dart');
  resolve('lib/services/laser_tracking_service.dart');
  print('Conflicts resolved.');
}
