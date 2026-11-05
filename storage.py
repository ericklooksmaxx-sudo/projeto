"""Where the bot keeps its runtime data (credits, premium keys, giveaways, warnings, anti-raid settings).

Everything lives in ``data/`` next to the code. The folder is git-ignored, created on import, and is the
only thing that needs a volume/backup when the bot runs in a container.
"""
import os

DATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")
os.makedirs(DATA_DIR, exist_ok=True)


def data_path(name: str) -> str:
    """Absolute path of a data file inside ``data/``."""
    return os.path.join(DATA_DIR, name)
