"""Merge authored Arabic/Persian copy and reuse identical interface meanings."""
import json
import re
import sys
from pathlib import Path

ROOT = Path('entry/src/main/resources')
COPY = Path('localization')


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def main():
    batch = sys.argv[1]
    locales = sys.argv[2:4] or ['ar', 'fa']
    source = read(ROOT/'en/element/string.json')['string']
    keys_path = COPY/f'rtl-source-{batch}.json'
    text_path = COPY/f'rtl-{batch}.txt'
    resources = {}
    for locale in locales:
        path = ROOT/locale/'element/string.json'
        resources[locale] = {row['name']: row['value'] for row in read(path)['string']}
    if text_path.exists():
        keys = list(read(keys_path)['en'])
        rows = [line.split(' || ') for line in text_path.read_text(encoding='utf-8').splitlines()]
        if len(rows) != len(keys) or any(len(row) != 2 for row in rows):
            raise ValueError(f'Batch {batch}: {len(rows)} rows for {len(keys)} keys')
        for key, values in zip(keys, rows):
            for index, locale in enumerate(locales):
                resources[locale][key] = values[index].replace(r'\n', '\n')
    for locale, values in resources.items():
        # Exact duplicate source labels have already received contextual copy.
        meanings = {row['value']: values[row['name']] for row in source if row['name'] in values}
        for row in source:
            if row['name'] in values:
                continue
            if row['value'] in meanings:
                values[row['name']] = meanings[row['value']]
            elif not row['value'].strip() or re.fullmatch(r'https?://\S+', row['value']):
                values[row['name']] = row['value']
        output = [{'name': row['name'], 'value': values[row['name']]} for row in source if row['name'] in values]
        (ROOT/locale/'element/string.json').write_text(json.dumps({'string': output}, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
        print(f'{locale}: {len(output)}/{len(source)}')
    if not text_path.exists():
        seen = set()
        missing = []
        for row in source:
            if all(row['name'] in resources[locale] for locale in locales):
                continue
            if row['value'] in seen:
                continue
            seen.add(row['value'])
            missing.append(row)
            if len(missing) == 150:
                break
        keys_path.write_text(json.dumps({'en': {row['name']: row['value'] for row in missing}}, ensure_ascii=False, indent=2), encoding='utf-8')
        for index, row in enumerate(missing):
            print(f"{index+1}. {row['name']}={row['value']}")


if __name__ == '__main__':
    main()
