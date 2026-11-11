import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/booking/data/booking_models.dart';
import '../../features/subscription/data/subscription_models.dart';
import '../utils/tanggal.dart';

/// Backend tiruan untuk mencoba aplikasi tanpa server. Data disimpan di perangkat.
/// Aturan kuota mengikuti blueprint bagian 8.2; backend asli wajib menjalankannya dalam transaksi database.
class MockBackend implements SubscriptionRepository, BookingRepository {
  static const _storageKey = 'movera_mock_v1';
  static const _routineWindowDays = 7;
  static const _assignWithinHours = 12;
  static const _autoCompleteAfterHours = 3;

  final SharedPreferences prefs;
  final DateTime Function() _now;
  final Random _random = Random();

  MockBackend(this.prefs, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  @override
  int get cancelCutoffMinutes => 60;

  @override
  int get minLeadMinutes => 60;

  static const _plans = [
    SubscriptionPlan(
      id: 'plan-bulanan',
      name: 'Paket Bulanan',
      description: 'Antar-jemput mobil listrik selama 30 hari.',
      price: 300000,
      durationDays: 30,
      dailyQuota: 4,
    ),
  ];

  static const _drivers = [
    ('Budi Santoso', 'R 1204 MV'),
    ('Slamet Riyadi', 'R 1311 MV'),
    ('Agus Prasetyo', 'R 1427 MV'),
  ];

  // ---------- penyimpanan ----------

  Map<String, dynamic> _load() {
    final raw = prefs.getString(_storageKey);
    if (raw == null) {
      return <String, dynamic>{
        'subscriptions': <dynamic>[],
        'payments': <String, dynamic>{},
        'quotas': <String, dynamic>{},
        'quota_tx': <dynamic>[],
        'bookings': <dynamic>[],
        'schedules': <dynamic>[],
        'places': <dynamic>[],
        'passengers': <dynamic>[],
      };
    }
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> _save(Map<String, dynamic> db) => prefs.setString(_storageKey, jsonEncode(db));

  String _id(String prefix) => '$prefix-${_now().microsecondsSinceEpoch}-${_random.nextInt(9999)}';

  List<Subscription> _subs(Map<String, dynamic> db) =>
      (db['subscriptions'] as List).map((e) => Subscription.fromJson(e as Map<String, dynamic>)).toList();

  Subscription? _subscriptionFor(Map<String, dynamic> db, DateTime day) {
    for (final s in _subs(db)) {
      if (s.coversDate(day)) return s;
    }
    return null;
  }

  DailyQuota _quota(Map<String, dynamic> db, Subscription sub, DateTime day) {
    final raw = (db['quotas'] as Map<String, dynamic>)[kunciTanggal(day)];
    if (raw != null) return DailyQuota.fromJson(raw as Map<String, dynamic>);
    return DailyQuota(date: tanggalSaja(day), total: sub.plan.dailyQuota);
  }

  void _putQuota(Map<String, dynamic> db, DailyQuota q, {required String action, String? bookingId}) {
    (db['quotas'] as Map<String, dynamic>)[kunciTanggal(q.date)] = q.toJson();
    (db['quota_tx'] as List).add({
      'date': kunciTanggal(q.date),
      'booking_id': bookingId,
      'action': action,
      'at': _now().toIso8601String(),
    });
  }

  List<Booking> _bookings(Map<String, dynamic> db) =>
      (db['bookings'] as List).map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList();

  void _putBookings(Map<String, dynamic> db, List<Booking> list) => db['bookings'] = list.map((b) => b.toJson()).toList();

  List<RecurringSchedule> _schedules(Map<String, dynamic> db) =>
      (db['schedules'] as List).map((e) => RecurringSchedule.fromJson(e as Map<String, dynamic>)).toList();

  String _pin() => (1000 + _random.nextInt(9000)).toString();

  // ---------- langganan ----------

  @override
  Future<List<SubscriptionPlan>> getPlans() async => _plans;

  @override
  Future<List<Subscription>> getSubscriptions() async {
    final db = _load();
    final today = tanggalSaja(_now());
    final list = _subs(db).where((s) => s.status == SubscriptionStatus.active && !s.endDate.isBefore(today)).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    return list;
  }

  @override
  Future<String> checkout(String planId) async {
    final db = _load();
    final plan = _plans.firstWhere((p) => p.id == planId);
    final paymentId = _id('pay');
    (db['payments'] as Map<String, dynamic>)[paymentId] = {'plan_id': plan.id, 'amount': plan.price, 'status': 'pending'};
    await _save(db);
    return paymentId;
  }

  @override
  Future<Subscription> simulatePaymentSuccess(String paymentId) async {
    final db = _load();
    final payment = (db['payments'] as Map<String, dynamic>)[paymentId] as Map<String, dynamic>?;
    if (payment == null) throw const BookingException('Pembayaran tidak ditemukan.');
    if (payment['status'] == 'paid') {
      // Idempotent: webhook ganda tidak membuat langganan ganda.
      return _subs(db).firstWhere((s) => s.id == payment['subscription_id']);
    }
    final plan = _plans.firstWhere((p) => p.id == payment['plan_id']);
    final today = tanggalSaja(_now());
    // Perpanjangan dimulai sehari setelah langganan terakhir berakhir.
    final active = _subs(db).where((s) => s.status == SubscriptionStatus.active && !s.endDate.isBefore(today)).toList()
      ..sort((a, b) => a.endDate.compareTo(b.endDate));
    final start = active.isEmpty ? today : active.last.endDate.add(const Duration(days: 1));
    final sub = Subscription(
      id: _id('sub'),
      plan: plan,
      startDate: start,
      endDate: start.add(Duration(days: plan.durationDays - 1)),
      status: SubscriptionStatus.active,
    );
    (db['subscriptions'] as List).add(sub.toJson());
    payment['status'] = 'paid';
    payment['subscription_id'] = sub.id;
    await _save(db);
    return sub;
  }

  @override
  Future<List<DailyQuota>> getQuotas(DateTime from, int days) async {
    final db = _load();
    final result = <DailyQuota>[];
    for (var i = 0; i < days; i++) {
      final day = tanggalSaja(from).add(Duration(days: i));
      final sub = _subscriptionFor(db, day);
      if (sub != null) result.add(_quota(db, sub, day));
    }
    return result;
  }

  // ---------- booking ----------

  /// Memeriksa dan mencadangkan satu kuota pada tanggal booking. Melempar BookingException jika gagal.
  void _reserve(Map<String, dynamic> db, DateTime at, String bookingId) {
    final sub = _subscriptionFor(db, at);
    if (sub == null) {
      throw BookingException('Tidak ada langganan aktif pada ${formatTanggalPendek(at)}.');
    }
    final q = _quota(db, sub, at);
    if (q.remaining <= 0) {
      throw BookingException('Kuota ${formatTanggalPendek(at)} sudah habis (${q.total} booking per hari).');
    }
    _putQuota(db, DailyQuota(date: q.date, total: q.total, reserved: q.reserved + 1, consumed: q.consumed),
        action: 'reserve', bookingId: bookingId);
  }

  /// [consume] true: cadangan jadi terpakai. false: cadangan dilepas.
  void _settle(Map<String, dynamic> db, DateTime at, String bookingId, {required bool consume}) {
    final sub = _subscriptionFor(db, at);
    if (sub == null) return;
    final q = _quota(db, sub, at);
    if (q.reserved <= 0) return;
    _putQuota(
      db,
      DailyQuota(date: q.date, total: q.total, reserved: q.reserved - 1, consumed: q.consumed + (consume ? 1 : 0)),
      action: consume ? 'consume' : 'release',
      bookingId: bookingId,
    );
  }

  Booking _newBooking({
    required BookingType type,
    required RideMode mode,
    required DateTime at,
    required Place pickup,
    required Place destination,
    required int passengers,
    required int detour,
    required String note,
    List<String> names = const [],
    String? scheduleId,
  }) =>
      Booking(
        id: _id('bk'),
        type: type,
        rideMode: mode,
        scheduledAt: at,
        pickup: pickup,
        destination: destination,
        passengerCount: passengers,
        passengerNames: names,
        maxDetourMinutes: detour,
        note: note,
        status: BookingStatus.pendingDispatch,
        createdAt: _now(),
        pickupPin: _pin(),
        recurringScheduleId: scheduleId,
      );

  void _validateLead(DateTime at) {
    if (at.isBefore(_now().add(Duration(minutes: minLeadMinutes)))) {
      throw BookingException('Booking paling cepat $minLeadMinutes menit dari sekarang.');
    }
  }

  @override
  Future<BookingResult> createBooking(BookingRequest r) async {
    if (r.passengerCount < 1) throw const BookingException('Jumlah penumpang minimal 1.');
    final db = _load();
    final bookings = _bookings(db);

    if (r.type == BookingType.flexible) {
      final at = r.scheduledAt!;
      _validateLead(at);
      final b = _newBooking(
        type: BookingType.flexible,
        mode: r.rideMode,
        at: at,
        pickup: r.pickup,
        destination: r.destination,
        passengers: r.passengerCount,
        detour: r.maxDetourMinutes,
        note: r.note,
        names: r.passengerNames,
      );
      _reserve(db, at, b.id);
      bookings.add(b);
      _putBookings(db, bookings);
      await _save(db);
      return BookingResult(created: [b]);
    }

    if (r.weekdays.isEmpty) throw const BookingException('Pilih minimal satu hari.');
    final schedule = RecurringSchedule(
      id: _id('rs'),
      weekdays: [...r.weekdays]..sort(),
      hour: r.hour,
      minute: r.minute,
      pickup: r.pickup,
      destination: r.destination,
      rideMode: r.rideMode,
      passengerCount: r.passengerCount,
      passengerNames: r.passengerNames,
      maxDetourMinutes: r.maxDetourMinutes,
      note: r.note,
    );
    (db['schedules'] as List).add(schedule.toJson());
    final (created, skipped) = _generateInstances(db, schedule, bookings);
    _putBookings(db, bookings);
    await _save(db);
    return BookingResult(created: created, skipped: skipped, schedule: schedule);
  }

  /// Membuat booking dari jadwal rutin untuk jendela [_routineWindowDays] hari ke depan.
  (List<Booking>, List<String>) _generateInstances(Map<String, dynamic> db, RecurringSchedule s, List<Booking> bookings) {
    final created = <Booking>[];
    final skipped = <String>[];
    final today = tanggalSaja(_now());
    for (var i = 0; i < _routineWindowDays; i++) {
      final day = today.add(Duration(days: i));
      if (!s.weekdays.contains(day.weekday)) continue;
      final at = DateTime(day.year, day.month, day.day, s.hour, s.minute);
      if (at.isBefore(_now().add(Duration(minutes: minLeadMinutes)))) continue;
      final exists = bookings.any((b) => b.recurringScheduleId == s.id && samaTanggal(b.scheduledAt, day));
      if (exists) continue;
      final b = _newBooking(
        type: BookingType.routine,
        mode: s.rideMode,
        at: at,
        pickup: s.pickup,
        destination: s.destination,
        passengers: s.passengerCount,
        detour: s.maxDetourMinutes,
        note: s.note,
        names: s.passengerNames,
        scheduleId: s.id,
      );
      try {
        _reserve(db, at, b.id);
        bookings.add(b);
        created.add(b);
      } on BookingException catch (e) {
        skipped.add('${formatTanggalPendek(day)}: ${e.message}');
      }
    }
    return (created, skipped);
  }

  /// Simulasi pekerjaan server: buat booking rutin baru, tugaskan driver, selesaikan trip lama.
  void _tick(Map<String, dynamic> db) {
    final bookings = _bookings(db);
    for (final s in _schedules(db).where((s) => s.isActive)) {
      _generateInstances(db, s, bookings);
    }
    final now = _now();
    for (var i = 0; i < bookings.length; i++) {
      final b = bookings[i];
      if (b.status == BookingStatus.pendingDispatch &&
          b.scheduledAt.difference(now).inHours < _assignWithinHours) {
        final d = _drivers[b.id.hashCode.abs() % _drivers.length];
        bookings[i] = b.copyWith(status: BookingStatus.assigned, driverName: d.$1, vehiclePlate: d.$2);
      }
      if (bookings[i].status.isActive &&
          now.isAfter(b.scheduledAt.add(const Duration(hours: _autoCompleteAfterHours)))) {
        _settle(db, b.scheduledAt, b.id, consume: true);
        bookings[i] = bookings[i].copyWith(status: BookingStatus.completed);
      }
    }
    _putBookings(db, bookings);
  }

  @override
  Future<List<Booking>> getBookings() async {
    final db = _load();
    _tick(db);
    await _save(db);
    return _bookings(db)..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  @override
  Future<List<RecurringSchedule>> getRecurringSchedules() async => _schedules(_load());

  Booking _cancelIn(Map<String, dynamic> db, List<Booking> bookings, int index, String reason) {
    final b = bookings[index];
    if (!b.status.isActive || b.status == BookingStatus.inProgress) {
      throw const BookingException('Booking ini tidak bisa dibatalkan.');
    }
    final beforeCutoff = _now().isBefore(b.scheduledAt.subtract(Duration(minutes: cancelCutoffMinutes)));
    _settle(db, b.scheduledAt, b.id, consume: !beforeCutoff);
    final updated = b.copyWith(
      status: BookingStatus.cancelled,
      cancelReason: reason,
      cancelledAt: _now(),
      quotaOutcome: beforeCutoff ? QuotaOutcome.released : QuotaOutcome.forfeited,
    );
    bookings[index] = updated;
    return updated;
  }

  @override
  Future<Booking> cancelBooking(String bookingId, String reason) async {
    final db = _load();
    final bookings = _bookings(db);
    final i = bookings.indexWhere((b) => b.id == bookingId);
    if (i < 0) throw const BookingException('Booking tidak ditemukan.');
    final updated = _cancelIn(db, bookings, i, reason);
    _putBookings(db, bookings);
    await _save(db);
    return updated;
  }

  @override
  Future<void> deactivateSchedule(String scheduleId) async {
    final db = _load();
    final schedules = _schedules(db);
    final si = schedules.indexWhere((s) => s.id == scheduleId);
    if (si < 0) throw const BookingException('Jadwal tidak ditemukan.');
    schedules[si] = schedules[si].deactivated();
    db['schedules'] = schedules.map((s) => s.toJson()).toList();
    final bookings = _bookings(db);
    for (var i = 0; i < bookings.length; i++) {
      final b = bookings[i];
      // Booking yang sudah lewat batas pembatalan tetap berjalan agar kuota tidak hangus.
      if (b.recurringScheduleId == scheduleId &&
          (b.status == BookingStatus.pendingDispatch || b.status == BookingStatus.assigned) &&
          _now().isBefore(b.scheduledAt.subtract(Duration(minutes: cancelCutoffMinutes)))) {
        _cancelIn(db, bookings, i, 'Jadwal rutin dinonaktifkan');
      }
    }
    _putBookings(db, bookings);
    await _save(db);
  }

  @override
  Future<List<Place>> getSavedPlaces() async =>
      (_load()['places'] as List).map((e) => Place.fromJson(e as Map<String, dynamic>)).toList();

  @override
  Future<void> savePlace(Place place) async {
    final db = _load();
    final places = (db['places'] as List).map((e) => Place.fromJson(e as Map<String, dynamic>)).toList()
      ..removeWhere((p) => p.label.toLowerCase() == place.label.toLowerCase());
    places.add(place);
    db['places'] = places.map((p) => p.toJson()).toList();
    await _save(db);
  }

  @override
  Future<void> deletePlace(String label) async {
    final db = _load();
    db['places'] = (db['places'] as List)
        .where((e) => ((e as Map<String, dynamic>)['label'] as String).toLowerCase() != label.toLowerCase())
        .toList();
    await _save(db);
  }

  List<Passenger> _passengers(Map<String, dynamic> db) =>
      ((db['passengers'] ?? <dynamic>[]) as List).map((e) => Passenger.fromJson(e as Map<String, dynamic>)).toList();

  @override
  Future<List<Passenger>> getPassengers() async => _passengers(_load());

  @override
  Future<Passenger> savePassenger(Passenger p) async {
    if (p.name.trim().isEmpty) throw const BookingException('Nama penumpang wajib diisi.');
    if (p.isChild && (p.emergencyName.trim().isEmpty || p.emergencyPhone.trim().isEmpty)) {
      throw const BookingException('Penumpang anak wajib punya kontak darurat (nama dan nomor HP).');
    }
    final db = _load();
    final list = _passengers(db);
    final saved = Passenger(
      id: p.id.isEmpty ? _id('ps') : p.id,
      name: p.name.trim(),
      relation: p.relation,
      isChild: p.isChild,
      school: p.school.trim(),
      notes: p.notes.trim(),
      emergencyName: p.emergencyName.trim(),
      emergencyPhone: p.emergencyPhone.trim(),
    );
    final i = list.indexWhere((x) => x.id == saved.id);
    if (i < 0) {
      list.add(saved);
    } else {
      list[i] = saved;
    }
    db['passengers'] = list.map((x) => x.toJson()).toList();
    await _save(db);
    return saved;
  }

  @override
  Future<void> deletePassenger(String id) async {
    final db = _load();
    db['passengers'] = _passengers(db).where((x) => x.id != id).map((x) => x.toJson()).toList();
    await _save(db);
  }

  @override
  Future<Booking> simulateComplete(String bookingId) async {
    final db = _load();
    final bookings = _bookings(db);
    final i = bookings.indexWhere((b) => b.id == bookingId);
    if (i < 0) throw const BookingException('Booking tidak ditemukan.');
    if (!bookings[i].status.isActive) throw const BookingException('Booking ini sudah tidak aktif.');
    _settle(db, bookings[i].scheduledAt, bookingId, consume: true);
    bookings[i] = bookings[i].copyWith(status: BookingStatus.completed);
    _putBookings(db, bookings);
    await _save(db);
    return bookings[i];
  }
}
