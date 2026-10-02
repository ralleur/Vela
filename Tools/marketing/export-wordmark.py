#!/usr/bin/env python3
"""Trace the approved installer lettering into a small, standalone SVG.

The two flat-color contours are taken from the approved wordmark, so the
website shares its letterforms. Requires Pillow for reading the source image.
"""
from collections import defaultdict
from pathlib import Path
from statistics import median
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
image = Image.open(ROOT / 'marketing/dmg/background@2x.png').convert('RGB')
region = (570, 96, 952, 235)


def simplify(points, tolerance=0.6):
    if len(points) <= 2:
        return points
    a, b = points[0], points[-1]
    dx, dy = b[0] - a[0], b[1] - a[1]
    length = (dx * dx + dy * dy) ** 0.5
    distances = [abs(dy * (x - a[0]) - dx * (y - a[1])) / length
                 if length else ((x - a[0]) ** 2 + (y - a[1]) ** 2) ** 0.5
                 for x, y in points]
    farthest = max(range(len(points)), key=lambda i: distances[i])
    if distances[farthest] <= tolerance:
        return [a, b]
    return simplify(points[:farthest + 1], tolerance)[:-1] + simplify(points[farthest:], tolerance)


def contours(pixels):
    edges = defaultdict(list)
    for x, y in sorted(pixels):
        for neighbor, start, end in (
            ((x, y - 1), (x, y), (x + 1, y)),
            ((x + 1, y), (x + 1, y), (x + 1, y + 1)),
            ((x, y + 1), (x + 1, y + 1), (x, y + 1)),
            ((x - 1, y), (x, y + 1), (x, y)),
        ):
            if neighbor not in pixels:
                edges[start].append(end)
    loops = []
    while edges:
        start = next(iter(edges))
        loop, current = [], start
        while True:
            loop.append(current)
            following = edges[current].pop()
            if not edges[current]:
                del edges[current]
            current = following
            if current == start:
                break
        area = abs(sum(a[0] * b[1] - b[0] * a[1]
                       for a, b in zip(loop, loop[1:] + loop[:1]))) / 2
        if area > 6:
            half = len(loop) // 2
            loops.append(simplify(loop[:half + 1])[:-1] + simplify(loop[half:] + loop[:1])[:-1])
    return loops


def path_for(loop):
    # Quadratic midpoint joins smooth sub-pixel raster stair steps.
    mids = [((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
            for a, b in zip(loop, loop[1:] + loop[:1])]
    path = f'M{mids[-1][0]:g},{mids[-1][1]:g}'
    for point, middle in zip(loop, mids):
        path += f'Q{point[0]:g},{point[1]:g} {middle[0]:g},{middle[1]:g}'
    return path + 'Z'


paths = []
for name, select, expected in (
    ('letters', lambda r, g, b: r > 190 and g > 190 and b > 180, 4),
    ('dot', lambda r, g, b: b > 180 and b > r * 1.3 and 70 < g < 190 and r < 170, 1),
):
    pixels = {(x, y) for y in range(region[1], region[3])
              for x in range(region[0], region[2]) if select(*image.getpixel((x, y)))}
    loops = contours(pixels)
    assert len(loops) == expected, f'Unexpected {name} contours: {len(loops)}; review source crop'
    color = '#' + ''.join(f'{int(median(image.getpixel(p)[c] for p in pixels)):02x}' for c in range(3))
    paths.append(f'  <path fill="{color}" fill-rule="evenodd" d="{"".join(path_for(loop) for loop in loops)}"/>')

svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="574 100 372 130" width="372" height="130">\n'
svg += '\n'.join(paths) + '\n</svg>\n'
for path in [ROOT / 'marketing/brand/vela-wordmark.svg', ROOT / 'website/assets/vela-wordmark.svg']:
    path.write_text(svg)
print(f'Exported approved Vela wordmark: {len(svg.encode())} bytes')
