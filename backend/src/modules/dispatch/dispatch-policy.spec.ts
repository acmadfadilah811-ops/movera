import { batteryEnough, BookingForTrip, checkTripBookings, haversineKm, overlaps, planStops, routeKm, tripDurationMinutes } from './dispatch-policy';

const b = (id: string, pick: [number, number], drop: [number, number], opts: Partial<BookingForTrip> = {}): BookingForTrip => ({
  id,
  pickup: { lat: pick[0], lng: pick[1] },
  destination: { lat: drop[0], lng: drop[1] },
  passengerCount: 1,
  shared: true,
  maxDetourMinutes: 15,
  ...opts,
});

describe('dispatch policy', () => {
  it('haversine: 0,01 derajat lintang sekitar 1,1 km', () => {
    expect(haversineKm({ lat: -7.72, lng: 109 }, { lat: -7.73, lng: 109 })).toBeCloseTo(1.11, 1);
  });

  it('urutan titik: semua jemput dulu lalu antar, terdekat lebih dulu', () => {
    const stops = planStops([b('A', [-7.70, 109.00], [-7.75, 109.05]), b('B', [-7.705, 109.005], [-7.74, 109.04])]);
    expect(stops.map((s) => `${s.type[0]}${s.bookingId}`)).toEqual(['PA', 'PB', 'DB', 'DA']);
  });

  it('jarak dan durasi trip', () => {
    const stops = planStops([b('A', [-7.70, 109.00], [-7.72, 109.00])]);
    const km = routeKm(stops);
    expect(km).toBeCloseTo(2.9, 1);
    expect(tripDurationMinutes(km, stops.length)).toBe(17);
  });

  it('menolak kapasitas berlebih dan penggabungan booking individual', () => {
    expect(checkTripBookings([b('A', [0, 0], [0.01, 0], { passengerCount: 3 }), b('B', [0, 0], [0.01, 0], { passengerCount: 2 })], 4).ok).toBe(false);
    const r = checkTripBookings([b('A', [0, 0], [0.01, 0], { shared: false }), b('B', [0, 0], [0.01, 0])], 4);
    expect(r.problems.join(' ')).toContain('individual');
    expect(checkTripBookings([b('A', [0, 0], [0.01, 0], { shared: false })], 4).ok).toBe(true);
  });

  it('menolak penggabungan yang menambah waktu melebihi batas detour', () => {
    const far = [b('A', [-7.70, 109.00], [-7.71, 109.00], { maxDetourMinutes: 5 }), b('B', [-7.60, 109.10], [-7.61, 109.10])];
    expect(checkTripBookings(far, 4).ok).toBe(false);
  });

  it('bentrok jadwal dan kecukupan baterai', () => {
    const t = new Date('2026-11-12T00:00:00Z');
    expect(overlaps(t, 30, new Date(t.getTime() + 29 * 60_000), 30)).toBe(true);
    expect(overlaps(t, 30, new Date(t.getTime() + 30 * 60_000), 30)).toBe(false);
    expect(batteryEnough(10, 300, 10)).toBe(true); // 30 km >= 15 + 15
    expect(batteryEnough(9, 300, 10)).toBe(false);
  });
});
