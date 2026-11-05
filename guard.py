import json
import os
import time
from collections import defaultdict, deque
from typing import Dict, Any, Tuple, Optional

from storage import data_path

CONFIG_FILE = data_path("guard.json")

DEFAULT_CONFIG = {
    "enabled": True,
    "action": "timeout",  # timeout | kick | ban
    "max_joins_per_minute": 8,
    "anti_invite": True,
    "anti_mass_mention": True,
    "max_mentions": 5,
    "anti_spam": True,
    "auto_role": True,
    "member_role_id": 1564136757761679511,
    "log_channel_id": None
}

class AntiRaidManager:
    def __init__(self, config_path: str = CONFIG_FILE):
        self.config_path = config_path
        self.config: Dict[str, Any] = {}
        self._load()
        self.join_history = deque()
        self.user_message_times = defaultdict(lambda: deque(maxlen=6))
        self.user_last_content = defaultdict(str)

    def _load(self):
        if os.path.isfile(self.config_path):
            try:
                with open(self.config_path, "r", encoding="utf-8") as f:
                    self.config = json.load(f)
            except Exception as e:
                print(f"[AntiRaid] Error loading config: {e}")
                self.config = DEFAULT_CONFIG.copy()
        else:
            self.config = DEFAULT_CONFIG.copy()
            self._save()

    def _save(self):
        temp_path = f"{self.config_path}.tmp"
        try:
            with open(temp_path, "w", encoding="utf-8") as f:
                json.dump(self.config, f, indent=2)
            os.replace(temp_path, self.config_path)
        except Exception as e:
            print(f"[AntiRaid] Error saving config: {e}")

    def get(self, key: str, default=None):
        return self.config.get(key, default)

    def set(self, key: str, value: Any):
        self.config[key] = value
        self._save()

    def register_join(self) -> Tuple[bool, int]:
        """Returns (is_raid_detected, current_joins_in_minute)"""
        if not self.config.get("enabled", True):
            return False, 0

        now = time.time()
        self.join_history.append(now)

        # Clear joins older than 60s
        while self.join_history and self.join_history[0] < now - 60:
            self.join_history.popleft()

        count = len(self.join_history)
        max_allowed = int(self.config.get("max_joins_per_minute", 8))
        return count >= max_allowed, count

    def check_spam(self, user_id: int, content: str) -> bool:
        """Returns True if message should be flagged as spam."""
        if not self.config.get("enabled", True) or not self.config.get("anti_spam", True):
            return False

        now = time.time()
        times = self.user_message_times[user_id]
        times.append(now)

        # 5 messages in under 3.5 seconds
        if len(times) >= 5 and (times[-1] - times[0]) < 3.5:
            return True

        # Duplicate message spam
        last = self.user_last_content[user_id]
        self.user_last_content[user_id] = content
        if len(content) > 12 and content == last and len(times) >= 3 and (times[-1] - times[-3]) < 4.0:
            return True

        return False

antiraid_manager = AntiRaidManager()
