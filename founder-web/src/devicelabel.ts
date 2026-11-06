/** The name shown in the device list, so the founder knows WHICH browser asks for approval. Order matters: the Chromium look-alikes (UC, Samsung, Opera, Edge, Vivaldi, Yandex) all also say "Chrome". Every browser works; each one is its own device and is approved once. */
export function browserName(ua: string): string {
  const t: Array<[RegExp, string]> = [[/UCBrowser\/|UBrowser\//, "UC Browser"], [/SamsungBrowser\//, "Samsung Internet"], [/OPR\/|OPT\/|OPiOS\/|Opera/, "Opera"], [/Edg(e|A|iOS)?\//, "Edge"], [/Vivaldi\//, "Vivaldi"], [/YaBrowser\//, "Yandex"], [/DuckDuckGo\//, "DuckDuckGo"], [/Firefox\/|FxiOS\//, "Firefox"], [/Chrome\/|CriOS\//, "Chrome"], [/Safari\//, "Safari"]];
  for (const [re, n] of t) if (re.test(ua || "")) return n;
  return "Browser";
}
