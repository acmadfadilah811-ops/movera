import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/tanggal.dart';
import '../../data/subscription_models.dart';

class SubscriptionState extends Equatable {
  final bool loading;
  final String? error;
  final List<SubscriptionPlan> plans;
  final List<Subscription> subscriptions;
  final List<DailyQuota> quotas;

  const SubscriptionState({
    this.loading = false,
    this.error,
    this.plans = const [],
    this.subscriptions = const [],
    this.quotas = const [],
  });

  /// Langganan yang berlaku hari ini.
  Subscription? get current {
    final today = DateTime.now();
    for (final s in subscriptions) {
      if (s.coversDate(today)) return s;
    }
    return null;
  }

  /// Perpanjangan yang sudah dibayar dan menunggu mulai.
  Subscription? get upcoming {
    final today = tanggalSaja(DateTime.now());
    for (final s in subscriptions) {
      if (s.startDate.isAfter(today)) return s;
    }
    return null;
  }

  DailyQuota? get todayQuota {
    final today = DateTime.now();
    for (final q in quotas) {
      if (samaTanggal(q.date, today)) return q;
    }
    return null;
  }

  SubscriptionState copyWith({
    bool? loading,
    String? error,
    bool clearError = false,
    List<SubscriptionPlan>? plans,
    List<Subscription>? subscriptions,
    List<DailyQuota>? quotas,
  }) =>
      SubscriptionState(
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        plans: plans ?? this.plans,
        subscriptions: subscriptions ?? this.subscriptions,
        quotas: quotas ?? this.quotas,
      );

  @override
  List<Object?> get props => [loading, error, plans, subscriptions, quotas];
}

class SubscriptionCubit extends Cubit<SubscriptionState> {
  final SubscriptionRepository repo;
  static const quotaDays = 7;

  SubscriptionCubit(this.repo) : super(const SubscriptionState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final results = await Future.wait([
        repo.getPlans(),
        repo.getSubscriptions(),
        repo.getQuotas(DateTime.now(), quotaDays),
      ]);
      emit(state.copyWith(
        loading: false,
        plans: results[0] as List<SubscriptionPlan>,
        subscriptions: results[1] as List<Subscription>,
        quotas: results[2] as List<DailyQuota>,
      ));
    } catch (e) {
      emit(state.copyWith(loading: false, error: 'Gagal memuat langganan: $e'));
    }
  }

  Future<String> checkout(String planId) => repo.checkout(planId);

  /// Mode data contoh saja. Di produksi, langganan aktif lewat webhook payment gateway.
  Future<Subscription> confirmMockPayment(String paymentId) async {
    final sub = await repo.simulatePaymentSuccess(paymentId);
    await load();
    return sub;
  }
}
