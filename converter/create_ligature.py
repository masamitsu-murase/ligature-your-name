
# See http://dmtr.org/ff.php

import pprint
import sys
import json
import fontforge
import psMat

# BASE_RESOURCE_FILE = "../resource/LigatureYourName.sfd"
# BOLD_BASE_RESOURCE_FILE = "../resource/LigatureYourNameBold.sfd"
BASE_RESOURCE_FILE = "../resource/LigatureYourNameTtf.sfd"
BOLD_BASE_RESOURCE_FILE = "../resource/LigatureYourNameTtfBold.sfd"

# Store ligatures in private area.
DEST_POS_START = 0xEA00
TEMP_POS = 0xE9FF

LIGATURE_SUBTABLE_NAME = "name_ligature-1"

DECORATE_NONE = 0
DECORATE_INVERSE = 1
DECORATE_BOTTOMLINE = 2
DECORATE_TOPLINE = 3
DECORATE_BOTHLINE = 4

def add_lookup(font):
    feature_tuple = (("liga", (("DFLT", ("dflt",)),
                               ("latn", ("dflt", "AZE ", "CRT ", "TRK ")),
                               ("grek", ("dflt",)),
                               ("cyrl", ("dflt",)),
                               ("hebr", ("dflt",)),
                               ("thai", ("dflt",)),
                               ("kana", ("dflt", "JAN ")),
                               ("hani", ("dflt",)),
                               ("math", ("dflt",)))),)
    font.addLookup("name_ligature", "gsub_ligature", (), feature_tuple)
    font.addLookupSubtable("name_ligature", LIGATURE_SUBTABLE_NAME)

def decorate(font, glyph, deco_type):
    ascent = font.ascent
    descent = font.descent
    height = ascent + descent
    width = glyph.width
    ratio = 0.95
    line_ratio = 0.1

    if deco_type in (DECORATE_INVERSE, DECORATE_BOTTOMLINE, DECORATE_TOPLINE, DECORATE_BOTHLINE):
        trans1 = psMat.translate((-width/2.0, -(ascent - descent)/2.0))
        scale = psMat.scale(ratio, ratio)
        trans2 = psMat.translate((width/2.0, (ascent - descent)/2.0))
        comp = psMat.compose(psMat.compose(trans1, scale), trans2)
        glyph.transform(comp)
        glyph.width = width

    if deco_type == DECORATE_INVERSE:
        pen = glyph.glyphPen(replace=False)
        pen.moveTo(0, ascent)
        pen.lineTo(width, ascent)
        pen.lineTo(width, -descent)
        pen.lineTo(0, -descent)
        pen.closePath()
    if deco_type in (DECORATE_BOTTOMLINE, DECORATE_BOTHLINE):
        pen = glyph.glyphPen(replace=False)
        pen.moveTo(0, -descent - height * line_ratio / 2)
        pen.lineTo(0, -descent + height * line_ratio / 2)
        pen.lineTo(width, -descent + height * line_ratio / 2)
        pen.lineTo(width, -descent - height * line_ratio / 2)
        pen.closePath()
    if deco_type in (DECORATE_TOPLINE, DECORATE_BOTHLINE):
        pen = glyph.glyphPen(replace=False)
        pen.moveTo(0, ascent + height * line_ratio / 2)
        pen.lineTo(width, ascent + height * line_ratio / 2)
        pen.lineTo(width, ascent - height * line_ratio / 2)
        pen.lineTo(0, ascent - height * line_ratio / 2)
        pen.closePath()
    glyph.correctDirection()

def create_ligature(font, bold_font, src_list, dest_pos, temp_pos, deco_type, bold):
    glyphname_list = []

    total_width = 0
    for src_char in src_list:
        base_font = font
        if bold:
            base_font = bold_font
        item = base_font.selection.select(("unicode",), src_char)
        glyph = next(iter(item.byGlyphs))
        glyphname_list.append(glyph.glyphname)
        width = glyph.width
        base_font.copy()

        font.selection.select(("unicode",), temp_pos)
        font.paste()

        trans = psMat.translate((total_width, 0))
        font.transform(trans)
        font.copy()

        font.selection.select(("unicode",), dest_pos)
        font.pasteInto()

        total_width += width

    glyph = next(iter(font.selection.select(("unicode",), dest_pos).byGlyphs))
    glyph.width = total_width
    glyph.addPosSub(LIGATURE_SUBTABLE_NAME, " ".join(glyphname_list))

    decorate(font, glyph, deco_type)

def convert(input_json_filename, output_filename):
    input_data = None
    with open(input_json_filename, "r") as input_json:
        input_data = json.load(input_json)

    font = fontforge.open(BASE_RESOURCE_FILE)
    bold_font = fontforge.open(BOLD_BASE_RESOURCE_FILE)

    add_lookup(font)

    for i, info in enumerate(input_data["ligature_list"]):
        ligature_code_points = tuple(ord(x) for x in info["ligature"])
        create_ligature(font, bold_font, ligature_code_points, DEST_POS_START + i, TEMP_POS, info["deco_type"], info["bold"])

    bold_font.close()
    bold_font = None

    next(iter(font.selection.select(("unicode",), TEMP_POS).byGlyphs)).clear()

    font.generate(output_filename, flags=("opentype",))
    font.close()

if __name__ == "__main__":
    convert(sys.argv[1], sys.argv[2])
