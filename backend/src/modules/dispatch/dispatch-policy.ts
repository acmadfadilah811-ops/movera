/**
 * Aturan dispatch versi MVP dalam bentuk fungsi murni (blueprint bagian 11).
 * Jarak memakai haversine x faktor jalan; cukup untuk armada pilot 10-20 mobil.
 */

export interface Point {
  lat: number;
  lng: number;
}

const ROAD_FACTOR = 1.3;
const CITY_SPEED_KMH = 25;
const MINUTES_PER_STOP = 5;

export function haversineKm(a: Point, b: Point): number {
  const R = 6371;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

export interface BookingForTrip {
  id: string;
  pickup: Point;
  destination: Point;
  passengerCount: number;
  shared: boolean;
  maxDetourMinutes: number;
}

export interface PlannedStop {
  bookingId: string;
  type: 'PICKUP' | 'DROPOFF';
  point: Point;
}

/**
 * Urutan titik: semua jemput dulu (tetangga terdekat dari titik jemput pertama), lalu semua antar
 * (tetangga terdekat dari jemput terakhir). Heuristik sederhana sebelum VRPTW (blueprint 11.6).
 */
export function planStops(bookings: BookingForTrip[]): PlannedStop[] {
  const nearestOrder = (start: Point, items: { bookingId: string; point: Point }[]) => {
    const rest = [...items];
    const out: { bookingId: string; point: Point }[] = [];
    let cur = start;
    while (rest.length) {
      rest.sort((x, y) => haversineKm(cur, x.point) - haversineKm(cur, y.point));
      const next = rest.shift()!;
      out.push(next);
      cur = next.point;
    }
    return out;
  };
  const pickups = bookings.map((b) => ({ bookingId: b.id, point: b.pickup }));
  const orderedPickups = nearestOrder(pickups[0].point, pickups);
  const lastPickup = orderedPickups[orderedPickups.length - 1].point;
  const orderedDrops = nearestOrder(lastPickup, bookings.map((b) => ({ bookingId: b.id, point: b.destination })));
  return [
    ...orderedPickups.map((p) => ({ ...p, type: 'PICKUP' as const })),
    ...orderedDrops.map((p) => ({ ...p, type: 'DROPOFF' as const })),
  ];
}

export function routeKm(stops: { point: Point }[]): number {
  let km = 0;
  for (let i = 1; i < stops.length; i++) km += haversineKm(stops[i - 1].point, stops[i].point);
  return Math.round(km * ROAD_FACTOR * 10) / 10;
}

export function tripDurationMinutes(km: number, stopCount: number): number {
  return Math.ceil((km / CITY_SPEED_KMH) * 60 + stopCount * MINUTES_PER_STOP);
}

/** Tambahan waktu perjalanan per booking dibanding jika diantar sendiri (menit). */
export function detourMinutes(stops: PlannedStop[], booking: BookingForTrip): number {
  const iPick = stops.findIndex((s) => s.bookingId === booking.id && s.type === 'PICKUP');
  const iDrop = stops.findIndex((s) => s.bookingId === booking.id && s.type === 'DROPOFF');
  const shared = routeKm(stops.slice(iPick, iDrop + 1));
  const direct = Math.round(haversineKm(booking.pickup, booking.destination) * ROAD_FACTOR * 10) / 10;
  const extraStops = iDrop - iPick - 1;
  return Math.max(0, tripDurationMinutes(shared, extraStops) - tripDurationMinutes(direct, 0));
}

export interface TripCheck {
  ok: boolean;
  problems: string[];
}

/** Hard constraints penggabungan booking ke satu trip (blueprint 5.2, 11.2). */
export function checkTripBookings(bookings: BookingForTrip[], seats: number): TripCheck {
  const problems: string[] = [];
  if (bookings.length === 0) problems.push('Pilih minimal satu booking.');
  const passengers = bookings.reduce((n, b) => n + b.passengerCount, 0);
  if (passengers > seats) problems.push(`Penumpang ${passengers} melebihi kapasitas ${seats} kursi.`);
  if (bookings.length > 1) {
    const notShared = bookings.filter((b) => !b.shared);
    if (notShared.length) problems.push('Booking individual tidak boleh digabung dengan booking lain.');
    if (!notShared.length) {
      const stops = planStops(bookings);
      for (const b of bookings) {
        const d = detourMinutes(stops, b);
        if (d > b.maxDetourMinutes) problems.push(`Tambahan waktu ${d} menit melebihi batas ${b.maxDetourMinutes} menit untuk salah satu booking.`);
      }
    }
  }
  return { ok: problems.length === 0, problems };
}

export function overlaps(aStart: Date, aMinutes: number, bStart: Date, bMinutes: number): boolean {
  const aEnd = aStart.getTime() + aMinutes * 60_000;
  const bEnd = bStart.getTime() + bMinutes * 60_000;
  return aStart.getTime() < bEnd && bStart.getTime() < aEnd;
}

/** Baterai cukup jika sisa jarak tempuh minimal 1,5x jarak trip ditambah cadangan kembali ke pool. */
export function batteryEnough(batteryPercent: number, fullRangeKm: number, tripKm: number, reserveKm = 15): boolean {
  return (fullRangeKm * batteryPercent) / 100 >= tripKm * 1.5 + reserveKm;
}
