# -*- coding: utf-8 -*-
from __future__ import absolute_import

import sys
import shutil
import click
import re

from urllib.request import urlopen
from lxml import etree

@click.command()
@click.argument('pagefile', type=click.Path(exists=True, dir_okay=False))
@click.option('-I', '--inplace', is_flag=True, default=False, help="Write result back to input file intead of stdout")
@click.option('-B', '--backup', default='', help="Write a copy of the original file under this suffix")
def cli(pagefile, inplace, backup):
    """Fix coordinates in PAGE-XML by setting negative points to zero."""

    with click.open_file(pagefile, 'rb') as page:
        tree = etree.parse(page)
    
    def page_namespace(tree):
        rootname = etree.QName(tree.getroot().tag)
        assert rootname.localname == 'PcGts', "not a PAGE content XML file"
        return rootname.namespace

    ns = {'pc': page_namespace(tree),
          'xlink' : "http://www.w3.org/1999/xlink",
          're' : "http://exslt.org/regular-expressions"}
    
    for coords in tree.getroot().xpath('//pc:Coords/@points[contains(.,"-")]/..', namespaces=ns):
        points = coords.attrib['points']
        points = [pair.split(',') for pair in points.split(' ')]
        points = " ".join('%i,%i' % (max(0, int(x)), max(0, int(y))) for x,y in points)
        coords.attrib['points'] = points
    
    result = etree.tostring(etree.ElementTree(tree.getroot()), pretty_print=True, encoding='UTF-8')
    
    if inplace:
        if backup:
            shutil.copyfile(pagefile, pagefile + backup)
        with click.open_file(pagefile, 'wb') as page:
            page.write(result)
    else:
        sys.stdout.buffer.write(result)

if __name__ == '__main__':
    cli()
