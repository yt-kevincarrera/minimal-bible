#!/usr/bin/env python3
"""Genera assets/data/headings.json desde bible.helloao.org (DOMINIO PÚBLICO).

Equivalente de tools/fetch_headings.ps1 para Linux y macOS. Los títulos de
sección (perícopas) son opcionales: sin este archivo la app funciona igual, solo
que sin títulos dentro de los capítulos.

Uso, desde la raíz del proyecto:

    python3 tools/fetch_headings.py

Formato de salida: {"<bookId 1..66>": {"<capítulo>": {"<verso>": "título"}}}
"""

import argparse
import json
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from fetch_bible import get_json  # noqa: E402  (mismo directorio)


def headings_of(chapter_json):
    """{verso: título} — un título se asocia al primer verso que lo sigue."""
    out = {}
    pending = []
    for item in chapter_json['chapter']['content']:
        kind = item.get('type')
        if kind == 'heading':
            text = ' '.join(
                p for p in item.get('content', []) if isinstance(p, str)
            ).strip()
            if text:
                pending.append(text)
        elif kind == 'verse' and pending:
            out[str(item['number'])] = ' · '.join(pending)
            pending = []
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--translation', default='spa_onbv')
    ap.add_argument('--workers', type=int, default=12)
    ap.add_argument('--out', default='assets/data/headings.json', type=Path)
    args = ap.parse_args()

    base = f'https://bible.helloao.org/api/{args.translation}'
    books = get_json(f'{base}/books.json')['books']

    jobs = [
        (b['order'], b['id'], c)
        for b in books
        for c in range(1, b['numberOfChapters'] + 1)
    ]

    result = {}
    done = 0

    def fetch(job):
        return job, get_json(f'{base}/{job[1]}/{job[2]}.json')

    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        for (order, _, chapter), data in pool.map(fetch, jobs):
            done += 1
            titles = headings_of(data)
            if titles:
                result.setdefault(str(order), {})[str(chapter)] = titles
            if done % 200 == 0:
                print(f'  {done}/{len(jobs)} capítulos', file=sys.stderr)

    ordered = {
        str(o): {
            str(c): result[str(o)][str(c)]
            for c in sorted(int(k) for k in result[str(o)])
        }
        for o in sorted(int(k) for k in result)
    }
    total = sum(len(v) for ch in ordered.values() for v in ch.values())
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(
        json.dumps(ordered, ensure_ascii=False), encoding='utf-8',
    )
    print(f'✓ {args.out}: {len(ordered)} libros, {total} títulos')
    return 0


if __name__ == '__main__':
    sys.exit(main())
