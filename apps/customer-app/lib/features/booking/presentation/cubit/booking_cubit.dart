import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/booking_models.dart';

class BookingState extends Equatable {
  final bool loading;
  final String? error;
  final List<Booking> bookings;
  final List<RecurringSchedule> schedules;
  final List<Place> savedPlaces;
  final List<Passenger> passengers;

  const BookingState({
    this.loading = false,
    this.error,
    this.bookings = const [],
    this.schedules = const [],
    this.savedPlaces = const [],
    this.passengers = const [],
  });

  List<Booking> get upcoming => bookings.where((b) => b.status.isActive).toList();

  List<Booking> get history => bookings.where((b) => !b.status.isActive).toList().reversed.toList();

  Booking? get next => upcoming.isEmpty ? null : upcoming.first;

  List<RecurringSchedule> get activeSchedules => schedules.where((s) => s.isActive).toList();

  BookingState copyWith({
    bool? loading,
    String? error,
    bool clearError = false,
    List<Booking>? bookings,
    List<RecurringSchedule>? schedules,
    List<Place>? savedPlaces,
    List<Passenger>? passengers,
  }) =>
      BookingState(
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        bookings: bookings ?? this.bookings,
        schedules: schedules ?? this.schedules,
        savedPlaces: savedPlaces ?? this.savedPlaces,
        passengers: passengers ?? this.passengers,
      );

  @override
  List<Object?> get props => [loading, error, bookings, schedules, savedPlaces, passengers];
}

class BookingCubit extends Cubit<BookingState> {
  final BookingRepository repo;

  BookingCubit(this.repo) : super(const BookingState());

  int get cancelCutoffMinutes => repo.cancelCutoffMinutes;
  int get minLeadMinutes => repo.minLeadMinutes;

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final bookings = await repo.getBookings();
      final schedules = await repo.getRecurringSchedules();
      final places = await repo.getSavedPlaces();
      final passengers = await repo.getPassengers();
      emit(state.copyWith(
          loading: false, bookings: bookings, schedules: schedules, savedPlaces: places, passengers: passengers));
    } catch (e) {
      emit(state.copyWith(loading: false, error: 'Gagal memuat booking: $e'));
    }
  }

  /// Melempar [BookingException] jika validasi gagal, supaya form bisa menampilkan pesannya.
  Future<BookingResult> create(BookingRequest request) async {
    final result = await repo.createBooking(request);
    await load();
    return result;
  }

  Future<Booking> cancel(String id, String reason) async {
    final b = await repo.cancelBooking(id, reason);
    await load();
    return b;
  }

  Future<void> deactivateSchedule(String id) async {
    await repo.deactivateSchedule(id);
    await load();
  }

  Future<void> savePlace(Place place) async {
    await repo.savePlace(place);
    await load();
  }

  Future<void> deletePlace(String label) async {
    await repo.deletePlace(label);
    await load();
  }

  /// Melempar [BookingException] jika data tidak lengkap.
  Future<Passenger> savePassenger(Passenger p) async {
    final saved = await repo.savePassenger(p);
    await load();
    return saved;
  }

  Future<void> deletePassenger(String id) async {
    await repo.deletePassenger(id);
    await load();
  }

  Future<void> simulateComplete(String id) async {
    await repo.simulateComplete(id);
    await load();
  }
}
