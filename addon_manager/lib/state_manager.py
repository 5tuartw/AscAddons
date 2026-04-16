"""
Tracks installation state per client.
"""

import json
from pathlib import Path
from typing import Dict, Optional


class StateManager:
    """Manages per-client addon installation state."""
    
    def __init__(self, state_file: str = "installation_state.json"):
        self.state_file = Path(state_file)
        self.state = self._load_state()
    
    def _load_state(self) -> Dict:
        """Load state from file."""
        if self.state_file.exists():
            try:
                with open(self.state_file, 'r') as f:
                    return json.load(f)
            except Exception:
                pass
        
        return {"clients": {}}
    
    def _save_state(self):
        """Save state to file."""
        try:
            with open(self.state_file, 'w') as f:
                json.dump(self.state, f, indent=2)
        except Exception as e:
            print(f"Warning: Could not save state: {e}")
    
    def get_installed_version(self, client_id: str, addon_name: str) -> Optional[str]:
        """Get the installed version/commit for an addon on a client."""
        return self.state.get("clients", {}).get(client_id, {}).get(addon_name)
    
    def set_installed_version(self, client_id: str, addon_name: str, version: str):
        """Record successful installation of an addon version to a client."""
        if "clients" not in self.state:
            self.state["clients"] = {}
        
        if client_id not in self.state["clients"]:
            self.state["clients"][client_id] = {}
        
        self.state["clients"][client_id][addon_name] = version
        self._save_state()

    def remove_installed_version(self, client_id: str, addon_name: str):
        """Remove a tracked addon version for a specific client."""
        client_addons = self.state.get("clients", {}).get(client_id)
        if not client_addons or addon_name not in client_addons:
            return

        del client_addons[addon_name]

        if not client_addons:
            del self.state["clients"][client_id]

        self._save_state()
    
    def remove_addon(self, addon_name: str):
        """Remove addon from all client tracking."""
        if "clients" in self.state:
            for client_id in self.state["clients"]:
                if addon_name in self.state["clients"][client_id]:
                    del self.state["clients"][client_id][addon_name]
        
        self._save_state()
    
    def remove_client(self, client_id: str):
        """Remove a client from tracking."""
        if "clients" in self.state and client_id in self.state["clients"]:
            del self.state["clients"][client_id]
            self._save_state()
    
    def get_all_client_versions(self, addon_name: str) -> Dict[str, str]:
        """Get versions installed on all clients for an addon."""
        result = {}
        
        if "clients" in self.state:
            for client_id, addons in self.state["clients"].items():
                if addon_name in addons:
                    result[client_id] = addons[addon_name]
        
        return result
