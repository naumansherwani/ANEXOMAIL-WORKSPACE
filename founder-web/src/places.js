// Home place: a bundled list of cities (name, country, time zone, centre) — no map service, no network. JS port of the user app's src/lib/places.ts (FC18: separate copy).
// "Detect my city" asks the browser for the position ONCE, picks the nearest city from this list ON THE DEVICE, and only that city is saved. The exact position is never sent or stored.
const ROWS = [
  // Pakistan
  ["Karachi", "Pakistan", "Asia/Karachi", 24.86, 67.01],
  ["Lahore", "Pakistan", "Asia/Karachi", 31.52, 74.36],
  ["Islamabad", "Pakistan", "Asia/Karachi", 33.69, 73.05],
  ["Rawalpindi", "Pakistan", "Asia/Karachi", 33.6, 73.04],
  ["Faisalabad", "Pakistan", "Asia/Karachi", 31.42, 73.08],
  ["Multan", "Pakistan", "Asia/Karachi", 30.2, 71.47],
  ["Peshawar", "Pakistan", "Asia/Karachi", 34.01, 71.58],
  ["Quetta", "Pakistan", "Asia/Karachi", 30.18, 66.98],
  ["Hyderabad", "Pakistan", "Asia/Karachi", 25.4, 68.37],
  ["Sialkot", "Pakistan", "Asia/Karachi", 32.49, 74.53],
  ["Gujranwala", "Pakistan", "Asia/Karachi", 32.16, 74.19],
  ["Sukkur", "Pakistan", "Asia/Karachi", 27.7, 68.86],
  ["Abbottabad", "Pakistan", "Asia/Karachi", 34.15, 73.22],
  // South Asia
  ["Delhi", "India", "Asia/Kolkata", 28.61, 77.21],
  ["Mumbai", "India", "Asia/Kolkata", 19.08, 72.88],
  ["Bengaluru", "India", "Asia/Kolkata", 12.97, 77.59],
  ["Kolkata", "India", "Asia/Kolkata", 22.57, 88.36],
  ["Chennai", "India", "Asia/Kolkata", 13.08, 80.27],
  ["Hyderabad", "India", "Asia/Kolkata", 17.39, 78.49],
  ["Ahmedabad", "India", "Asia/Kolkata", 23.02, 72.57],
  ["Dhaka", "Bangladesh", "Asia/Dhaka", 23.81, 90.41],
  ["Colombo", "Sri Lanka", "Asia/Colombo", 6.93, 79.86],
  ["Kathmandu", "Nepal", "Asia/Kathmandu", 27.72, 85.32],
  ["Kabul", "Afghanistan", "Asia/Kabul", 34.53, 69.17],
  ["Tashkent", "Uzbekistan", "Asia/Tashkent", 41.3, 69.24],
  // Middle East
  ["Dubai", "United Arab Emirates", "Asia/Dubai", 25.2, 55.27],
  ["Abu Dhabi", "United Arab Emirates", "Asia/Dubai", 24.45, 54.38],
  ["Riyadh", "Saudi Arabia", "Asia/Riyadh", 24.71, 46.68],
  ["Jeddah", "Saudi Arabia", "Asia/Riyadh", 21.54, 39.17],
  ["Makkah", "Saudi Arabia", "Asia/Riyadh", 21.39, 39.86],
  ["Doha", "Qatar", "Asia/Qatar", 25.29, 51.53],
  ["Kuwait City", "Kuwait", "Asia/Kuwait", 29.38, 47.99],
  ["Muscat", "Oman", "Asia/Muscat", 23.59, 58.41],
  ["Manama", "Bahrain", "Asia/Bahrain", 26.23, 50.59],
  ["Baghdad", "Iraq", "Asia/Baghdad", 33.31, 44.37],
  ["Tehran", "Iran", "Asia/Tehran", 35.69, 51.39],
  ["Tel Aviv", "Israel", "Asia/Jerusalem", 32.09, 34.78],
  ["Amman", "Jordan", "Asia/Amman", 31.95, 35.93],
  ["Beirut", "Lebanon", "Asia/Beirut", 33.89, 35.5],
  ["Istanbul", "Türkiye", "Europe/Istanbul", 41.01, 28.98],
  ["Ankara", "Türkiye", "Europe/Istanbul", 39.93, 32.86],
  // East and South-East Asia
  ["Singapore", "Singapore", "Asia/Singapore", 1.35, 103.82],
  ["Kuala Lumpur", "Malaysia", "Asia/Kuala_Lumpur", 3.14, 101.69],
  ["Jakarta", "Indonesia", "Asia/Jakarta", -6.21, 106.85],
  ["Bangkok", "Thailand", "Asia/Bangkok", 13.76, 100.5],
  ["Ho Chi Minh City", "Vietnam", "Asia/Ho_Chi_Minh", 10.82, 106.63],
  ["Manila", "Philippines", "Asia/Manila", 14.6, 120.98],
  ["Hong Kong", "Hong Kong", "Asia/Hong_Kong", 22.32, 114.17],
  ["Shanghai", "China", "Asia/Shanghai", 31.23, 121.47],
  ["Beijing", "China", "Asia/Shanghai", 39.9, 116.41],
  ["Shenzhen", "China", "Asia/Shanghai", 22.54, 114.06],
  ["Taipei", "Taiwan", "Asia/Taipei", 25.03, 121.57],
  ["Seoul", "South Korea", "Asia/Seoul", 37.57, 126.98],
  ["Tokyo", "Japan", "Asia/Tokyo", 35.68, 139.69],
  ["Osaka", "Japan", "Asia/Tokyo", 34.69, 135.5],
  // Europe
  ["London", "United Kingdom", "Europe/London", 51.51, -0.13],
  ["Manchester", "United Kingdom", "Europe/London", 53.48, -2.24],
  ["Birmingham", "United Kingdom", "Europe/London", 52.49, -1.89],
  ["Glasgow", "United Kingdom", "Europe/London", 55.86, -4.25],
  ["Dublin", "Ireland", "Europe/Dublin", 53.35, -6.26],
  ["Lisbon", "Portugal", "Europe/Lisbon", 38.72, -9.14],
  ["Madrid", "Spain", "Europe/Madrid", 40.42, -3.7],
  ["Barcelona", "Spain", "Europe/Madrid", 41.39, 2.17],
  ["Paris", "France", "Europe/Paris", 48.86, 2.35],
  ["Brussels", "Belgium", "Europe/Brussels", 50.85, 4.35],
  ["Amsterdam", "Netherlands", "Europe/Amsterdam", 52.37, 4.9],
  ["Berlin", "Germany", "Europe/Berlin", 52.52, 13.4],
  ["Munich", "Germany", "Europe/Berlin", 48.14, 11.58],
  ["Frankfurt", "Germany", "Europe/Berlin", 50.11, 8.68],
  ["Zurich", "Switzerland", "Europe/Zurich", 47.37, 8.54],
  ["Geneva", "Switzerland", "Europe/Zurich", 46.2, 6.14],
  ["Vienna", "Austria", "Europe/Vienna", 48.21, 16.37],
  ["Rome", "Italy", "Europe/Rome", 41.9, 12.5],
  ["Milan", "Italy", "Europe/Rome", 45.46, 9.19],
  ["Copenhagen", "Denmark", "Europe/Copenhagen", 55.68, 12.57],
  ["Stockholm", "Sweden", "Europe/Stockholm", 59.33, 18.07],
  ["Oslo", "Norway", "Europe/Oslo", 59.91, 10.75],
  ["Helsinki", "Finland", "Europe/Helsinki", 60.17, 24.94],
  ["Warsaw", "Poland", "Europe/Warsaw", 52.23, 21.01],
  ["Prague", "Czechia", "Europe/Prague", 50.08, 14.44],
  ["Budapest", "Hungary", "Europe/Budapest", 47.5, 19.04],
  ["Athens", "Greece", "Europe/Athens", 37.98, 23.73],
  ["Bucharest", "Romania", "Europe/Bucharest", 44.43, 26.1],
  ["Kyiv", "Ukraine", "Europe/Kyiv", 50.45, 30.52],
  ["Moscow", "Russia", "Europe/Moscow", 55.76, 37.62],
  // Africa
  ["Cairo", "Egypt", "Africa/Cairo", 30.04, 31.24],
  ["Lagos", "Nigeria", "Africa/Lagos", 6.52, 3.38],
  ["Nairobi", "Kenya", "Africa/Nairobi", -1.29, 36.82],
  ["Addis Ababa", "Ethiopia", "Africa/Addis_Ababa", 9.03, 38.74],
  ["Johannesburg", "South Africa", "Africa/Johannesburg", -26.2, 28.05],
  ["Cape Town", "South Africa", "Africa/Johannesburg", -33.92, 18.42],
  ["Casablanca", "Morocco", "Africa/Casablanca", 33.57, -7.59],
  ["Accra", "Ghana", "Africa/Accra", 5.6, -0.19],
  // Americas
  ["New York", "United States", "America/New_York", 40.71, -74.01],
  ["Washington", "United States", "America/New_York", 38.91, -77.04],
  ["Boston", "United States", "America/New_York", 42.36, -71.06],
  ["Miami", "United States", "America/New_York", 25.76, -80.19],
  ["Atlanta", "United States", "America/New_York", 33.75, -84.39],
  ["Chicago", "United States", "America/Chicago", 41.88, -87.63],
  ["Houston", "United States", "America/Chicago", 29.76, -95.37],
  ["Dallas", "United States", "America/Chicago", 32.78, -96.8],
  ["Denver", "United States", "America/Denver", 39.74, -104.99],
  ["Phoenix", "United States", "America/Phoenix", 33.45, -112.07],
  ["Los Angeles", "United States", "America/Los_Angeles", 34.05, -118.24],
  ["San Francisco", "United States", "America/Los_Angeles", 37.77, -122.42],
  ["Seattle", "United States", "America/Los_Angeles", 47.61, -122.33],
  ["Toronto", "Canada", "America/Toronto", 43.65, -79.38],
  ["Montréal", "Canada", "America/Toronto", 45.5, -73.57],
  ["Vancouver", "Canada", "America/Vancouver", 49.28, -123.12],
  ["Mexico City", "Mexico", "America/Mexico_City", 19.43, -99.13],
  ["Bogotá", "Colombia", "America/Bogota", 4.71, -74.07],
  ["Lima", "Peru", "America/Lima", -12.05, -77.04],
  ["São Paulo", "Brazil", "America/Sao_Paulo", -23.55, -46.63],
  ["Rio de Janeiro", "Brazil", "America/Sao_Paulo", -22.91, -43.17],
  ["Buenos Aires", "Argentina", "America/Argentina/Buenos_Aires", -34.6, -58.38],
  ["Santiago", "Chile", "America/Santiago", -33.45, -70.67],
  // Oceania
  ["Sydney", "Australia", "Australia/Sydney", -33.87, 151.21],
  ["Melbourne", "Australia", "Australia/Melbourne", -37.81, 144.96],
  ["Brisbane", "Australia", "Australia/Brisbane", -27.47, 153.03],
  ["Perth", "Australia", "Australia/Perth", -31.95, 115.86],
  ["Auckland", "New Zealand", "Pacific/Auckland", -36.85, 174.76],
];

export const PLACES = ROWS.map(([city, country, iana, lat, lon]) => ({
  city,
  country,
  iana,
  lat,
  lon,
}));

export const placeLabel = (p) =>
  p.country ? `${p.city}, ${p.country}` : p.city;

const rad = (d) => (d * Math.PI) / 180;

/** Great-circle distance in kilometres. */
export function distanceKm(aLat, aLon, bLat, bLon) {
  const dLat = rad(bLat - aLat);
  const dLon = rad(bLon - aLon);
  const h =
    Math.sin(dLat / 2) ** 2 + Math.cos(rad(aLat)) * Math.cos(rad(bLat)) * Math.sin(dLon / 2) ** 2;
  return 12742 * Math.asin(Math.min(1, Math.sqrt(h)));
}

/** The list's nearest city to a position, and how far it is. */
export function nearestPlace(lat, lon) {
  if (!Number.isFinite(lat) || !Number.isFinite(lon) || Math.abs(lat) > 90 || Math.abs(lon) > 180)
    return null;
  let best = null;
  for (const p of PLACES) {
    const km = distanceKm(lat, lon, p.lat, p.lon);
    if (!best || km < best.km) best = { place: p, km };
  }
  return best;
}

const fold = (s) => s.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();

/** Type-ahead: city names starting with the text first, then words inside, then country. Max 8. */
export function searchPlaces(query, limit = 8) {
  const q = fold(query.trim());
  if (!q) return [];
  const scored = [];
  for (const p of PLACES) {
    const c = fold(p.city);
    const k = fold(p.country);
    const score = c.startsWith(q)
      ? 0
      : c.split(" ").some((w) => w.startsWith(q))
        ? 1
        : c.includes(q)
          ? 2
          : k.startsWith(q)
            ? 3
            : -1;
    if (score >= 0) scored.push([score, p]);
  }
  return scored
    .sort((a, b) => a[0] - b[0] || a[1].city.localeCompare(b[1].city))
    .slice(0, limit)
    .map((x) => x[1]);
}

/** A city for a bare time zone ("Asia/Karachi" -> Karachi): the first city of the list in that zone. */
export function placeForZone(iana) {
  return PLACES.find((p) => p.iana === iana) ?? null;
}

/** Is `x` a well-formed saved place (what the server returns)? */
export function isPlace(x) {
  const p = x;
  return (
    !!p &&
    typeof p.city === "string" &&
    p.city.length > 0 &&
    typeof p.iana === "string" &&
    Number.isFinite(p.lat) &&
    Number.isFinite(p.lon)
  );
}
