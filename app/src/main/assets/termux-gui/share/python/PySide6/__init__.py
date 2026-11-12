"""PySide6 compatibility layer for Termux, built on top of PyQt6.

There are no PySide6 wheels for Android, but Termux ships PyQt6 (``pkg install pyqt6``). This
package lets the large majority of PySide6 programs run unchanged by mapping the PySide6 modules
to PyQt6 and smoothing over the API differences (``Signal``/``Slot``/``Property``, short enum names
such as ``Qt.AlignCenter`` and ``exec_()``).

It is only a compatibility layer: ``QUiLoader``, ``shiboken6`` and a few PySide-only APIs are not
available. It is never used when a real PySide6 is installed, because it lives in a separate
directory that comes last on ``sys.path``.
"""

try:
    from PyQt6.QtCore import PYQT_VERSION_STR as _pyqt_version
    from PyQt6.QtCore import QT_VERSION_STR as _qt_version
except ImportError as _error:  # pragma: no cover
    raise ImportError(
        "this PySide6 compatibility layer needs PyQt6, install it with: pkg install x11-repo && pkg install pyqt6"
    ) from _error

__version__ = _qt_version
__version_info__ = tuple(int(part) for part in _qt_version.split(".")[:3])
__compat__ = "PyQt6 " + _pyqt_version
__all__ = ["QtCore", "QtGui", "QtWidgets", "QtNetwork", "QtSvg", "QtSvgWidgets", "QtPrintSupport",
           "QtTest", "QtWebEngineCore", "QtWebEngineWidgets"]
