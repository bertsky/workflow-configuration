import sys
import os
from difflib import unified_diff

import click
from lxml import etree as ET

from ocrd.decorators import ocrd_loglevel
from ocrd_utils import resource_filename, initLogging, getLogger
from ocrd_models.constants import NAMESPACES
from ocrd_models.utils import xmllint_format

NAME = os.path.basename(sys.argv[0])
XSL = resource_filename(__package__, NAME + '.xsl')
assert XSL.exists(), XSL

if NAME.startswith('page-'):
    TYPE = "PAGE"
elif NAME.startswith('mets-'):
    TYPE = "METS"
else:
    TYPE = "input"
HELP = f"""
\b
Open {TYPE} file XMLFILE (or stdin) and apply the XSL transformation "{XSL.name}"
Write the result to stdout, unless...
-i / --inplace is given - in which case the result is written back to the
                          file silently, or
-d / --diff is given    - in which case the result will be compared to the
                          input and a patch shown on stdout.
"""

@click.command(context_settings=dict(help_option_names=['-h', '--help']))
@ocrd_loglevel
@click.option('-s', '--string-param', multiple=True, metavar='NAME=VALUE', help='set param NAME to string literal VALUE')
@click.option('-p', '--xpath-param', multiple=True, metavar='NAME=VALUE', help='set param NAME to XPath expression VALUE')
@click.option('-i', '--inplace', is_flag=True, help='overwrite input file with result of transformation')
@click.option('-P', '--pretty', is_flag=True, help='pretty-print output (line breaks with indentation')
@click.option('-d', '--diff', is_flag=True, help='show diff between input and output via pager')
@click.option('-D', '--dump', is_flag=True, help='just print the transformation stylesheet (XSL)')
@click.argument('xmlfile', type=click.Path(dir_okay=False, allow_dash=True), required=False)
def cli(log_level, string_param, xpath_param, inplace, pretty, diff, dump, xmlfile):
    if dump:
        click.echo(open(XSL).read())
        sys.exit(0)
    initLogging()
    LOG = getLogger("ocrd.xsl_transform")
    LOG.info("parsing xsl='%s'", str(XSL))
    xsl = ET.parse(XSL)
    xslt = ET.XSLT(xsl)
    xsltparams = dict()
    for setting in string_param:
        key, val = setting.split('=')
        xsltparams[key] = "'%s'" % val
    for setting in xpath_param:
        key, val = setting.split('=')
        xsltparams[key] = ET.XPath("'%s'" % val, namespaces={
            'page': NAMESPACES['page'],
            'pc': NAMESPACES['page'],
            'mets': NAMESPACES['mets']})
    if not xmlfile or xmlfile == '-':
        xmlinput = sys.stdin.read()
    else:
        xmlinput = open(xmlfile).read()
    # ET.parse(xmlfile)
    result = xslt(ET.fromstring(xmlinput.encode("utf-8")), **xsltparams)
    for error in xslt.error_log:
        LOG.error(error)
    if result.getroot() is None:
        # plain xsl:output
        ret = str(result)
    else:
        root = result.getroot()
        ret = ET.tostring(ET.ElementTree(root), pretty_print=True, encoding='UTF-8')
        if pretty:
            ret = xmllint_format(ret)
        ret = ret.decode('utf-8')
    if diff:
        if pretty:
            xmlinput = xmllint_format(xmlinput.encode('utf-8')).decode('utf-8')
        click.echo_via_pager(unified_diff(xmlinput.split('\n'), ret.split('\n')))
    elif inplace:
        assert xmlfile and xmlfile != '-'
        with open(xmlfile, 'w') as output:
            output.write(ret)
    else:
        click.echo(ret)


cli.help = HELP
