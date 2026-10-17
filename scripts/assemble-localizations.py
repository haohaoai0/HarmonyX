"""Assemble reviewed UI copy. This script never calls a translation service."""
import argparse
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('copy', type=Path)
    parser.add_argument('--resources', type=Path, default=Path('entry/src/main/resources'))
    args = parser.parse_args()
    copy = json.loads(args.copy.read_text(encoding='utf-8'))
    if 'reference' in copy:
        reference = json.loads((args.copy.parent/copy['reference']).read_text(encoding='utf-8'))
        keys = list(next(iter(reference.values())))
        native = {}
        for locale,values in copy['locales'].items():
            if len(values) != len(keys):
                raise ValueError(f'{locale}: {len(values)} values for {len(keys)} interface entries')
            native[locale] = dict(zip(keys,values))
        copy = native
    base = json.loads((args.resources/'base/element/string.json').read_text(encoding='utf-8'))['string']
    valid_keys = {row['name'] for row in base}
    empty_keys = {row['name'] for row in base if not row['value'].strip()}
    for locale, values in copy.items():
        file = args.resources/locale/'element/string.json'
        existing = json.loads(file.read_text(encoding='utf-8'))['string'] if file.exists() else []
        merged = {row['name']:row['value'] for row in existing}
        for key,value in values.items():
            if key not in valid_keys or not isinstance(value,str) or (not value.strip() and key not in empty_keys):
                raise ValueError(f'Invalid copy: {locale}/{key}')
            merged[key] = value
        # Do not invent an English translation for a missing entry.
        output = [{'name':row['name'],'value':merged[row['name']]} for row in base if row['name'] in merged]
        file.parent.mkdir(parents=True,exist_ok=True)
        file.write_text(json.dumps({'string':output},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        print(f'{locale}: {len(output)}/{len(base)}')


if __name__ == '__main__':
    main()
