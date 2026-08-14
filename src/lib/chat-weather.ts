/**
 * ANEXOChat — LIVE WEATHER (Open-Meteo only, locked 14 Aug 2026).
 *
 * FOUNDER LOCK:
 *   - SIRF Open-Meteo: koi API key nahi, koi registration nahi, koi cost nahi.
 *   - Location sirf user ki ijazat se (browser Geolocation). Ijazat nahi =
 *     koi weather claim nahi, sirf device clock ka time band.
 *   - Jo dikhaya jaye woh Open-Meteo ka asli jawab ho — guess kabhi nahi.
 *   - Doosra koi weather provider ya paid API kabhi nahi.
 */

export type LiveWeather = {
  effect: "rain" | "storm" | "snow" | "sunny" | "none";
  code: number;
  temperature_c: number;
  label: string;
  at: string;
};

/** Open-Meteo WMO weather_code -> honest bucket + label. */
export function decodeWeatherCode(code: number): { effect: LiveWeather["effect"]; label: string } {
  if (code === 0) return { effect: "sunny", label: "Clear" };
  if (code === 1 || code === 2) return { effect: "sunny", label: "Mainly clear" };
  if (code === 3) return { effect: "none", label: "Overcast" };
  if (code === 45 || code === 48) return { effect: "none", label: "Fog" };
  if (code >= 51 && code <= 57) return { effect: "rain", label: "Drizzle" };
  if (code >= 61 && code <= 67) return { effect: "rain", label: "Rain" };
  if (code >= 71 && code <= 77) return { effect: "snow", label: "Snow" };
  if (code >= 80 && code <= 82) return { effect: "rain", label: "Rain showers" };
  if (code === 85 || code === 86) return { effect: "snow", label: "Snow showers" };
  if (code >= 95 && code <= 99) return { effect: "storm", label: "Thunderstorm" };
  return { effect: "none", label: "Unknown condition" };
}

export function requestPosition(): Promise<{ lat: number; lon: number }> {
  return new Promise((resolve, reject) => {
    if (typeof navigator === "undefined" || !navigator.geolocation) {
      reject(new Error("Location not available on this device"));
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (pos) => resolve({ lat: pos.coords.latitude, lon: pos.coords.longitude }),
      (err) => reject(new Error(err.message || "Location permission denied")),
      { timeout: 10_000, maximumAge: 600_000 },
    );
  });
}

/** Open-Meteo current weather. Sirf asli jawab, warna throw. */
export async function fetchLiveWeather(lat: number, lon: number): Promise<LiveWeather> {
  const url =
    `https://api.open-meteo.com/v1/forecast?latitude=${lat.toFixed(3)}` +
    `&longitude=${lon.toFixed(3)}&current=weather_code,temperature_2m`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Open-Meteo unavailable (${res.status})`);
  const json = (await res.json()) as {
    current?: { weather_code?: number; temperature_2m?: number; time?: string };
  };
  const code = json.current?.weather_code;
  const temp = json.current?.temperature_2m;
  if (typeof code !== "number" || typeof temp !== "number") {
    throw new Error("Open-Meteo returned no current reading");
  }
  const decoded = decodeWeatherCode(code);
  return {
    effect: decoded.effect,
    code,
    temperature_c: temp,
    label: decoded.label,
    at: json.current?.time ?? new Date().toISOString(),
  };
}
