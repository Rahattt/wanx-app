/// 1536 → "1.5 KB"; one decimal below 10, none above.
String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return i == 0
      ? '$bytes B'
      : '${v.toStringAsFixed(v < 10 ? 1 : 0)} ${units[i]}';
}
