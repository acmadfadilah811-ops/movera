import 'package:flutter_test/flutter_test.dart';
import 'package:movera_pelanggan/core/mock/mock_backend.dart';
import 'package:movera_pelanggan/features/booking/data/booking_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _home = Place(label: 'Rumah', address: 'Jl. Gatot Subroto, Cilacap', latitude: -7.72, longitude: 109.01);
const _office = Place(label: 'Kantor', address: 'Jl. A. Yani, Cilacap', latitude: -7.73, longitude: 109.02);

BookingRequest flexible(DateTime at) => BookingRequest(
      type: BookingType.flexible,
      rideMode: RideMode.individual,
      pickup: _home,
      destination: _office,
      passengerCount: 1,
      maxDetourMinutes: 0,
      note: '',
      scheduledAt: at,
    );

void main() {
  // Kamis, 12 November 2026 06.00
  var now = DateTime(2026, 11, 12, 6, 0);
  late MockBackend backend;

  Future<void> subscribe() async {
    final pay = await backend.checkout('plan-bulanan');
    await backend.simulatePaymentSuccess(pay);
  }

  setUp(() async {
    now = DateTime(2026, 11, 12, 6, 0);
    SharedPreferences.setMockInitialValues({});
    backend = MockBackend(await SharedPreferences.getInstance(), clock: () => now);
  });

  test('booking ditolak tanpa langganan aktif', () async {
    expect(() => backend.createBooking(flexible(DateTime(2026, 11, 12, 9))), throwsA(isA<BookingException>()));
  });

  test('pembayaran mengaktifkan 30 hari dan webhook ganda tidak menggandakan langganan', () async {
    final pay = await backend.checkout('plan-bulanan');
    final a = await backend.simulatePaymentSuccess(pay);
    final b = await backend.simulatePaymentSuccess(pay);
    expect(a.id, b.id);
    expect(a.startDate, DateTime(2026, 11, 12));
    expect(a.endDate, DateTime(2026, 12, 11));
    expect((await backend.getSubscriptions()).length, 1);
  });

  test('perpanjangan mulai sehari setelah masa aktif berakhir', () async {
    await subscribe();
    await subscribe();
    final subs = await backend.getSubscriptions();
    expect(subs.length, 2);
    expect(subs[1].startDate, DateTime(2026, 12, 12));
  });

  test('kuota 4 per hari: booking ke-5 ditolak, tanggal lain tetap bisa', () async {
    await subscribe();
    for (var h = 9; h < 13; h++) {
      await backend.createBooking(flexible(DateTime(2026, 11, 13, h)));
    }
    final q = (await backend.getQuotas(DateTime(2026, 11, 13), 1)).single;
    expect(q.reserved, 4);
    expect(q.remaining, 0);
    expect(() => backend.createBooking(flexible(DateTime(2026, 11, 13, 15))), throwsA(isA<BookingException>()));
    await backend.createBooking(flexible(DateTime(2026, 11, 14, 9)));
  });

  test('booking kurang dari batas waktu minimal ditolak', () async {
    await subscribe();
    expect(() => backend.createBooking(flexible(DateTime(2026, 11, 12, 6, 30))), throwsA(isA<BookingException>()));
  });

  test('booking di luar masa langganan ditolak', () async {
    await subscribe();
    expect(() => backend.createBooking(flexible(DateTime(2026, 12, 12, 9))), throwsA(isA<BookingException>()));
  });

  test('batal sebelum batas waktu mengembalikan kuota, sesudahnya hangus', () async {
    await subscribe();
    final early = (await backend.createBooking(flexible(DateTime(2026, 11, 12, 10)))).created.single;
    final late = (await backend.createBooking(flexible(DateTime(2026, 11, 12, 11)))).created.single;

    final c1 = await backend.cancelBooking(early.id, 'Jadwal berubah');
    expect(c1.quotaOutcome, QuotaOutcome.released);

    now = DateTime(2026, 11, 12, 10, 30); // 30 menit sebelum booking jam 11.00
    final c2 = await backend.cancelBooking(late.id, 'Jadwal berubah');
    expect(c2.quotaOutcome, QuotaOutcome.forfeited);

    final q = (await backend.getQuotas(DateTime(2026, 11, 12), 1)).single;
    expect(q.reserved, 0);
    expect(q.consumed, 1);
    expect(q.remaining, 3);
  });

  test('perjalanan selesai memindahkan cadangan menjadi terpakai', () async {
    await subscribe();
    final b = (await backend.createBooking(flexible(DateTime(2026, 11, 12, 10)))).created.single;
    await backend.simulateComplete(b.id);
    final q = (await backend.getQuotas(DateTime(2026, 11, 12), 1)).single;
    expect(q.reserved, 0);
    expect(q.consumed, 1);
  });

  test('jadwal rutin membuat booking per tanggal dan melewati tanggal yang kuotanya habis', () async {
    await subscribe();
    // Habiskan kuota Senin 16 Nov.
    for (var h = 9; h < 13; h++) {
      await backend.createBooking(flexible(DateTime(2026, 11, 16, h)));
    }
    final r = await backend.createBooking(const BookingRequest(
      type: BookingType.routine,
      rideMode: RideMode.shared,
      pickup: _home,
      destination: _office,
      passengerCount: 1,
      maxDetourMinutes: 15,
      note: '',
      weekdays: [1, 3, 5], // Senin, Rabu, Jumat
      hour: 7,
      minute: 0,
    ));
    // Jendela 12-18 Nov: Jumat 13, Senin 16 (penuh), Rabu 18.
    expect(r.created.map((b) => b.scheduledAt.day).toList(), [13, 18]);
    expect(r.skipped.length, 1);

    // Hari berikutnya generator menambah tanggal baru tanpa menggandakan yang lama.
    now = DateTime(2026, 11, 14, 6);
    final all = await backend.getBookings();
    final routineDays = all.where((b) => b.recurringScheduleId == r.schedule!.id).map((b) => b.scheduledAt.day).toList()..sort();
    expect(routineDays, [13, 18, 20]);
  });

  test('menghentikan jadwal rutin membatalkan booking yang masih jauh dan mengembalikan kuota', () async {
    await subscribe();
    final r = await backend.createBooking(const BookingRequest(
      type: BookingType.routine,
      rideMode: RideMode.individual,
      pickup: _home,
      destination: _office,
      passengerCount: 1,
      maxDetourMinutes: 0,
      note: '',
      weekdays: [5],
      hour: 7,
      minute: 0,
    ));
    await backend.deactivateSchedule(r.schedule!.id);
    final b = (await backend.getBookings()).single;
    expect(b.status, BookingStatus.cancelled);
    expect(b.quotaOutcome, QuotaOutcome.released);
    expect((await backend.getQuotas(DateTime(2026, 11, 13), 1)).single.remaining, 4);
  });

  test('penumpang anak wajib punya kontak darurat; data bisa diubah dan dihapus', () async {
    expect(
      () => backend.savePassenger(const Passenger(id: '', name: 'Rafi', relation: 'Anak', isChild: true)),
      throwsA(isA<BookingException>()),
    );
    final p = await backend.savePassenger(const Passenger(
      id: '',
      name: ' Rafi ',
      relation: 'Anak',
      isChild: true,
      school: 'SD N 1 Cilacap',
      emergencyName: 'Ibu Rina',
      emergencyPhone: '081200000000',
    ));
    expect(p.id, isNotEmpty);
    expect(p.name, 'Rafi');
    await backend.savePassenger(Passenger(
      id: p.id,
      name: 'Rafi Pratama',
      relation: 'Anak',
      isChild: true,
      emergencyName: 'Ibu Rina',
      emergencyPhone: '081200000000',
    ));
    final list = await backend.getPassengers();
    expect(list.single.name, 'Rafi Pratama');
    await backend.deletePassenger(p.id);
    expect(await backend.getPassengers(), isEmpty);
  });

  test('nama penumpang tersimpan di booking sekali jalan dan booking rutin', () async {
    await subscribe();
    final single = await backend.createBooking(BookingRequest(
      type: BookingType.flexible,
      rideMode: RideMode.individual,
      pickup: _home,
      destination: _office,
      passengerCount: 2,
      passengerNames: const ['Siti', 'Rafi (anak)'],
      maxDetourMinutes: 0,
      note: '',
      scheduledAt: DateTime(2026, 11, 12, 10),
    ));
    expect(single.created.single.passengerNames, ['Siti', 'Rafi (anak)']);
    final routine = await backend.createBooking(const BookingRequest(
      type: BookingType.routine,
      rideMode: RideMode.individual,
      pickup: _home,
      destination: _office,
      passengerCount: 1,
      passengerNames: ['Rafi (anak)'],
      maxDetourMinutes: 0,
      note: '',
      weekdays: [5],
      hour: 6,
      minute: 30,
    ));
    final stored = (await backend.getBookings()).firstWhere((b) => b.id == routine.created.single.id);
    expect(stored.passengerNames, ['Rafi (anak)']);
  });

  test('alamat tersimpan: label sama menimpa, bisa dihapus', () async {
    await backend.savePlace(_home);
    await backend.savePlace(const Place(label: 'rumah', address: 'Alamat baru', latitude: -7.7, longitude: 109.0));
    final places = await backend.getSavedPlaces();
    expect(places.single.address, 'Alamat baru');
    await backend.deletePlace('Rumah');
    expect(await backend.getSavedPlaces(), isEmpty);
  });
}
