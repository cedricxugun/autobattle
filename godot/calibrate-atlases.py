"""Read-only alpha analysis. Writes frame metadata; never modifies artwork."""
from pathlib import Path
import json
import numpy as np
from PIL import Image

root = Path(__file__).parent / 'wanxiang'
result = {}
for path in sorted((root / 'assets/characters').glob('*.png')):
    actor_id = int(path.stem.split('-')[0])
    columns, rows = (3, 3) if actor_id >= 54 else (9, 3)
    alpha = np.array(Image.open(path).getchannel('A'))
    h, w = alpha.shape
    solid = alpha > 80
    def boundaries(density, length, count):
        cuts = [0]
        for index in range(1, count):
            expected = length * index / count
            radius = length / count * .23
            lo, hi = round(expected-radius), round(expected+radius)
            segment = density[lo:hi].astype(float)
            # Transparent gutters take precedence; distance breaks equal scores.
            score = segment + np.abs(np.arange(lo, hi)-expected)*.015
            cuts.append(int(lo+score.argmin()))
        return cuts + [length]
    ys = boundaries(solid.sum(axis=1), h, rows)
    rectangles = []
    for row in range(rows):
        top, bottom = ys[row:row+2]
        xs = boundaries(solid[top:bottom].sum(axis=0), w, columns)
        for col in range(columns):
            left, right = xs[col:col+2]
            yy, xx = np.where(alpha[top:bottom, left:right] > 40)
            if not len(xx):
                raise ValueError(f'Empty frame: {path.name}, {row}, {col}')
            x0, x1 = max(left, left+int(xx.min())-2), min(right, left+int(xx.max())+3)
            y0, y1 = max(top, top+int(yy.min())-2), min(bottom, top+int(yy.max())+3)
            rectangles.append([x0, y0, x1-x0, y1-y0])
    canvas = [max(r[2] for r in rectangles)+16, max(r[3] for r in rectangles)+20]
    result[path.name] = {'canvas': canvas, 'frames': rectangles, 'row_boundaries': ys}
(root/'data/atlas-layouts.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
print(f'Calibrated {len(result)} atlases, {sum(len(v["frames"]) for v in result.values())} populated frames. Original PNGs unchanged.')
