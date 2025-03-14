import os
import sys

from ocrd_utils import resource_filename

def cli():
    name = os.path.basename(sys.argv[0])
    script = resource_filename(__package__, name + '.sh')
    #os.environ["PATH"] = f"{resource}:{os.getenv('PATH')}"
    os.execv(script, sys.argv)

if __name__ == "__main__":
    cli()
