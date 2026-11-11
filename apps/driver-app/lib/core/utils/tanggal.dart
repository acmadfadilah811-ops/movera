/// Format tanggal & jam bahasa Indonesia tanpa paket intl.
const _hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const _hariPendek = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
const _bulan = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
const _bulanPendek = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

String namaHari(int weekday) => _hari[weekday - 1];
String namaHariPendek(int weekday) => _hariPendek[weekday - 1];

String _dua(int n) => n.toString().padLeft(2, '0');

/// 07.30
String formatJam(DateTime d) => '${_dua(d.hour)}.${_dua(d.minute)}';

/// 12 Nov 2026
String formatTanggalPendek(DateTime d) => '${d.day} ${_bulanPendek[d.month - 1]} ${d.year}';

/// Kamis, 12 November 2026
String formatTanggalPanjang(DateTime d) => '${namaHari(d.weekday)}, ${d.day} ${_bulan[d.month - 1]} ${d.year}';

/// Kam, 12 Nov · 07.30
String formatJadwal(DateTime d) => '${namaHariPendek(d.weekday)}, ${d.day} ${_bulanPendek[d.month - 1]} · ${formatJam(d)}';

/// Tanggal tanpa jam (untuk kunci kuota harian).
DateTime tanggalSaja(DateTime d) => DateTime(d.year, d.month, d.day);

/// Kunci tanggal "2026-11-12".
String kunciTanggal(DateTime d) => '${d.year}-${_dua(d.month)}-${_dua(d.day)}';

bool samaTanggal(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
