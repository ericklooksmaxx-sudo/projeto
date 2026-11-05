import json
import os
import time
from typing import Dict, Any, Tuple

from storage import data_path

DB_PATH = data_path("wallet.json")

class CreditsManager:
    def __init__(self, db_path: str = DB_PATH):
        self.db_path = db_path
        self.data: Dict[str, Dict[str, Any]] = {}
        self._load()

    def _load(self):
        if os.path.isfile(self.db_path):
            try:
                with open(self.db_path, "r", encoding="utf-8") as f:
                    self.data = json.load(f)
            except Exception as e:
                print(f"[CreditsManager] Error loading {self.db_path}: {e}")
                self.data = {}
        else:
            self.data = {}

    def _save(self):
        temp_path = f"{self.db_path}.tmp"
        try:
            with open(temp_path, "w", encoding="utf-8") as f:
                json.dump(self.data, f, indent=2)
            os.replace(temp_path, self.db_path)
        except Exception as e:
            print(f"[CreditsManager] Error saving {self.db_path}: {e}")

    def _get_user_data(self, user_id: int) -> Dict[str, Any]:
        key = str(user_id)
        if key not in self.data:
            self.data[key] = {
                "credits": 0,
                "last_daily": 0.0,
                "total_commands": 0
            }
        return self.data[key]

    def get_credits(self, user_id: int) -> int:
        user_data = self._get_user_data(user_id)
        return int(user_data.get("credits", 0))

    def set_credits(self, user_id: int, amount: int) -> int:
        user_data = self._get_user_data(user_id)
        user_data["credits"] = max(0, int(amount))
        self._save()
        return user_data["credits"]

    def add_credits(self, user_id: int, amount: int) -> int:
        user_data = self._get_user_data(user_id)
        user_data["credits"] = max(0, int(user_data.get("credits", 0)) + amount)
        self._save()
        return user_data["credits"]

    def use_credit(self, user_id: int, amount: int = 1) -> bool:
        user_data = self._get_user_data(user_id)
        current = int(user_data.get("credits", 0))
        if current < amount:
            return False
        user_data["credits"] = current - amount
        user_data["total_commands"] = int(user_data.get("total_commands", 0)) + 1
        self._save()
        return True

    def refund_credit(self, user_id: int, amount: int = 1) -> int:
        return self.add_credits(user_id, amount)

    def can_claim_daily(self, user_id: int, cooldown_seconds: int = 86400) -> Tuple[bool, int]:
        user_data = self._get_user_data(user_id)
        last_daily = float(user_data.get("last_daily", 0.0))
        now = time.time()
        elapsed = now - last_daily
        if elapsed >= cooldown_seconds:
            return True, 0
        return False, int(cooldown_seconds - elapsed)

    def claim_daily_premium(self, user_id: int, cap: int = 100, cooldown_seconds: int = 86400) -> Tuple[bool, int, int]:
        """Premium users get topped up to 100 credits daily (capped at 100 maximum)."""
        can_claim, remaining = self.can_claim_daily(user_id, cooldown_seconds)
        user_data = self._get_user_data(user_id)
        current = int(user_data.get("credits", 0))

        if not can_claim:
            return False, current, remaining

        # If current is less than 100, set to 100. If already >= 100, keep capped at 100.
        new_balance = cap
        user_data["credits"] = new_balance
        user_data["last_daily"] = time.time()
        self._save()
        return True, new_balance, 0

    def claim_daily_regular(self, user_id: int, amount: int = 5, cooldown_seconds: int = 86400) -> Tuple[bool, int, int]:
        """Regular users get +5 credits daily."""
        can_claim, remaining = self.can_claim_daily(user_id, cooldown_seconds)
        user_data = self._get_user_data(user_id)
        current = int(user_data.get("credits", 0))

        if not can_claim:
            return False, current, remaining

        user_data["credits"] = current + amount
        user_data["last_daily"] = time.time()
        self._save()
        return True, user_data["credits"], 0

credits_manager = CreditsManager()
