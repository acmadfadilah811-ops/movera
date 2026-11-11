/// Format angka ke Rupiah tanpa desimal, contoh: 300000 -> "Rp300.000".
String formatRupiah(num? value) {
  final n = (value ?? 0).round();
  final digits = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return '${n < 0 ? '-' : ''}Rp$buf';
}
