"""Turkish -> English localisation for Torpido.

Source strings in the code are Turkish and double as keys. This script
finds every user-facing literal, checks it has an English translation in
scripts/l10n_en.py, and writes App/Resources/{tr,en}.lproj/Localizable.strings.

    python3 scripts/l10n.py            # write files, list missing translations
    python3 scripts/l10n.py --audit    # also list literals that may be shown verbatim
"""
import glob
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SKIP = ("DesignCatalogView", "DebugLaunchState", "Theme.generated")
# Network protocol code: full of wire words (SOAP, SSDP, HTTP), so only
# literals in a localized context there count as copy.
WIRE = ("UPnPMessages", "DLNARenderer", "PlayerController+Cast")
LITERAL = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
TURKISH = r"[çğıöşüÇĞİÖŞÜ]"
# Contexts where SwiftUI or String(localized:) looks the literal up.
LOCALIZED_BEFORE = re.compile(
    r"(Text|Label|Button|navigationTitle|Section|TextField|SecureField|Toggle|LabeledContent|Picker|"
    r"accessibilityLabel|accessibilityHint|accessibilityValue|confirmationDialog|alert|"
    r"String\(localized:|LocalizedStringKey|title:|message:|actionTitle:|text:|value:|prompt:|hint:)\s*\(?\s*$")


# Literals that look like words but are code, headers, SQL or doc-comment examples.
NOT_COPY = {
    "MediaBrowser Client=", ", Device=", ", DeviceId=", ", Version=", ", Token=",
    "ParentIndexNumber,IndexNumber,SortName", "schema.sql is missing from the app bundle",
    "Torpido could not open its database: %@", "Expected a string or number", "init(coder:) is not used",
    "see all", " AND ", "search_name LIKE ? ESCAPE '!'", "İSTANBUL Çocuk  TV", "istanbul cocuk tv",
    "Kanalı", "Çocuk", "S2 · B5 · Bölüm adı", "%lld.circle.fill", "1 sa 32 dk · 1,2 GB",
    "1 sa 52 dk · 38 dk izlendi", "TORPİDO", "%@: %@",
    # JSON keys, HTTP headers, API paths, asset and item-type names
    "Night", "Content-Type", "Id", "Name", "Type", "Movie", "Episode", "Video", "Items", "Username", "Pw",
    "User", "Authorization", "Users/%@/Views", "Users/%@/Items", "Fields", "Sessions/Playing", "Range",
    "Videos", "Folder", "Series", "Season",
}


def looks_like_copy(text):
    if not text or text in NOT_COPY or to_key(text) in NOT_COPY:
        return False
    if text.startswith(("http", "#", "SELECT", "INSERT", "UPDATE", "DELETE", "CREATE", "DROP")):
        return False
    if "/" in text and " " not in text:
        return False  # API paths
    if re.fullmatch(r"[a-z0-9_.\-:/{}()\\]+", text) or re.fullmatch(r"[A-Za-z]+\.[A-Za-z.]+", text):
        return False  # identifiers, symbol names, keys, file names
    if re.fullmatch(r"[A-Z][A-Za-z]+[A-Z][A-Za-z]*", text) and not re.search(TURKISH, text):
        return False  # CamelCase type and protocol names
    has_words = re.search(r"[A-Za-zçğıöşüÇĞİÖŞÜ]{2,}", text)
    return bool(has_words) and (" " in text or bool(re.search(TURKISH, text)) or text[:1].isupper())


def to_key(text):
    """Swift interpolations become format specifiers, as Xcode does for keys."""
    def spec(m):
        inner = m.group(1)
        return "%lld" if re.search(r"(count|total|Ms|fps|number|index|needed|statusCode|PerSecond)", inner) else "%@"
    return re.sub(r"\\\(((?:[^()]|\([^()]*\))*)\)", spec, text)


def scan():
    found = {}
    for path in sorted(glob.glob(str(ROOT / "App/**/*.swift"), recursive=True)):
        if any(s in path for s in SKIP):
            continue
        src = pathlib.Path(path).read_text(encoding="utf-8")
        for m in LITERAL.finditer(src):
            text = m.group(1)
            if not looks_like_copy(text):
                continue
            before = src[max(0, m.start() - 60):m.start()]
            localized = bool(LOCALIZED_BEFORE.search(before))
            if not localized and any(w in path for w in WIRE):
                continue
            line = src.count("\n", 0, m.start()) + 1
            found.setdefault(to_key(text), []).append((pathlib.Path(path).relative_to(ROOT), line, localized))
    return found


def escape(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')


def main():
    sys.path.insert(0, str(ROOT / "scripts"))
    from l10n_en import EN
    found = scan()
    missing = [k for k in found if k not in EN]
    out = ROOT / "App/Resources"
    for lang, table in (("tr", {k: k for k in found}), ("en", {k: EN[k] for k in found if k in EN})):
        folder = out / f"{lang}.lproj"
        folder.mkdir(parents=True, exist_ok=True)
        lines = [f'"{escape(k)}" = "{escape(v)}";' for k, v in sorted(table.items())]
        (folder / "Localizable.strings").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"{len(found)} strings, {len(found) - len(missing)} translated, {len(missing)} missing")
    for k in missing:
        print("  MISSING:", k)
    if "--audit" in sys.argv:
        for k, places in sorted(found.items()):
            for path, line, localized in places:
                if not localized:
                    print(f"  VERBATIM? {path}:{line}  {k}")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
