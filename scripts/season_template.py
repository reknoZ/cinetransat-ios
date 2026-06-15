#!/usr/bin/env python3
"""Shared programme template for generate_seed_data / seed scripts."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from generate_seed_data import (
    TZ,
    poster_stem_for,
    screening,
    starts_iso,
    sunset_iso,
)

_REPO_ROOT = Path(__file__).resolve().parent.parent
_TBD_TITLE = "TBD"
_TBD_BLURB = "TBD"
_TBD_POSTER_KEY = "tbd"


def _load_sunset_times_2026() -> dict[str, str]:
    """date (YYYY-MM-DD) → HH:MM from repo Sunset JSON or scripts/data/sunset_2026.json."""
    candidates = [
        _REPO_ROOT / "Sunset JSON",
        Path(__file__).resolve().parent / "data" / "sunset_2026.json",
    ]
    for path in candidates:
        if not path.exists():
            continue
        rows = json.loads(path.read_text(encoding="utf-8"))
        return {row["date"]: row["sunset"] for row in rows}
    return {}


def _sunset_at_for(season_year: int, month: int, day: int, table: dict[str, str]) -> tuple[int, int]:
    key = f"{season_year:04d}-{month:02d}-{day:02d}"
    raw = table.get(key, "21:18")
    hour, minute = (int(part) for part in raw.split(":"))
    return hour, minute


def _tbd_screening_spec(month: int, day: int, sunset_table: dict[str, str], season_year: int) -> tuple[str, int, int, dict[str, Any]]:
    return (
        _TBD_TITLE,
        month,
        day,
        {
            "minutes": 0,
            "blurb": _TBD_BLURB,
            "poster_key": _TBD_POSTER_KEY,
            "search_title": "",
            "sunset_at": _sunset_at_for(season_year, month, day, sunset_table),
        },
    )

# (week_id_suffix, week_label, list of screening specs)
# Each spec: title, month, day, kwargs for screening()
WeekSpec = tuple[str, str, list[tuple[str, int, int, dict[str, Any]]]]

TEMPLATE_2025: list[WeekSpec] = [
    (
        "w1",
        "10–13 juillet",
        [
            ("Les Bronzés font du ski", 7, 10, {"minutes": 90, "blurb": "Comédie culte des Bronzés coincés à la montagne."}),
            ("Le Vieux qui ne voulait pas fêter son anniversaire", 7, 11, {"minutes": 114, "blurb": "Road movie absurde et tendre entre Suède et explosion."}),
            ("Shaun of the Dead", 7, 12, {"minutes": 99, "blurb": "Zombie comedy britannique iconique."}),
            ("Bottoms", 7, 13, {"minutes": 91, "blurb": "Comédie déjantée de lycée et club de combat improbable."}),
        ],
    ),
    (
        "w2",
        "17–20 juillet",
        [
            ("E.T. l'extra-terrestre", 7, 17, {"minutes": 115, "blurb": "Le classique Spielberg sur l'amitié et le retour à la maison."}),
            ("Les Mitchell contre les machines", 7, 18, {"minutes": 114, "blurb": "Road trip familial face à une révolte des robots."}),
            ("Soirée choréoké", 7, 19, {"canceled": True, "minutes": None, "blurb": "Soirée spéciale — annulée en raison des conditions."}),
            ("Au revoir là-haut", 7, 20, {"canceled": True, "minutes": 117, "blurb": "Drame poétique post-Grande Guerre — séance annulée."}),
        ],
    ),
    (
        "w3",
        "24–27 juillet",
        [
            ("Marinette", 7, 24, {"minutes": 95, "blurb": "Biopic sportif sur la footballeuse Marinette Pichon."}),
            ("Ninjababy", 7, 25, {"minutes": 103, "blurb": "Comédie norvégienne d'une grossesse dessinée en ninja."}),
            ("Paddington 2", 7, 26, {"canceled": True, "minutes": 103, "blurb": "Aventures de l'ours le plus aimable de Londres — séance annulée."}),
            ("Soirée courts-métrages", 7, 27, {"canceled": True, "minutes": None, "blurb": "Programme de courts — annulé."}),
        ],
    ),
    (
        "w4",
        "31 juillet – 3 août",
        [
            ("The Holiday", 7, 31, {"minutes": 136, "blurb": "Romance hivernale entre Los Angeles et la campagne anglaise."}),
            ("Ma vie de Courgette", 8, 1, {"minutes": 66, "blurb": "Stop-motion délicat sur l'enfance et la résilience."}),
            ("Terminator 2 : Le Jugement dernier", 8, 2, {"minutes": 137, "blurb": "Science-fiction d'action avec Schwarzenegger."}),
            ("La Famille Asada", 8, 3, {"minutes": 127, "blurb": "Drame familial japonais autour d'un restaurant et des liens."}),
        ],
    ),
    (
        "w5",
        "7–10 août",
        [
            ("Puan", 8, 7, {"minutes": 110, "blurb": "Comédie argentine sur l'université, la politique et l'amitié."}),
            ("Lost in Translation", 8, 8, {"minutes": 102, "blurb": "Rencontre fugace à Tokyo entre deux âmes en décalage."}),
            ("Pulp Fiction", 8, 9, {"minutes": 154, "blurb": "Anthologie criminelle signée Tarantino."}),
            ("North by Northwest", 8, 10, {"minutes": 136, "blurb": "Thriller hitchcockien à travers les États-Unis."}),
        ],
    ),
    (
        "w6",
        "14–17 août",
        [
            (
                "Soirée rattrapage",
                8,
                14,
                {
                    "minutes": None,
                    "blurb": "Programme variable : films manqués ou invités de la saison.",
                    "poster_key": "paddington-2",
                },
            ),
            ("Everything Everywhere All at Once", 8, 15, {"minutes": 139, "blurb": "Multivers délirant et émouvant sur les choix de vie."}),
            (
                "Bãhubali : The Beginning",
                8,
                16,
                {
                    "minutes": 159,
                    "blurb": "Épopée indienne grand spectacle.",
                    "search_title": "Baahubali The Beginning",
                },
            ),
            ("Le Fabuleux Destin d'Amélie Poulain", 8, 17, {"minutes": 122, "blurb": "Paris poétique et jeux du hasard."}),
        ],
    ),
]

# Same calendar rhythm as 2025 (Thu–Sun blocks; dates shifted one day for 2026 weekdays).
# Mix: 6 French, 11 Hollywood/English, 4 international, 3 soirées spéciales.
def _film_spec(
    title: str,
    month: int,
    day: int,
    sunset_table: dict[str, str],
    season_year: int,
    **kwargs: Any,
) -> tuple[str, int, int, dict[str, Any]]:
    return (title, month, day, {**kwargs, "sunset_at": _sunset_at_for(season_year, month, day, sunset_table)})


def build_template_2026(season_year: int = 2026) -> list[WeekSpec]:
    sunset_table = _load_sunset_times_2026()

    def f(title: str, month: int, day: int, **kwargs: Any) -> tuple[str, int, int, dict[str, Any]]:
        return _film_spec(title, month, day, sunset_table, season_year, **kwargs)

    return [
        (
            "w1",
            "9–12 juillet",
            [
                f(
                    "Grease",
                    7,
                    9,
                    minutes=110,
                    blurb="Ouverture de la saison : comédie musicale des années 50 au lycée Rydell.",
                    poster_key="grease",
                ),
                f("La Grande Vadrouille", 7, 10, minutes=132, blurb="Classique absurde de la Seconde Guerre mondiale avec Bourvil et de Funès."),
                f(
                    "Back to the Future",
                    7,
                    11,
                    minutes=116,
                    blurb="Voyage dans le temps et rock'n'roll des années 1980.",
                    poster_key="back-to-the-future",
                ),
                f(
                    "The Grand Budapest Hotel",
                    7,
                    12,
                    minutes=100,
                    blurb="Farce colorée et nostalgique signée Wes Anderson.",
                    poster_key="the-grand-budapest-hotel",
                ),
            ],
        ),
        (
            "w2",
            "16–19 juillet",
            [
                f("Jurassic Park", 7, 16, minutes=127, blurb="Les dinosaures sortent de leur enclos — le blockbuster paranoïaque de Spielberg."),
                f("Kung Fu Panda", 7, 17, minutes=92, blurb="Un panda maladroit devient un héros de légende."),
                f(
                    "Soirée choréoké",
                    7,
                    18,
                    minutes=None,
                    blurb="Chantez devant l'écran : tubes français et internationaux sous les étoiles.",
                    poster_key="soirée-choréoké",
                ),
                f("Les Choristes", 7, 19, minutes=97, blurb="Un professeur de musique transforme la vie d'élèves en pensionnat."),
            ],
        ),
        (
            "w3",
            "23–26 juillet",
            [
                f("Intouchables", 7, 23, minutes=112, blurb="Comédie française sur une amitié improbable entre un aristocrate et son aide."),
                f(
                    "Parasite",
                    7,
                    24,
                    minutes=132,
                    blurb="Thriller social coréen sur deux familles aux antipodes.",
                    poster_key="parasite",
                ),
                f(
                    "Flashdance",
                    7,
                    25,
                    minutes=95,
                    blurb="Une soudeuse rêve de devenir danseuse — tubes et chorégraphies des années 80.",
                    poster_key="flashdance",
                ),
                f(
                    "Soirée courts-métrages",
                    7,
                    26,
                    minutes=None,
                    blurb="Sélection de courts métrages suisses et internationaux.",
                    poster_key="soirée-court-métrages",
                ),
            ],
        ),
        (
            "w4",
            "30 juillet – 2 août",
            [
                f(
                    "Notting Hill",
                    7,
                    30,
                    minutes=124,
                    blurb="Romance londonienne entre une star et un libraire.",
                    poster_key="notting-hill",
                ),
                f("Delicatessen", 7, 31, minutes=99, blurb="Comédie noire et burlesque dans un immeuble post-apocalyptique."),
                f(
                    "Kirikou et la Sorcière",
                    8,
                    1,
                    minutes=71,
                    blurb="Conte africain en animation pour petits et grands.",
                    poster_key="kirikou-et-la-sorciere",
                ),
                f(
                    "Raiders of the Lost Ark",
                    8,
                    2,
                    minutes=115,
                    blurb="Indiana Jones et une course contre la montre pour l'Arche d'alliance.",
                    poster_key="raiders-of-the-lost-ark",
                ),
            ],
        ),
        (
            "w5",
            "6–9 août",
            [
                f(
                    "Your Name.",
                    8,
                    6,
                    minutes=106,
                    blurb="Deux adolescents échangent leurs corps à distance — anime poétique.",
                    search_title="Your Name",
                    poster_key="your-name",
                ),
                f(
                    "Cinema Paradiso",
                    8,
                    7,
                    minutes=124,
                    blurb="Hommage au cinéma de village et à l'amitié entre un projectionniste et un enfant.",
                    poster_key="cinema-paradiso",
                ),
                f("Forrest Gump", 8, 8, minutes=142, blurb="Une odyssée américaine vue par un homme simple et bon."),
                f(
                    "The Matrix",
                    8,
                    9,
                    minutes=136,
                    blurb="Science-fiction et kung-fu : le monde n'est peut-être qu'une simulation.",
                    poster_key="the-matrix",
                ),
            ],
        ),
        (
            "w6",
            "13–16 août",
            [
                f(
                    "Soirée rattrapage",
                    8,
                    13,
                    minutes=None,
                    blurb="Programme variable : films manqués ou invités de la saison.",
                    poster_key="soirée-rattrapage",
                ),
                f("Casablanca", 8, 14, minutes=102, blurb="Romance et exil au Maroc pendant la guerre — classique intemporel."),
                f(
                    "RRR",
                    8,
                    15,
                    minutes=187,
                    blurb="Épopée indienne d'amitié, de rébellion et de numéros spectaculaires.",
                    poster_key="rrr",
                ),
                f(
                    "Le Dîner de cons",
                    8,
                    16,
                    minutes=80,
                    blurb="Farce française autour d'un dîner de fous entre amis.",
                    poster_key="le-diner-de-cons",
                ),
            ],
        ),
    ]


TEMPLATE_2026: list[WeekSpec] = build_template_2026()


def build_season_document(season_year: int, template: list[WeekSpec]) -> dict:
    weeks = []
    for week_suffix, label, specs in template:
        screenings = []
        for title, month, day, kwargs in specs:
            screenings.append(
                screening(
                    title,
                    season_year,
                    month,
                    day,
                    canceled=kwargs.get("canceled", False),
                    minutes=kwargs.get("minutes"),
                    blurb=kwargs.get("blurb", ""),
                    search_title=kwargs.get("search_title"),
                    poster_key=kwargs.get("poster_key"),
                    sunset_at=kwargs.get("sunset_at"),
                )
            )
        weeks.append(
            {
                "id": f"{season_year}-{week_suffix}",
                "label": label,
                "screenings": screenings,
            }
        )

    return {
        "schemaVersion": 2,
        "seasonYear": season_year,
        "updatedAt": datetime.now(TZ).isoformat(timespec="seconds"),
        "weeks": weeks,
    }
