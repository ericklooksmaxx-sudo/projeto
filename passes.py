import json
import os
import time
import secrets
import string
from typing import Dict, Any, List, Tuple, Optional

from storage import data_path

KEYS_DB = data_path("passes.json")

def _generate_token() -> str:
    alphabet = string.ascii_uppercase + string.digits
    part1 = ''.join(secrets.choice(alphabet) for _ in range(4))
    part2 = ''.join(secrets.choice(alphabet) for _ in range(4))
    part3 = ''.join(secrets.choice(alphabet) for _ in range(4))
    return f"PREM-{part1}-{part2}-{part3}"

class KeyManager:
    def __init__(self, db_path: str = KEYS_DB):
        self.db_path = db_path
        self.keys: Dict[str, Dict[str, Any]] = {}
        self._load()

    def _load(self):
        if os.path.isfile(self.db_path):
            try:
                with open(self.db_path, "r", encoding="utf-8") as f:
                    self.keys = json.load(f)
            except Exception as e:
                print(f"[KeyManager] Error loading {self.db_path}: {e}")
                self.keys = {}
        else:
            self.keys = {}

    def _save(self):
        temp_path = f"{self.db_path}.tmp"
        try:
            with open(temp_path, "w", encoding="utf-8") as f:
                json.dump(self.keys, f, indent=2)
            os.replace(temp_path, self.db_path)
        except Exception as e:
            print(f"[KeyManager] Error saving {self.db_path}: {e}")

    def generate_keys(self, count: int, creator_id: int) -> List[str]:
        generated = []
        for _ in range(max(1, count)):
            key = _generate_token()
            while key in self.keys:
                key = _generate_token()
            self.keys[key] = {
                "created_by": creator_id,
                "created_at": time.time(),
                "claimed": False,
                "claimed_by": None,
                "claimed_at": None,
                "revoked": False
            }
            generated.append(key)
        self._save()
        return generated

    def redeem_key(self, key_str: str, user_id: int) -> Tuple[bool, str]:
        key = key_str.strip().upper()
        if key not in self.keys:
            return False, "Invalid key. Please check your key and try again."

        info = self.keys[key]
        if info.get("revoked"):
            return False, "This key has been revoked by an administrator."

        if info.get("claimed"):
            claimed_by = info.get("claimed_by")
            return False, f"This key has already been redeemed by <@{claimed_by}>."

        info["claimed"] = True
        info["claimed_by"] = user_id
        info["claimed_at"] = time.time()
        self._save()
        return True, "Key successfully redeemed!"

    def has_active_key(self, user_id: int) -> bool:
        """Premium entitlement that survives a missing/failed role grant."""
        return any(
            info.get("claimed")
            and not info.get("revoked")
            and info.get("claimed_by") is not None
            and str(info.get("claimed_by")) == str(user_id)
            for info in self.keys.values()
        )

    def revoke_key(self, key_str: str) -> Tuple[bool, Optional[int]]:
        key = key_str.strip().upper()
        if key not in self.keys:
            return False, None

        info = self.keys[key]
        claimed_by = info.get("claimed_by")
        info["revoked"] = True
        self._save()
        return True, claimed_by

    def revoke_user(self, user_id: int) -> int:
        revoked_count = 0
        for key, info in self.keys.items():
            if info.get("claimed_by") == user_id and not info.get("revoked"):
                info["revoked"] = True
                revoked_count += 1
        if revoked_count > 0:
            self._save()
        return revoked_count

    def get_stats(self) -> Dict[str, int]:
        total = len(self.keys)
        claimed = sum(1 for k in self.keys.values() if k.get("claimed"))
        revoked = sum(1 for k in self.keys.values() if k.get("revoked"))
        active = total - claimed - revoked
        return {
            "total": total,
            "active": active,
            "claimed": claimed,
            "revoked": revoked
        }

key_manager = KeyManager()
