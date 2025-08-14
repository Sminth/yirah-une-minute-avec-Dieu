#!/usr/bin/env python3
"""
Downloader de musiques vers assets/audio/ pour l'app One Minute.

Usage basique:
  python3 scripts/download_audio.py --input scripts/urls.sample.txt

Ou avec URLs directes:
  python3 scripts/download_audio.py \
    https://example.com/track1.mp3 \
    https://example.com/track2.mp3

Options clés:
  --dest DIR           Dossier de destination (par défaut: assets/audio)
  --overwrite          Réécrire si le fichier existe déjà
  --no-validate-mime   Ne pas vérifier le type MIME (audio/*)

Prérequis:
  pip install -r scripts/requirements.txt
"""

from __future__ import annotations

import argparse
import mimetypes
import os
from pathlib import Path
from typing import Iterable, List
from urllib.parse import urlparse

import requests
from requests.exceptions import RequestException
from tqdm import tqdm


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Télécharge des fichiers audio dans assets/audio/")
    parser.add_argument("urls", nargs="*", help="URLs de fichiers audio à télécharger")
    parser.add_argument("--input", "-i", dest="input_file", help="Fichier texte avec 1 URL par ligne")
    parser.add_argument("--dest", "-d", default="assets/audio", help="Dossier de destination")
    parser.add_argument("--overwrite", action="store_true", help="Écrase si le fichier existe")
    parser.add_argument("--no-validate-mime", action="store_true", help="Ne pas vérifier que le MIME est audio/*")
    return parser.parse_args()


def read_urls(args: argparse.Namespace) -> List[str]:
    urls: List[str] = []
    if args.input_file:
        with open(args.input_file, "r", encoding="utf-8") as f:
            for line in f:
                u = line.strip()
                if u and not u.startswith("#"):
                    urls.append(u)
    urls.extend(args.urls)
    # déduplication en conservant l'ordre
    seen = set()
    unique_urls: List[str] = []
    for u in urls:
        if u not in seen:
            seen.add(u)
            unique_urls.append(u)
    return unique_urls


def ensure_dest_directory(dest: Path) -> None:
    dest.mkdir(parents=True, exist_ok=True)


def filename_from_url(url: str) -> str:
    parsed = urlparse(url)
    name = os.path.basename(parsed.path)
    return name or "audio"


def extension_from_mime(mime: str | None) -> str | None:
    if not mime:
        return None
    # exemple: audio/mpeg -> .mp3
    ext = mimetypes.guess_extension(mime)
    return ext


def download(url: str, dest_dir: Path, overwrite: bool = False, validate_mime: bool = True) -> Path | None:
    try:
        with requests.get(url, stream=True, timeout=30) as r:
            r.raise_for_status()
            mime = r.headers.get("Content-Type", "").split(";")[0].strip()
            if validate_mime and not mime.startswith("audio/"):
                print(f"[SKIP] MIME non audio ({mime}) pour {url}")
                return None

            total = int(r.headers.get("Content-Length", 0))
            # déterminer le nom de fichier
            name = filename_from_url(url)
            # si pas d'extension, tenter depuis MIME
            root, ext = os.path.splitext(name)
            if not ext:
                guessed = extension_from_mime(mime)
                if guessed:
                    name = root + guessed

            out_path = dest_dir / name
            if out_path.exists() and not overwrite:
                print(f"[EXIST] {out_path}")
                return out_path

            desc = f"Downloading {name}"
            with open(out_path, "wb") as f, tqdm(total=total if total > 0 else None, unit="B", unit_scale=True, desc=desc) as pbar:
                for chunk in r.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
                        if total > 0:
                            pbar.update(len(chunk))

            # validation simple: taille raisonnable
            if out_path.stat().st_size < 10_000:
                print(f"[WARN] Fichier très petit (<10KB): {out_path}")
            print(f"[OK] {out_path}")
            return out_path

    except RequestException as e:
        print(f"[ERR ] Échec téléchargement {url}: {e}")
        return None


def main() -> None:
    args = parse_args()
    urls = read_urls(args)
    if not urls:
        print("Aucune URL fournie. Passe un fichier --input ou des URLs.")
        return

    dest = Path(args.dest)
    ensure_dest_directory(dest)

    print(f"Destination: {dest.resolve()}")
    for url in urls:
        download(url, dest, overwrite=args.overwrite, validate_mime=not args.no_validate_mime)


if __name__ == "__main__":
    main()


