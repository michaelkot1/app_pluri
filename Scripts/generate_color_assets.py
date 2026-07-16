#!/usr/bin/env python3
"""One-off generator for Pluri design-system color sets (design.md §2).

Regenerates every PluriColor asset in Assets.xcassets with light + dark
variants. Safe to re-run; it overwrites existing colorsets of the same name.
"""

import json
import pathlib

ASSETS = pathlib.Path(__file__).resolve().parent.parent / (
    "pluri_fable_xcode/Pluri/Assets.xcassets"
)

# name: (light hex, dark hex). Dark values are sensible inversions per M0-05;
# refine later.
COLORS = {
    # Brand
    "BrandOrange": ("FF5C39", "FF6E4D"),
    "BrandOrangeDeep": ("E8460F", "D9440F"),
    "BrandCoralSoft": ("FF7A59", "FF8A6C"),
    # Sunrise gradient
    "SunriseCore": ("F4A63B", "E09327"),
    "SunriseMid": ("F6C561", "C99A3E"),
    "SunriseEdge": ("F3E7C4", "3A3324"),
    # Status / activity path
    "StatusGreen": ("2FBF71", "3BD182"),
    "StatusGreenDeep": ("12A55A", "17B865"),
    "StatusRedSoft": ("F0553C", "F26A54"),
    "StatusBlue": ("7FA8F5", "8FB4F7"),
    # Heart-rate zones
    "Zone0": ("B9D4EA", "5B7891"),
    "Zone1": ("9FD9E6", "4E8794"),
    "Zone2": ("F6D97A", "C4A94F"),
    "Zone3": ("F4A85E", "C97F3B"),
    "Zone4": ("EF7C6B", "D96A5A"),
    "Zone5": ("C86BD8", "A94FBB"),
    # Accent surfaces
    "AccentPink": ("F26D82", "D95570"),
    "AccentLavender": ("EEEFF6", "2E2F3A"),
    # Neutrals
    "BgCanvas": ("FBFAF7", "1A1917"),
    "BgSurface": ("FFFFFF", "242220"),
    "BgMuted": ("F2F2F0", "2E2C2A"),
    "TextPrimary": ("1C1C1E", "F5F4F1"),
    "TextSecondary": ("6E6E73", "A8A8AD"),
    "TextTertiary": ("B0B0B5", "636368"),
    "LineDivider": ("ECECEC", "3A3A3C"),
}

def component(hex6: str) -> dict:
    return {
        "color-space": "srgb",
        "components": {
            "alpha": "1.000",
            "red": f"0x{hex6[0:2]}",
            "green": f"0x{hex6[2:4]}",
            "blue": f"0x{hex6[4:6]}",
        },
    }


def colorset(light: str, dark: str) -> dict:
    return {
        "colors": [
            {"color": component(light), "idiom": "universal"},
            {
                "appearances": [{"appearance": "luminosity", "value": "dark"}],
                "color": component(dark),
                "idiom": "universal",
            },
        ],
        "info": {"author": "xcode", "version": 1},
    }


def main() -> None:
    group = ASSETS / "PluriColors"
    group.mkdir(exist_ok=True)
    (group / "Contents.json").write_text(
        json.dumps({"info": {"author": "xcode", "version": 1}, "properties": {"provides-namespace": False}}, indent=2)
    )
    for name, (light, dark) in COLORS.items():
        directory = group / f"{name}.colorset"
        directory.mkdir(exist_ok=True)
        (directory / "Contents.json").write_text(json.dumps(colorset(light, dark), indent=2) + "\n")
    print(f"Wrote {len(COLORS)} colorsets to {group}")


if __name__ == "__main__":
    main()
