"""
Configuration management for addon manager.
"""

import json
import os
from pathlib import Path
from typing import Dict, List, Optional


class ConfigManager:
    """Manages addon configuration file."""
    
    def __init__(self, config_path: str = "config.json"):
        self.config_path = Path(config_path)
        self.config = self.load()
    
    def load(self) -> Dict:
        """Load configuration from JSON file."""
        if not self.config_path.exists():
            # Create default config
            default_config = {
                "version": "1.0.0",
                "game_clients": {},
                "settings": {
                    "backup_directory": "./backups/savedvariables",
                    "temp_directory": "./temp/addon_repos",
                    "keep_backups_days": 30,
                    "auto_detect_folders": False,
                    "auto_detect_savedvars": False
                },
                "addons": []
            }
            self.save(default_config)
            return default_config
        
        with open(self.config_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    
    def save(self, config: Optional[Dict] = None) -> None:
        """Save configuration to JSON file."""
        if config is None:
            config = self.config
        
        with open(self.config_path, 'w', encoding='utf-8') as f:
            json.dump(config, f, indent=2, ensure_ascii=False)
        
        self.config = config
    
    def get_addons(self) -> List[Dict]:
        """Get list of tracked addons."""
        return self.config.get('addons', [])
    
    def get_addon_by_name(self, name: str) -> Optional[Dict]:
        """Get addon configuration by name."""
        for addon in self.config.get('addons', []):
            if addon['name'] == name:
                return addon
        return None
    
    def add_addon(self, addon: Dict) -> bool:
        """Add new addon to configuration."""
        # Check if addon already exists
        if self.get_addon_by_name(addon['name']):
            return False
        
        self.config['addons'].append(addon)
        self.save()
        return True
    
    def remove_addon(self, name: str) -> bool:
        """Remove addon from configuration."""
        addons = self.config.get('addons', [])
        initial_len = len(addons)
        
        self.config['addons'] = [a for a in addons if a['name'] != name]
        
        if len(self.config['addons']) < initial_len:
            self.save()
            return True
        return False
    
    def update_addon(self, name: str, addon_data: Dict) -> bool:
        """Update addon configuration."""
        for i, addon in enumerate(self.config.get('addons', [])):
            if addon['name'] == name:
                self.config['addons'][i] = addon_data
                self.save()
                return True
        return False
    
    def get_enabled_clients(self) -> List[tuple]:
        """Get list of enabled game clients as (id, config) tuples."""
        clients = []
        for client_id, client_config in self.config.get('game_clients', {}).items():
            if client_config.get('enabled', True):
                clients.append((client_id, client_config))
        return clients
    
    def get_setting(self, key: str, default=None):
        """Get a setting value."""
        return self.config.get('settings', {}).get(key, default)
