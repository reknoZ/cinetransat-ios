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


# English synopses for the 2026 programme (French remains in each `blurb=`).
_BLURB_EN_2026: dict[str, str] = {
    "Back to the Future": (
        "Marty, hurled to 1955 in a DeLorean, must get his parents to fall for each other "
        "or vanish from the future. Where he's going, he doesn't need roads!"
    ),
    "La Famille Bélier": (
        "Paula, the only hearing member of a deaf family, discovers her voice and must choose "
        "between belting out Michel Sardou or staying the rock of her family."
    ),
    "Billy Elliot": (
        "A miner's son discovers dance and dreams of ballet instead of boxing gloves."
    ),
    "Flow": (
        "A cat wakes in a flooded world and boards a boat with other animals to survive "
        "a silent deluge. Noah's Ark, minus Noah."
    ),
    "Sauvages": (
        "In Borneo, a teen and a baby orangutan confront deforestation and discover "
        "their bond with nature and each other."
    ),
    "Love and Other Disasters": (
        "A Vogue assistant overrates her gaydar. Her gay best friend falls head over heels. "
        "Romantic mix-ups and small disasters ensue…"
    ),
    "Paddington": (
        "A Peruvian bear arrives in London with his hat, his love of marmalade, and… his clumsiness. "
        "His adoptive family's patience is sorely tested. But who could stay mad at such a polite little bear?"
    ),
    "Soirées courts-métrages": "A selection of Swiss and international short films.",
    "I Am Not a Witch": (
        "A girl is accused of witchcraft and sent to a camp where she must survive "
        "an absurd, cruel system."
    ),
    "Singin' in the Rain": (
        "Hollywood goes from silent to sound; Gene Kelly dances in the rain, a starlet lip-syncs badly."
    ),
    "Wadjda": "A Saudi girl dreams of a forbidden bicycle and defies the rules. Pedal, Wadjda, pedal!",
    "The Girl Who Leapt Through Time": (
        "A teen discovers she can rewind time. What could possibly go wrong?"
    ),
    "CHOREOKE": "Sing along to the screen: French and international hits under the stars.",
    "Jumanji: Welcome to the Jungle": (
        "Four teens trapped in a cursed video game must survive a jungle full of booby traps and cheesy clichés."
    ),
    "Bon Schuur Ticino (Ciao-ciao bourbine)": (
        "In Switzerland, an absurd popular initiative triggers national chaos between regions "
        "that no longer understand each other at all. Grüezi!"
    ),
    "Portrait de la jeune fille en feu": (
        "A painter must complete a young woman's portrait as a forbidden passion slowly grows. "
        "Hurray for lesbians!"
    ),
    "BlacKkKlansman": (
        "In the 1970s, a Black detective infiltrates the Ku Klux Klan by phone. "
        "He'll need a stand-in to go undercover…"
    ),
    "Much Ado About Nothing": (
        "Two couples flirt, spar, and fall in love in a Shakespearean comedy of misunderstandings "
        "worthy of a telenovela."
    ),
    "The Mummy": (
        "A mercenary with perfect hair and a clumsy librarian have awakened Imhotep's mummy. "
        "He's not very happy."
    ),
    "Lo que quisimos ser": (
        "Two strangers invent a love story to escape their reality, "
        "and end up blurring fiction and feeling."
    ),
    "Ocean's Eleven": (
        "A slick casino heist brings eleven pros together for a precision job at the heart of Las Vegas, "
        "set to funky jazz."
    ),
    "Everything Everywhere All at Once": (
        "A woman does her taxes, then saves the multiverse and her dysfunctional family across parallel realities. "
        "Kung fu, existential bagel: it's chaos, and it's magnificent."
    ),
    "Baahubali 2: The Conclusion": (
        "A mighty hero uncovers his royal past and launches an epic war to reclaim a stolen throne "
        "and avenge his lineage."
    ),
    "Intouchables": (
        "A quadriplegic aristocrat hires a caregiver from the projects who introduces him to (among other things) disco."
    ),
}

# (audio FR, audio EN, subtitles FR, subtitles EN)
_LANGUAGE_2026: dict[str, tuple[str, str, str, str]] = {
    "Back to the Future": ("Anglais", "English", "Français", "French"),
    "La Famille Bélier": ("Français", "French", "Anglais", "English"),
    "Billy Elliot": ("Anglais", "English", "Français", "French"),
    "Flow": ("Sans dialogue", "No dialogue", "Français", "French"),
    "Sauvages": ("Français", "French", "Anglais", "English"),
    "Love and Other Disasters": ("Anglais", "English", "Français", "French"),
    "Paddington": ("Anglais", "English", "Français", "French"),
    "Soirées courts-métrages": ("Variable", "Various", "Variable", "Various"),
    "I Am Not a Witch": ("Anglais", "English", "Français", "French"),
    "Singin' in the Rain": ("Anglais", "English", "Français", "French"),
    "Wadjda": ("Arabe", "Arabic", "Français", "French"),
    "The Girl Who Leapt Through Time": ("Japonais", "Japanese", "Français", "French"),
    "CHOREOKE": ("Multilingue", "Multilingual", "Paroles à l'écran", "On-screen lyrics"),
    "Jumanji: Welcome to the Jungle": ("Anglais", "English", "Français", "French"),
    "Bon Schuur Ticino (Ciao-ciao bourbine)": ("Multilingue", "Multilingual", "Français", "French"),
    "Portrait de la jeune fille en feu": ("Français", "French", "Anglais", "English"),
    "BlacKkKlansman": ("Anglais", "English", "Français", "French"),
    "Much Ado About Nothing": ("Anglais", "English", "Français", "French"),
    "The Mummy": ("Anglais", "English", "Français", "French"),
    "Lo que quisimos ser": ("Espagnol", "Spanish", "Français", "French"),
    "Ocean's Eleven": ("Anglais", "English", "Français", "French"),
    "Everything Everywhere All at Once": ("Anglais", "English", "Français", "French"),
    "Baahubali 2: The Conclusion": ("Tamoul", "Tamil", "Français", "French"),
    "Intouchables": ("Français", "French", "Anglais", "English"),
}


# Official 2026 programme (schema v3: legalAge + recommendedAge on each screening).
def build_template_2026(season_year: int = 2026) -> list[WeekSpec]:
    sunset_table = _load_sunset_times_2026()

    def f(title: str, month: int, day: int, **kwargs: Any) -> tuple[str, int, int, dict[str, Any]]:
        if title in _BLURB_EN_2026:
            kwargs.setdefault("blurb_en", _BLURB_EN_2026[title])
        if title in _LANGUAGE_2026:
            audio_fr, audio_en, subs_fr, subs_en = _LANGUAGE_2026[title]
            kwargs.setdefault("audio_language", audio_fr)
            kwargs.setdefault("audio_language_en", audio_en)
            kwargs.setdefault("subtitle_language", subs_fr)
            kwargs.setdefault("subtitle_language_en", subs_en)
        return _film_spec(title, month, day, sunset_table, season_year, **kwargs)

    return [
        (
            "w1",
            "9–12 juillet",
            [
                f(
                    "Back to the Future",
                    7,
                    9,
                    minutes=116,
                    legal_age=10,
                    blurb="Marty, propulsé en 1955 via une DeLorean, doit aider ses parents à se draguer pour ne pas disparaître du futur. Là où il va, il n'y a pas besoin de routes !",
                    poster_key="back-to-the-future",
                ),
                f(
                    "La Famille Bélier",
                    7,
                    10,
                    minutes=105,
                    legal_age=8,
                    recommended_age=12,
                    blurb="Paula, seule entendante d'une famille sourde, découvre sa voix et doit choisir entre chanter du Michel Sardou ou rester le pilier de sa famille.",
                    poster_key="la-famille-belier",
                ),
                f(
                    "Billy Elliot",
                    7,
                    11,
                    minutes=110,
                    legal_age=10,
                    recommended_age=12,
                    blurb="Un gamin fils de mineur découvre la danse et rêve de ballet plutôt que de gants de boxe.",
                    poster_key="billy-elliot",
                ),
                f(
                    "Flow",
                    7,
                    12,
                    minutes=85,
                    legal_age=6,
                    recommended_age=8,
                    blurb="Un chat se réveille dans un monde submergé et embarque sur un bateau avec d'autres animaux pour survivre à un déluge silencieux. L'Arche sans Noé.",
                    poster_key="flow",
                ),
            ],
        ),
        (
            "w2",
            "16–19 juillet",
            [
                f(
                    "Sauvages",
                    7,
                    16,
                    minutes=87,
                    legal_age=6,
                    recommended_age=8,
                    blurb="À Bornéo, une ado et un bébé orang-outan affrontent la déforestation et découvrent leur lien à la nature et aux autres.",
                    poster_key="sauvages",
                ),
                f(
                    "Love and Other Disasters",
                    7,
                    17,
                    minutes=90,
                    legal_age=7,
                    recommended_age=12,
                    blurb="Une assistante chez Vogue surestime son gaydar. Son meilleur ami homosexuel a un coup de foudre. S'ensuivent quiproquos romantiques et autres petits désastres…",
                    poster_key="love-and-other-disasters",
                ),
                f(
                    "Paddington",
                    7,
                    18,
                    minutes=95,
                    legal_age=0,
                    recommended_age=6,
                    blurb="Un ours péruvien débarque à Londres avec son chapeau, son amour de la marmelade et… sa maladresse. La patience de sa famille adoptive est mise à rude épreuve. Mais qui peut en vouloir à un ourson si poli ?",
                    poster_key="paddington",
                ),
                f(
                    "Soirées courts-métrages",
                    7,
                    19,
                    legal_age=16,
                    blurb="Sélection de courts métrages suisses et internationaux.",
                    poster_key="soiree-court-metrages",
                ),
            ],
        ),
        (
            "w3",
            "23–26 juillet",
            [
                f(
                    "I Am Not a Witch",
                    7,
                    23,
                    minutes=93,
                    legal_age=16,
                    blurb="Une fillette est accusée de sorcellerie et envoyée dans un camp, où elle doit survivre à un système absurde et cruel.",
                    poster_key="i-am-not-a-witch",
                ),
                f(
                    "Singin' in the Rain",
                    7,
                    24,
                    minutes=103,
                    legal_age=7,
                    blurb="Hollywood passe du muet au parlant, Gene Kelly danse sous la pluie, une starlette chante faux.",
                    poster_key="singin-in-the-rain",
                ),
                f(
                    "Wadjda",
                    7,
                    25,
                    minutes=98,
                    legal_age=10,
                    blurb="Une fillette saoudienne rêve de vélo interdit et défie les règles. Roule, Wadjda, roule !",
                    poster_key="wadjda",
                ),
                f(
                    "The Girl Who Leapt Through Time",
                    7,
                    26,
                    minutes=98,
                    legal_age=10,
                    blurb="Une ado découvre qu'elle peut remonter le temps. Qu'est-ce qui pourrait mal tourner ?",
                    poster_key="the-girl-who-leapt-through-time",
                ),
            ],
        ),
        (
            "w4",
            "30 juillet – 2 août",
            [
                f(
                    "CHOREOKE",
                    7,
                    30,
                    blurb="Chantez devant l'écran : tubes français et internationaux sous les étoiles.",
                    poster_key="soiree-choreoke",
                ),
                f(
                    "Jumanji: Welcome to the Jungle",
                    7,
                    31,
                    minutes=119,
                    legal_age=12,
                    blurb="Quatre ados coincés dans un jeu vidéo maudit doivent survivre dans une jungle pleine de pièges explosifs et de clichés ringards.",
                    poster_key="jumanji-welcome-to-the-jungle",
                ),
                f(
                    "Bon Schuur Ticino (Ciao-ciao bourbine)",
                    8,
                    1,
                    minutes=88,
                    legal_age=6,
                    recommended_age=10,
                    blurb="En Suisse, une initiative populaire absurde déclenche un chaos national entre régions qui ne se comprennent plus du tout. Grüezi !",
                    poster_key="bon-schuur-ticino",
                ),
                f(
                    "Portrait de la jeune fille en feu",
                    8,
                    2,
                    minutes=121,
                    legal_age=12,
                    recommended_age=16,
                    blurb="Une peintre doit réaliser le portrait d'une jeune femme, alors qu'une passion interdite naît progressivement. Bravo les lesbiennes !",
                    poster_key="portrait-de-la-jeune-fille-en-feu",
                ),
            ],
        ),
        (
            "w5",
            "6–9 août",
            [
                f(
                    "BlacKkKlansman",
                    8,
                    6,
                    minutes=135,
                    legal_age=12,
                    recommended_age=14,
                    blurb="Dans les années 70, un policier noir infiltre le Ku Klux Klan par téléphone. Il va avoir besoin d'une doublure pour aller sur le terrain…",
                    poster_key="blackkklansman",
                ),
                f(
                    "Much Ado About Nothing",
                    8,
                    7,
                    minutes=111,
                    legal_age=10,
                    blurb="Deux couples se cherchent, se provoquent et s'aiment dans une comédie shakespearienne de malentendus digne d'une telenovela.",
                    poster_key="much-ado-about-nothing",
                ),
                f(
                    "The Mummy",
                    8,
                    8,
                    minutes=125,
                    legal_age=12,
                    recommended_age=14,
                    blurb="Un mercenaire au brushing impeccable et une bibliothécaire maladroite ont réveillé la momie d'Imhotep. Il est pas très content.",
                    poster_key="the-mummy",
                ),
                f(
                    "Lo que quisimos ser",
                    8,
                    9,
                    minutes=90,
                    legal_age=7,
                    blurb="Deux inconnus inventent une histoire d'amour pour échapper à leur réalité, et finissent par brouiller fiction et sentiments.",
                    poster_key="lo-que-quisimos-ser",
                ),
            ],
        ),
        (
            "w6",
            "13–16 août",
            [
                f(
                    "Ocean's Eleven",
                    8,
                    13,
                    minutes=116,
                    legal_age=10,
                    recommended_age=14,
                    blurb="Un braquage de casino ultra stylé réunit onze pros du crime pour un casse millimétré au cœur de Las Vegas sur fond de jazz funky.",
                    poster_key="oceans-eleven",
                ),
                f(
                    "Everything Everywhere All at Once",
                    8,
                    14,
                    minutes=139,
                    legal_age=16,
                    blurb="Une dame fait sa compta, puis sauve le multivers et sa relation dysfonctionnelle avec sa famille à travers plusieurs réalités parallèles. Kung-fu, bagel existentiel : c'est n'importe quoi, et c'est magnifique.",
                    poster_key="everything-everywhere-all-at-once",
                ),
                f(
                    "Baahubali 2: The Conclusion",
                    8,
                    15,
                    minutes=167,
                    legal_age=16,
                    blurb="Un héros très balèze découvre son passé royal et lance une guerre épique pour reprendre un trône volé et venger sa lignée.",
                    search_title="Baahubali 2: The Conclusion",
                    poster_key="baahubali-2-the-conclusion",
                ),
                f(
                    "Intouchables",
                    8,
                    16,
                    minutes=112,
                    legal_age=10,
                    blurb="Un aristocrate tétraplégique engage un aide-soignant venu de banlieue qui lui fait découvrir (entre autres) le disco.",
                    poster_key="intouchables",
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
                    blurb_en=kwargs.get("blurb_en"),
                    search_title=kwargs.get("search_title"),
                    poster_key=kwargs.get("poster_key"),
                    legal_age=kwargs.get("legal_age"),
                    recommended_age=kwargs.get("recommended_age"),
                    sunset_at=kwargs.get("sunset_at"),
                    audio_language=kwargs.get("audio_language"),
                    audio_language_en=kwargs.get("audio_language_en"),
                    subtitle_language=kwargs.get("subtitle_language"),
                    subtitle_language_en=kwargs.get("subtitle_language_en"),
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
        "schemaVersion": 3,
        "seasonYear": season_year,
        "updatedAt": datetime.now(TZ).isoformat(timespec="seconds"),
        "weeks": weeks,
    }
