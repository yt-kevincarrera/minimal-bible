#!/usr/bin/env python3
"""Genera assets/data/rv1960.json desde bible.helloao.org (DOMINIO PÚBLICO).

Equivalente de tools/fetch_bible.ps1 para Linux y macOS (el .ps1 solo corre en
Windows), con los nombres de libro EXACTOS que espera la app (ver jsonKey en
lib/data/books.dart).

Uso, desde la raíz del proyecto:

    python3 tools/fetch_bible.py                 # spa_rvg (Reina-Valera Gómez)
    python3 tools/fetch_bible.py --translation spa_r09   # Reina-Valera 1909

Solo usa la librería estándar. Respeta el proxy del entorno (HTTPS_PROXY).
"""

import argparse
import json
import sys
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

# Nombres de libro en orden canónico 1..66 (deben coincidir con books.dart).
JKEYS = [
    'Génesis', 'Éxodo', 'Levítico', 'Números', 'Deuteronomio', 'Josué',
    'Jueces', 'Rut', '1 Samuel', '2 Samuel', '1 Reyes', '2 Reyes',
    '1 Crónicas', '2 Crónicas', 'Esdras', 'Nehemías', 'Ester', 'Job',
    'Salmos', 'Proverbios', 'Eclesiastés', 'Cantares', 'Isaías', 'Jeremías',
    'Lamentaciones', 'Ezequiel', 'Daniel', 'Oseas', 'Joel', 'Amós', 'Abdías',
    'Jonás', 'Miqueas', 'Nahúm', 'Habacuc', 'Sofonías', 'Hageo', 'Zacarías',
    'Malaquías', 'S. Mateo', 'S. Marcos', 'S. Lucas', 'S.Juan', 'Hechos',
    'Romanos', '1 Corintios', '2 Corintios', 'Gálatas', 'Efesios',
    'Filipenses', 'Colosenses', '1 Tesalonicenses', '2 Tesalonicenses',
    '1 Timoteo', '2 Timoteo', 'Tito', 'Filemón', 'Hebreos', 'Santiago',
    '1 Pedro', '2 Pedro', '1 Juan', '2 Juan', '3 Juan', 'Judas', 'Apocalipsis',
]


def get_json(url, tries=5):
    for attempt in range(tries):
        try:
            with urllib.request.urlopen(url, timeout=30) as r:
                return json.loads(r.read().decode('utf-8'))
        except Exception:
            if attempt == tries - 1:
                raise
            time.sleep(0.5 * (attempt + 1))


def verses_of(chapter_json):
    """Extrae {"1": "texto", …} del contenido de un capítulo."""
    out = {}
    for item in chapter_json['chapter']['content']:
        if item.get('type') != 'verse':
            continue
        parts = []
        for piece in item.get('content', []):
            if isinstance(piece, str):
                parts.append(piece)
            elif isinstance(piece, dict) and piece.get('text'):
                parts.append(piece['text'])
        text = ''.join(parts).strip()
        if text:
            out[str(item['number'])] = text
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--translation', default='spa_rvg')
    ap.add_argument('--workers', type=int, default=12)
    ap.add_argument(
        '--out', default='assets/data/rv1960.json', type=Path,
    )
    args = ap.parse_args()

    base = f'https://bible.helloao.org/api/{args.translation}'
    books = get_json(f'{base}/books.json')['books']

    jobs = []
    for b in books:
        if not 1 <= b['order'] <= len(JKEYS):
            continue
        for c in range(1, b['numberOfChapters'] + 1):
            jobs.append((JKEYS[b['order'] - 1], b['id'], c))

    result = {}
    failures = []
    done = 0

    def fetch(job):
        key, book_id, chapter = job
        return job, get_json(f'{base}/{book_id}/{chapter}.json')

    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        for job, data in pool.map(fetch, jobs):
            key, _, chapter = job
            done += 1
            try:
                result.setdefault(key, {})[str(chapter)] = verses_of(data)
            except Exception as e:  # capítulo con forma inesperada
                failures.append((key, chapter, repr(e)))
            if done % 100 == 0:
                print(f'  {done}/{len(jobs)} capítulos', file=sys.stderr)

    # Ordena libros (canónico) y capítulos (numérico) para un JSON estable.
    ordered = {}
    for key in JKEYS:
        chapters = result.get(key)
        if not chapters:
            failures.append((key, '*', 'libro ausente'))
            continue
        ordered[key] = {str(c): chapters[str(c)]
                        for c in sorted(int(k) for k in chapters)}

    total = sum(len(v) for ch in ordered.values() for v in ch.values())
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(
        json.dumps(ordered, ensure_ascii=False), encoding='utf-8',
    )
    print(f'✓ {args.out}: {len(ordered)} libros, {total} versículos')
    if failures:
        print(f'⚠ {len(failures)} fallos: {failures[:5]}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
