import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/work_models.dart';

class WorkState extends Equatable {
  final bool loading;
  final String? error;
  final Shift? shift;
  final List<Trip> trips;
  final List<Incident> incidents;
  final List<Trip> history;

  const WorkState({
    this.loading = false,
    this.error,
    this.shift,
    this.trips = const [],
    this.incidents = const [],
    this.history = const [],
  });

  List<Trip> get openTrips => trips.where((t) => t.status.isOpen).toList();

  Trip? get activeTrip => trips.where((t) => t.status == TripStatus.inProgress).firstOrNull;

  Trip? get nextTrip => activeTrip ?? (openTrips.isEmpty ? null : openTrips.first);

  int get completedToday => trips.where((t) => t.status == TripStatus.completed).length;

  WorkState copyWith({
    bool? loading,
    String? error,
    bool clearError = false,
    Shift? shift,
    List<Trip>? trips,
    List<Incident>? incidents,
    List<Trip>? history,
  }) =>
      WorkState(
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        shift: shift ?? this.shift,
        trips: trips ?? this.trips,
        incidents: incidents ?? this.incidents,
        history: history ?? this.history,
      );

  @override
  List<Object?> get props => [loading, error, shift, trips, incidents, history];
}

/// Semua aksi melempar [WorkException] bila ditolak aturan, supaya layar bisa menampilkan pesannya.
class WorkCubit extends Cubit<WorkState> {
  final WorkRepository repo;

  WorkCubit(this.repo) : super(const WorkState());

  int get noShowWaitMinutes => repo.noShowWaitMinutes;
  int get minBatteryPercent => repo.minBatteryPercent;

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final day = await repo.getToday();
      final history = await repo.getHistory();
      emit(state.copyWith(loading: false, shift: day.shift, trips: day.trips, incidents: day.incidents, history: history));
    } catch (e) {
      emit(state.copyWith(loading: false, error: 'Gagal memuat data kerja: $e'));
    }
  }

  Future<T> _run<T>(Future<T> Function() action) async {
    final result = await action();
    await load();
    return result;
  }

  Future<void> startShift({required List<ChecklistItem> checklist, required int batteryPercent, required int odometer}) =>
      _run(() => repo.startShift(checklist: checklist, batteryPercent: batteryPercent, odometer: odometer));

  Future<void> setBreak(bool onBreak) => _run(() => repo.setBreak(onBreak));
  Future<void> startCharging() => _run(() => repo.startCharging());
  Future<void> finishCharging(int battery) => _run(() => repo.finishCharging(battery));
  Future<void> updateBattery(int battery) => _run(() => repo.updateBattery(battery));

  Future<void> endShift({required int batteryPercent, required int odometer, required String note}) =>
      _run(() => repo.endShift(batteryPercent: batteryPercent, odometer: odometer, note: note));

  Future<Trip> acceptTrip(String id) => _run(() => repo.acceptTrip(id));
  Future<Trip> rejectTrip(String id, String reason) => _run(() => repo.rejectTrip(id, reason));
  Future<Trip> arrive(String tripId, String stopId) => _run(() => repo.arriveAtStop(tripId, stopId));
  Future<Trip> confirmPickup(String tripId, String stopId, String pin) => _run(() => repo.confirmPickup(tripId, stopId, pin));
  Future<Trip> markNoShow(String tripId, String stopId) => _run(() => repo.markNoShow(tripId, stopId));
  Future<Trip> confirmDropoff(String tripId, String stopId) => _run(() => repo.confirmDropoff(tripId, stopId));

  Future<Incident> reportIncident({required IncidentType type, required String description, String? tripId, bool emergency = false}) =>
      _run(() => repo.reportIncident(type: type, description: description, tripId: tripId, emergency: emergency));
}
