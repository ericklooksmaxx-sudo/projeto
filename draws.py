import json
import os
import time
import asyncio
import random
import discord
from typing import Dict, Any, List, Optional

from storage import data_path

GIVEAWAY_DB = data_path("draws.json")
WARNINGS_DB = data_path("strikes.json")

class GiveawayManager:
    def __init__(self, db_path: str = GIVEAWAY_DB):
        self.db_path = db_path
        self.giveaways: Dict[str, Dict[str, Any]] = {}
        self._load()

    def _load(self):
        if os.path.isfile(self.db_path):
            try:
                with open(self.db_path, "r", encoding="utf-8") as f:
                    self.giveaways = json.load(f)
            except Exception as e:
                print(f"[GiveawayManager] Error loading {self.db_path}: {e}")
                self.giveaways = {}
        else:
            self.giveaways = {}

    def _save(self):
        temp = f"{self.db_path}.tmp"
        try:
            with open(temp, "w", encoding="utf-8") as f:
                json.dump(self.giveaways, f, indent=2)
            os.replace(temp, self.db_path)
        except Exception as e:
            print(f"[GiveawayManager] Error saving {self.db_path}: {e}")

    def create_giveaway(self, message_id: int, channel_id: int, guild_id: int, host_id: int, prize: str, winners: int, end_time: float):
        self.giveaways[str(message_id)] = {
            "channel_id": channel_id,
            "guild_id": guild_id,
            "host_id": host_id,
            "prize": prize,
            "winners": winners,
            "end_time": end_time,
            "ended": False,
            "winner_ids": []
        }
        self._save()

    def get_giveaway(self, message_id: int) -> Optional[Dict[str, Any]]:
        return self.giveaways.get(str(message_id))

    def end_giveaway(self, message_id: int, winner_ids: List[int]):
        key = str(message_id)
        if key in self.giveaways:
            self.giveaways[key]["ended"] = True
            self.giveaways[key]["winner_ids"] = winner_ids
            self._save()

giveaway_manager = GiveawayManager()

class WarningsManager:
    def __init__(self, db_path: str = WARNINGS_DB):
        self.db_path = db_path
        self.warnings: Dict[str, List[Dict[str, Any]]] = {}
        self._load()

    def _load(self):
        if os.path.isfile(self.db_path):
            try:
                with open(self.db_path, "r", encoding="utf-8") as f:
                    self.warnings = json.load(f)
            except Exception as e:
                self.warnings = {}
        else:
            self.warnings = {}

    def _save(self):
        temp = f"{self.db_path}.tmp"
        try:
            with open(temp, "w", encoding="utf-8") as f:
                json.dump(self.warnings, f, indent=2)
            os.replace(temp, self.db_path)
        except Exception as e:
            pass

    def add_warning(self, user_id: int, moderator_id: int, reason: str) -> int:
        key = str(user_id)
        if key not in self.warnings:
            self.warnings[key] = []
        self.warnings[key].append({
            "moderator_id": moderator_id,
            "reason": reason,
            "timestamp": time.time()
        })
        self._save()
        return len(self.warnings[key])

    def get_warnings(self, user_id: int) -> List[Dict[str, Any]]:
        return self.warnings.get(str(user_id), [])

    def clear_warnings(self, user_id: int) -> int:
        key = str(user_id)
        count = len(self.warnings.get(key, []))
        if key in self.warnings:
            del self.warnings[key]
            self._save()
        return count

warnings_manager = WarningsManager()
