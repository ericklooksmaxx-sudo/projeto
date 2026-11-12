"""Helpers for the PySide6 compatibility layer (see __init__.py)."""

import enum
import importlib


def promote_enums(module):
    """Make scoped PyQt6 enum members available on their class, like PySide6 does.

    PyQt6 only accepts ``Qt.AlignmentFlag.AlignCenter`` while PySide6 code very often uses the
    short form ``Qt.AlignCenter``. This copies every enum member to the class that defines the enum
    (``QMessageBox.Yes``, ``QSizePolicy.Expanding``, ...) unless the name is already taken.
    """
    for _, cls in list(vars(module).items()):
        if not isinstance(cls, type):
            continue
        try:
            members = list(vars(cls).items())
        except TypeError:
            continue
        for _, value in members:
            if isinstance(value, type) and issubclass(value, enum.Enum):
                # __members__ (not iteration) also contains aliases and combined flags such as
                # Qt.AlignCenter, which Flag enums skip when iterated.
                for name, member in value.__members__.items():
                    if not hasattr(cls, name):
                        try:
                            setattr(cls, name, member)
                        except (TypeError, AttributeError):
                            break


def add_exec_aliases(module):
    """PySide6 still accepts ``exec_()``, PyQt6 removed it in favour of ``exec()``."""
    for _, cls in list(vars(module).items()):
        if isinstance(cls, type) and hasattr(cls, "exec") and not hasattr(cls, "exec_"):
            try:
                setattr(cls, "exec_", getattr(cls, "exec"))
            except (TypeError, AttributeError):
                pass


def reexport(namespace, qt_module):
    """Copy the public names of ``PyQt6.<qt_module>`` into ``namespace`` and fix PySide6 differences."""
    module = importlib.import_module("PyQt6." + qt_module)
    for name in dir(module):
        if not name.startswith("_"):
            namespace[name] = getattr(module, name)
    promote_enums(module)
    add_exec_aliases(module)
    return module
