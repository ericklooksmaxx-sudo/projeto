"""PySide6.QtCore on top of PyQt6."""
from ._compat import reexport as _reexport

_module = _reexport(globals(), "QtCore")
Signal = _module.pyqtSignal
Slot = _module.pyqtSlot
Property = _module.pyqtProperty
__version__ = _module.QT_VERSION_STR
