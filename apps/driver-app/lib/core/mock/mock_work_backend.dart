import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/work/data/work_models.dart';
import '../utils/tanggal.dart';

/// Backend tiruan untuk aplikasi driver. Data hari ini dibuat otomatis dan disimpan di perangkat.
/// Backend asli wajib memvalidasi aturan yang sama di server.
class MockWorkBackend implements WorkRepository {
  static const _storageKey = 'movera_driver_mock_v1';

  /// PIN contoh per booking supaya alur verifikasi bisa dicoba.
  static const demoPins = {'bk-a': '1234', 'bk-b': '2468', 'bk-c': '1357', 'bk-d': '8642'};

  final SharedPreferences prefs;
  final DateTime Function() _now;
  final Random _random = Random();

  MockWorkBackend(this.prefs, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  @override
  int get noShowWaitMinutes => 5;

  @override
  int get minBatteryPercent => 25;

  static const _vehicle = Vehicle(id: 'veh-1', plate: 'R 1204 MV', model: 'Mobil listrik 5 kursi', seats: 4, fullRangeKm: 300);

  // ---------- penyimpanan ----------

  Map<String, dynamic> _load() {
    final raw = prefs.getString(_storageKey);
    if (raw == null) return <String, dynamic>{'days': <String, dynamic>{}};
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> _save(Map<String, dynamic> db) => prefs.setString(_storageKey, jsonEncode(db));

  String _id(String p) => '$p-${_now().microsecondsSinceEpoch}-${_random.nextInt(9999)}';

  Map<String, dynamic> _day(Map<String, dynamic> db) {
    final days = db['days'] as Map<String, dynamic>;
    final key = kunciTanggal(_now());
    return days.putIfAbsent(key, () => _generateDay()) as Map<String, dynamic>;
  }

  Shift _shift(Map<String, dynamic> day) => Shift.fromJson(day['shift'] as Map<String, dynamic>);
  void _putShift(Map<String, dynamic> day, Shift s) => day['shift'] = s.toJson();

  List<Trip> _trips(Map<String, dynamic> day) =>
      (day['trips'] as List).map((e) => Trip.fromJson(e as Map<String, dynamic>)).toList();
  void _putTrips(Map<String, dynamic> day, List<Trip> t) => day['trips'] = t.map((x) => x.toJson()).toList();

  // ---------- data contoh ----------

  static const _places = {
    'rumah_siti': StopPlace(label: 'Rumah', address: 'Jl. Gatot Subroto, Cilacap Tengah', latitude: -7.7180, longitude: 109.0060),
    'kantor_siti': StopPlace(label: 'Kantor', address: 'Jl. Jend. Sudirman, Cilacap Selatan', latitude: -7.7290, longitude: 109.0120),
    'rumah_rafi': StopPlace(label: 'Rumah', address: 'Jl. Kalimantan, Sidakaya', latitude: -7.7040, longitude: 109.0180),
    'sekolah_rafi': StopPlace(label: 'Sekolah', address: 'Jl. Ketapang, Cilacap Tengah', latitude: -7.7150, longitude: 109.0210),
    'rumah_budi': StopPlace(label: 'Rumah', address: 'Jl. Perwira, Kebonmanis', latitude: -7.6950, longitude: 109.0310),
    'pabrik_budi': StopPlace(label: 'Tempat kerja', address: 'Kawasan Industri, Cilacap Utara', latitude: -7.6820, longitude: 109.0420),
    'rumah_dewi': StopPlace(label: 'Rumah', address: 'Jl. Dr. Rajiman, Tegalkamulyan', latitude: -7.7090, longitude: 108.9980),
    'rs_dewi': StopPlace(label: 'Tujuan', address: 'Jl. Kendeng, Cilacap Tengah', latitude: -7.7200, longitude: 109.0150),
  };

  TripStop _stop(String id, int seq, StopType type, String booking, String place, String customer, List<String> names,
          {String note = '', bool child = false, String emName = '', String emPhone = ''}) =>
      TripStop(
        id: id,
        sequence: seq,
        type: type,
        bookingId: booking,
        place: _places[place]!,
        passengerNames: names,
        passengerCount: names.length,
        customerName: customer,
        customerPhone: '0812-0000-${1000 + seq}',
        note: note,
        hasChild: child,
        emergencyName: emName,
        emergencyPhone: emPhone,
      );

  Map<String, dynamic> _generateDay() {
    final now = _now();
    // Tugas pertama dimulai di setengah jam berikutnya + 30 menit.
    final base = DateTime(now.year, now.month, now.day, now.hour, now.minute < 30 ? 30 : 0)
        .add(Duration(hours: now.minute < 30 ? 0 : 1, minutes: 30));
    final d = kunciTanggal(now);
    final shift = Shift(id: _id('sh'), date: tanggalSaja(now), status: ShiftStatus.notStarted, vehicle: _vehicle, batteryPercent: 82);
    final trips = [
      Trip(
        id: 'trip-1-$d',
        scheduledAt: base,
        shared: false,
        status: TripStatus.assigned,
        estimatedKm: 6,
        stops: [
          _stop('s1-$d', 1, StopType.pickup, 'bk-a', 'rumah_siti', 'Siti Aminah', ['Siti Aminah'], note: 'Pagar hijau, tunggu di depan'),
          _stop('s2-$d', 2, StopType.dropoff, 'bk-a', 'kantor_siti', 'Siti Aminah', ['Siti Aminah']),
        ],
      ),
      Trip(
        id: 'trip-2-$d',
        scheduledAt: base.add(const Duration(hours: 1, minutes: 30)),
        shared: true,
        status: TripStatus.assigned,
        estimatedKm: 14,
        stops: [
          _stop('s3-$d', 1, StopType.pickup, 'bk-b', 'rumah_rafi', 'Rina Wati', ['Rafi (anak)'],
              child: true, emName: 'Rina Wati (ibu)', emPhone: '0812-3456-7890', note: 'Butuh kursi anak'),
          _stop('s4-$d', 2, StopType.pickup, 'bk-c', 'rumah_budi', 'Budi Hartono', ['Budi Hartono']),
          _stop('s5-$d', 3, StopType.dropoff, 'bk-b', 'sekolah_rafi', 'Rina Wati', ['Rafi (anak)'],
              child: true, emName: 'Rina Wati (ibu)', emPhone: '0812-3456-7890'),
          _stop('s6-$d', 4, StopType.dropoff, 'bk-c', 'pabrik_budi', 'Budi Hartono', ['Budi Hartono']),
        ],
      ),
      Trip(
        id: 'trip-3-$d',
        scheduledAt: base.add(const Duration(hours: 4)),
        shared: false,
        status: TripStatus.assigned,
        estimatedKm: 5,
        stops: [
          _stop('s7-$d', 1, StopType.pickup, 'bk-d', 'rumah_dewi', 'Dewi Lestari', ['Dewi Lestari', 'Ibu Dewi']),
          _stop('s8-$d', 2, StopType.dropoff, 'bk-d', 'rs_dewi', 'Dewi Lestari', ['Dewi Lestari', 'Ibu Dewi']),
        ],
      ),
    ];
    return <String, dynamic>{
      'shift': shift.toJson(),
      'trips': trips.map((t) => t.toJson()).toList(),
      'incidents': <dynamic>[],
    };
  }

  // ---------- shift ----------

  @override
  Future<WorkDay> getToday() async {
    final db = _load();
    final day = _day(db);
    await _save(db);
    return WorkDay(
      shift: _shift(day),
      trips: _trips(day)..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt)),
      incidents: (day['incidents'] as List).map((e) => Incident.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  void _validateBattery(int b) {
    if (b < 0 || b > 100) throw const WorkException('Persentase baterai harus 0-100.');
  }

  @override
  Future<Shift> startShift({required List<ChecklistItem> checklist, required int batteryPercent, required int odometer}) async {
    _validateBattery(batteryPercent);
    if (odometer <= 0) throw const WorkException('Isi angka odometer kendaraan.');
    final failed = checklist.where((c) => c.critical && !c.ok).toList();
    if (failed.isNotEmpty) {
      throw WorkException('Kendaraan belum layak jalan: ${failed.map((c) => c.label).join(', ')}. '
          'Laporkan ke operasional sebelum mulai shift.');
    }
    final db = _load();
    final day = _day(db);
    final s = _shift(day);
    if (s.status != ShiftStatus.notStarted) throw const WorkException('Shift hari ini sudah dimulai.');
    final updated = s.copyWith(
      status: ShiftStatus.available,
      startedAt: _now(),
      startBattery: batteryPercent,
      batteryPercent: batteryPercent,
      startOdometer: odometer,
      checklist: checklist,
    );
    _putShift(day, updated);
    await _save(db);
    return updated;
  }

  Future<Shift> _updateShift(Shift Function(Shift s) change) async {
    final db = _load();
    final day = _day(db);
    final updated = change(_shift(day));
    _putShift(day, updated);
    await _save(db);
    return updated;
  }

  bool _hasTripRunning(Map<String, dynamic> day) => _trips(day).any((t) => t.status == TripStatus.inProgress);

  @override
  Future<Shift> setBreak(bool onBreak) async {
    final db = _load();
    final day = _day(db);
    final s = _shift(day);
    if (!s.status.isOnDuty) throw const WorkException('Mulai shift dulu.');
    if (onBreak && _hasTripRunning(day)) throw const WorkException('Selesaikan perjalanan yang berjalan sebelum istirahat.');
    final updated = s.copyWith(status: onBreak ? ShiftStatus.onBreak : ShiftStatus.available);
    _putShift(day, updated);
    await _save(db);
    return updated;
  }

  @override
  Future<Shift> startCharging() async {
    final db = _load();
    final day = _day(db);
    final s = _shift(day);
    if (!s.status.isOnDuty) throw const WorkException('Mulai shift dulu.');
    if (_hasTripRunning(day)) throw const WorkException('Tidak bisa mengecas saat perjalanan berjalan.');
    final updated = s.copyWith(status: ShiftStatus.charging);
    _putShift(day, updated);
    await _save(db);
    return updated;
  }

  @override
  Future<Shift> finishCharging(int batteryPercent) async {
    _validateBattery(batteryPercent);
    return _updateShift((s) {
      if (s.status != ShiftStatus.charging) throw const WorkException('Kendaraan tidak sedang dicas.');
      if (batteryPercent < s.batteryPercent) {
        throw WorkException('Baterai setelah cas tidak boleh lebih rendah dari sebelumnya (${s.batteryPercent}%).');
      }
      return s.copyWith(status: ShiftStatus.available, batteryPercent: batteryPercent);
    });
  }

  @override
  Future<Shift> updateBattery(int batteryPercent) async {
    _validateBattery(batteryPercent);
    return _updateShift((s) {
      if (!s.status.isOnDuty) throw const WorkException('Mulai shift dulu.');
      return s.copyWith(batteryPercent: batteryPercent);
    });
  }

  @override
  Future<Shift> endShift({required int batteryPercent, required int odometer, required String note}) async {
    _validateBattery(batteryPercent);
    final db = _load();
    final day = _day(db);
    final s = _shift(day);
    if (!s.status.isOnDuty) throw const WorkException('Shift belum berjalan.');
    if (_hasTripRunning(day)) throw const WorkException('Masih ada perjalanan yang berjalan.');
    if (odometer < (s.startOdometer ?? 0)) {
      throw WorkException('Odometer akhir tidak boleh lebih kecil dari awal (${s.startOdometer}).');
    }
    final updated = s.copyWith(
      status: ShiftStatus.ended,
      endedAt: _now(),
      endBattery: batteryPercent,
      batteryPercent: batteryPercent,
      endOdometer: odometer,
      endNote: note,
    );
    _putShift(day, updated);
    await _save(db);
    return updated;
  }

  // ---------- trip ----------

  Future<Trip> _updateTrip(String tripId, Trip Function(Trip t, Shift s, Map<String, dynamic> day) change) async {
    final db = _load();
    final day = _day(db);
    final trips = _trips(day);
    final i = trips.indexWhere((t) => t.id == tripId);
    if (i < 0) throw const WorkException('Tugas tidak ditemukan.');
    final updated = change(trips[i], _shift(day), day);
    trips[i] = updated;
    _putTrips(day, trips);
    await _save(db);
    return updated;
  }

  void _requireWorking(Shift s) {
    if (s.status == ShiftStatus.notStarted) throw const WorkException('Mulai shift dulu.');
    if (s.status == ShiftStatus.ended) throw const WorkException('Shift hari ini sudah selesai.');
    if (s.status == ShiftStatus.onBreak) throw const WorkException('Anda sedang istirahat. Lanjutkan bertugas dulu.');
    if (s.status == ShiftStatus.charging) throw const WorkException('Kendaraan sedang dicas. Selesaikan pengecasan dulu.');
  }

  @override
  Future<Trip> acceptTrip(String tripId) => _updateTrip(tripId, (t, s, _) {
        _requireWorking(s);
        if (t.status != TripStatus.assigned) throw const WorkException('Tugas ini sudah dikonfirmasi atau ditutup.');
        return t.copyWith(status: TripStatus.accepted);
      });

  @override
  Future<Trip> rejectTrip(String tripId, String reason) => _updateTrip(tripId, (t, s, _) {
        if (reason.trim().isEmpty) throw const WorkException('Alasan penolakan wajib diisi.');
        if (t.status != TripStatus.assigned && t.status != TripStatus.accepted) {
          throw const WorkException('Tugas yang sudah berjalan tidak bisa ditolak.');
        }
        return t.copyWith(status: TripStatus.rejected, rejectReason: reason.trim());
      });

  TripStop _requireNext(Trip t, String stopId) {
    if (t.status != TripStatus.accepted && t.status != TripStatus.inProgress) {
      throw const WorkException('Konfirmasi tugas ini dulu.');
    }
    final next = t.nextStop;
    if (next == null || next.id != stopId) throw const WorkException('Kerjakan titik sesuai urutan manifest.');
    return next;
  }

  Trip _replaceStop(Trip t, TripStop stop) {
    final stops = t.stops.map((s) => s.id == stop.id ? stop : s).toList();
    return t.copyWith(stops: stops);
  }

  /// Menandai trip selesai jika semua titik final, lalu mengurangi baterai sesuai perkiraan jarak.
  Trip _finishIfDone(Trip t, Map<String, dynamic> day) {
    if (t.nextStop != null) return t;
    final s = _shift(day);
    final used = (t.estimatedKm / s.vehicle.fullRangeKm * 100).ceil();
    _putShift(day, s.copyWith(batteryPercent: max(0, s.batteryPercent - used)));
    return t.copyWith(status: TripStatus.completed, completedAt: _now());
  }

  @override
  Future<Trip> arriveAtStop(String tripId, String stopId) => _updateTrip(tripId, (t, s, _) {
        _requireWorking(s);
        final stop = _requireNext(t, stopId);
        if (stop.status == StopStatus.arrived) return t;
        final updated = _replaceStop(t, stop.withStatus(StopStatus.arrived, arrivedAt: _now()));
        return t.status == TripStatus.accepted ? updated.copyWith(status: TripStatus.inProgress, startedAt: _now()) : updated;
      });

  @override
  Future<Trip> confirmPickup(String tripId, String stopId, String pin) => _updateTrip(tripId, (t, s, day) {
        final stop = _requireNext(t, stopId);
        if (stop.type != StopType.pickup) throw const WorkException('Titik ini bukan titik jemput.');
        if (stop.status != StopStatus.arrived) throw const WorkException('Tandai tiba di lokasi dulu.');
        if (demoPins[stop.bookingId] != pin.trim()) throw const WorkException('PIN tidak cocok. Minta penumpang mengecek PIN di aplikasinya.');
        return _finishIfDone(_replaceStop(t, stop.withStatus(StopStatus.done, doneAt: _now())), day);
      });

  @override
  Future<Trip> markNoShow(String tripId, String stopId) => _updateTrip(tripId, (t, s, day) {
        final stop = _requireNext(t, stopId);
        if (stop.type != StopType.pickup || stop.status != StopStatus.arrived) {
          throw const WorkException('Penumpang tidak hadir hanya bisa dicatat di titik jemput setelah tiba.');
        }
        final waited = _now().difference(stop.arrivedAt!).inMinutes;
        if (waited < noShowWaitMinutes) {
          throw WorkException('Tunggu minimal $noShowWaitMinutes menit sejak tiba (baru $waited menit).');
        }
        // Titik antar untuk booking yang sama ikut dilewati.
        final stops = t.stops.map((x) {
          if (x.id == stop.id) return x.withStatus(StopStatus.noShow, doneAt: _now());
          if (x.bookingId == stop.bookingId && x.type == StopType.dropoff) return x.withStatus(StopStatus.skipped, doneAt: _now());
          return x;
        }).toList();
        return _finishIfDone(t.copyWith(stops: stops), day);
      });

  @override
  Future<Trip> confirmDropoff(String tripId, String stopId) => _updateTrip(tripId, (t, s, day) {
        final stop = _requireNext(t, stopId);
        if (stop.type != StopType.dropoff) throw const WorkException('Titik ini bukan titik antar.');
        if (stop.status != StopStatus.arrived) throw const WorkException('Tandai tiba di lokasi dulu.');
        return _finishIfDone(_replaceStop(t, stop.withStatus(StopStatus.done, doneAt: _now())), day);
      });

  @override
  Future<Incident> reportIncident({required IncidentType type, required String description, String? tripId, bool emergency = false}) async {
    if (description.trim().length < 10) throw const WorkException('Ceritakan kejadiannya minimal 10 karakter.');
    final db = _load();
    final day = _day(db);
    final incident = Incident(
      id: _id('inc'),
      type: type,
      description: description.trim(),
      tripId: tripId,
      createdAt: _now(),
      emergency: emergency,
    );
    (day['incidents'] as List).add(incident.toJson());
    await _save(db);
    return incident;
  }

  @override
  Future<List<Trip>> getHistory() async {
    final db = _load();
    final days = db['days'] as Map<String, dynamic>;
    final all = <Trip>[];
    for (final d in days.values) {
      all.addAll(_trips(d as Map<String, dynamic>).where((t) => !t.status.isOpen));
    }
    return all..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
  }
}
