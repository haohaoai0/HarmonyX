"""Add localized frog choices, or apply the store's display name to a checkout."""
import argparse
import json
import re
from pathlib import Path


FROG_LABELS = {
    "base": ("小青蛙（白底）", "小青蛙（黑底）"),
    "zh_CN": ("小青蛙（白底）", "小青蛙（黑底）"),
    "zh_Hant": ("小青蛙（白底）", "小青蛙（黑底）"),
    "en": ("Blue frog · White", "Blue frog · Black"),
    "ar": ("ضفدع أزرق · أبيض", "ضفدع أزرق · أسود"),
    "de": ("Blauer Frosch · Weiß", "Blauer Frosch · Schwarz"),
    "es": ("Rana azul · Blanco", "Rana azul · Negro"),
    "fa": ("قورباغهٔ آبی · سفید", "قورباغهٔ آبی · سیاه"),
    "fr": ("Grenouille bleue · Blanc", "Grenouille bleue · Noir"),
    "hi": ("नीला मेंढक · सफ़ेद", "नीला मेंढक · काला"),
    "id": ("Katak biru · Putih", "Katak biru · Hitam"),
    "it": ("Rana blu · Bianco", "Rana blu · Nero"),
    "ja": ("青いカエル（白背景）", "青いカエル（黒背景）"),
    "ko": ("파란 개구리 · 흰 배경", "파란 개구리 · 검은 배경"),
    "ms": ("Katak biru · Putih", "Katak biru · Hitam"),
    "pt": ("Sapo azul · Branco", "Sapo azul · Preto"),
    "ru": ("Синяя лягушка · Белый", "Синяя лягушка · Чёрный"),
    "th": ("กบสีฟ้า · พื้นขาว", "กบสีฟ้า · พื้นดำ"),
    "tr": ("Mavi kurbağa · Beyaz", "Mavi kurbağa · Siyah"),
    "uk": ("Синя жабка · Білий", "Синя жабка · Чорний"),
    "vi": ("Ếch xanh · Trắng", "Ếch xanh · Đen"),
}
STORE_NAME = "Croak X"
STORE_BUNDLE_NAME = "com.haohaoai0.CroakX"
RESOURCE_VALUE = re.compile(
    r'("name"\s*:\s*"([^"\\]+)"\s*,\s*"value"\s*:\s*)("(?:\\.|[^"\\])*")'
)


def add_frog_labels(path: Path) -> None:
    with path.open(encoding="utf-8-sig", newline="") as stream:
        text = stream.read()
    data = json.loads(text)
    locale = path.parent.parent.name
    labels = FROG_LABELS[locale]
    names = {item["name"] for item in data["string"]}
    additions = []
    for suffix, label in zip(("white", "black"), labels):
        name = f"settings_app_icon_frog_{suffix}"
        if name not in names:
            additions.append({"name": name, "value": label})
    if not additions:
        return
    newline = "\r\n" if "\r\n" in text else "\n"
    index = text.rfind("]")
    entries = ["\n".join("    " + line for line in json.dumps(item, ensure_ascii=False, indent=2).splitlines())
               for item in additions]
    insertion = (",\n" + ",\n".join(entries) + "\n  ").replace("\n", newline)
    result = text[:index].rstrip() + insertion + text[index:]
    json.loads(result)
    with path.open("w", encoding="utf-8", newline="") as stream:
        stream.write(result)


def rebrand(path: Path) -> None:
    with path.open(encoding="utf-8-sig", newline="") as stream:
        text = stream.read()

    def replace_value(match: re.Match) -> str:
        key = match.group(2)
        value = json.loads(match.group(3))
        # This describes the existing physical download directory, not the brand.
        if key == "storage_path_note":
            return match.group(0)
        updated = re.sub(r"Harmony X|HarmonyX|HarmonX|呱友X", STORE_NAME, value)
        if key in ("app_name", "EntryAbility_label", "ShareReceiverAbility_label"):
            updated = STORE_NAME
        if updated == value:
            return match.group(0)
        return match.group(1) + json.dumps(updated, ensure_ascii=False)

    result = RESOURCE_VALUE.sub(replace_value, text)
    json.loads(result)
    with path.open("w", encoding="utf-8", newline="") as stream:
        stream.write(result)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--store", action="store_true")
    args = parser.parse_args()
    locales = sorted((args.project / "entry/src/main/resources").glob("*/element/string.json"))
    for path in locales:
        add_frog_labels(path)
    if args.store:
        for path in locales:
            rebrand(path)
        for path in (args.project / "AppScope/resources").glob("*/element/string.json"):
            rebrand(path)
        app_config = args.project / "AppScope/app.json5"
        text = app_config.read_text(encoding="utf-8")
        text = re.sub(
            r'("bundleName"\s*:\s*")[^"]+(")',
            rf"\g<1>{STORE_BUNDLE_NAME}\g<2>",
            text,
            count=1,
        )
        app_config.write_text(text, encoding="utf-8", newline="\n")
    print(f"Updated {len(locales)} locales; store branding: {args.store}")


if __name__ == "__main__":
    main()
