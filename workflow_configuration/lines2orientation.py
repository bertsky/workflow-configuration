# -*- coding: utf-8 -*-
from __future__ import absolute_import

import sys
import shutil
import click
import re
from hashlib import md5

from urllib.request import urlopen
from lxml import etree

from shapely.geometry import Polygon
from shapely import linestrings
import numpy as np

from ocrd_utils import polygon_from_points, points_from_polygon
from ocrd_models.utils import xmllint_format

SIMPLIFY = 5

@click.command(context_settings=dict(help_option_names=['-h', '--help']))
@click.argument('pagefile', type=click.Path(exists=True, dir_okay=False))
@click.option('-I', '--inplace', is_flag=True, default=False, help="Write result back to input file intead of stdout")
@click.option('-B', '--backup', default='', help="Write a copy of the original file under this suffix")
def cli(pagefile, inplace, backup):
    """Retrieve lines from all paragraphs and geometrically determine their average skew."""

    with click.open_file(pagefile, 'rb') as page:
        tree = etree.parse(page)
    
    def page_namespace(tree):
        rootname = etree.QName(tree.getroot().tag)
        assert rootname.localname == 'PcGts', "not a PAGE content XML file"
        return rootname.namespace

    ns = {'pc': page_namespace(tree),
          'xlink' : "http://www.w3.org/1999/xlink",
          're' : "http://exslt.org/regular-expressions"}

    paragraphs = [region
                  for region in tree.getroot().xpath('//pc:TextRegion', namespaces=ns)
                  if (region.get('type', 'paragraph') == 'paragraph' and
                      len(region.findall('pc:TextLine', ns)) >= 2)]
    all_angles = []
    for paragraph in paragraphs:
        polygons = [Polygon(polygon_from_points(points)) for points in
                    paragraph.xpath('//pc:TextLine/pc:Coords/@points', namespaces=ns)]
        angles = []
        for polygon in polygons:
            coords = list(polygon.oriented_envelope.normalize().exterior.coords)
            # normalize() → documentation says this starts at lower left and runs clockwise.
            # But our y coordinate is inverted, so this would be the upper left and counter-cw.
            # However, the "lower left" criterion itself is unreliable (often incorrect).
            # So intead of making assumptions to know which edge is the baseline and which is
            # the side that could easily break for short lines (if based purely on length),
            # let's always take the longer side, and exclude it if it deviates too much from
            # the other lines in this region.
            l1, l2 = linestrings((coords[0:2], coords[1:3]))
            assert l1.length and l2.length, (coords, polygon.wkt, paragraph.get('id'))
            if l1.length > l2.length:
                l2, l1 = l1, l2
            if l2.length < l1.length * 3:
                #print("skipping line with ratio", l2.length / l1.length, "in paragraph", paragraph.get('id'), file=sys.stderr)
                continue
            xd, yd = np.diff(l2.coords, axis=0).squeeze()
            angles.append((l2.length, np.arctan(yd / xd) / np.pi * 180))
        if not len(angles):
            continue
        angles = np.array(angles)
        lengths = angles[:, 0]
        angles = angles[:, 1]
        lengths_dev = lengths / np.median(lengths)
        angles = angles[(0.67 <= lengths_dev) & (lengths_dev <= 1.33)]
        angles_dev = np.abs(angles - np.median(angles))
        angles = angles[angles_dev <= 2 * np.median(angles_dev)]
        #print(len(angles), np.mean(angles), np.std(angles), file=sys.stderr)
        all_angles.extend(angles)
    #print(len(all_angles), np.mean(all_angles), np.std(all_angles), file=sys.stderr)

    page = tree.getroot().find('pc:Page', ns)
    assert not page.get('orientation', ''), page.get('orientation', '')
    if len(all_angles):
        val = str(round(float(-np.mean(all_angles)), 3))
        page.set('orientation', val)

    result = etree.tostring(etree.ElementTree(tree.getroot()), pretty_print=True, encoding='UTF-8')
    result = xmllint_format(result)
    
    if inplace:
        if backup:
            shutil.copyfile(pagefile, pagefile + backup)
        with click.open_file(pagefile, 'wb') as page:
            page.write(result)
    else:
        sys.stdout.buffer.write(result)

if __name__ == '__main__':
    cli()
