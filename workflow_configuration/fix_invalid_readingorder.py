import click
import shutil
import sys

from lxml import etree

from ocrd_models.constants import NAMESPACES
from ocrd_models.utils import xmllint_format
from ocrd_validators import PageValidator
from ocrd_validators.page_validator import ReadingOrderInvalidError


@click.command(context_settings=dict(help_option_names=['-h', '--help']))
@click.argument('pagefile', type=click.Path(exists=True, dir_okay=False))
@click.option('-I', '--inplace', is_flag=True, default=False, help="Write result back to input file intead of stdout")
@click.option('-B', '--backup', default='', help="Write a copy of the original file under this suffix")
def cli(pagefile, inplace, backup):
    """Remove invalid references from the ReadingOrder."""

    report = PageValidator.validate(filename=pagefile)
    if report.is_valid:
        print("Nothing to do, page validation found no ReadingOrder issues.", file=sys.stderr)
        return

    with click.open_file(pagefile, 'rb') as page:
        tree = etree.parse(page)

    for err in report.errors:
        if isinstance(err, ReadingOrderInvalidError):
            ref = tree.find(f'//*[@regionRef="{err.region_ref}"]', namespaces=NAMESPACES)
            ref.getparent().remove(ref)
    
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
