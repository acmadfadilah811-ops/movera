import 'package:equatable/equatable.dart';

class Place extends Equatable {
  final String label;
  final String address;
  final double latitude;
  final double longitude;

  const Place({required this.label, required this.address, required this.latitude, required this.longitude});

  factory Place.fromJson(Map<String, dynamic> j) => Place(
        label: (j['label'] ?? '') as String,
        address: j['address'] as String,
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {'label': label, 'address': address, 'latitude': latitude, 'longitude': longitude};

  Place withLabel(String l) => Place(label: l, address: address, latitude: latitude, longitude: longitude);

  @override
  List<Object?> get props => [label, address, latitude, longitude];
}

/// Penumpang yang didaftarkan pelanggan, misalnya anak yang diantar ke sekolah.
class Passenger extends Equatable {
  final String id;
  final String name;
  final String relation;
  final bool isChild;
  final String school;
  final String notes;
  final String emergencyName;
  final String emergencyPhone;

  const Passenger({
    required this.id,
    required this.name,
    required this.relation,
    required this.isChild,
    this.school = '',
    this.notes = '',
    this.emergencyName = '',
    this.emergencyPhone = '',
  });

  factory Passenger.fromJson(Map<String, dynamic> j) => Passenger(
        id: j['id'] as String,
        name: j['name'] as String,
        relation: (j['relation'] ?? '') as String,
        isChild: (j['is_child'] ?? false) as bool,
        school: (j['school'] ?? '') as String,
        notes: (j['notes'] ?? '') as String,
        emergencyName: (j['emergency_name'] ?? '') as String,
        emergencyPhone: (j['emergency_phone'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'relation': relation,
        'is_child': isChild,
        'school': school,
        'notes': notes,
        'emergency_name': emergencyName,
        'emergency_phone': emergencyPhone,
      };

  @override
  List<Object?> get props => [id, name, relation, isChild, school, notes, emergencyName, emergencyPhone];
}

enum BookingType { flexible, routine }

enum RideMode { individual, shared }

enum BookingStatus { pendingDispatch, assigned, onTheWay, inProgress, completed, cancelled, noShow }

extension BookingStatusLabel on BookingStatus {
  String get label => switch (this) {
        BookingStatus.pendingDispatch => 'Menunggu penugasan',
        BookingStatus.assigned => 'Driver ditugaskan',
        BookingStatus.onTheWay => 'Driver menuju lokasi',
        BookingStatus.inProgress => 'Dalam perjalanan',
        BookingStatus.completed => 'Selesai',
        BookingStatus.cancelled => 'Dibatalkan',
        BookingStatus.noShow => 'Tidak hadir',
      };

  bool get isActive => this == BookingStatus.pendingDispatch ||
      this == BookingStatus.assigned ||
      this == BookingStatus.onTheWay ||
      this == BookingStatus.inProgress;
}

/// Apa yang terjadi pada kuota saat booking dibatalkan.
enum QuotaOutcome { released, forfeited }

class Booking extends Equatable {
  final String id;
  final BookingType type;
  final RideMode rideMode;
  final DateTime scheduledAt;
  final Place pickup;
  final Place destination;
  final int passengerCount;

  /// Nama penumpang terdaftar yang ikut (untuk manifest driver).
  final List<String> passengerNames;
  final int maxDetourMinutes;
  final String note;
  final BookingStatus status;
  final String? recurringScheduleId;
  final DateTime createdAt;
  final String? cancelReason;
  final DateTime? cancelledAt;
  final QuotaOutcome? quotaOutcome;
  final String? driverName;
  final String? vehiclePlate;
  final String pickupPin;

  const Booking({
    required this.id,
    required this.type,
    required this.rideMode,
    required this.scheduledAt,
    required this.pickup,
    required this.destination,
    required this.passengerCount,
    required this.maxDetourMinutes,
    required this.note,
    required this.status,
    required this.createdAt,
    required this.pickupPin,
    this.passengerNames = const [],
    this.recurringScheduleId,
    this.cancelReason,
    this.cancelledAt,
    this.quotaOutcome,
    this.driverName,
    this.vehiclePlate,
  });

  Booking copyWith({
    BookingStatus? status,
    String? cancelReason,
    DateTime? cancelledAt,
    QuotaOutcome? quotaOutcome,
    String? driverName,
    String? vehiclePlate,
  }) =>
      Booking(
        id: id,
        type: type,
        rideMode: rideMode,
        scheduledAt: scheduledAt,
        pickup: pickup,
        destination: destination,
        passengerCount: passengerCount,
        passengerNames: passengerNames,
        maxDetourMinutes: maxDetourMinutes,
        note: note,
        status: status ?? this.status,
        createdAt: createdAt,
        pickupPin: pickupPin,
        recurringScheduleId: recurringScheduleId,
        cancelReason: cancelReason ?? this.cancelReason,
        cancelledAt: cancelledAt ?? this.cancelledAt,
        quotaOutcome: quotaOutcome ?? this.quotaOutcome,
        driverName: driverName ?? this.driverName,
        vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      );

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        id: j['id'] as String,
        type: BookingType.values.byName(j['booking_type'] as String),
        rideMode: RideMode.values.byName(j['ride_mode'] as String),
        scheduledAt: DateTime.parse(j['scheduled_at'] as String),
        pickup: Place.fromJson(j['pickup'] as Map<String, dynamic>),
        destination: Place.fromJson(j['destination'] as Map<String, dynamic>),
        passengerCount: (j['passenger_count'] as num).toInt(),
        passengerNames: ((j['passenger_names'] ?? const []) as List).cast<String>(),
        maxDetourMinutes: (j['max_detour_minutes'] as num).toInt(),
        note: (j['note'] ?? '') as String,
        status: BookingStatus.values.byName(j['status'] as String),
        createdAt: DateTime.parse(j['created_at'] as String),
        pickupPin: (j['pickup_pin'] ?? '') as String,
        recurringScheduleId: j['recurring_schedule_id'] as String?,
        cancelReason: j['cancel_reason'] as String?,
        cancelledAt: j['cancelled_at'] == null ? null : DateTime.parse(j['cancelled_at'] as String),
        quotaOutcome: j['quota_outcome'] == null ? null : QuotaOutcome.values.byName(j['quota_outcome'] as String),
        driverName: j['driver_name'] as String?,
        vehiclePlate: j['vehicle_plate'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'booking_type': type.name,
        'ride_mode': rideMode.name,
        'scheduled_at': scheduledAt.toIso8601String(),
        'pickup': pickup.toJson(),
        'destination': destination.toJson(),
        'passenger_count': passengerCount,
        'passenger_names': passengerNames,
        'max_detour_minutes': maxDetourMinutes,
        'note': note,
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
        'pickup_pin': pickupPin,
        'recurring_schedule_id': recurringScheduleId,
        'cancel_reason': cancelReason,
        'cancelled_at': cancelledAt?.toIso8601String(),
        'quota_outcome': quotaOutcome?.name,
        'driver_name': driverName,
        'vehicle_plate': vehiclePlate,
      };

  @override
  List<Object?> get props => [id, status, scheduledAt, quotaOutcome, driverName];
}

/// Jadwal rutin: membuat booking otomatis per tanggal, kuota dicadangkan per tanggal.
class RecurringSchedule extends Equatable {
  final String id;
  final List<int> weekdays; // 1 = Senin ... 7 = Minggu
  final int hour;
  final int minute;
  final Place pickup;
  final Place destination;
  final RideMode rideMode;
  final int passengerCount;
  final List<String> passengerNames;
  final int maxDetourMinutes;
  final String note;
  final bool isActive;

  const RecurringSchedule({
    required this.id,
    required this.weekdays,
    required this.hour,
    required this.minute,
    required this.pickup,
    required this.destination,
    required this.rideMode,
    required this.passengerCount,
    required this.maxDetourMinutes,
    required this.note,
    this.passengerNames = const [],
    this.isActive = true,
  });

  RecurringSchedule deactivated() => RecurringSchedule(
        id: id,
        weekdays: weekdays,
        hour: hour,
        minute: minute,
        pickup: pickup,
        destination: destination,
        rideMode: rideMode,
        passengerCount: passengerCount,
        passengerNames: passengerNames,
        maxDetourMinutes: maxDetourMinutes,
        note: note,
        isActive: false,
      );

  factory RecurringSchedule.fromJson(Map<String, dynamic> j) => RecurringSchedule(
        id: j['id'] as String,
        weekdays: (j['weekdays'] as List).map((e) => (e as num).toInt()).toList(),
        hour: (j['hour'] as num).toInt(),
        minute: (j['minute'] as num).toInt(),
        pickup: Place.fromJson(j['pickup'] as Map<String, dynamic>),
        destination: Place.fromJson(j['destination'] as Map<String, dynamic>),
        rideMode: RideMode.values.byName(j['ride_mode'] as String),
        passengerCount: (j['passenger_count'] as num).toInt(),
        passengerNames: ((j['passenger_names'] ?? const []) as List).cast<String>(),
        maxDetourMinutes: (j['max_detour_minutes'] as num).toInt(),
        note: (j['note'] ?? '') as String,
        isActive: j['is_active'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'weekdays': weekdays,
        'hour': hour,
        'minute': minute,
        'pickup': pickup.toJson(),
        'destination': destination.toJson(),
        'ride_mode': rideMode.name,
        'passenger_count': passengerCount,
        'passenger_names': passengerNames,
        'max_detour_minutes': maxDetourMinutes,
        'note': note,
        'is_active': isActive,
      };

  @override
  List<Object?> get props => [id, weekdays, hour, minute, isActive];
}

/// Data form booking yang dikirim ke backend.
class BookingRequest {
  final BookingType type;
  final RideMode rideMode;
  final Place pickup;
  final Place destination;
  final int passengerCount;
  final List<String> passengerNames;
  final int maxDetourMinutes;
  final String note;

  /// Untuk booking fleksibel.
  final DateTime? scheduledAt;

  /// Untuk booking rutin.
  final List<int> weekdays;
  final int hour;
  final int minute;

  const BookingRequest({
    required this.type,
    required this.rideMode,
    required this.pickup,
    required this.destination,
    required this.passengerCount,
    required this.maxDetourMinutes,
    required this.note,
    this.passengerNames = const [],
    this.scheduledAt,
    this.weekdays = const [],
    this.hour = 0,
    this.minute = 0,
  });
}

/// Hasil membuat booking. Untuk jadwal rutin, [skipped] berisi tanggal yang tidak bisa dibuatkan booking.
class BookingResult {
  final List<Booking> created;
  final List<String> skipped;
  final RecurringSchedule? schedule;

  const BookingResult({required this.created, this.skipped = const [], this.schedule});
}

class BookingException implements Exception {
  final String message;
  const BookingException(this.message);

  @override
  String toString() => message;
}

abstract class BookingRepository {
  Future<List<Booking>> getBookings();
  Future<List<RecurringSchedule>> getRecurringSchedules();
  Future<BookingResult> createBooking(BookingRequest request);

  /// Membatalkan booking. Kuota dikembalikan jika masih sebelum batas waktu pembatalan.
  Future<Booking> cancelBooking(String bookingId, String reason);

  /// Menonaktifkan jadwal rutin dan membatalkan booking turunannya yang belum berjalan.
  Future<void> deactivateSchedule(String scheduleId);

  Future<List<Place>> getSavedPlaces();
  Future<void> savePlace(Place place);
  Future<void> deletePlace(String label);

  Future<List<Passenger>> getPassengers();

  /// Melempar [BookingException] jika data tidak lengkap.
  Future<Passenger> savePassenger(Passenger passenger);
  Future<void> deletePassenger(String id);

  /// Batas menit sebelum jadwal agar pembatalan masih mengembalikan kuota.
  int get cancelCutoffMinutes;

  /// Minimal menit dari sekarang untuk booking baru.
  int get minLeadMinutes;

  /// Hanya untuk mode data contoh: tandai perjalanan selesai agar kuota tercatat terpakai.
  Future<Booking> simulateComplete(String bookingId);
}
