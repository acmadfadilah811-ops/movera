import 'package:flutter_test/flutter_test.dart';
import 'package:movera_driver/core/mock/mock_work_backend.dart';
import 'package:movera_driver/features/work/data/work_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<ChecklistItem> allOk() => defaultChecklist.map((c) => c.withOk(true)).toList();

void main() {
  late DateTime now;
  late MockWorkBackend backend;

  setUp(() async {
    now = DateTime(2026, 11, 12, 5, 40);
    SharedPreferences.setMockInitialValues({});
    backend = MockWorkBackend(await SharedPreferences.getInstance(), clock: () => now);
  });

  Future<Trip> trip(int n) async => (await backend.getToday()).trips[n - 1];

  Future<void> startShift() => backend.startShift(checklist: allOk(), batteryPercent: 80, odometer: 12000);

  test('data hari ini: shift belum mulai dan 3 tugas baru', () async {
    final day = await backend.getToday();
    expect(day.shift.status, ShiftStatus.notStarted);
    expect(day.trips.length, 3);
    expect(day.trips.every((t) => t.status == TripStatus.assigned), isTrue);
    expect(day.trips[1].shared, isTrue);
  });

  test('shift ditolak jika butir checklist wajib tidak lolos', () async {
    final items = allOk();
    items[0] = items[0].withOk(false); // rem
    expect(() => backend.startShift(checklist: items, batteryPercent: 80, odometer: 12000), throwsA(isA<WorkException>()));
    // Butir tidak wajib boleh tidak lolos.
    final optional = allOk().map((c) => c.critical ? c : c.withOk(false)).toList();
    final s = await backend.startShift(checklist: optional, batteryPercent: 80, odometer: 12000);
    expect(s.status, ShiftStatus.available);
    expect(() => startShift(), throwsA(isA<WorkException>()));
  });

  test('tugas hanya bisa dikonfirmasi saat shift berjalan; penolakan wajib beralasan', () async {
    final t = await trip(1);
    expect(() => backend.acceptTrip(t.id), throwsA(isA<WorkException>()));
    expect(() => backend.rejectTrip(t.id, ' '), throwsA(isA<WorkException>()));
    await startShift();
    expect((await backend.acceptTrip(t.id)).status, TripStatus.accepted);
    final r = await backend.rejectTrip((await trip(3)).id, 'Bentrok dengan tugas lain');
    expect(r.status, TripStatus.rejected);
  });

  test('titik harus dikerjakan sesuai urutan dan PIN harus cocok', () async {
    await startShift();
    var t = await backend.acceptTrip((await trip(2)).id);
    final stops = [...t.stops]..sort((a, b) => a.sequence.compareTo(b.sequence));
    expect(() => backend.arriveAtStop(t.id, stops[1].id), throwsA(isA<WorkException>()));
    t = await backend.arriveAtStop(t.id, stops[0].id);
    expect(t.status, TripStatus.inProgress);
    expect(() => backend.confirmPickup(t.id, stops[0].id, '0000'), throwsA(isA<WorkException>()));
    t = await backend.confirmPickup(t.id, stops[0].id, MockWorkBackend.demoPins[stops[0].bookingId]!);
    expect(t.nextStop!.id, stops[1].id);
  });

  test('tidak hadir baru boleh setelah menunggu 5 menit, titik antarnya ikut dilewati', () async {
    await startShift();
    var t = await backend.acceptTrip((await trip(1)).id);
    final pickup = t.stops.firstWhere((s) => s.type == StopType.pickup);
    t = await backend.arriveAtStop(t.id, pickup.id);
    now = now.add(const Duration(minutes: 3));
    expect(() => backend.markNoShow(t.id, pickup.id), throwsA(isA<WorkException>()));
    now = now.add(const Duration(minutes: 2));
    t = await backend.markNoShow(t.id, pickup.id);
    expect(t.status, TripStatus.completed);
    expect(t.stops.firstWhere((s) => s.type == StopType.dropoff).status, StopStatus.skipped);
  });

  test('trip shared selesai penuh dan baterai berkurang sesuai jarak', () async {
    await startShift();
    var t = await backend.acceptTrip((await trip(2)).id);
    while (t.nextStop != null) {
      final s = t.nextStop!;
      t = await backend.arriveAtStop(t.id, s.id);
      t = s.type == StopType.pickup
          ? await backend.confirmPickup(t.id, s.id, MockWorkBackend.demoPins[s.bookingId]!)
          : await backend.confirmDropoff(t.id, s.id);
    }
    expect(t.status, TripStatus.completed);
    final day = await backend.getToday();
    expect(day.shift.batteryPercent, 80 - 5); // 14 km dari 300 km = 4,7% dibulatkan ke atas
    expect((await backend.getHistory()).single.id, t.id);
  });

  test('istirahat dan mengecas menahan pekerjaan; baterai setelah cas tidak boleh turun', () async {
    await startShift();
    var t = await backend.acceptTrip((await trip(1)).id);
    await backend.setBreak(true);
    final pickup = t.stops.firstWhere((s) => s.type == StopType.pickup);
    expect(() => backend.arriveAtStop(t.id, pickup.id), throwsA(isA<WorkException>()));
    await backend.setBreak(false);
    t = await backend.arriveAtStop(t.id, pickup.id);
    expect(() => backend.startCharging(), throwsA(isA<WorkException>()));
    t = await backend.confirmPickup(t.id, pickup.id, MockWorkBackend.demoPins[pickup.bookingId]!);
    final drop = t.nextStop!;
    t = await backend.arriveAtStop(t.id, drop.id);
    await backend.confirmDropoff(t.id, drop.id);
    await backend.startCharging();
    expect(() => backend.finishCharging(10), throwsA(isA<WorkException>()));
    final s = await backend.finishCharging(95);
    expect(s.status, ShiftStatus.available);
    expect(s.batteryPercent, 95);
  });

  test('akhir shift ditolak saat trip berjalan atau odometer mundur', () async {
    await startShift();
    final t = await backend.acceptTrip((await trip(1)).id);
    await backend.arriveAtStop(t.id, t.stops.firstWhere((s) => s.type == StopType.pickup).id);
    expect(() => backend.endShift(batteryPercent: 70, odometer: 12050, note: ''), throwsA(isA<WorkException>()));
    await backend.rejectTrip((await trip(3)).id, 'Kendaraan bermasalah');
    // Trip 1 masih berjalan, selesaikan dulu lewat tidak hadir.
    now = now.add(const Duration(minutes: 6));
    await backend.markNoShow(t.id, t.stops.firstWhere((s) => s.type == StopType.pickup).id);
    expect(() => backend.endShift(batteryPercent: 70, odometer: 11000, note: ''), throwsA(isA<WorkException>()));
    final s = await backend.endShift(batteryPercent: 70, odometer: 12050, note: 'Aman');
    expect(s.status, ShiftStatus.ended);
    expect(s.endOdometer! - s.startOdometer!, 50);
  });

  test('laporan insiden butuh deskripsi yang cukup', () async {
    expect(() => backend.reportIncident(type: IncidentType.delay, description: 'macet'), throwsA(isA<WorkException>()));
    await backend.reportIncident(type: IncidentType.delay, description: 'Macet parah di Jl. Gatot Subroto', emergency: false);
    expect((await backend.getToday()).incidents.length, 1);
  });
}
