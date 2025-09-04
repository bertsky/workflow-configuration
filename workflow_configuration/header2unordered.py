# -*- coding: utf-8 -*-
from __future__ import absolute_import

import sys
import shutil
import click
import re

from urllib.request import urlopen
from lxml import etree

from ocrd_models.utils import xmllint_format

@click.command(context_settings=dict(help_option_names=['-h', '--help']))
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

    textregiontypes = {reg.get('id'): reg.get('type', '')
                       for reg in tree.getroot().xpath('//pc:TextRegion', namespaces=ns)}

    orderedgroup = tree.getroot().xpath('/pc:PcGts/pc:Page/pc:ReadingOrder/pc:OrderedGroup', namespaces=ns)
    assert orderedgroup is not None, "file %s has no existing ReadingOrder" % pagefile
    orderedgroup = orderedgroup[0]

    orderedgrouprefs = sorted(orderedgroup.findall('pc:RegionRefIndexed', ns),
                              key=lambda ref: int(ref.get('index')))
    orderedgrouprefs = [ref.get('regionRef') for ref in orderedgrouprefs]
    unorderedgroup = etree.SubElement(orderedgroup.getparent(), '{%s}UnorderedGroup' % ns['pc'])
    unorderedgroup.set('id', orderedgroup.get('id'))
    orderedgroup.getparent().remove(orderedgroup)

    orderedgroup = None
    index = 0
    for rid in orderedgrouprefs:
        if textregiontypes[rid] == 'header':
            orderedgroup = etree.SubElement(unorderedgroup, '{%s}OrderedGroup' % ns['pc'])
            orderedgroup.set('id', rid + '_group')
            index = 0
        if orderedgroup is None:
            ref = etree.SubElement(unorderedgroup, '{%s}RegionRef' % ns['pc'])
            ref.set('regionRef', rid)
        else:
            ref = etree.SubElement(orderedgroup, '{%s}RegionRefIndexed' % ns['pc'])
            ref.set('regionRef', rid)
            ref.set('index', str(index))
            index += 1
    
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
