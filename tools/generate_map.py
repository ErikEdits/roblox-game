#!/usr/bin/env python3
"""NEON CITY map generator.

Writes Rojo `.model.json` files into src/Workspace/ so the city is visible in
Roblox Studio edit mode and ships inside the built place file.

Phase 1 art direction (see design doc section 5): simple shapes, strong
silhouettes, neon accents, few lights. Re-run after editing:

    python3 tools/generate_map.py
"""

import json
import math
import os
import random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "src", "Workspace")

random.seed(7)

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------

IDENTITY = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
VERTICAL = [[0, -1, 0], [1, 0, 0], [0, 0, 1]]  # cylinder axis (X) -> up


def yaw(deg):
    r = math.radians(deg)
    c, s = round(math.cos(r), 6), round(math.sin(r), 6)
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]


def rgb(r, g, b):
    return [round(r / 255, 4), round(g / 255, 4), round(b / 255, 4)]


# Palette
DARK = rgb(22, 22, 32)
ASPHALT = rgb(32, 32, 42)
CONCRETE = rgb(58, 56, 72)
PLAZA = rgb(52, 44, 82)
CYAN = rgb(0, 235, 255)
MAGENTA = rgb(255, 40, 200)
GOLD = rgb(255, 200, 60)
LIME = rgb(140, 255, 60)
ORANGE = rgb(255, 120, 30)
RED = rgb(255, 60, 60)
VIOLET = rgb(150, 80, 255)
WHITE = rgb(240, 240, 255)
GLASS = rgb(70, 190, 255)
GRASS = rgb(30, 70, 45)

NEONS = [CYAN, MAGENTA, GOLD, LIME, ORANGE, VIOLET]


def part(name, pos, size, color, material="SmoothPlastic", rot=None, cls="Part",
         attrs=None, children=None, **props):
    properties = {
        "Anchored": True,
        "Size": list(size),
        "CFrame": {"CFrame": {"position": list(pos), "orientation": rot or IDENTITY}},
        "Color": color,
        "Material": material,
        "TopSurface": "Smooth",
        "BottomSurface": "Smooth",
    }
    if material == "Neon" or props.pop("noshadow", False):
        properties["CastShadow"] = False
    properties.update(props)
    node = {"name": name, "className": cls, "properties": properties}
    if attrs:
        node["attributes"] = attrs
    if children:
        node["children"] = children
    return node


def cyl(name, pos, height, diameter, color, material="SmoothPlastic", **kw):
    return part(name, pos, (height, diameter, diameter), color, material, rot=VERTICAL,
                Shape="Cylinder", **kw)


def ball(name, pos, d, color, material="Neon", **kw):
    return part(name, pos, (d, d, d), color, material, Shape="Ball", **kw)


def label(text, face="Front", color=WHITE, ppu=20, font="GothamBlack"):
    return {
        "name": "Label",
        "className": "SurfaceGui",
        "properties": {
            "Face": face,
            "SizingMode": "PixelsPerStud",
            "PixelsPerStud": ppu,
            "LightInfluence": 0,
        },
        "children": [{
            "name": "Text",
            "className": "TextLabel",
            "properties": {
                "Size": {"UDim2": [[1, 0], [1, 0]]},
                "BackgroundTransparency": 1,
                "Text": text,
                "TextScaled": True,
                "TextColor3": color,
                "Font": font,
            },
        }],
    }


def light(brightness=2, rng=40, color=WHITE):
    return {"name": "Light", "className": "PointLight",
            "properties": {"Brightness": brightness, "Range": rng, "Color": color, "Shadows": False}}


def folder(name, children):
    return {"name": name, "className": "Folder", "children": children}


def model(name, children, attrs=None):
    node = {"name": name, "className": "Model", "children": children}
    if attrs:
        node["attributes"] = attrs
    return node


def walk(node):
    """Mark as walkable ground (keeps the Default collision group so NPCs walk on it)."""
    node.setdefault("attributes", {})["Walkable"] = True
    return node


def invisible(name, pos, size, attrs=None):
    return part(name, pos, size, WHITE, "SmoothPlastic", attrs=attrs, Transparency=1,
                CanCollide=False, CanTouch=False, CanQuery=False, CastShadow=False)


def building(name, center, size, body, accent, facing="S", sign=None, windows=True):
    """Decorative city building. facing = side the front points to (N=-Z, S=+Z, E=+X, W=-X)."""
    x, z = center
    w, h, d = size
    kids = [
        part("Body", (x, h / 2, z), (w, h, d), body),
        part("Roof", (x, h + 0.5, z), (w + 1, 1, d + 1), [c * 0.6 for c in body]),
        part("Band", (x, h * 0.85, z), (w + 0.6, 0.8, d + 0.6), accent, "Neon"),
    ]
    if windows:
        for i, fy in enumerate((0.35, 0.6)):
            kids.append(part("Windows%d" % i, (x, h * fy, z), (w + 0.3, h * 0.08, d + 0.3), GLASS, "Glass",
                             Transparency=0.35))
    if sign:
        offset = {"S": (0, d / 2 + 0.6), "N": (0, -d / 2 - 0.6), "E": (w / 2 + 0.6, 0), "W": (-w / 2 - 0.6, 0)}[facing]
        face = {"S": "Back", "N": "Front", "E": "Right", "W": "Left"}[facing]
        sw = min(w, d) * 0.8 if facing in ("E", "W") else w * 0.8
        ssize = (sw, h * 0.18, 1) if facing in ("S", "N") else (1, h * 0.18, sw)
        kids.append(part("Sign", (x + offset[0], h * 0.68, z + offset[1]), ssize, [c * 0.15 for c in accent],
                         children=[label(sign, face, accent)]))
    return model(name, kids)


def tower(name, x, z, w, d, h, accent):
    return model(name, [
        part("Body", (x, h / 2, z), (w, h, d), DARK),
        part("StripA", (x - w / 2 - 0.2, h / 2, z), (0.6, h * 0.9, 1.2), accent, "Neon"),
        part("StripB", (x + w / 2 + 0.2, h / 2, z), (0.6, h * 0.9, 1.2), accent, "Neon"),
        part("Crown", (x, h + 0.6, z), (w + 1, 1.2, d + 1), accent, "Neon"),
    ])


def lamp(name, x, z, h=14, color=GOLD, with_light=False):
    head_children = [light(2, 40, color)] if with_light else None
    return model(name, [
        part("Pole", (x, h / 2, z), (0.6, h, 0.6), rgb(60, 60, 70), "Metal"),
        ball("Head", (x, h + 0.8, z), 2, color, children=head_children),
    ])


def arch(name, x, z, text, color, along="X", width=52, height=30):
    """Gateway arch across a road. along = axis the beam spans."""
    kids = []
    if along == "X":
        kids.append(part("PillarL", (x - width / 2, height / 2, z), (4, height, 4), DARK))
        kids.append(part("PillarR", (x + width / 2, height / 2, z), (4, height, 4), DARK))
        kids.append(part("Beam", (x, height, z), (width + 4, 6, 3), [c * 0.15 for c in color],
                         children=[label(text, "Front", color), label(text, "Back", color)]))
        kids.append(part("Glow", (x, height - 3.3, z), (width + 4, 0.6, 3.4), color, "Neon"))
    else:
        kids.append(part("PillarL", (x, height / 2, z - width / 2), (4, height, 4), DARK))
        kids.append(part("PillarR", (x, height / 2, z + width / 2), (4, height, 4), DARK))
        kids.append(part("Beam", (x, height, z), (3, 6, width + 4), [c * 0.15 for c in color],
                         children=[label(text, "Right", color), label(text, "Left", color)]))
        kids.append(part("Glow", (x, height - 3.3, z), (3.4, 0.6, width + 4), color, "Neon"))
    return model(name, kids)


def kiosk(name, x, z, text, color, prompt):
    """Small booth with a ProximityPrompt target (the Counter part)."""
    return model(name, [
        part("Counter", (x, 2, z), (10, 4, 5), [c * 0.25 for c in color], attrs={"Prompt": prompt}),
        part("CounterGlow", (x, 4.1, z), (10.4, 0.3, 5.4), color, "Neon"),
        part("PostL", (x - 4.6, 5.5, z + 2), (0.6, 11, 0.6), DARK),
        part("PostR", (x + 4.6, 5.5, z + 2), (0.6, 11, 0.6), DARK),
        part("Canopy", (x, 11.2, z + 0.5), (11, 0.6, 7), DARK),
        part("SignBoard", (x, 13, z + 0.5), (11, 3, 1), [c * 0.15 for c in color],
             children=[label(text, "Front", color), label(text, "Back", color)]),
    ])


# ----------------------------------------------------------------------------
# Layout constants
# ----------------------------------------------------------------------------

PLOT_SIZE = 80
PLOT_X = 72
PLOT_ROWS = 8
PLOT_Z0 = -136
PLOT_STEP = 92
AVENUE_W = 40

TRACK_X = 220
TRACK_Z1 = 240
TRACK_Z2 = 560
TRACK_W = 36
START_X = -60

# ----------------------------------------------------------------------------
# City
# ----------------------------------------------------------------------------

ground = [
    walk(part("Ground", (0, -2, -60), (1700, 4, 1900), rgb(18, 18, 26), "Concrete")),
    walk(part("PlazaFloor", (0, 0, 0), (160, 0.6, 160), PLAZA, "Slate")),
    part("PlazaRim", (0, 0, 0), (163, 0.4, 163), MAGENTA, "Neon"),
    # Avenues (top at y = 0.2)
    walk(part("AvenueNorth", (0, 0, -460), (AVENUE_W, 0.4, 760), ASPHALT, "Asphalt")),
    walk(part("AvenueSouth", (0, 0, 151), (AVENUE_W, 0.4, 142), ASPHALT, "Asphalt")),
    walk(part("AvenueEast", (320, 0, 0), (480, 0.4, AVENUE_W), ASPHALT, "Asphalt")),
    walk(part("AvenueWest", (-270, 0, 0), (380, 0.4, AVENUE_W), ASPHALT, "Asphalt")),
    # Centre lines
    part("LineNorth", (0, 0.22, -460), (0.6, 0.05, 760), CYAN, "Neon"),
    part("LineSouth", (0, 0.22, 151), (0.6, 0.05, 142), RED, "Neon"),
    part("LineEast", (320, 0.22, 0), (480, 0.05, 0.6), MAGENTA, "Neon"),
    part("LineWest", (-270, 0.22, 0), (380, 0.05, 0.6), GOLD, "Neon"),
]

# --- Main Plaza -------------------------------------------------------------
plaza = [
    cyl("FountainBasin", (0, 1.8, 0), 3, 28, rgb(200, 200, 215), "Marble"),
    cyl("FountainWater", (0, 3.35, 0), 0.2, 25, rgb(0, 190, 255), "Glass", Transparency=0.3),
    cyl("FountainColumn", (0, 13, 0), 20, 4, rgb(200, 200, 215), "Marble"),
    cyl("FountainRing", (0, 3.4, 0), 0.3, 28.6, CYAN, "Neon"),
    part("CitySign", (0, 27, 0), (44, 8, 1.2), rgb(15, 5, 20),
         children=[label("NEON CITY", "Front", MAGENTA), label("NEON CITY", "Back", CYAN)]),
    part("CitySignGlow", (0, 22.6, 0), (46, 0.6, 1.6), MAGENTA, "Neon"),
    # Boards (runtime fills them with SurfaceGuis)
    part("LeaderboardBoard", (-64, 12, -10), (1, 18, 30), rgb(12, 10, 20)),
    part("LeaderboardFrame", (-64.3, 12, -10), (0.8, 19, 31), CYAN, "Neon"),
    part("LeaderboardPostA", (-64, 1.6, -22), (1, 3, 1), DARK),
    part("LeaderboardPostB", (-64, 1.6, 2), (1, 3, 1), DARK),
    part("EventBoard", (64, 12, -10), (1, 18, 30), rgb(12, 10, 20)),
    part("EventFrame", (64.3, 12, -10), (0.8, 19, 31), MAGENTA, "Neon"),
    part("EventPostA", (64, 1.6, -22), (1, 3, 1), DARK),
    part("EventPostB", (64, 1.6, 2), (1, 3, 1), DARK),
    kiosk("ShopKiosk", -45, 42, "SHOP", CYAN, "Shop"),
    kiosk("CardRushKiosk", 45, 42, "CARD RUSH", MAGENTA, "CardRush"),
    kiosk("TasksKiosk", -40, -52, "DAILY TASKS", LIME, "Tasks"),
    kiosk("BuildKiosk", 40, -52, "BUILD INFO", GOLD, "Build"),
    arch("ArchNorth", 0, -78, "RESORT DISTRICT", CYAN, "X"),
    arch("ArchSouth", 0, 78, "RACING DISTRICT", RED, "X"),
    arch("ArchEast", 78, 0, "ENTERTAINMENT", MAGENTA, "Z"),
    arch("ArchWest", -78, 0, "SHOPPING", GOLD, "Z"),
]
for i in range(8):
    a = math.radians(22.5 + i * 45)
    plaza.append(lamp("PlazaLamp%d" % i, round(math.cos(a) * 66, 2), round(math.sin(a) * 66, 2), 14,
                      NEONS[i % len(NEONS)], with_light=(i % 2 == 0)))

# --- Resort District decor -----------------------------------------------------
resort = []
for i in range(PLOT_ROWS):
    z = PLOT_Z0 - i * PLOT_STEP + PLOT_STEP / 2
    resort.append(lamp("AvenueLampW%d" % i, -23, z, 12, CYAN))
    resort.append(lamp("AvenueLampE%d" % i, 23, z, 12, MAGENTA))
resort.append(arch("HotelDistrictGate", 0, -842, "HOTEL DISTRICT", GOLD, "X"))
for i, (x, z, w, d, h) in enumerate([(-70, -890, 50, 40, 90), (70, -890, 50, 40, 110),
                                     (-150, -870, 40, 40, 70), (150, -870, 40, 40, 80),
                                     (0, -940, 60, 40, 140)]):
    resort.append(tower("HotelTower%d" % i, x, z, w, d, h, NEONS[i % len(NEONS)]))

# --- Entertainment District --------------------------------------------------
ent = [
    building("GrandNeon", (200, -95), (100, 40, 60), rgb(35, 15, 45), GOLD, "S", "THE GRAND NEON"),
    part("GrandNeonCanopy", (200, 12, -60), (40, 1.2, 10), GOLD, "Neon"),
    part("GrandNeonColumnA", (184, 6, -57), (1.6, 12, 1.6), GOLD, "Neon"),
    part("GrandNeonColumnB", (216, 6, -57), (1.6, 12, 1.6), GOLD, "Neon"),
    part("GrandNeonDoor", (200, 5, -64.8), (14, 10, 0.6), rgb(20, 20, 35), "Glass", Transparency=0.2),
    model("CardRushMachine", [
        part("Cabinet", (200, 4, -42), (7, 8, 3.5), rgb(40, 10, 50), attrs={"Prompt": "CardRush"}),
        part("Screen", (200, 5, -40.2), (5.6, 3.6, 0.2), MAGENTA, "Neon"),
        part("Marquee", (200, 8.8, -42), (7.4, 1.8, 3.9), rgb(20, 5, 25),
             children=[label("CARD RUSH", "Back", MAGENTA)]),
    ]),
    building("ArcadeHall", (335, -85), (50, 20, 40), rgb(30, 20, 60), LIME, "S", "ARCADE"),
    building("NeonCinema", (460, -90), (60, 26, 50), rgb(40, 15, 30), RED, "S", "CINEMA"),
    building("ClubHelix", (200, 95), (60, 22, 50), rgb(20, 20, 55), VIOLET, "N", "CLUB HELIX"),
]
for i, x in enumerate(range(120, 541, 60)):
    ent.append(lamp("EastLampN%d" % i, x, -23, 12, MAGENTA, with_light=(i % 3 == 0)))
    ent.append(lamp("EastLampS%d" % i, x, 23, 12, CYAN))
for i, (x, z) in enumerate([(120, 150), (280, -150), (540, 60), (540, -150)]):
    ent.append(tower("SignTower%d" % i, x, z, 14, 14, 60 + i * 10, NEONS[(i + 1) % len(NEONS)]))

# --- Racing District ----------------------------------------------------------
racing = [
    walk(part("TrackNorth", (0, 0, TRACK_Z1), (2 * TRACK_X + TRACK_W, 0.4, TRACK_W), rgb(28, 28, 36), "Asphalt")),
    walk(part("TrackSouth", (0, 0, TRACK_Z2), (2 * TRACK_X + TRACK_W, 0.4, TRACK_W), rgb(28, 28, 36), "Asphalt")),
    walk(part("TrackWest", (-TRACK_X, 0, (TRACK_Z1 + TRACK_Z2) / 2),
              (TRACK_W, 0.4, TRACK_Z2 - TRACK_Z1 - TRACK_W), rgb(28, 28, 36), "Asphalt")),
    walk(part("TrackEast", (TRACK_X, 0, (TRACK_Z1 + TRACK_Z2) / 2),
              (TRACK_W, 0.4, TRACK_Z2 - TRACK_Z1 - TRACK_W), rgb(28, 28, 36), "Asphalt")),
    walk(part("Infield", (0, 0, (TRACK_Z1 + TRACK_Z2) / 2),
              (2 * TRACK_X - TRACK_W, 0.3, TRACK_Z2 - TRACK_Z1 - TRACK_W), GRASS, "Grass")),
]
inner_x = TRACK_X - TRACK_W / 2
inner_z1, inner_z2 = TRACK_Z1 + TRACK_W / 2, TRACK_Z2 - TRACK_W / 2
outer_x = TRACK_X + TRACK_W / 2
outer_z1, outer_z2 = TRACK_Z1 - TRACK_W / 2, TRACK_Z2 + TRACK_W / 2
wall_h = 3
walls = [
    ("InnerN", (0, inner_z1 + 0.5), (2 * inner_x, 1)),
    ("InnerS", (0, inner_z2 - 0.5), (2 * inner_x, 1)),
    ("InnerW", (-inner_x + 0.5, (TRACK_Z1 + TRACK_Z2) / 2), (1, inner_z2 - inner_z1)),
    ("InnerE", (inner_x - 0.5, (TRACK_Z1 + TRACK_Z2) / 2), (1, inner_z2 - inner_z1)),
    ("OuterS", (0, outer_z2 + 0.5), (2 * outer_x + 2, 1)),
    ("OuterW", (-outer_x - 0.5, (TRACK_Z1 + TRACK_Z2) / 2), (1, outer_z2 - outer_z1 + 2)),
    ("OuterE", (outer_x + 0.5, (TRACK_Z1 + TRACK_Z2) / 2), (1, outer_z2 - outer_z1 + 2)),
    ("OuterNW", ((-outer_x - 24) / 2, outer_z1 - 0.5), (outer_x - 24, 1)),
    ("OuterNE", ((outer_x + 24) / 2, outer_z1 - 0.5), (outer_x - 24, 1)),
]
for i, (name, (x, z), (sx, sz)) in enumerate(walls):
    racing.append(part("Wall" + name, (x, wall_h / 2, z), (sx, wall_h, sz), RED if i % 2 == 0 else WHITE, "Neon"))

checkpoints = [(100, TRACK_Z1), (TRACK_X, 400), (0, TRACK_Z2), (-TRACK_X, 400), (START_X, TRACK_Z1)]
for i, (x, z) in enumerate(checkpoints):
    along_x = z in (TRACK_Z1, TRACK_Z2)  # gate spans the track width
    color = MAGENTA if i == len(checkpoints) - 1 else CYAN
    text = "FINISH" if i == len(checkpoints) - 1 else "CHECKPOINT %d" % (i + 1)
    if along_x:
        racing.append(arch("Gate%d" % (i + 1), x, z, text, color, "Z", width=TRACK_W + 4, height=16))
    else:
        racing.append(arch("Gate%d" % (i + 1), x, z, text, color, "X", width=TRACK_W + 4, height=16))
# Start / finish line stripes
for i in range(6):
    racing.append(part("StartStripe%d" % i, (START_X, 0.22, TRACK_Z1 - 15 + i * 6), (3, 0.05, 3),
                       WHITE if i % 2 == 0 else DARK))
racing += [
    building("PitGarage", (-120, 180), (70, 16, 34), rgb(40, 40, 48), RED, "S", "PIT GARAGE"),
    model("Grandstand", [
        part("Step1", (120, 1.5, 200), (80, 3, 8), CONCRETE),
        part("Step2", (120, 3.5, 207), (80, 7, 6), CONCRETE),
        part("Step3", (120, 5.5, 213), (80, 11, 6), CONCRETE),
        part("Roof", (120, 16, 208), (84, 1, 20), DARK),
        part("RoofGlow", (120, 15.4, 198.4), (84, 0.6, 0.8), RED, "Neon"),
        part("RoofPostA", (80, 8, 216), (1, 16, 1), DARK),
        part("RoofPostB", (160, 8, 216), (1, 16, 1), DARK),
    ]),
]

# --- Shopping District -------------------------------------------------------
shop = [
    building("NeonMall", (-180, -80), (80, 24, 50), rgb(30, 25, 50), CYAN, "S", "NEON MALL"),
    building("Boutique", (-180, 70), (50, 16, 40), rgb(45, 25, 40), MAGENTA, "N", "BOUTIQUE"),
    building("SkyBank", (-420, -90), (50, 50, 40), rgb(25, 30, 45), GOLD, "S", "SKY BANK"),
]
# VIP Lounge: hollow room with a VIP-only door (client unlocks it for VIP owners)
lx, lz, lw, ld, lh = -300, -75, 50, 40, 16
front = lz + ld / 2
vip_children = [
    walk(part("Floor", (lx, 0.3, lz), (lw, 0.6, ld), rgb(40, 30, 20), "Wood")),
    part("WallBack", (lx, lh / 2, lz - ld / 2), (lw, lh, 1), rgb(25, 20, 15)),
    part("WallLeft", (lx - lw / 2, lh / 2, lz), (1, lh, ld), rgb(25, 20, 15)),
    part("WallRight", (lx + lw / 2, lh / 2, lz), (1, lh, ld), rgb(25, 20, 15)),
    part("WallFrontL", (lx - (lw / 4 + 2), lh / 2, front), (lw / 2 - 4, lh, 1), rgb(25, 20, 15)),
    part("WallFrontR", (lx + (lw / 4 + 2), lh / 2, front), (lw / 2 - 4, lh, 1), rgb(25, 20, 15)),
    part("WallFrontTop", (lx, lh - 3, front), (8, 6, 1), rgb(25, 20, 15)),
    part("Roof", (lx, lh + 0.5, lz), (lw + 1, 1, ld + 1), rgb(20, 16, 12)),
    part("RoofGlow", (lx, lh - 0.2, lz), (lw + 1.4, 0.6, ld + 1.4), GOLD, "Neon"),
    part("VIPDoor", (lx, 5, front), (8, 10, 0.8), GOLD, "Glass", Transparency=0.3,
         attrs={"VIPDoor": True}, children=[label("VIP ONLY", "Back", WHITE)]),
    part("Sign", (lx, lh + 3, front), (24, 4, 1), rgb(25, 18, 5), children=[label("VIP LOUNGE", "Back", GOLD)]),
    part("SofaA", (lx - 14, 1.6, lz - 8), (14, 2, 5), rgb(120, 20, 60)),
    part("SofaB", (lx + 14, 1.6, lz - 8), (14, 2, 5), rgb(120, 20, 60)),
    part("Bar", (lx, 2.1, lz - 15), (22, 3.6, 3), rgb(30, 20, 10)),
    part("BarGlow", (lx, 4, lz - 15), (22.4, 0.3, 3.4), GOLD, "Neon"),
    ball("Chandelier", (lx, lh - 3, lz), 3, GOLD, children=[light(2, 30, GOLD)]),
]
shop.append(model("VIPLounge", vip_children))
shop.append(model("TrainStation", [
    walk(part("Platform", (-440, 1, 70), (40, 2, 60), CONCRETE, "Concrete")),
    part("Canopy", (-440, 14, 70), (44, 1, 64), DARK),
    part("CanopyGlow", (-440, 13.4, 70), (44.4, 0.4, 64.4), CYAN, "Neon"),
    part("PostA", (-458, 7, 45), (1, 12, 1), DARK),
    part("PostB", (-422, 7, 45), (1, 12, 1), DARK),
    part("PostC", (-458, 7, 95), (1, 12, 1), DARK),
    part("PostD", (-422, 7, 95), (1, 12, 1), DARK),
    part("Sign", (-440, 17, 38), (30, 4, 1), rgb(5, 15, 20), children=[label("TRAIN STATION", "Front", CYAN), label("TRAIN STATION", "Back", CYAN)]),
    part("Rail", (-470, 0.4, 70), (4, 0.4, 200), rgb(80, 80, 90), "Metal"),
]))
for i, x in enumerate(range(-120, -441, -60)):
    shop.append(lamp("WestLampN%d" % i, x, -23, 12, GOLD))
    shop.append(lamp("WestLampS%d" % i, x, 23, 12, CYAN, with_light=(i % 3 == 1)))

# --- Skyline ---------------------------------------------------------------
skyline = []
spots = []
for i in range(34):
    a = (i / 34) * math.tau
    r = random.uniform(700, 780)
    x, z = math.cos(a) * r, math.sin(a) * r - 60
    if abs(x) < 240 and z < -600:
        continue  # keep the far end of the Resort / Hotel District clear
    spots.append((round(x, 1), round(z, 1)))
for i, (x, z) in enumerate(spots):
    w = random.choice([30, 40, 50])
    h = random.randint(80, 220)
    skyline.append(tower("Skyline%d" % i, x, z, w, w, h, random.choice(NEONS)))

city = folder("City", [
    folder("Ground", ground),
    folder("Plaza", plaza),
    folder("Resort", resort),
    folder("Entertainment", ent),
    folder("Racing", racing),
    folder("Shopping", shop),
    folder("Skyline", skyline),
])

# ----------------------------------------------------------------------------
# Plots
# ----------------------------------------------------------------------------
plots = []
index = 0
for row in range(PLOT_ROWS):
    z = PLOT_Z0 - row * PLOT_STEP
    for side in (-1, 1):
        index += 1
        x = side * PLOT_X
        facing = -90 if side < 0 else 90  # buildings' front (-Z local) points at the avenue
        sign_x = side * 28
        color = NEONS[index % len(NEONS)]
        plots.append(model("Plot%d" % index, [
            walk(part("Base", (x, 0, z), (PLOT_SIZE, 1, PLOT_SIZE), rgb(40, 40, 56), "Concrete")),
            part("Rim", (x, -0.1, z), (PLOT_SIZE + 2, 0.8, PLOT_SIZE + 2), color, "Neon"),
            part("SignPost", (sign_x, 1.5, z - 30), (0.8, 3, 0.8), DARK),
            part("Sign", (sign_x, 6.5, z - 30), (1, 7, 18), rgb(12, 10, 20),
                 children=[label("PLOT %d\nFREE" % index, "Right" if side < 0 else "Left", color, 25)]),
        ], attrs={"Index": index, "Facing": facing}))

# ----------------------------------------------------------------------------
# Race track data
# ----------------------------------------------------------------------------
path_points = [(START_X, TRACK_Z1), (180, TRACK_Z1), (TRACK_X, 280), (TRACK_X, 520), (180, TRACK_Z2),
               (-180, TRACK_Z2), (-TRACK_X, 520), (-TRACK_X, 280), (-180, TRACK_Z1)]
grid = []
for i in range(8):
    row, col = divmod(i, 2)
    grid.append(invisible("G%d" % (i + 1), (START_X - 16 - row * 16, 2, TRACK_Z1 - 9 + col * 18), (2, 2, 2)))
race = folder("RaceTrack", [
    folder("Checkpoints", [invisible("CP%d" % (i + 1), (x, 2, z), (2, 2, 2)) for i, (x, z) in enumerate(checkpoints)]),
    folder("Path", [invisible("W%d" % (i + 1), (x, 2, z), (2, 2, 2)) for i, (x, z) in enumerate(path_points)]),
    folder("Grid", grid),
    part("JoinPad", (40, 0.3, 190), (18, 0.6, 18), RED, "Neon", attrs={"Prompt": "Race", "RaceJoinPad": True},
         CanCollide=True),
    part("JoinSign", (40, 9, 200), (18, 5, 1), rgb(20, 5, 5),
         children=[label("STREET RACE", "Front", RED), label("STREET RACE", "Back", RED)]),
    part("JoinSignPost", (40, 3.3, 200), (1, 6.6, 1), DARK),
])

# ----------------------------------------------------------------------------
# Event areas
# ----------------------------------------------------------------------------
generators = []
for i, (x, z) in enumerate([(140, 50), (270, -40), (500, 50)]):
    generators.append(model("Generator%d" % (i + 1), [
        part("Body", (x, 3.5, z), (6, 7, 5), rgb(70, 72, 80), "DiamondPlate"),
        part("Status", (x, 7.3, z), (6.2, 0.6, 5.2), LIME, "Neon"),
        part("Sign", (x, 9.5, z), (6, 2, 0.4), rgb(10, 10, 10),
             children=[label("GENERATOR", "Front", GOLD), label("GENERATOR", "Back", GOLD)]),
    ]))
stage_x, stage_z = 400, 130
stage_lights = []
for i in range(10):
    stage_lights.append(part("L%d" % (i + 1), (stage_x - 36 + i * 8, 26, stage_z + 14), (5, 2, 1), NEONS[i % len(NEONS)], "Neon"))
concert = folder("Concert", [
    part("Stage", (stage_x, 2, stage_z), (80, 4, 30), rgb(25, 25, 35)),
    part("StageEdge", (stage_x, 4.05, stage_z - 15), (80, 0.2, 1), MAGENTA, "Neon"),
    part("BackWall", (stage_x, 15, stage_z + 16), (80, 30, 2), rgb(15, 12, 25),
         children=[label("LIVE", "Front", MAGENTA, 10)]),
    part("SpeakerL", (stage_x - 46, 8, stage_z), (8, 16, 8), DARK),
    part("SpeakerR", (stage_x + 46, 8, stage_z), (8, 16, 8), DARK),
    folder("Lights", stage_lights),
    invisible("CrowdZone", (stage_x, 10, 70), (90, 20, 80)),
])
event_areas = folder("EventAreas", [folder("Generators", generators), concert])

# ----------------------------------------------------------------------------
# NPC spawns, attractions, zones, teleports
# ----------------------------------------------------------------------------
npc_spawns = folder("NPCSpawns", [
    invisible("TrainStation", (-440, 2, 0), (4, 4, 4)),
    invisible("ResortBusStop", (0, 2, -830), (4, 4, 4)),
    invisible("EastGate", (540, 2, 0), (4, 4, 4)),
    invisible("RaceParking", (0, 2, 200), (4, 4, 4)),
    invisible("PlazaNorth", (0, 2, -60), (4, 4, 4)),
    invisible("PlazaEast", (60, 2, 0), (4, 4, 4)),
    invisible("PlazaWest", (-60, 2, 0), (4, 4, 4)),
])


def attraction(name, pos, types, weight):
    return invisible(name, (pos[0], 2, pos[1]), (4, 4, 4), attrs={"Types": types, "Weight": weight})


attractions = folder("Attractions", [
    attraction("PlazaFountain", (22, -22), "Tourist,Family,Event,Business", 2),
    attraction("GrandNeon", (200, -58), "Tourist,Luxury,Business", 4),
    attraction("Arcade", (335, -60), "Family,Tourist", 3),
    attraction("Cinema", (460, -60), "Tourist,Family,Event", 2),
    attraction("NeonMall", (-180, -50), "Tourist,Family,Luxury", 3),
    attraction("Boutique", (-180, 45), "Luxury,Tourist", 2),
    attraction("Grandstand", (120, 190), "Racer,Event", 4),
    attraction("PitGarage", (-120, 204), "Racer", 3),
])

zones = folder("Zones", [
    invisible("Plaza", (0, 20, 0), (170, 60, 170)),
    invisible("Resort District", (0, 20, -470), (260, 60, 770)),
    invisible("Entertainment District", (322, 20, 0), (475, 60, 440)),
    invisible("Racing District", (0, 20, 342), (520, 60, 515)),
    invisible("Shopping District", (-278, 20, 0), (385, 60, 400)),
])

teleports = folder("Teleports", [
    part("PadResort", (-30, 0.35, 62), (10, 0.3, 10), CYAN, "Neon", attrs={"Target": "Resort"},
         children=[label("MY RESORT", "Top", WHITE, 12)]),
    part("PadRacing", (0, 0.35, 66), (10, 0.3, 10), RED, "Neon", attrs={"Target": "Racing"},
         children=[label("RACING", "Top", WHITE, 12)]),
    part("PadEntertainment", (30, 0.35, 62), (10, 0.3, 10), MAGENTA, "Neon", attrs={"Target": "Entertainment"},
         children=[label("ARCADE", "Top", WHITE, 12)]),
])

spawn = {
    "className": "SpawnLocation",
    "properties": {
        "Anchored": True,
        "Size": [12, 1, 12],
        "CFrame": {"CFrame": {"position": [0, 0.3, 40], "orientation": IDENTITY}},
        "Color": CYAN,
        "Material": "Neon",
        "Transparency": 0.4,
        "Neutral": True,
        "Duration": 0,
        "TopSurface": "Smooth",
        "BottomSurface": "Smooth",
        "CanCollide": True,
    },
}


def write(name, node):
    node = dict(node)
    node.pop("name", None)
    path = os.path.join(OUT, name + ".model.json")
    with open(path, "w") as f:
        json.dump(node, f, indent=1)
    return path


def count_parts(node):
    n = 1 if node.get("className") in ("Part", "SpawnLocation") else 0
    for child in node.get("children", []):
        n += count_parts(child)
    return n


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    outputs = {
        "City": city, "Plots": folder("Plots", plots), "RaceTrack": race, "EventAreas": event_areas,
        "NPCSpawns": npc_spawns, "Attractions": attractions, "Zones": zones, "Teleports": teleports,
        "SpawnLocation": spawn,
    }
    total = 0
    for name, node in outputs.items():
        write(name, node)
        total += count_parts(node)
    print("Map written to %s (%d parts)" % (OUT, total))
