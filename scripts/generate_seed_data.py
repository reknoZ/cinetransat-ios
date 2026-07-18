#!/usr/bin/env python3
"""
Regenerate scripts/data/seasons/{year}.json and public_config.json.

Keep programme data in sync with CinéTransat/FestivalProgram.swift (FestivalProgramBootstrap).
"""

from __future__ import annotations

import json
import re
import unicodedata
from datetime import datetime, timedelta, timezone
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
DATA_DIR = SCRIPT_DIR / "data"
SEASONS_DIR = DATA_DIR / "seasons"

TZ = timezone(timedelta(hours=2))
SEASON_YEAR = 2025

# Official projection start times (Europe/Zurich) for 2026 — sunset varies nightly.
PROJECTION_START_2026: dict[str, tuple[int, int]] = {
    "20260709": (21, 44),
    "20260710": (21, 43),
    "20260711": (21, 43),
    "20260712": (21, 42),
    "20260716": (21, 39),
    "20260717": (21, 38),
    "20260718": (21, 37),
    "20260719": (21, 0),
    "20260723": (21, 31),
    "20260724": (21, 30),
    "20260725": (21, 29),
    "20260726": (21, 28),
    "20260730": (21, 0),
    "20260731": (21, 21),
    "20260801": (21, 20),
    "20260802": (21, 19),
    "20260806": (21, 13),
    "20260807": (21, 11),
    "20260808": (21, 10),
    "20260809": (21, 8),
    "20260813": (21, 1),
    "20260814": (21, 0),
    "20260815": (20, 58),
    "20260816": (20, 56),
}


def sunset_iso(y: int, m: int, d: int, h: int = 21, mi: int = 18) -> str:
    return datetime(y, m, d, h, mi, tzinfo=TZ).isoformat(timespec="seconds")


def starts_iso(y: int, m: int, d: int, h: int = 21, mi: int = 45) -> str:
    sid = f"{y:04d}{m:02d}{d:02d}"
    if y == 2026 and sid in PROJECTION_START_2026:
        h, mi = PROJECTION_START_2026[sid]
    return datetime(y, m, d, h, mi, tzinfo=TZ).isoformat(timespec="seconds")


def slug_poster_key(title: str) -> str:
    """ASCII slug (English title). Match iOS `PosterKey.slug`."""
    normalized = unicodedata.normalize("NFD", title)
    ascii_text = "".join(c for c in normalized if unicodedata.category(c) != "Mn")
    slug = re.sub(r"[^a-z0-9]+", "-", ascii_text.lower()).strip("-")
    return slug or "unknown"


# Programme display title → exact stem in hosting/public/posters/ (sync with PosterCatalog.swift)
POSTER_STEM_BY_TITLE: dict[str, str] = {
    "Les Bronzés font du ski": "les-bronzes-font-du-ski",
    "Le Vieux qui ne voulait pas fêter son anniversaire": "le-vieux-qui-ne-voulait-pas-feter-son-anniversaire",
    "Shaun of the Dead": "shaun-of-the-dead",
    "Bottoms": "bottoms",
    "E.T. l'extra-terrestre": "e.t.-the-extraterrestial",
    "Les Mitchell contre les machines": "the-mitchells-vs-the-machines",
    "Soirée choréoké": "soirée-choréoké",
    "Au revoir là-haut": "au-revoir-la-haut",
    "Marinette": "marinette",
    "Ninjababy": "ninjababy",
    "Paddington 2": "paddington-2",
    "Soirée courts-métrages": "soirée-court-métrages",
    "The Holiday": "the-holiday",
    "Ma vie de Courgette": "ma-vie-de-courgette",
    "Terminator 2 : Le Jugement dernier": "terminator-2-judgment-day",
    "La Famille Asada": "la-famille-asada",
    "Puan": "puan",
    "Lost in Translation": "lost-in-translation",
    "Pulp Fiction": "pulp-fiction",
    "North by Northwest": "north-by-northwest",
    "Soirée rattrapage": "soirée-rattrapage",
    "Everything Everywhere All at Once": "everything-everywhere-all-at-once",
    "Bãhubali : The Beginning": "bahubali-the-beginning",
    "Le Fabuleux Destin d'Amélie Poulain": "le-fabuleux-destin-d'amelie-poulain",
    # 2026 season
    "Back to the Future": "back-to-the-future",
    "La Famille Bélier": "la-famille-belier",
    "Billy Elliot": "billy-elliot",
    "Flow": "flow",
    "Sauvages": "sauvages",
    "Love and Other Disasters": "love-and-other-disasters",
    "Paddington": "paddington",
    "Soirées courts-métrages": "soiree-court-metrages",
    "I Am Not a Witch": "i-am-not-a-witch",
    "Singin' in the Rain": "singin-in-the-rain",
    "Wadjda": "wadjda",
    "The Girl Who Leapt Through Time": "the-girl-who-leapt-through-time",
    "CHOREOKE": "soiree-choreoke",
    "Jumanji: Welcome to the Jungle": "jumanji-welcome-to-the-jungle",
    "Bon Schuur Ticino (Ciao-ciao bourbine)": "bon-schuur-ticino",
    "Portrait de la jeune fille en feu": "portrait-de-la-jeune-fille-en-feu",
    "BlacKkKlansman": "blackkklansman",
    "Much Ado About Nothing": "much-ado-about-nothing",
    "The Mummy": "the-mummy",
    "Lo que quisimos ser": "lo-que-quisimos-ser",
    "Ocean's Eleven": "oceans-eleven",
    "Baahubali 2: The Conclusion": "baahubali-2-the-conclusion",
    "Intouchables": "intouchables",
}


def poster_stem_for(title: str, search_title: str | None = None, poster_key: str | None = None) -> str:
    if poster_key:
        return poster_key
    if title in POSTER_STEM_BY_TITLE:
        return POSTER_STEM_BY_TITLE[title]
    return slug_poster_key(search_title or title)


def screening(
    title: str,
    y: int,
    m: int,
    d: int,
    *,
    canceled: bool = False,
    minutes: int | None = None,
    blurb: str = "",
    blurb_en: str | None = None,
    search_title: str | None = None,
    poster_key: str | None = None,
    legal_age: int | None = None,
    recommended_age: int | None = None,
    sunset_at: tuple[int, int] | None = None,
    audio_language: str | None = None,
    audio_language_en: str | None = None,
    subtitle_language: str | None = None,
    subtitle_language_en: str | None = None,
) -> dict:
    sunset_h, sunset_mi = sunset_at if sunset_at is not None else (21, 18)
    sid = f"{y:04d}{m:02d}{d:02d}"
    doc = {
        "id": sid,
        "title": title,
        "startsAt": starts_iso(y, m, d),
        "sunset": sunset_iso(y, m, d, sunset_h, sunset_mi),
        "isCanceled": canceled,
        "synopsis": blurb,
        "posterKey": poster_stem_for(title, search_title, poster_key),
    }
    if blurb_en:
        doc["synopsisEn"] = blurb_en
    if minutes is not None:
        doc["runtimeMinutes"] = minutes
    if search_title is not None:
        doc["searchTitle"] = search_title
    if legal_age is not None:
        doc["legalAge"] = legal_age
    if recommended_age is not None:
        doc["recommendedAge"] = recommended_age
    if audio_language is not None:
        doc["audioLanguage"] = audio_language
    if audio_language_en is not None:
        doc["audioLanguageEn"] = audio_language_en
    if subtitle_language is not None:
        doc["subtitleLanguage"] = subtitle_language
    if subtitle_language_en is not None:
        doc["subtitleLanguageEn"] = subtitle_language_en
    return doc


def build_season_document(season_year: int) -> dict:
    weeks = [
        (
            "2025-w1",
            "10–13 juillet",
            [
                screening(
                    "Les Bronzés font du ski",
                    season_year,
                    7,
                    10,
                    minutes=90,
                    blurb="Comédie culte des Bronzés coincés à la montagne.",
                ),
                screening(
                    "Le Vieux qui ne voulait pas fêter son anniversaire",
                    season_year,
                    7,
                    11,
                    minutes=114,
                    blurb="Road movie absurde et tendre entre Suède et explosion.",
                ),
                screening(
                    "Shaun of the Dead",
                    season_year,
                    7,
                    12,
                    minutes=99,
                    blurb="Zombie comedy britannique iconique.",
                ),
                screening(
                    "Bottoms",
                    season_year,
                    7,
                    13,
                    minutes=91,
                    blurb="Comédie déjantée de lycée et club de combat improbable.",
                ),
            ],
        ),
        (
            "2025-w2",
            "17–20 juillet",
            [
                screening(
                    "E.T. l'extra-terrestre",
                    season_year,
                    7,
                    17,
                    minutes=115,
                    blurb="Le classique Spielberg sur l'amitié et le retour à la maison.",
                ),
                screening(
                    "Les Mitchell contre les machines",
                    season_year,
                    7,
                    18,
                    minutes=114,
                    blurb="Road trip familial face à une révolte des robots.",
                ),
                screening(
                    "Soirée choréoké",
                    season_year,
                    7,
                    19,
                    canceled=True,
                    minutes=None,
                    blurb="Soirée spéciale — annulée en raison des conditions.",
                ),
                screening(
                    "Au revoir là-haut",
                    season_year,
                    7,
                    20,
                    canceled=True,
                    minutes=117,
                    blurb="Drame poétique post-Grande Guerre — séance annulée.",
                ),
            ],
        ),
        (
            "2025-w3",
            "24–27 juillet",
            [
                screening(
                    "Marinette",
                    season_year,
                    7,
                    24,
                    minutes=95,
                    blurb="Biopic sportif sur la footballeuse Marinette Pichon.",
                ),
                screening(
                    "Ninjababy",
                    season_year,
                    7,
                    25,
                    minutes=103,
                    blurb="Comédie norvégienne d'une grossesse dessinée en ninja.",
                ),
                screening(
                    "Paddington 2",
                    season_year,
                    7,
                    26,
                    canceled=True,
                    minutes=103,
                    blurb="Aventures de l'ours le plus aimable de Londres — séance annulée.",
                ),
                screening(
                    "Soirée courts-métrages",
                    season_year,
                    7,
                    27,
                    canceled=True,
                    minutes=None,
                    blurb="Programme de courts — annulé.",
                ),
            ],
        ),
        (
            "2025-w4",
            "31 juillet – 3 août",
            [
                screening(
                    "The Holiday",
                    season_year,
                    7,
                    31,
                    minutes=136,
                    blurb="Romance hivernale entre Los Angeles et la campagne anglaise.",
                ),
                screening(
                    "Ma vie de Courgette",
                    season_year,
                    8,
                    1,
                    minutes=66,
                    blurb="Stop-motion délicat sur l'enfance et la résilience.",
                ),
                screening(
                    "Terminator 2 : Le Jugement dernier",
                    season_year,
                    8,
                    2,
                    minutes=137,
                    blurb="Science-fiction d'action avec Schwarzenegger.",
                ),
                screening(
                    "La Famille Asada",
                    season_year,
                    8,
                    3,
                    minutes=127,
                    blurb="Drame familial japonais autour d'un restaurant et des liens.",
                ),
            ],
        ),
        (
            "2025-w5",
            "7–10 août",
            [
                screening(
                    "Puan",
                    season_year,
                    8,
                    7,
                    minutes=110,
                    blurb="Comédie argentine sur l'université, la politique et l'amitié.",
                ),
                screening(
                    "Lost in Translation",
                    season_year,
                    8,
                    8,
                    minutes=102,
                    blurb="Rencontre fugace à Tokyo entre deux âmes en décalage.",
                ),
                screening(
                    "Pulp Fiction",
                    season_year,
                    8,
                    9,
                    minutes=154,
                    blurb="Anthologie criminelle signée Tarantino.",
                ),
                screening(
                    "North by Northwest",
                    season_year,
                    8,
                    10,
                    minutes=136,
                    blurb="Thriller hitchcockien à travers les États-Unis.",
                ),
            ],
        ),
        (
            "2025-w6",
            "14–17 août",
            [
                screening(
                    "Soirée rattrapage",
                    season_year,
                    8,
                    14,
                    minutes=None,
                    blurb="Programme variable : films manqués ou invités de la saison.",
                    poster_key="paddington-2",
                ),
                screening(
                    "Everything Everywhere All at Once",
                    season_year,
                    8,
                    15,
                    minutes=139,
                    blurb="Multivers délirant et émouvant sur les choix de vie.",
                ),
                screening(
                    "Bãhubali : The Beginning",
                    season_year,
                    8,
                    16,
                    minutes=159,
                    blurb="Épopée indienne grand spectacle.",
                    search_title="Baahubali The Beginning",
                ),
                screening(
                    "Le Fabuleux Destin d'Amélie Poulain",
                    season_year,
                    8,
                    17,
                    minutes=122,
                    blurb="Paris poétique et jeux du hasard.",
                ),
            ],
        ),
    ]

    return {
        "schemaVersion": 2,
        "seasonYear": season_year,
        "updatedAt": datetime.now(TZ).isoformat(timespec="seconds"),
        "weeks": [
            {"id": week_id, "label": label, "screenings": screenings}
            for week_id, label, screenings in weeks
        ],
    }


def build_public_config_document(current_season_year: int) -> dict:
    return {
        "schemaVersion": 2,
        "currentSeasonYear": current_season_year,
        "websiteURL": "https://www.cinetransat.ch/",
        "practicalInfoURL": "https://www.cinetransat.ch/infos-pratiques",
        "contactEmail": "info@cinetransat.ch",
        "facebookURL": "https://www.facebook.com/cinetransat",
        "instagramURL": "https://www.instagram.com/cinetransat",
        "posterBaseURL": (
            "https://cinetransat-497ce.web.app/posters/{posterKey}.jpg"
        ),
        "rattrapageVotingOpen": False,
    }


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2)
        handle.write("\n")


def main() -> None:
    season_path = SEASONS_DIR / f"{SEASON_YEAR}.json"
    config_path = DATA_DIR / "public_config.json"
    write_json(season_path, build_season_document(SEASON_YEAR))
    write_json(config_path, build_public_config_document(SEASON_YEAR))
    print(f"Wrote {season_path}")
    print(f"Wrote {config_path}")


if __name__ == "__main__":
    main()
