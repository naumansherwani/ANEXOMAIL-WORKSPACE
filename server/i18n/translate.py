#!/usr/bin/env python3
"""
ANEXOMAIL — offline translation builder (Argos Translate, koi bahar ka API nahi).

Kaam:
  1. `src/i18n/en.json` (English source) padhta hai.
  2. Har target zubaan ke liye Argos ka language package install/load karta hai.
  3. Sirf woh strings translate karta hai jo pehle se bundle mein nahi hain
     (incremental — dobara chalane par sasta).
  4. Brand naam (ANEXOMAIL, ANEXOChat, ANEXOVideoCall, LEO, NEXATECT, Polar)
     translate NAHI hote — placeholder se protect kiye jate hain.
  5. Jis zubaan ka Argos package maujood na ho, us key ko chhod deta hai —
     website wahan asli English dikhayegi (dummy text kabhi nahi).

Chalao (server par, /opt/anexomail-web se):
    python3 server/i18n/translate.py                 # sab zubaanein
    python3 server/i18n/translate.py ur ar es        # sirf yeh zubaanein
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

from argostranslate import package, translate

ROOT = Path(__file__).resolve().parents[2]
I18N = ROOT / "src" / "i18n"
SOURCE = I18N / "en.json"

# BCP-47 tag  ->  Argos language code
TARGETS: dict[str, str] = {
    "hi-IN": "hi",
    "ur-PK": "ur",
    "ar-SA": "ar",
    "es-ES": "es",
    "fr-FR": "fr",
    "de-DE": "de",
    "de-CH": "de",
    "pt-BR": "pt",
    "zh-CN": "zh",
    "ja-JP": "ja",
    "ko-KR": "ko",
    "tr-TR": "tr",
    "it-IT": "it",
    "ro-RO": "ro",
    "ru-RU": "ru",
    "nl-NL": "nl",
    "pl-PL": "pl",
    "uk-UA": "uk",
    "id-ID": "id",
    "ms-MY": "ms",
    "vi-VN": "vi",
    "th-TH": "th",
    "bn-BD": "bn",
    "pa-IN": "pa",
    "fa-IR": "fa",
    "he-IL": "he",
    "el-GR": "el",
    "sv-SE": "sv",
    "sw-KE": "sw",
}

BRANDS = [
    "ANEXOMAIL Workspace",
    "ANEXOVideoCall",
    "ANEXOMAIL",
    "ANEXOChat",
    "NEXATECT",
    "Business Pro",
    "Polar",
    "LEO",
    "Leo",
]


def protect(text: str) -> tuple[str, dict[str, str]]:
    """Brand naam ko token se badal do taake engine unhein na chhede."""
    tokens: dict[str, str] = {}
    out = text
    for i, brand in enumerate(BRANDS):
        if brand in out:
            token = f"XQ{i}QX"
            tokens[token] = brand
            out = out.replace(brand, token)
    return out, tokens


def restore(text: str, tokens: dict[str, str]) -> str:
    out = text
    for token, brand in tokens.items():
        out = re.sub(re.escape(token), brand, out, flags=re.IGNORECASE)
    return out


def ensure_packages() -> None:
    print("Argos package index update…")
    package.update_package_index()


def install_for(code: str) -> bool:
    available = package.get_available_packages()
    match = next((p for p in available if p.from_code == "en" and p.to_code == code), None)
    if match is None:
        return False
    installed = {(p.from_code, p.to_code) for p in package.get_installed_packages()}
    if ("en", code) not in installed:
        print(f"  installing en -> {code}…")
        package.install_from_path(match.download())
    return True


def engine_for(code: str):
    langs = {l.code: l for l in translate.get_installed_languages()}
    src, dst = langs.get("en"), langs.get(code)
    if src is None or dst is None:
        return None
    return src.get_translation(dst)


def build(tag: str, code: str, source: dict[str, str]) -> None:
    out_path = I18N / f"{tag}.json"
    bundle: dict[str, str] = {}
    if out_path.exists():
        bundle = json.loads(out_path.read_text(encoding="utf-8"))

    if not install_for(code):
        print(f"{tag}: Argos package (en -> {code}) maujood nahi — English rahegi")
        return
    engine = engine_for(code)
    if engine is None:
        print(f"{tag}: engine load nahi hui — English rahegi")
        return

    pending = [k for k in source if k not in bundle]
    if not pending:
        print(f"{tag}: pehle se poora ({len(bundle)} strings)")
        return

    print(f"{tag}: {len(pending)} nayi strings translate ho rahi hain…")
    for key in pending:
        safe, tokens = protect(key)
        try:
            translated = engine.translate(safe)
        except Exception as err:  # noqa: BLE001 — ek string fail ho to baqi chalti rahein
            print(f"  skip: {key[:40]!r} ({err})")
            continue
        value = restore(translated, tokens).strip()
        if value:
            bundle[key] = value

    out_path.write_text(json.dumps(bundle, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{tag}: {len(bundle)}/{len(source)} strings likh di")


def main() -> int:
    if not SOURCE.exists():
        print("src/i18n/en.json nahi mili — pehle chalao: bun run i18n:extract")
        return 1
    source = json.loads(SOURCE.read_text(encoding="utf-8"))
    wanted = sys.argv[1:]
    ensure_packages()
    for tag, code in TARGETS.items():
        if wanted and tag not in wanted and code not in wanted:
            continue
        build(tag, code, source)
    print("done — ab: bun run build:bun && pm2 restart anexomail-web")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
