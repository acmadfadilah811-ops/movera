import 'package:equatable/equatable.dart';

/// Paket langganan. Harga, masa aktif, dan kuota diatur admin.
class SubscriptionPlan extends Equatable {
  final String id;
  final String name;
  final String description;
  final int price;
  final int durationDays;
  final int dailyQuota;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.durationDays,
    required this.dailyQuota,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> j) => SubscriptionPlan(
        id: j['id'] as String,
        name: j['name'] as String,
        description: (j['description'] ?? '') as String,
        price: (j['price'] as num).toInt(),
        durationDays: (j['duration_days'] as num).toInt(),
        dailyQuota: (j['daily_quota'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'price': price,
        'duration_days': durationDays,
        'daily_quota': dailyQuota,
      };

  @override
  List<Object?> get props => [id, name, price, durationDays, dailyQuota];
}

enum SubscriptionStatus { pendingPayment, active, expired, cancelled }

class Subscription extends Equatable {
  final String id;
  final SubscriptionPlan plan;
  final DateTime startDate;
  final DateTime endDate;
  final SubscriptionStatus status;

  const Subscription({
    required this.id,
    required this.plan,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  /// Langganan berlaku pada tanggal [d] (tanggal mulai dan akhir ikut dihitung).
  bool coversDate(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return status == SubscriptionStatus.active && !day.isBefore(startDate) && !day.isAfter(endDate);
  }

  int daysLeft(DateTime today) {
    final t = DateTime(today.year, today.month, today.day);
    if (t.isAfter(endDate)) return 0;
    final from = t.isBefore(startDate) ? startDate : t;
    return endDate.difference(from).inDays + 1;
  }

  factory Subscription.fromJson(Map<String, dynamic> j) => Subscription(
        id: j['id'] as String,
        plan: SubscriptionPlan.fromJson(j['plan'] as Map<String, dynamic>),
        startDate: DateTime.parse(j['start_date'] as String),
        endDate: DateTime.parse(j['end_date'] as String),
        status: SubscriptionStatus.values.byName(j['status'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'plan': plan.toJson(),
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'status': status.name,
      };

  @override
  List<Object?> get props => [id, plan, startDate, endDate, status];
}

/// Kuota satu tanggal operasional: remaining = total - reserved - consumed.
class DailyQuota extends Equatable {
  final DateTime date;
  final int total;
  final int reserved;
  final int consumed;

  const DailyQuota({required this.date, required this.total, this.reserved = 0, this.consumed = 0});

  int get remaining => total - reserved - consumed;

  factory DailyQuota.fromJson(Map<String, dynamic> j) => DailyQuota(
        date: DateTime.parse(j['date'] as String),
        total: (j['total'] as num).toInt(),
        reserved: (j['reserved'] as num).toInt(),
        consumed: (j['consumed'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'total': total,
        'reserved': reserved,
        'consumed': consumed,
      };

  @override
  List<Object?> get props => [date, total, reserved, consumed];
}

abstract class SubscriptionRepository {
  Future<List<SubscriptionPlan>> getPlans();

  /// Langganan yang berlaku hari ini atau yang akan datang (perpanjangan), urut tanggal mulai.
  Future<List<Subscription>> getSubscriptions();

  /// Membuat pembelian paket. Mengembalikan id pembayaran.
  Future<String> checkout(String planId);

  /// Hanya untuk mode data contoh: anggap pembayaran sukses lalu aktifkan langganan.
  Future<Subscription> simulatePaymentSuccess(String paymentId);

  /// Kuota untuk rentang tanggal; tanggal di luar masa langganan tidak dikembalikan.
  Future<List<DailyQuota>> getQuotas(DateTime from, int days);
}
