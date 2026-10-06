#!/usr/bin/env python3
"""Rebuild assets/fonts/noto_sans_cjk_subset.otf from the locale table.

The web build has no system fonts, so CJK text needs a bundled font. Shipping
all of Noto Sans CJK would add ~16 MB; subsetting to the glyphs the locale
table actually uses keeps it ~250 KB. Re-run after editing locale_table.csv:

    pip install fonttools && python3 tools/gen_font_subset.py
"""
from fontTools import subset
from fontTools.ttLib import TTCollection

SRC = "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc"  # fonts-noto-cjk
OUT = "assets/fonts/noto_sans_cjk_subset.otf"

idx = next(i for i, f in enumerate(TTCollection(SRC).fonts)
           if f["name"].getDebugName(1) == "Noto Sans CJK TC")
text = open("src/locale/locale_table.csv", encoding="utf-8").read()
chars = set(text) | {chr(i) for i in range(32, 127)} | set("←↑→↓·×%：（）、。！？「」—…")
opts = subset.Options()
opts.font_number = idx
opts.layout_features = ["*"]
opts.notdef_outline = True
font = subset.load_font(SRC, opts)
sub = subset.Subsetter(opts)
sub.populate(text="".join(chars))
sub.subset(font)
subset.save_font(font, OUT, opts)
print(f"wrote {OUT}")
