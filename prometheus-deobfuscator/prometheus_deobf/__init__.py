"""Static deobfuscator for the Prometheus Lua obfuscator."""

from .deobfuscate import deobfuscate, deobfuscate_ast

__all__ = ["deobfuscate", "deobfuscate_ast"]
__version__ = "1.0.0"
