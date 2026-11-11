import 'package:flutter_test/flutter_test.dart';
import 'package:movera_pelanggan/core/utils/rupiah.dart';
import 'package:movera_pelanggan/core/utils/tanggal.dart';

void main() {
  test('formatRupiah memakai titik ribuan tanpa desimal', () {
    expect(formatRupiah(0), 'Rp0');
    expect(formatRupiah(500), 'Rp500');
    expect(formatRupiah(300000), 'Rp300.000');
    expect(formatRupiah(1250000.6), 'Rp1.250.001');
    expect(formatRupiah(-15000), '-Rp15.000');
  });

  test('format tanggal bahasa Indonesia', () {
    final d = DateTime(2026, 11, 12, 7, 5);
    expect(formatTanggalPanjang(d), 'Kamis, 12 November 2026');
    expect(formatJadwal(d), 'Kam, 12 Nov · 07.05');
    expect(kunciTanggal(d), '2026-11-12');
  });
}
