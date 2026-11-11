# BLUEPRINT APLIKASI TRANSPORTASI BERLANGGANAN

**Versi:** 1.1\
**Status:** Spesifikasi produk dan arsitektur acuan\
**Wilayah pilot:** Kabupaten Cilacap, Jawa Tengah\
**Model:** Managed Fleet Subscription Transportation Platform

------------------------------------------------------------------------

## 1. Ringkasan Eksekutif

Platform ini merupakan layanan transportasi antar-jemput berbasis
langganan bulanan. Perusahaan memiliki dan mengelola seluruh armada
mobil serta mempekerjakan driver internal. Pelanggan membeli paket di
awal periode dan menggunakan layanan berdasarkan kuota booking harian.

Sistem terdiri dari tiga aplikasi utama: 1. **Customer App** --- untuk
pelanggan melakukan langganan, mengatur jadwal, membuat booking, dan
melacak kendaraan. 2. **Driver App** --- untuk driver karyawan menerima
tugas, melihat manifest, melakukan navigasi, dan memperbarui status
perjalanan. 3. **Admin Dashboard** --- untuk mengelola pelanggan,
langganan, booking, dispatch, driver, armada, keuangan, dan operasional.

Model ini bukan marketplace driver mitra. Perusahaan bertanggung jawab
atas armada, tenaga kerja, kualitas layanan, dan pengendalian
perjalanan.

## 2. Keputusan Produk dan Operasional

  -----------------------------------------------------------------------
  Komponen                            Keputusan
  ----------------------------------- -----------------------------------
  Model bisnis                        Langganan transportasi

  Harga paket awal                    Rp300.000

  Masa aktif                          30 hari

  Pembayaran                          Sekali di awal periode

  Kuota                               Maksimal 4 booking per hari

  Armada                              Mobil milik perusahaan

  Driver                              Karyawan internal

  Model layanan                       Individual dan shared ride

  Jenis jadwal                        Rutin dan fleksibel

  Penugasan                           Otomatis dan manual

  Wilayah pilot                       Seluruh Kabupaten Cilacap

  Jumlah armada pilot                 10--20 mobil

  Layanan sekolah                     Antar dan jemput; tidak termasuk
                                      serah terima oleh driver
  -----------------------------------------------------------------------

### 2.1 Definisi booking dan kuota

Satu booking adalah satu permintaan perjalanan dari satu titik
penjemputan ke satu tujuan atau rangkaian tujuan yang didefinisikan
dalam kebijakan produk. Contoh: - Rumah → kantor = 1 booking. - Kantor →
rumah = 1 booking. - Rumah → sekolah = 1 booking. - Sekolah → rumah = 1
booking.

Kuota maksimum empat booking per tanggal operasional. Kuota harus
diperiksa dan dicadangkan secara atomik ketika booking dibuat. Kuota
difinalisasi sebagai terpakai ketika perjalanan memenuhi aturan
penyelesaian. Kebijakan pembatalan menentukan apakah reservasi
dikembalikan atau hangus.

**Catatan bisnis:** Empat booking per hari selama 30 hari berpotensi
mencapai 120 booking per pelanggan per bulan. Harga Rp300.000 harus
diuji melalui perhitungan biaya per kilometer, jarak layanan, sharing,
utilisasi armada, gaji, BBM, perawatan, dan depresiasi. Jangan
menjanjikan perjalanan individual tanpa batas jarak pada harga tersebut
sebelum analisis unit economics selesai.

## 3. Visi, Tujuan, dan Pengguna

### 3.1 Visi

Menyediakan layanan antar-jemput harian yang terjadwal, dapat
diandalkan, dan mudah dipantau dengan model pembayaran berlangganan.

### 3.2 Tujuan produk

-   Mempermudah pelanggan mengatur perjalanan rutin dan fleksibel.
-   Menyediakan transparansi status perjalanan melalui aplikasi.
-   Meningkatkan utilisasi armada milik perusahaan.
-   Mengelola jadwal driver dan kendaraan secara terpusat.
-   Menggabungkan booking yang kompatibel tanpa mengabaikan preferensi
    pelanggan.
-   Menyediakan pengawasan keselamatan dan audit operasional.

### 3.3 Segmen pengguna

-   **Pekerja:** perjalanan rumah--kantor, pabrik, toko, dan tempat
    kerja lainnya.
-   **Pelajar dan orang tua:** antar-jemput sekolah dengan notifikasi
    kepada wali.
-   **Keluarga/masyarakat umum:** kebutuhan mobilitas harian sesuai
    cakupan layanan.

## 4. Ruang Lingkup Aplikasi

### 4.1 Customer App

  Modul             Fitur
  ----------------- ------------------------------------------------
  Authentication    Registrasi, login, OTP, pemulihan akun
  Profile           Identitas, nomor kontak, foto
  Address Book      Alamat rumah, kantor, sekolah, alamat favorit
  Subscription      Daftar paket, pembelian, status langganan
  Quota             Kuota harian, reservasi, penggunaan, riwayat
  Booking           Booking fleksibel dan booking rutin
  Passenger         Data penumpang dan profil anak/dependen
  Ride Preference   Individual atau bersedia berbagi
  Tracking          Posisi kendaraan dan status perjalanan
  Trip History      Riwayat dan detail perjalanan
  Notification      Pengingat jadwal, penugasan, status perjalanan
  Support           Bantuan, komplain, pelaporan masalah

### 4.2 Driver App

  Modul                 Fitur
  --------------------- ------------------------------------------------
  Authentication        Login karyawan
  Work Schedule         Shift, kehadiran, waktu istirahat
  Availability          Status tersedia/tidak tersedia
  Task Management       Daftar tugas dan detail penugasan
  Trip Manifest         Penumpang, urutan pickup/drop-off, catatan
  Navigation            Navigasi ke titik berikutnya
  GPS Tracking          Pengiriman lokasi saat bertugas
  Pickup Verification   PIN/OTP atau metode verifikasi aman
  Trip Status           Tiba, penumpang naik, perjalanan mulai/selesai
  Vehicle Inspection    Checklist kendaraan sebelum/sesudah shift
  Incident Report       Laporan insiden, kerusakan, keadaan darurat
  History               Riwayat perjalanan dan tugas

### 4.3 Admin Dashboard

  Modul                     Fitur
  ------------------------- ---------------------------------------
  Overview                  Statistik dan ringkasan operasional
  Customer Management       Data pelanggan dan status akun
  Subscription Management   Paket, langganan, masa aktif
  Booking Management        Daftar dan detail booking
  Dispatch Center           Penugasan otomatis dan manual
  Fleet Management          Kendaraan, dokumen, status, kapasitas
  Driver Management         Data karyawan, SIM, status kerja
  Shift Management          Jadwal kerja dan ketersediaan
  Live Fleet Tracking       Peta kendaraan aktif
  Route Management          Rute dan titik pemberhentian
  Maintenance               Jadwal servis dan riwayat perawatan
  Payment Management        Pembayaran, refund, invoice
  Finance Reports           Pendapatan dan biaya
  Complaint Center          Pengaduan dan tindak lanjut
  Audit & Settings          Hak akses, konfigurasi, log aktivitas

### 4.4 Role internal

-   `SUPER_ADMIN`: konfigurasi dan akses penuh.
-   `OPERATIONS_ADMIN`: booking, dispatch, perjalanan.
-   `FLEET_ADMIN`: kendaraan, dokumen, perawatan.
-   `FINANCE_ADMIN`: pembayaran, refund, laporan keuangan.
-   `CUSTOMER_SUPPORT`: pelanggan dan komplain.
-   `CUSTOMER`: langganan dan booking miliknya.
-   `DRIVER`: tugas dan perjalanan yang ditugaskan.

## 5. Model Layanan dan Armada

### 5.1 Individual ride

Satu kendaraan ditugaskan untuk satu booking atau satu kelompok
penumpang yang memang memesan bersama. Sistem tidak boleh menambahkan
penumpang dari booking lain ke perjalanan individual.

### 5.2 Shared ride

Beberapa booking dapat digabungkan dalam satu trip apabila: - Setiap
pelanggan menyetujui shared ride. - Kapasitas kursi dan kebutuhan
penumpang terpenuhi. - Waktu pickup dan drop-off masih sesuai. -
Tambahan waktu perjalanan berada dalam batas kebijakan. - Rute masih
layak dan aman. - Tidak ada konflik jadwal driver atau kendaraan.

### 5.3 Kapasitas kendaraan

Kapasitas harus berasal dari data kendaraan yang diverifikasi. Kursi
pengemudi tidak dihitung sebagai kursi penumpang. Pertimbangkan bagasi,
kursi anak, kebutuhan aksesibilitas, dan jumlah penumpang aktual. Sistem
tidak boleh melampaui kapasitas legal maupun kapasitas konfigurasi
kendaraan.

### 5.4 Fleet management

Data kendaraan minimal: - Nomor polisi, merek, model, tahun. - Jenis
kendaraan dan kapasitas penumpang. - Dokumen kendaraan dan masa
berlaku. - Status aktif, tersedia, ditugaskan, dalam perjalanan,
perawatan, atau tidak beroperasi. - Kilometer dan histori servis. -
Driver/shift yang menggunakan kendaraan. - Checklist kelayakan jalan dan
laporan insiden.

## 6. Wilayah Operasional

Cakupan produk direncanakan untuk seluruh Kabupaten Cilacap. Untuk
mengelola armada 10--20 mobil, gunakan zona operasional yang dapat
dikonfigurasi oleh admin.

Contoh kelompok zona awal: 1. Cilacap Kota. 2. Kesugihan dan sekitarnya.
3. Maos, Sampang, Kroya. 4. Adipala, Binangun, Nusawungu. 5. Jeruklegi,
Kawunganten, Bantarsari. 6. Sidareja, Gandrungmangu, Cipari. 7.
Majenang, Cimanggu, Wanareja. 8. Dayeuhluhur, Karangpucung dan wilayah
barat.

Pembagian tersebut adalah pengelompokan perencanaan, bukan batas
administratif resmi. Batas poligon harus ditetapkan berdasarkan data
geospasial yang valid.

Cakupan seluruh kabupaten tidak otomatis berarti semua lokasi dilayani
setiap saat. Admin perlu mengatur jam layanan, zona aktif, jarak
maksimum, waktu tempuh, dan ketersediaan armada.

## 7. User Journey

### 7.1 Pembelian langganan

1.  Pelanggan membuat akun dan memverifikasi nomor kontak.
2.  Pelanggan melengkapi profil dan alamat.
3.  Pelanggan memilih paket.
4.  Backend membuat transaksi pembayaran.
5.  Payment gateway mengirim webhook.
6.  Backend memverifikasi signature, nominal, dan status transaksi.
7.  Langganan diaktifkan setelah pembayaran terverifikasi.
8.  Sistem menyediakan kuota sesuai tanggal masa aktif.

### 7.2 Booking rutin

1.  Pelanggan menentukan alamat jemput dan tujuan.
2.  Pelanggan memilih hari aktif dan jam perjalanan.
3.  Pelanggan mengatur preferensi individual/shared.
4.  Sistem menyimpan recurring schedule.
5.  Sistem membuat instance booking untuk tanggal yang relevan sesuai
    jendela pembuatan booking.
6.  Setiap instance divalidasi terhadap langganan, kuota, zona, dan
    kapasitas.
7.  Booking masuk ke dispatch.

Jadwal rutin tidak boleh langsung mengurangi seluruh kuota masa depan.
Kuota dicadangkan per tanggal sesuai kebijakan booking.

### 7.3 Booking fleksibel

1.  Pelanggan memilih tanggal dan waktu.
2.  Pelanggan memilih pickup dan tujuan.
3.  Pelanggan memilih jumlah penumpang dan preferensi ride.
4.  Backend memvalidasi langganan, kuota, waktu, dan zona.
5.  Sistem mencadangkan kuota.
6.  Booking masuk ke dispatch.
7.  Pelanggan menerima status booking.

### 7.4 Perjalanan

1.  Driver login dan memulai shift.
2.  Driver melakukan checklist kendaraan.
3.  Sistem menampilkan trip manifest.
4.  Driver menuju titik pickup.
5.  Driver melakukan verifikasi penumpang.
6.  Status perjalanan diperbarui.
7.  Driver mengikuti urutan stop.
8.  Penumpang turun dan status drop-off dikonfirmasi.
9.  Trip diselesaikan.
10. Backend memfinalisasi penggunaan kuota dan menyimpan audit trail.

## 8. Aturan Bisnis

### 8.1 Langganan

-   Langganan aktif hanya setelah pembayaran terverifikasi.
-   Masa aktif menggunakan tanggal mulai dan tanggal akhir yang
    eksplisit.
-   Semua perhitungan tanggal menggunakan zona waktu `Asia/Jakarta`.
-   Booking baru ditolak jika langganan tidak aktif atau telah
    kedaluwarsa.
-   Perpanjangan dan perubahan paket mengikuti kebijakan yang dapat
    dikonfigurasi.

### 8.2 Kuota

Setiap catatan kuota harian memiliki: - `total`: kuota maksimum. -
`reserved`: kuota yang dicadangkan booking. - `consumed`: kuota yang
sudah digunakan.

Rumus: `remaining = total - reserved - consumed`

Aturan: - Kuota default paket awal adalah 4 per tanggal. - Reservasi
kuota dilakukan dalam transaksi database. - Kuota tidak boleh negatif
atau melebihi total. - Penyelesaian trip memindahkan reservasi menjadi
konsumsi. - Pembatalan mengikuti aturan cutoff dan alasan pembatalan. -
Pembatalan oleh perusahaan atau kegagalan penyediaan layanan harus
memiliki aturan pengembalian kuota yang jelas. - Semua perubahan dicatat
di `quota_transactions`.

### 8.3 Pembatalan dan no-show

Kebijakan harus dapat dikonfigurasi, minimal membedakan: - Pembatalan
sebelum batas waktu. - Pembatalan setelah batas waktu. - Driver
membatalkan. - Perusahaan tidak dapat menyediakan kendaraan. - Pelanggan
tidak hadir. - Keadaan darurat atau force majeure.

Jangan menghapus booking yang dibatalkan. Simpan status, alasan, aktor,
waktu, dan dampak kuotanya.

### 8.4 Dispatch

-   Hanya driver aktif dan sedang dalam shift yang dapat ditugaskan.
-   SIM dan dokumen terkait harus masih berlaku.
-   Kendaraan harus aktif dan layak jalan.
-   Driver dan kendaraan tidak boleh memiliki konflik waktu.
-   Kapasitas kendaraan tidak boleh terlampaui.
-   Shared ride harus disetujui oleh pelanggan terkait.
-   Admin dapat mengambil alih penugasan dan setiap perubahan dicatat.

## 9. Database Design / ERD

### 9.1 Domain dan tabel

  -----------------------------------------------------------------------
  Domain                              Tabel
  ----------------------------------- -----------------------------------
  Identity                            users, roles, permissions,
                                      user_roles

  Customer                            customers, customer_addresses,
                                      customer_dependents,
                                      authorized_contacts

  Subscription                        subscription_plans, subscriptions,
                                      daily_quotas, quota_transactions

  Payment                             payments, refunds, invoices,
                                      webhook_events

  Booking                             bookings, booking_stops,
                                      recurring_schedules,
                                      booking_recurrences

  Fleet                               vehicles, vehicle_documents,
                                      vehicle_maintenance,
                                      vehicle_assignments

  Workforce                           drivers, employees, driver_shifts,
                                      driver_attendance

  Dispatch                            dispatch_jobs, dispatch_candidates,
                                      trips, trip_bookings

  Tracking                            trip_stops, trip_status_logs,
                                      driver_locations

  Operations                          service_zones, operating_hours,
                                      complaints, notifications,
                                      audit_logs
  -----------------------------------------------------------------------

### 9.2 Relasi utama

-   `users` memiliki profil `customers`, `drivers`, atau `employees`.
-   `customers` memiliki banyak `subscriptions`.
-   `subscription_plans` menjadi template untuk banyak `subscriptions`.
-   `subscriptions` memiliki banyak `daily_quotas`.
-   `daily_quotas` memiliki banyak `quota_transactions`.
-   `customers` membuat banyak `bookings`.
-   `subscriptions` mengotorisasi booking pelanggan.
-   `recurring_schedules` menghasilkan booking.
-   `bookings` memiliki beberapa `booking_stops`.
-   `trips` mengelompokkan booking melalui `trip_bookings`.
-   `trips` memiliki satu driver dan satu kendaraan.
-   `trips` memiliki banyak `trip_stops`, `trip_status_logs`, dan
    catatan lokasi.
-   `service_zones` mengelompokkan area operasional.

### 9.3 ERD Mermaid

``` mermaid
erDiagram
    USERS ||--o| CUSTOMERS : has
    USERS ||--o| DRIVERS : has
    USERS ||--o| EMPLOYEES : has

    CUSTOMERS ||--o{ SUBSCRIPTIONS : owns
    SUBSCRIPTION_PLANS ||--o{ SUBSCRIPTIONS : defines
    SUBSCRIPTIONS ||--o{ DAILY_QUOTAS : generates
    DAILY_QUOTAS ||--o{ QUOTA_TRANSACTIONS : records

    CUSTOMERS ||--o{ BOOKINGS : creates
    SUBSCRIPTIONS ||--o{ BOOKINGS : authorizes
    RECURRING_SCHEDULES ||--o{ BOOKINGS : generates
    BOOKINGS ||--o{ BOOKING_STOPS : contains

    TRIPS ||--o{ TRIP_BOOKINGS : groups
    BOOKINGS ||--o| TRIP_BOOKINGS : assigned
    DRIVERS ||--o{ TRIPS : operates
    VEHICLES ||--o{ TRIPS : uses

    TRIPS ||--o{ TRIP_STOPS : contains
    TRIPS ||--o{ TRIP_STATUS_LOGS : records
    TRIPS ||--o{ DRIVER_LOCATIONS : tracks

    DRIVERS ||--o{ DRIVER_SHIFTS : works
    SERVICE_ZONES ||--o{ BOOKINGS : covers
    SERVICE_ZONES ||--o{ VEHICLES : allocates
```

### 9.4 Kolom penting

  -----------------------------------------------------------------------
  Tabel                               Kolom penting
  ----------------------------------- -----------------------------------
  users                               id, name, email, phone,
                                      password_hash, status

  customers                           id, user_id, customer_type

  drivers                             id, user_id, employee_code,
                                      license_number, employment_status

  subscription_plans                  id, name, price, duration_days,
                                      daily_quota, is_active

  subscriptions                       id, customer_id, plan_id,
                                      start_date, end_date, status

  daily_quotas                        id, subscription_id, quota_date,
                                      total, reserved, consumed

  quota_transactions                  id, daily_quota_id, booking_id,
                                      action, quantity

  bookings                            id, customer_id, subscription_id,
                                      scheduled_at, booking_type,
                                      ride_mode, status

  booking_stops                       id, booking_id, stop_type,
                                      sequence, location

  recurring_schedules                 id, customer_id, weekdays,
                                      start_time, end_time, is_active

  vehicles                            id, plate_number, vehicle_type,
                                      capacity, status

  driver_shifts                       id, driver_id, starts_at, ends_at,
                                      status

  trips                               id, driver_id, vehicle_id, status,
                                      started_at, completed_at

  trip_bookings                       id, trip_id, booking_id,
                                      pickup_sequence, dropoff_sequence

  trip_stops                          id, trip_id, sequence_number,
                                      stop_type, location

  driver_locations                    id, driver_id, trip_id, location,
                                      recorded_at

  service_zones                       id, name, boundary, is_active
  -----------------------------------------------------------------------

### 9.5 Constraint penting

-   Unique `(subscription_id, quota_date)` pada `daily_quotas`.
-   Unique `booking_id` pada `trip_bookings` agar booking tidak masuk
    dua trip.
-   Validasi `reserved + consumed <= total`.
-   Validasi kapasitas kendaraan.
-   Pencegahan konflik jadwal driver dan kendaraan dengan database
    constraint/transaksi locking.
-   Indeks geospasial GiST pada geometri zona dan lokasi yang relevan.
-   Foreign key dan status validation untuk semua entitas penting.

## 10. API Specification

### 10.1 Konvensi

-   Base path: `/api/v1`
-   Format: JSON
-   Authentication: Bearer access token dan refresh token
-   Realtime: Socket.IO
-   Dokumentasi: OpenAPI 3.1
-   Semua endpoint harus memiliki validasi input, otorisasi, rate limit
    yang sesuai, dan audit untuk operasi sensitif.

### 10.2 Authentication

  Method   Endpoint              Fungsi
  -------- --------------------- ----------------
  POST     `/auth/register`      Registrasi
  POST     `/auth/login`         Login
  POST     `/auth/logout`        Logout
  POST     `/auth/refresh`       Refresh token
  POST     `/auth/otp/request`   Meminta OTP
  POST     `/auth/otp/verify`    Verifikasi OTP
  GET      `/auth/me`            Profil akun

### 10.3 Subscription dan payment

  Method   Endpoint                     Fungsi
  -------- ---------------------------- --------------------------
  GET      `/plans`                     Daftar paket
  POST     `/subscriptions`             Membuat pembelian paket
  GET      `/subscriptions/current`     Langganan aktif
  GET      `/subscriptions/history`     Riwayat langganan
  GET      `/subscriptions/:id/quota`   Kuota langganan
  POST     `/payments/checkout`         Membuat pembayaran
  GET      `/payments/:id`              Detail pembayaran
  POST     `/webhooks/payment`          Callback payment gateway

Webhook wajib diverifikasi menggunakan signature/credential resmi
provider. Aktivasi langganan tidak boleh hanya bergantung pada redirect
dari halaman pembayaran.

### 10.4 Customer booking

  Method   Endpoint                     Fungsi
  -------- ---------------------------- ----------------------
  POST     `/bookings`                  Membuat booking
  GET      `/bookings`                  Daftar booking
  GET      `/bookings/:id`              Detail booking
  POST     `/bookings/:id/cancel`       Membatalkan booking
  POST     `/recurring-schedules`       Membuat jadwal rutin
  GET      `/recurring-schedules`       Daftar jadwal
  PATCH    `/recurring-schedules/:id`   Mengubah jadwal
  DELETE   `/recurring-schedules/:id`   Menonaktifkan jadwal
  GET      `/trips/:id/tracking`        Melihat tracking
  GET      `/trips/history`             Riwayat perjalanan

### 10.5 Driver

  Method   Endpoint                            Fungsi
  -------- ----------------------------------- -----------------------
  GET      `/driver/profile`                   Profil
  GET      `/driver/shifts`                    Jadwal shift
  POST     `/driver/availability`              Status ketersediaan
  GET      `/driver/tasks`                     Daftar tugas
  GET      `/driver/tasks/:id`                 Detail tugas
  POST     `/driver/tasks/:id/accept`          Konfirmasi tugas
  POST     `/driver/tasks/:id/reject`          Menolak dengan alasan
  POST     `/driver/trips/:id/pickup`          Konfirmasi pickup
  POST     `/driver/trips/:id/start`           Mulai trip
  POST     `/driver/trips/:id/complete`        Selesaikan trip
  POST     `/driver/location`                  Update lokasi
  POST     `/driver/vehicles/:id/inspection`   Checklist kendaraan
  POST     `/driver/incidents`                 Laporan insiden

### 10.6 Admin dan dispatch

  Method   Endpoint                      Fungsi
  -------- ----------------------------- ----------------------
  GET      `/admin/dashboard`            Statistik
  GET      `/admin/bookings`             Semua booking
  GET      `/admin/dispatch/queue`       Antrean dispatch
  POST     `/admin/dispatch/auto`        Menjalankan dispatch
  POST     `/admin/dispatch/manual`      Penugasan manual
  POST     `/admin/trips/:id/reassign`   Mengganti penugasan
  GET      `/admin/fleet`                Daftar armada
  POST     `/admin/fleet/vehicles`       Tambah kendaraan
  GET      `/admin/drivers`              Daftar driver
  GET      `/admin/live-tracking`        Monitoring armada
  GET      `/admin/service-zones`        Zona layanan
  GET      `/admin/reports/operations`   Laporan operasional
  GET      `/admin/reports/finance`      Laporan keuangan

### 10.7 Contoh request booking

``` json
{
  "booking_type": "flexible",
  "ride_mode": "shared",
  "scheduled_at": "2026-11-12T07:00:00+07:00",
  "passenger_count": 1,
  "pickup": {
    "address": "Cilacap Selatan",
    "latitude": -7.726,
    "longitude": 109.010
  },
  "destination": {
    "address": "Cilacap Tengah",
    "latitude": -7.728,
    "longitude": 109.015
  },
  "preferences": {
    "allow_shared_ride": true,
    "max_detour_minutes": 15
  }
}
```

### 10.8 Contoh respons

``` json
{
  "success": true,
  "data": {
    "booking_id": "uuid",
    "status": "pending_dispatch",
    "quota": {
      "total": 4,
      "reserved": 1,
      "consumed": 0,
      "remaining": 3
    }
  }
}
```

### 10.9 Socket.IO events

  Event                 Fungsi
  --------------------- ----------------------------
  `driver:location`     Update lokasi driver
  `booking:assigned`    Booking mendapat penugasan
  `booking:cancelled`   Booking dibatalkan
  `trip:started`        Perjalanan dimulai
  `trip:stop:arrived`   Tiba di titik perjalanan
  `trip:completed`      Perjalanan selesai
  `fleet:status`        Status armada berubah

Setiap koneksi dan subscription room harus diotorisasi. Customer hanya
boleh melihat perjalanan miliknya. Akses admin mengikuti role dan
cakupan tugas.

## 11. Dispatch Engine dan Algoritma Sharing

### 11.1 Prinsip dispatch

Gunakan hybrid dispatch: - Sistem mencari dan memberi rekomendasi
penugasan otomatis. - Sistem dapat melakukan auto-assignment berdasarkan
aturan yang disetujui. - Admin dapat melakukan penugasan manual atau
override. - Semua perubahan tercatat dalam audit log.

### 11.2 Hard constraints

Kandidat hanya layak jika: - Driver aktif dan sedang dalam shift. - SIM
dan dokumen wajib masih berlaku. - Kendaraan aktif dan layak jalan. -
Kendaraan tidak dalam perawatan. - Kapasitas kursi mencukupi. - Tidak
ada konflik jadwal. - Zona dan waktu layanan sesuai. - Ride mode dan
preferensi sharing sesuai. - Estimasi rute memenuhi batas detour dan
waktu tiba.

### 11.3 Scoring kandidat

Skor awal yang dapat diuji:

`Score = 0.35D + 0.25T + 0.20R + 0.10U + 0.10Z`

Keterangan: - `D`: kedekatan driver dengan pickup. - `T`: kesesuaian
jadwal. - `R`: efisiensi rute. - `U`: utilisasi kendaraan. - `Z`:
kesesuaian zona.

Setiap komponen dinormalisasi ke 0--100. Bobot harus dievaluasi
menggunakan data pilot, bukan dianggap bobot final yang terbukti
optimal.

### 11.4 Algoritma MVP

Gunakan insertion heuristic: 1. Ambil booking baru yang lolos validasi.
2. Ambil kandidat driver dan kendaraan yang tersedia. 3. Periksa hard
constraints. 4. Coba sisipkan pickup dan drop-off ke rute yang sudah
ada. 5. Hitung tambahan jarak dan waktu. 6. Periksa kapasitas, time
windows, dan detour. 7. Hitung skor kandidat. 8. Pilih kandidat terbaik
yang feasible. 9. Simpan assignment dalam transaksi atomik. 10. Jika
tidak ada kandidat, masukkan ke antrean admin.

### 11.5 Pseudocode

``` python
def dispatch_booking(booking):
    validate_subscription(booking.customer)
    reserve_daily_quota_atomically(booking)

    candidates = get_available_fleet(
        zone=booking.service_zone,
        time=booking.scheduled_at
    )

    eligible = []

    for vehicle in candidates:
        driver = get_available_driver(vehicle)

        if not driver.is_on_shift:
            continue
        if not driver.has_valid_license:
            continue
        if vehicle.is_in_maintenance:
            continue
        if has_schedule_conflict(driver, booking):
            continue
        if has_schedule_conflict(vehicle, booking):
            continue
        if not has_capacity(vehicle, booking):
            continue

        route = evaluate_route_insertion(
            vehicle.current_trip,
            booking
        )

        if not route.is_feasible:
            continue

        score = calculate_dispatch_score(
            driver, vehicle, route, booking
        )

        eligible.append((score, vehicle, driver, route))

    if not eligible:
        return enqueue_for_manual_dispatch(booking)

    best = max(eligible, key=lambda item: item[0])

    return assign_atomically(
        booking=booking,
        vehicle=best[1],
        driver=best[2],
        route=best[3]
    )
```

Implementasi produksi harus menangani race condition, idempotency,
retry, dan kegagalan assignment. Jika dispatch gagal setelah kuota
dicadangkan, sistem harus melakukan kompensasi atau melepas reservasi
sesuai aturan.

### 11.6 Tahap lanjutan

Setelah data perjalanan terkumpul, evaluasi penggunaan Vehicle Routing
Problem with Time Windows (VRPTW) untuk optimasi banyak kendaraan dan
banyak titik. Jangan memaksakan optimasi kompleks sebelum kualitas data
waktu tempuh, pickup, dan permintaan cukup baik.

## 12. GPS dan Realtime Tracking

### 12.1 Alur data

1.  Driver App membaca GPS ketika driver sedang bertugas.
2.  Aplikasi mengirim koordinat dan timestamp ke backend.
3.  Backend memvalidasi autentikasi, trip aktif, akurasi, dan urutan
    timestamp.
4.  Redis menyimpan lokasi terbaru.
5.  Socket.IO mengirim lokasi ke customer yang berhak dan admin.
6.  Histori lokasi disimpan sesuai kebijakan retensi.
7.  Ketika trip berakhir, pengiriman lokasi trip dihentikan.

Interval 3--5 detik dapat menjadi konfigurasi awal saat trip aktif,
tetapi harus diuji terhadap konsumsi baterai, jaringan, akurasi, dan
kebijakan background Android.

### 12.2 Keamanan lokasi

-   Lokasi tidak boleh dapat dilihat oleh pengguna yang tidak terkait.
-   Driver tidak boleh mengirim lokasi untuk trip yang bukan miliknya.
-   Customer hanya dapat melihat kendaraan pada trip yang sah.
-   Admin hanya dapat melihat data sesuai role.
-   Simpan audit akses lokasi sensitif.
-   Terapkan kebijakan retensi dan penghapusan data.

## 13. Rancangan Operasional

### 13.1 Struktur organisasi

-   Owner/Management.
-   Operations Manager.
-   Dispatcher.
-   Fleet Officer.
-   Finance/Admin.
-   Customer Support.
-   Driver karyawan.

Pada tahap pilot, satu orang dapat merangkap fungsi administratif,
tetapi hak akses dan tanggung jawab harus tetap dibedakan.

### 13.2 Shift

Contoh jam yang dapat dikonfigurasi: - Pagi: 05.00--10.00. - Siang:
10.00--15.00. - Sore: 15.00--20.00. - Malam: sesuai kebutuhan.

Jam tersebut adalah contoh perencanaan. Jadwal final harus mematuhi
ketentuan ketenagakerjaan, istirahat, dan keselamatan berkendara.

### 13.3 SOP driver

**Sebelum shift** - Check-in. - Verifikasi kendaraan. - Checklist ban,
rem, lampu, bahan bakar, kebersihan, dan dokumen. - Periksa manifest.

**Saat pickup** - Menuju lokasi. - Konfirmasi tiba. - Verifikasi
penumpang dengan PIN/OTP atau mekanisme yang ditetapkan. - Perbarui
status pickup.

**Saat perjalanan** - Ikuti rute dan urutan stop. - Tidak mengangkut
penumpang di luar manifest. - Laporkan keterlambatan, kerusakan, atau
insiden.

**Saat drop-off** - Konfirmasi penumpang turun. - Perbarui status. -
Catat insiden atau barang tertinggal.

**Akhir shift** - Check-out. - Pemeriksaan kendaraan. - Pengisian
laporan.

### 13.4 SOP khusus pelajar

Layanan yang dipilih adalah antar dan jemput, tanpa layanan serah terima
oleh driver. Karena penumpang dapat berupa anak, sistem dan SOP tetap
harus memiliki: - Persetujuan orang tua/wali. - Data kontak darurat. -
Identitas penumpang yang sesuai. - Notifikasi saat pickup dan
drop-off. - Instruksi jika anak tidak ditemukan. - Instruksi jika tidak
ada pihak yang menerima anak di tujuan. - Prosedur insiden dan eskalasi.

Jangan menganggap notifikasi GPS sebagai bukti serah terima. Ketentuan
siapa yang boleh menerima anak dan apa yang dilakukan jika tidak ada
penerima harus disepakati dengan wali sebelum layanan digunakan.

## 14. Keamanan, Privasi, dan Kepatuhan

  Area             Rekomendasi
  ---------------- ----------------------------------------------
  Authentication   Access token dan refresh token
  Authorization    RBAC dan ownership checks
  Password         Argon2id atau bcrypt dengan konfigurasi aman
  API              Validation, rate limiting, audit
  Payment          Verifikasi webhook dan idempotency
  GPS              Akses terbatas pada trip yang sah
  Database         Backup, encryption, least privilege
  Child data       Persetujuan wali dan akses terbatas
  Audit            Log perubahan data dan dispatch
  Privacy          Retensi dan penghapusan data

Perhatikan UU Perlindungan Data Pribadi Indonesia dan kewajiban lain
yang berlaku untuk penyelenggaraan layanan transportasi. Persyaratan
izin, asuransi, ketenagakerjaan, keselamatan kendaraan, dan perlindungan
anak perlu diverifikasi dengan pihak profesional dan instansi terkait
sebelum operasi komersial.

## 15. Teknologi dan Arsitektur Final

  Layer             Teknologi                  Fungsi
  ----------------- -------------------------- --------------------------
  Customer App      Flutter                    Android/iOS
  Driver App        Flutter                    Android
  Admin Dashboard   Next.js                    Web
  Backend           NestJS / Node.js           Business logic
  Database          PostgreSQL                 Data utama
  Geospatial        PostGIS                    Lokasi dan zona
  Cache             Redis                      Cache dan posisi terbaru
  Realtime          Socket.IO                  Tracking dan event
  Background Jobs   BullMQ                     Job terjadwal
  Maps              Google Maps Platform       Maps, routes, geocoding
  Payment           Midtrans atau Xendit       Pembayaran
  Push              Firebase Cloud Messaging   Notifikasi
  Deployment        Docker                     Packaging dan deployment
  API Docs          OpenAPI 3.1                Kontrak API

### 15.1 Arsitektur deployment

``` text
Customer App ─┐
Driver App ───┼── HTTPS / WebSocket ── Nginx / SSL
Admin Web ────┘                            |
                                          v
                                NestJS Modular Monolith
                                ├── REST API
                                ├── Socket.IO
                                ├── Background Worker
                                └── Dispatch Engine
                                      |
                         ┌────────────┴────────────┐
                         v                         v
                    PostgreSQL                  Redis
                    + PostGIS               Cache / Queue
                         |
                  Automated Backup

External:
- Google Maps Platform
- Payment Gateway
- Firebase Cloud Messaging
- Object Storage
- Monitoring / Error Tracking
```

Untuk pilot, gunakan satu application server dan database managed atau
server database terpisah. Redis dapat berjalan bersama aplikasi pada
tahap awal dengan persistence dan recovery yang benar. Siapkan staging
dan production terpisah.

### 15.2 Struktur repository

``` text
transport-platform/
├── apps/
│   ├── customer-app/
│   ├── driver-app/
│   └── admin-dashboard/
├── backend/
│   └── src/
│       ├── modules/
│       │   ├── auth/
│       │   ├── customers/
│       │   ├── subscriptions/
│       │   ├── quotas/
│       │   ├── bookings/
│       │   ├── recurring/
│       │   ├── dispatch/
│       │   ├── fleet/
│       │   ├── drivers/
│       │   ├── shifts/
│       │   ├── trips/
│       │   ├── tracking/
│       │   ├── payments/
│       │   ├── notifications/
│       │   ├── reports/
│       │   └── audit/
│       ├── common/
│       ├── config/
│       └── database/
├── packages/
│   ├── shared-types/
│   ├── api-contracts/
│   └── validation/
├── infrastructure/
│   ├── docker/
│   ├── nginx/
│   ├── monitoring/
│   └── backups/
├── docs/
│   ├── PRD.md
│   ├── ERD.md
│   ├── API.md
│   ├── DISPATCH.md
│   └── OPERATIONS.md
└── docker-compose.yml
```

## 16. Roadmap Pengembangan

Estimasi target perencanaan MVP: 12--16 minggu dengan tim kecil yang
kompeten dan penggunaan AI-assisted development. Estimasi harus
diperbarui setelah scope, tim, dan kesiapan integrasi dikonfirmasi.

  Fase                  Durasi target Deliverable
  ------------------- --------------- ---------------------------------
  Foundation                 2 minggu Repo, database, auth, RBAC
  Subscription               2 minggu Payment, subscription, quota
  Customer App               3 minggu Profil, booking, jadwal
  Driver App                 2 minggu Task, shift, GPS
  Admin Dashboard            2 minggu Fleet, customer, dispatch
  Sharing Engine             2 minggu Grouping dan route insertion
  Integration & QA           2 minggu End-to-end dan security testing
  Pilot Preparation          1 minggu Deployment, SOP, training

## 17. KPI dan Unit Economics

Dashboard harus mengukur: - Monthly Recurring Revenue (MRR). - Active
Subscriptions. - Renewal Rate. - Booking Completion Rate. - Cancellation
dan No-show Rate. - Driver Utilization. - Vehicle Utilization. - Average
Pickup Time. - Average Trip Duration. - Cost per Trip. - Cost per
Kilometer. - Revenue per Vehicle. - Empty Kilometer Ratio. - Customer
Retention. - Complaint Rate.

Keputusan harga harus didasarkan pada biaya aktual per kilometer, jumlah
booking, tingkat sharing, waktu tunggu, utilisasi armada, biaya tenaga
kerja, BBM, perawatan, asuransi, pajak, depresiasi, server, dan payment
gateway.

## 18. Testing dan Acceptance Criteria

Sebelum pilot, minimal uji: - Registrasi, login, dan kontrol akses. -
Pembayaran berhasil, gagal, pending, dan webhook duplikat. - Kuota
terakhir dipesan dua request bersamaan. - Booking rutin menghasilkan
instance yang benar. - Booking fleksibel dan pembatalan. - Dispatch
otomatis dan manual. - Konflik jadwal driver/kendaraan. - Sharing dengan
kapasitas dan batas detour. - GPS terputus dan tersambung kembali. -
Driver tidak hadir. - Kendaraan rusak saat bertugas. - Penumpang tidak
ditemukan. - Backup dan pemulihan database. - Hak akses lokasi dan data
anak.

### Definition of Done MVP

-   [ ] Authentication dan RBAC berjalan.
-   [ ] Payment gateway terverifikasi.
-   [ ] Subscription dan kuota harian berjalan.
-   [ ] Concurrent booking tidak menyebabkan kuota berlebih.
-   [ ] Booking rutin dan fleksibel berjalan.
-   [ ] Driver App dapat menerima dan menyelesaikan tugas.
-   [ ] GPS background tracking diuji pada perangkat nyata.
-   [ ] Admin dapat mengelola armada dan driver.
-   [ ] Dispatch otomatis dan manual berjalan.
-   [ ] Shared trip mematuhi kapasitas dan batas detour.
-   [ ] SOP pelajar tersedia.
-   [ ] Backup dan recovery diuji.
-   [ ] Security testing dasar selesai.
-   [ ] Simulasi operasional 10--20 kendaraan berhasil.

## 19. Keputusan yang Masih Perlu Divalidasi

Blueprint ini menetapkan arsitektur produk, tetapi beberapa parameter
komersial dan operasional belum boleh dianggap final:

1.  Batas jarak dan waktu layanan untuk paket Rp300.000.
2.  Apakah kuota booking dihitung per penumpang, per permintaan, atau
    per perjalanan gabungan. Rekomendasi awal dokumen ini: per
    booking/permintaan.
3.  Batas detour maksimum untuk shared ride.
4.  Jam operasional dan hari layanan.
5.  Kebijakan pembatalan, no-show, refund, dan pengembalian kuota.
6.  Kapasitas dan model mobil yang akan dibeli/digunakan.
7.  Jumlah driver, pola shift, dan hari istirahat.
8.  Kebijakan anak sekolah ketika tidak ada penerima di lokasi tujuan.
9.  Zona layanan yang benar-benar aktif pada saat pilot.
10. Kelayakan unit economics dan persyaratan perizinan.

## 20. Urutan Implementasi yang Direkomendasikan

1.  **Backend Foundation:** database migrations, authentication, RBAC,
    audit.
2.  **Subscription Engine:** payment, aktivasi, masa aktif, kuota.
3.  **Booking Engine:** flexible booking, recurring schedule,
    cancellation.
4.  **Fleet dan Workforce:** kendaraan, driver, shift, maintenance.
5.  **Dispatch Engine:** auto assignment, manual dispatch, sharing.
6.  **Admin Dashboard:** kontrol operasional dan laporan.
7.  **Customer dan Driver Apps:** integrasi API, GPS, notifikasi.
8.  **Pilot:** simulasi dan peluncuran terbatas di Cilacap.

------------------------------------------------------------------------

**Dokumen ini merupakan blueprint acuan produk dan arsitektur versi
1.1.** Dokumen ini belum menggantikan spesifikasi implementasi rinci,
migration SQL lengkap, kontrak OpenAPI final, analisis unit economics,
atau kajian perizinan dan keselamatan operasional.
