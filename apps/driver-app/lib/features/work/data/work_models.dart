import 'package:equatable/equatable.dart';

/// Mobil listrik armada Movera yang dipakai driver pada shift ini.
class Vehicle extends Equatable {
  final String id;
  final String plate;
  final String model;
  final int seats;

  /// Jarak tempuh saat baterai penuh (km), dari data kendaraan.
  final int fullRangeKm;

  const Vehicle({required this.id, required this.plate, required this.model, required this.seats, required this.fullRangeKm});

  int rangeAt(int batteryPercent) => (fullRangeKm * batteryPercent / 100).floor();

  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
        id: j['id'] as String,
        plate: j['plate'] as String,
        model: j['model'] as String,
        seats: (j['seats'] as num).toInt(),
        fullRangeKm: (j['full_range_km'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {'id': id, 'plate': plate, 'model': model, 'seats': seats, 'full_range_km': fullRangeKm};

  @override
  List<Object?> get props => [id, plate];
}

/// Butir checklist kendaraan sebelum shift. [critical] true: shift tidak boleh dimulai kalau tidak lolos.
class ChecklistItem extends Equatable {
  final String key;
  final String label;
  final bool critical;
  final bool ok;

  const ChecklistItem({required this.key, required this.label, required this.critical, this.ok = false});

  ChecklistItem withOk(bool v) => ChecklistItem(key: key, label: label, critical: critical, ok: v);

  factory ChecklistItem.fromJson(Map<String, dynamic> j) => ChecklistItem(
        key: j['key'] as String,
        label: j['label'] as String,
        critical: j['critical'] as bool,
        ok: j['ok'] as bool,
      );

  Map<String, dynamic> toJson() => {'key': key, 'label': label, 'critical': critical, 'ok': ok};

  @override
  List<Object?> get props => [key, ok];
}

const defaultChecklist = [
  ChecklistItem(key: 'rem', label: 'Rem berfungsi baik', critical: true),
  ChecklistItem(key: 'ban', label: 'Ban dan tekanan angin normal', critical: true),
  ChecklistItem(key: 'lampu', label: 'Lampu depan, belakang, sein menyala', critical: true),
  ChecklistItem(key: 'sabuk', label: 'Sabuk pengaman semua kursi berfungsi', critical: true),
  ChecklistItem(key: 'peringatan', label: 'Tidak ada lampu peringatan di dasbor', critical: true),
  ChecklistItem(key: 'kebersihan', label: 'Kabin bersih', critical: false),
  ChecklistItem(key: 'dokumen', label: 'STNK dan SIM dibawa', critical: true),
  ChecklistItem(key: 'kabel', label: 'Kabel cas darurat tersedia', critical: false),
];

enum ShiftStatus { notStarted, available, onBreak, charging, ended }

extension ShiftStatusLabel on ShiftStatus {
  String get label => switch (this) {
        ShiftStatus.notStarted => 'Belum mulai shift',
        ShiftStatus.available => 'Bertugas',
        ShiftStatus.onBreak => 'Istirahat',
        ShiftStatus.charging => 'Sedang mengecas',
        ShiftStatus.ended => 'Shift selesai',
      };

  bool get isOnDuty => this == ShiftStatus.available || this == ShiftStatus.onBreak || this == ShiftStatus.charging;
}

class Shift extends Equatable {
  final String id;
  final DateTime date;
  final ShiftStatus status;
  final Vehicle vehicle;
  final int batteryPercent;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? startOdometer;
  final int? endOdometer;
  final int? startBattery;
  final int? endBattery;
  final List<ChecklistItem> checklist;
  final String endNote;

  const Shift({
    required this.id,
    required this.date,
    required this.status,
    required this.vehicle,
    required this.batteryPercent,
    this.startedAt,
    this.endedAt,
    this.startOdometer,
    this.endOdometer,
    this.startBattery,
    this.endBattery,
    this.checklist = const [],
    this.endNote = '',
  });

  Shift copyWith({
    ShiftStatus? status,
    int? batteryPercent,
    DateTime? startedAt,
    DateTime? endedAt,
    int? startOdometer,
    int? endOdometer,
    int? startBattery,
    int? endBattery,
    List<ChecklistItem>? checklist,
    String? endNote,
  }) =>
      Shift(
        id: id,
        date: date,
        status: status ?? this.status,
        vehicle: vehicle,
        batteryPercent: batteryPercent ?? this.batteryPercent,
        startedAt: startedAt ?? this.startedAt,
        endedAt: endedAt ?? this.endedAt,
        startOdometer: startOdometer ?? this.startOdometer,
        endOdometer: endOdometer ?? this.endOdometer,
        startBattery: startBattery ?? this.startBattery,
        endBattery: endBattery ?? this.endBattery,
        checklist: checklist ?? this.checklist,
        endNote: endNote ?? this.endNote,
      );

  factory Shift.fromJson(Map<String, dynamic> j) => Shift(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        status: ShiftStatus.values.byName(j['status'] as String),
        vehicle: Vehicle.fromJson(j['vehicle'] as Map<String, dynamic>),
        batteryPercent: (j['battery_percent'] as num).toInt(),
        startedAt: j['started_at'] == null ? null : DateTime.parse(j['started_at'] as String),
        endedAt: j['ended_at'] == null ? null : DateTime.parse(j['ended_at'] as String),
        startOdometer: (j['start_odometer'] as num?)?.toInt(),
        endOdometer: (j['end_odometer'] as num?)?.toInt(),
        startBattery: (j['start_battery'] as num?)?.toInt(),
        endBattery: (j['end_battery'] as num?)?.toInt(),
        checklist: ((j['checklist'] ?? const []) as List).map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>)).toList(),
        endNote: (j['end_note'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'status': status.name,
        'vehicle': vehicle.toJson(),
        'battery_percent': batteryPercent,
        'started_at': startedAt?.toIso8601String(),
        'ended_at': endedAt?.toIso8601String(),
        'start_odometer': startOdometer,
        'end_odometer': endOdometer,
        'start_battery': startBattery,
        'end_battery': endBattery,
        'checklist': checklist.map((c) => c.toJson()).toList(),
        'end_note': endNote,
      };

  @override
  List<Object?> get props => [id, status, batteryPercent, startedAt, endedAt, endOdometer];
}

class StopPlace extends Equatable {
  final String label;
  final String address;
  final double latitude;
  final double longitude;

  const StopPlace({required this.label, required this.address, required this.latitude, required this.longitude});

  factory StopPlace.fromJson(Map<String, dynamic> j) => StopPlace(
        label: (j['label'] ?? '') as String,
        address: j['address'] as String,
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {'label': label, 'address': address, 'latitude': latitude, 'longitude': longitude};

  @override
  List<Object?> get props => [address, latitude, longitude];
}

enum StopType { pickup, dropoff }

enum StopStatus { pending, arrived, done, noShow, skipped }

extension StopStatusLabel on StopStatus {
  String get label => switch (this) {
        StopStatus.pending => 'Belum',
        StopStatus.arrived => 'Sudah tiba',
        StopStatus.done => 'Selesai',
        StopStatus.noShow => 'Penumpang tidak hadir',
        StopStatus.skipped => 'Dilewati',
      };

  bool get isFinal => this == StopStatus.done || this == StopStatus.noShow || this == StopStatus.skipped;
}

/// Satu titik dalam manifest. Shared ride punya beberapa pickup dan dropoff.
class TripStop extends Equatable {
  final String id;
  final int sequence;
  final StopType type;
  final String bookingId;
  final StopPlace place;
  final List<String> passengerNames;
  final int passengerCount;
  final String customerName;
  final String customerPhone;
  final String note;
  final bool hasChild;
  final String emergencyName;
  final String emergencyPhone;
  final StopStatus status;
  final DateTime? arrivedAt;
  final DateTime? doneAt;

  const TripStop({
    required this.id,
    required this.sequence,
    required this.type,
    required this.bookingId,
    required this.place,
    required this.passengerNames,
    required this.passengerCount,
    required this.customerName,
    required this.customerPhone,
    this.note = '',
    this.hasChild = false,
    this.emergencyName = '',
    this.emergencyPhone = '',
    this.status = StopStatus.pending,
    this.arrivedAt,
    this.doneAt,
  });

  TripStop withStatus(StopStatus s, {DateTime? arrivedAt, DateTime? doneAt}) => TripStop(
        id: id,
        sequence: sequence,
        type: type,
        bookingId: bookingId,
        place: place,
        passengerNames: passengerNames,
        passengerCount: passengerCount,
        customerName: customerName,
        customerPhone: customerPhone,
        note: note,
        hasChild: hasChild,
        emergencyName: emergencyName,
        emergencyPhone: emergencyPhone,
        status: s,
        arrivedAt: arrivedAt ?? this.arrivedAt,
        doneAt: doneAt ?? this.doneAt,
      );

  factory TripStop.fromJson(Map<String, dynamic> j) => TripStop(
        id: j['id'] as String,
        sequence: (j['sequence'] as num).toInt(),
        type: StopType.values.byName(j['type'] as String),
        bookingId: j['booking_id'] as String,
        place: StopPlace.fromJson(j['place'] as Map<String, dynamic>),
        passengerNames: (j['passenger_names'] as List).cast<String>(),
        passengerCount: (j['passenger_count'] as num).toInt(),
        customerName: j['customer_name'] as String,
        customerPhone: (j['customer_phone'] ?? '') as String,
        note: (j['note'] ?? '') as String,
        hasChild: (j['has_child'] ?? false) as bool,
        emergencyName: (j['emergency_name'] ?? '') as String,
        emergencyPhone: (j['emergency_phone'] ?? '') as String,
        status: StopStatus.values.byName(j['status'] as String),
        arrivedAt: j['arrived_at'] == null ? null : DateTime.parse(j['arrived_at'] as String),
        doneAt: j['done_at'] == null ? null : DateTime.parse(j['done_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'sequence': sequence,
        'type': type.name,
        'booking_id': bookingId,
        'place': place.toJson(),
        'passenger_names': passengerNames,
        'passenger_count': passengerCount,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'note': note,
        'has_child': hasChild,
        'emergency_name': emergencyName,
        'emergency_phone': emergencyPhone,
        'status': status.name,
        'arrived_at': arrivedAt?.toIso8601String(),
        'done_at': doneAt?.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, status, arrivedAt, doneAt];
}

enum TripStatus { assigned, accepted, inProgress, completed, rejected }

extension TripStatusLabel on TripStatus {
  String get label => switch (this) {
        TripStatus.assigned => 'Tugas baru',
        TripStatus.accepted => 'Dikonfirmasi',
        TripStatus.inProgress => 'Berjalan',
        TripStatus.completed => 'Selesai',
        TripStatus.rejected => 'Ditolak',
      };

  bool get isOpen => this == TripStatus.assigned || this == TripStatus.accepted || this == TripStatus.inProgress;
}

class Trip extends Equatable {
  final String id;
  final DateTime scheduledAt;
  final bool shared;
  final TripStatus status;
  final List<TripStop> stops;
  final String? rejectReason;
  final DateTime? startedAt;
  final DateTime? completedAt;

  /// Perkiraan jarak trip (km), untuk cek kecukupan baterai.
  final double estimatedKm;

  const Trip({
    required this.id,
    required this.scheduledAt,
    required this.shared,
    required this.status,
    required this.stops,
    required this.estimatedKm,
    this.rejectReason,
    this.startedAt,
    this.completedAt,
  });

  /// Titik berikutnya yang harus dikerjakan sesuai urutan.
  TripStop? get nextStop {
    final pending = stops.where((s) => !s.status.isFinal).toList()..sort((a, b) => a.sequence.compareTo(b.sequence));
    return pending.isEmpty ? null : pending.first;
  }

  int get passengerTotal => stops.where((s) => s.type == StopType.pickup).fold(0, (n, s) => n + s.passengerCount);

  Trip copyWith({TripStatus? status, List<TripStop>? stops, String? rejectReason, DateTime? startedAt, DateTime? completedAt}) => Trip(
        id: id,
        scheduledAt: scheduledAt,
        shared: shared,
        status: status ?? this.status,
        stops: stops ?? this.stops,
        estimatedKm: estimatedKm,
        rejectReason: rejectReason ?? this.rejectReason,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt ?? this.completedAt,
      );

  factory Trip.fromJson(Map<String, dynamic> j) => Trip(
        id: j['id'] as String,
        scheduledAt: DateTime.parse(j['scheduled_at'] as String),
        shared: j['shared'] as bool,
        status: TripStatus.values.byName(j['status'] as String),
        stops: (j['stops'] as List).map((e) => TripStop.fromJson(e as Map<String, dynamic>)).toList(),
        estimatedKm: (j['estimated_km'] as num).toDouble(),
        rejectReason: j['reject_reason'] as String?,
        startedAt: j['started_at'] == null ? null : DateTime.parse(j['started_at'] as String),
        completedAt: j['completed_at'] == null ? null : DateTime.parse(j['completed_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'scheduled_at': scheduledAt.toIso8601String(),
        'shared': shared,
        'status': status.name,
        'stops': stops.map((s) => s.toJson()).toList(),
        'estimated_km': estimatedKm,
        'reject_reason': rejectReason,
        'started_at': startedAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, status, stops, startedAt, completedAt];
}

enum IncidentType { vehicleDamage, accident, passengerIssue, childNoReceiver, delay, other }

extension IncidentTypeLabel on IncidentType {
  String get label => switch (this) {
        IncidentType.vehicleDamage => 'Kerusakan kendaraan',
        IncidentType.accident => 'Kecelakaan',
        IncidentType.passengerIssue => 'Masalah penumpang',
        IncidentType.childNoReceiver => 'Anak tidak ada penerima',
        IncidentType.delay => 'Terlambat / macet',
        IncidentType.other => 'Lainnya',
      };
}

class Incident extends Equatable {
  final String id;
  final IncidentType type;
  final String description;
  final String? tripId;
  final DateTime createdAt;
  final bool emergency;

  const Incident({
    required this.id,
    required this.type,
    required this.description,
    required this.createdAt,
    this.tripId,
    this.emergency = false,
  });

  factory Incident.fromJson(Map<String, dynamic> j) => Incident(
        id: j['id'] as String,
        type: IncidentType.values.byName(j['type'] as String),
        description: j['description'] as String,
        tripId: j['trip_id'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        emergency: (j['emergency'] ?? false) as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'description': description,
        'trip_id': tripId,
        'created_at': createdAt.toIso8601String(),
        'emergency': emergency,
      };

  @override
  List<Object?> get props => [id];
}

class WorkException implements Exception {
  final String message;
  const WorkException(this.message);

  @override
  String toString() => message;
}

/// Data hari ini untuk driver.
class WorkDay {
  final Shift shift;
  final List<Trip> trips;
  final List<Incident> incidents;

  const WorkDay({required this.shift, required this.trips, required this.incidents});
}

abstract class WorkRepository {
  Future<WorkDay> getToday();

  /// Gagal jika ada butir checklist wajib yang tidak lolos.
  Future<Shift> startShift({required List<ChecklistItem> checklist, required int batteryPercent, required int odometer});
  Future<Shift> setBreak(bool onBreak);
  Future<Shift> startCharging();
  Future<Shift> finishCharging(int batteryPercent);
  Future<Shift> updateBattery(int batteryPercent);

  /// Gagal jika masih ada trip yang berjalan.
  Future<Shift> endShift({required int batteryPercent, required int odometer, required String note});

  Future<Trip> acceptTrip(String tripId);
  Future<Trip> rejectTrip(String tripId, String reason);
  Future<Trip> arriveAtStop(String tripId, String stopId);

  /// Verifikasi PIN dari penumpang. Gagal jika PIN salah.
  Future<Trip> confirmPickup(String tripId, String stopId, String pin);

  /// Hanya boleh setelah menunggu [noShowWaitMinutes] menit sejak tiba.
  Future<Trip> markNoShow(String tripId, String stopId);
  Future<Trip> confirmDropoff(String tripId, String stopId);

  Future<Incident> reportIncident({required IncidentType type, required String description, String? tripId, bool emergency = false});

  Future<List<Trip>> getHistory();

  int get noShowWaitMinutes;

  /// Baterai minimal (persen) yang disarankan untuk menerima trip.
  int get minBatteryPercent;
}
