import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/presentation/widgets/movera_widgets.dart';
import '../../../../core/theme/movera_colors.dart';
import '../../../../core/utils/tanggal.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../core/presentation/pages/location_picker_page.dart';
import '../../../profile/presentation/pages/passengers_page.dart';
import '../../../profile/presentation/pages/saved_places_page.dart';
import '../../../subscription/presentation/cubit/subscription_cubit.dart';
import '../../data/booking_models.dart';
import '../cubit/booking_cubit.dart';

class CreateBookingPage extends StatefulWidget {
  /// Dipanggil saat pengguna belum berlangganan dan ingin melihat paket.
  final VoidCallback? onOpenSubscription;
  const CreateBookingPage({super.key, this.onOpenSubscription});

  @override
  State<CreateBookingPage> createState() => _CreateBookingPageState();
}

class _CreateBookingPageState extends State<CreateBookingPage> {
  static const _maxPassengers = 4;
  static const _detourOptions = [10, 15, 20];

  BookingType _type = BookingType.flexible;
  RideMode _mode = RideMode.individual;
  Place? _pickup;
  Place? _destination;
  DateTime? _date;
  TimeOfDay? _time;
  final Set<int> _weekdays = {};
  /// Pemesan ikut berangkat.
  bool _selfIncluded = true;
  final Set<String> _passengerIds = {};
  int _guests = 0;
  int _detour = 15;
  final _noteController = TextEditingController();
  bool _busy = false;

  int get _passengerTotal => (_selfIncluded ? 1 : 0) + _passengerIds.length + _guests;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  ThemeData _pickerTheme(BuildContext context) => ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(primary: MoveraColors.accent, onPrimary: Colors.black, surface: MoveraColors.card),
      );

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionCubit>().state;
    return Scaffold(
      backgroundColor: MoveraColors.bg,
      appBar: AppBar(
        backgroundColor: MoveraColors.bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Buat Booking', style: moveraText(size: 18, weight: FontWeight.w700)),
      ),
      body: sub.current == null ? _noSubscription(context) : _form(context, sub),
    );
  }

  Widget _noSubscription(BuildContext context) => EmptyState(
        icon: Icons.card_membership_rounded,
        title: 'Belum berlangganan',
        message: 'Booking hanya bisa dibuat saat langganan aktif.',
        action: widget.onOpenSubscription == null
            ? null
            : PrimaryButton(
                label: 'Lihat Paket',
                onPressed: () {
                  Navigator.pop(context);
                  widget.onOpenSubscription!();
                },
              ),
      );

  Widget _form(BuildContext context, SubscriptionState sub) {
    final places = context.watch<BookingCubit>().state.savedPlaces;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        const SectionLabel('Jenis booking'),
        _segmented<BookingType>(
          value: _type,
          options: const {BookingType.flexible: 'Sekali jalan', BookingType.routine: 'Rutin mingguan'},
          onChanged: (v) => setState(() => _type = v),
        ),
        const SizedBox(height: 22),
        const SectionLabel('Rute'),
        _placeTile(
          icon: Icons.trip_origin_rounded,
          label: 'Titik jemput',
          place: _pickup,
          onTap: () => _choosePlace(context, places, isPickup: true),
        ),
        const SizedBox(height: 8),
        _placeTile(
          icon: Icons.location_on_rounded,
          label: 'Tujuan',
          place: _destination,
          onTap: () => _choosePlace(context, places, isPickup: false),
        ),
        const SizedBox(height: 22),
        SectionLabel(_type == BookingType.flexible ? 'Waktu jemput' : 'Jadwal rutin'),
        if (_type == BookingType.flexible)
          Row(children: [
            Expanded(
              child: _pickerTile(
                Icons.calendar_today_rounded,
                _date == null ? 'Pilih tanggal' : formatTanggalPendek(_date!),
                () => _pickDate(context, sub),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _timeTile(context)),
          ])
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var d = 1; d <= 7; d++)
                _chip(namaHariPendek(d), _weekdays.contains(d), () {
                  setState(() => _weekdays.contains(d) ? _weekdays.remove(d) : _weekdays.add(d));
                }),
            ],
          ),
          const SizedBox(height: 8),
          _timeTile(context),
          const SizedBox(height: 8),
          Text('Booking dibuat otomatis untuk 7 hari ke depan dan terus diperbarui. Kuota dicadangkan per tanggal.',
              style: moveraText(size: 12, color: MoveraColors.textMuted, height: 1.45)),
        ],
        _quotaHint(sub),
        const SizedBox(height: 22),
        SectionLabel('Siapa yang berangkat? ($_passengerTotal/$_maxPassengers)'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _chip('Saya', _selfIncluded, () {
            if (!_selfIncluded && _passengerTotal >= _maxPassengers) return;
            setState(() => _selfIncluded = !_selfIncluded);
          }),
          for (final p in context.watch<BookingCubit>().state.passengers)
            _chip(p.name, _passengerIds.contains(p.id), () {
              final selected = _passengerIds.contains(p.id);
              if (!selected && _passengerTotal >= _maxPassengers) return;
              setState(() => selected ? _passengerIds.remove(p.id) : _passengerIds.add(p.id));
            }),
          ActionChip(
            avatar: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Daftarkan penumpang'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PassengerFormPage())),
          ),
        ]),
        const SizedBox(height: 8),
        MoveraCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            Expanded(child: Text('Penumpang lain (tanpa data)', style: moveraText(size: 13))),
            IconButton(
              onPressed: _guests > 0 ? () => setState(() => _guests--) : null,
              icon: const Icon(Icons.remove_circle_outline_rounded),
              color: MoveraColors.accent,
              disabledColor: MoveraColors.textFaint,
            ),
            Text('$_guests', style: moveraText(size: 16, weight: FontWeight.w700)),
            IconButton(
              onPressed: _passengerTotal < _maxPassengers ? () => setState(() => _guests++) : null,
              icon: const Icon(Icons.add_circle_outline_rounded),
              color: MoveraColors.accent,
              disabledColor: MoveraColors.textFaint,
            ),
          ]),
        ),
        const SizedBox(height: 22),
        const SectionLabel('Preferensi perjalanan'),
        _segmented<RideMode>(
          value: _mode,
          options: const {RideMode.individual: 'Sendiri', RideMode.shared: 'Bersedia berbagi'},
          onChanged: (v) => setState(() => _mode = v),
        ),
        const SizedBox(height: 8),
        if (_mode == RideMode.shared) ...[
          Text('Mobil bisa menjemput penumpang lain searah. Batas tambahan waktu perjalanan:',
              style: moveraText(size: 12, color: MoveraColors.textMuted, height: 1.45)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final m in _detourOptions) _chip('$m menit', _detour == m, () => setState(() => _detour = m)),
          ]),
        ] else
          Text('Mobil hanya untuk Anda dan penumpang dalam booking ini.',
              style: moveraText(size: 12, color: MoveraColors.textMuted, height: 1.45)),
        const SizedBox(height: 22),
        const SectionLabel('Catatan untuk driver'),
        TextField(
          controller: _noteController,
          maxLines: 2,
          maxLength: 200,
          style: moveraText(),
          decoration: InputDecoration(
            hintText: 'Contoh: rumah pagar hijau, tunggu di depan gerbang sekolah',
            hintStyle: moveraText(size: 13, color: MoveraColors.textFaint),
            filled: true,
            fillColor: MoveraColors.card,
            counterStyle: moveraText(size: 11, color: MoveraColors.textFaint),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: _type == BookingType.flexible ? 'Pesan' : 'Simpan Jadwal Rutin',
          busy: _busy,
          onPressed: () => _submit(context),
        ),
      ],
    );
  }

  Widget _quotaHint(SubscriptionState sub) {
    if (_type != BookingType.flexible || _date == null) return const SizedBox.shrink();
    final q = sub.quotas.where((q) => samaTanggal(q.date, _date!)).firstOrNull;
    if (q == null) return const SizedBox.shrink();
    final color = q.remaining > 0 ? MoveraColors.textMuted : MoveraColors.danger;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text('Sisa kuota ${formatTanggalPendek(_date!)}: ${q.remaining} dari ${q.total}',
          style: moveraText(size: 12, color: color)),
    );
  }

  Widget _segmented<T>({required T value, required Map<T, String> options, required ValueChanged<T> onChanged}) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: MoveraColors.card, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          for (final e in options.entries)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: value == e.key ? MoveraColors.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(e.value,
                      textAlign: TextAlign.center,
                      style: moveraText(
                          size: 13,
                          weight: FontWeight.w600,
                          color: value == e.key ? MoveraColors.onAccent : MoveraColors.textMuted)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? MoveraColors.accent : MoveraColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? MoveraColors.accent : MoveraColors.border),
          ),
          child: Text(label,
              style: moveraText(size: 13, weight: FontWeight.w600, color: selected ? MoveraColors.onAccent : MoveraColors.text)),
        ),
      );

  Widget _placeTile({required IconData icon, required String label, required Place? place, required VoidCallback onTap}) {
    return MoveraCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Icon(icon, color: MoveraColors.accent, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(place == null ? label : (place.label.isEmpty ? label : place.label),
                style: moveraText(size: 12, color: MoveraColors.textMuted)),
            const SizedBox(height: 2),
            Text(place?.address ?? 'Pilih lokasi',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: moveraText(size: 14, weight: FontWeight.w600, color: place == null ? MoveraColors.textFaint : MoveraColors.text)),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: MoveraColors.textFaint),
      ]),
    );
  }

  Widget _pickerTile(IconData icon, String text, VoidCallback onTap) => MoveraCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 18, color: MoveraColors.accent),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: moveraText(size: 14, weight: FontWeight.w600))),
        ]),
      );

  Widget _timeTile(BuildContext context) => _pickerTile(
        Icons.schedule_rounded,
        _time == null ? 'Pilih jam' : '${_time!.hour.toString().padLeft(2, '0')}.${_time!.minute.toString().padLeft(2, '0')}',
        () async {
          final t = await showTimePicker(
            context: context,
            initialTime: _time ?? const TimeOfDay(hour: 7, minute: 0),
            builder: (c, child) => Theme(data: _pickerTheme(c), child: MediaQuery(
              data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
              child: child!,
            )),
          );
          if (t != null) setState(() => _time = t);
        },
      );

  Future<void> _pickDate(BuildContext context, SubscriptionState sub) async {
    final now = DateTime.now();
    final last = (sub.upcoming ?? sub.current)!.endDate;
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: tanggalSaja(now),
      lastDate: last,
      helpText: 'Tanggal jemput',
      builder: (c, child) => Theme(data: _pickerTheme(c), child: child!),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _choosePlace(BuildContext context, List<Place> saved, {required bool isPickup}) async {
    final cubit = context.read<BookingCubit>();
    final choice = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: MoveraColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isPickup ? 'Titik jemput' : 'Tujuan', style: moveraText(size: 18, weight: FontWeight.w700)),
            const SizedBox(height: 14),
            for (final p in saved)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MoveraCard(
                  onTap: () => Navigator.pop(c, p),
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    const Icon(Icons.bookmark_rounded, color: MoveraColors.accent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.label, style: moveraText(weight: FontWeight.w600)),
                        Text(p.address, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: moveraText(size: 12, color: MoveraColors.textMuted)),
                      ]),
                    ),
                  ]),
                ),
              ),
            if (saved.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Belum ada alamat tersimpan.', style: moveraText(size: 13, color: MoveraColors.textMuted)),
              ),
            SecondaryButton(label: 'Pilih di peta', icon: Icons.map_rounded, onPressed: () => Navigator.pop(c, 'map')),
          ]),
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    Place? place;
    if (choice is Place) {
      place = choice;
    } else {
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(builder: (_) => LocationPickerPage(title: isPickup ? 'Titik Jemput' : 'Tujuan')),
      );
      if (result == null || !context.mounted) return;
      final ll = result['location'] as LatLng;
      place = Place(label: '', address: result['address'] as String, latitude: ll.latitude, longitude: ll.longitude);
      final label = await askPlaceLabel(context);
      if (label != null && label.isNotEmpty) {
        place = place.withLabel(label);
        await cubit.savePlace(place);
      }
    }
    setState(() {
      if (isPickup) {
        _pickup = place;
      } else {
        _destination = place;
      }
    });
  }

  String? _validate() {
    if (_pickup == null) return 'Pilih titik jemput.';
    if (_destination == null) return 'Pilih tujuan.';
    if (_pickup!.latitude == _destination!.latitude && _pickup!.longitude == _destination!.longitude) {
      return 'Titik jemput dan tujuan tidak boleh sama.';
    }
    if (_time == null) return 'Pilih jam jemput.';
    if (_type == BookingType.flexible && _date == null) return 'Pilih tanggal jemput.';
    if (_type == BookingType.routine && _weekdays.isEmpty) return 'Pilih minimal satu hari.';
    if (_passengerTotal < 1) return 'Pilih minimal satu penumpang.';
    return null;
  }

  List<String> _passengerNames(BuildContext context) {
    final auth = context.read<AuthBloc>().state.currentUser;
    final registered = context.read<BookingCubit>().state.passengers;
    return [
      if (_selfIncluded) auth?.fullName ?? 'Pemesan',
      for (final p in registered)
        if (_passengerIds.contains(p.id)) p.isChild ? '${p.name} (anak)' : p.name,
      if (_guests > 0) '$_guests penumpang lain',
    ];
  }

  Future<void> _submit(BuildContext context) async {
    final problem = _validate();
    if (problem != null) {
      showMoveraSnack(context, problem, error: true);
      return;
    }
    final request = BookingRequest(
      type: _type,
      rideMode: _mode,
      pickup: _pickup!,
      destination: _destination!,
      passengerCount: _passengerTotal,
      passengerNames: _passengerNames(context),
      maxDetourMinutes: _mode == RideMode.shared ? _detour : 0,
      note: _noteController.text.trim(),
      scheduledAt: _type == BookingType.flexible
          ? DateTime(_date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute)
          : null,
      weekdays: _weekdays.toList(),
      hour: _time!.hour,
      minute: _time!.minute,
    );
    setState(() => _busy = true);
    final bookingCubit = context.read<BookingCubit>();
    final subCubit = context.read<SubscriptionCubit>();
    try {
      final result = await bookingCubit.create(request);
      await subCubit.load();
      if (!context.mounted) return;
      if (_type == BookingType.flexible) {
        showMoveraSnack(context, 'Booking dibuat untuk ${formatJadwal(result.created.first.scheduledAt)}.');
        Navigator.pop(context);
      } else {
        await _showRoutineResult(context, result);
        if (context.mounted) Navigator.pop(context);
      }
    } on BookingException catch (e) {
      if (context.mounted) showMoveraSnack(context, e.message, error: true);
    } catch (e) {
      if (context.mounted) showMoveraSnack(context, 'Gagal membuat booking: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showRoutineResult(BuildContext context, BookingResult r) => showDialog(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: MoveraColors.card,
          title: Text('Jadwal rutin tersimpan', style: moveraText(size: 17, weight: FontWeight.w700)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r.created.length} booking dibuat untuk 7 hari ke depan.', style: moveraText(size: 13)),
            if (r.skipped.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Tidak dibuat:', style: moveraText(size: 13, weight: FontWeight.w600, color: MoveraColors.warning)),
              for (final s in r.skipped) Text('- $s', style: moveraText(size: 12, color: MoveraColors.textMuted, height: 1.5)),
            ],
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Oke'))],
        ),
      );
}
