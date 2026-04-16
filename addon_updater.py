#!/usr/bin/env python3
"""
WoW Addon Updater for Ascension
Manages GitHub-hosted addons with SavedVariables backup and interactive updates.
"""

import os
import sys
import json
import shutil
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# Try to import inquirer for interactive CLI, fallback to simple input
try:
    import inquirer
    HAS_INQUIRER = True
except ImportError:
    HAS_INQUIRER = False
    print("Note: Install 'inquirer' for better interactive experience: pip3 install inquirer")
    print()


class AddonUpdater:
    def __init__(self, config_path: str = "addon_updater_config.json"):
        self.config_path = config_path
        self.config = self.load_config()
        self.temp_dir = Path("./temp/addon_repos")
        self.temp_dir.mkdir(parents=True, exist_ok=True)
        
    def load_config(self) -> Dict:
        """Load configuration from JSON file."""
        try:
            with open(self.config_path, 'r', encoding='utf-8') as f:
                return json.load(f)
        except FileNotFoundError:
            print(f"Error: Config file not found: {self.config_path}")
            sys.exit(1)
        except json.JSONDecodeError as e:
            print(f"Error: Invalid JSON in config file: {e}")
            sys.exit(1)
    
    def run_command(self, cmd: List[str], cwd: Optional[str] = None) -> Tuple[int, str, str]:
        """Run a shell command and return (returncode, stdout, stderr)."""
        result = subprocess.run(
            cmd,
            cwd=cwd,
            capture_output=True,
            text=True
        )
        return result.returncode, result.stdout, result.stderr
    
    def get_repo_local_path(self, addon_name: str) -> Path:
        """Get the local path for a cloned repo."""
        return self.temp_dir / addon_name
    
    def get_remote_commit(self, repo_url: str, branch: str = "master") -> Optional[str]:
        """Get the latest commit hash from remote repo."""
        cmd = ["git", "ls-remote", repo_url, f"refs/heads/{branch}"]
        returncode, stdout, stderr = self.run_command(cmd)
        
        if returncode != 0:
            print(f"  Warning: Could not fetch remote info: {stderr.strip()}")
            return None
        
        if stdout.strip():
            return stdout.split()[0][:8]  # Short hash
        return None
    
    def get_local_commit(self, local_path: Path) -> Optional[str]:
        """Get the current commit hash from local repo."""
        if not (local_path / ".git").exists():
            return None
        
        cmd = ["git", "rev-parse", "--short=8", "HEAD"]
        returncode, stdout, stderr = self.run_command(cmd, cwd=str(local_path))
        
        if returncode != 0:
            return None
        
        return stdout.strip()
    
    def clone_or_update_repo(self, addon: Dict) -> bool:
        """Clone repo if needed, or fetch latest changes."""
        local_path = self.get_repo_local_path(addon['name'])
        repo_url = addon['repo']
        branch = addon.get('branch', 'master')
        
        if local_path.exists():
            # Fetch latest
            print(f"  Fetching latest changes from {repo_url}...")
            cmd = ["git", "fetch", "origin", branch]
            returncode, stdout, stderr = self.run_command(cmd, cwd=str(local_path))
            
            if returncode != 0:
                print(f"  Error fetching: {stderr}")
                return False
            
            # Reset to latest
            cmd = ["git", "reset", "--hard", f"origin/{branch}"]
            returncode, stdout, stderr = self.run_command(cmd, cwd=str(local_path))
            
            if returncode != 0:
                print(f"  Error updating: {stderr}")
                return False
        else:
            # Clone repo
            print(f"  Cloning {repo_url}...")
            cmd = ["git", "clone", "-b", branch, repo_url, str(local_path)]
            returncode, stdout, stderr = self.run_command(cmd)
            
            if returncode != 0:
                print(f"  Error cloning: {stderr}")
                return False
        
        return True
    
    def check_addon_status(self, addon: Dict) -> Dict:
        """Check if addon has updates available."""
        status = {
            'name': addon['name'],
            'has_update': False,
            'local_commit': None,
            'remote_commit': None,
            'error': None
        }
        
        # Get remote commit
        remote_commit = self.get_remote_commit(addon['repo'], addon.get('branch', 'master'))
        if remote_commit is None:
            status['error'] = "Could not fetch remote info"
            return status
        
        status['remote_commit'] = remote_commit
        
        # Get local commit
        local_path = self.get_repo_local_path(addon['name'])
        local_commit = self.get_local_commit(local_path)
        status['local_commit'] = local_commit
        
        # Check if update available
        if local_commit is None:
            status['has_update'] = True  # Not installed yet
        elif local_commit != remote_commit:
            status['has_update'] = True
        
        return status
    
    def backup_saved_variables(self, addon: Dict, client_id: str) -> bool:
        """Backup SavedVariables files for an addon."""
        client = self.config['game_clients'][client_id]
        wtf_path = Path(client['wtf_path'])
        
        if not wtf_path.exists():
            print(f"    Warning: WTF path not found: {wtf_path}")
            return False
        
        # Create backup directory
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_base = Path(self.config['backup_directory'])
        backup_dir = backup_base / timestamp / client_id / addon['name']
        backup_dir.mkdir(parents=True, exist_ok=True)
        
        backed_up = False
        
        # Backup account-level SavedVariables
        account_sv_dir = wtf_path / "Account"
        if account_sv_dir.exists():
            for account_folder in account_sv_dir.iterdir():
                if not account_folder.is_dir():
                    continue
                
                sv_dir = account_folder / "SavedVariables"
                if not sv_dir.exists():
                    continue
                
                for sv_file in addon.get('saved_variables', []):
                    sv_path = sv_dir / sv_file
                    if sv_path.exists():
                        dest = backup_dir / "Account" / account_folder.name / sv_file
                        dest.parent.mkdir(parents=True, exist_ok=True)
                        shutil.copy2(sv_path, dest)
                        print(f"    Backed up: {account_folder.name}/{sv_file}")
                        backed_up = True
                
                # Also backup character-specific SavedVariables
                for realm_folder in account_folder.iterdir():
                    if not realm_folder.is_dir() or realm_folder.name == "SavedVariables":
                        continue
                    
                    for char_folder in realm_folder.iterdir():
                        if not char_folder.is_dir():
                            continue
                        
                        char_sv_dir = char_folder / "SavedVariables"
                        if not char_sv_dir.exists():
                            continue
                        
                        for sv_file in addon.get('saved_variables', []):
                            sv_path = char_sv_dir / sv_file
                            if sv_path.exists():
                                dest = backup_dir / "Characters" / realm_folder.name / char_folder.name / sv_file
                                dest.parent.mkdir(parents=True, exist_ok=True)
                                shutil.copy2(sv_path, dest)
                                print(f"    Backed up: {char_folder.name}/{sv_file}")
                                backed_up = True
        
        if backed_up:
            print(f"    Backup location: {backup_dir}")
        else:
            print(f"    No SavedVariables found to backup")
        
        return True
    
    def install_addon(self, addon: Dict, client_id: str) -> bool:
        """Install/update addon to game client."""
        client = self.config['game_clients'][client_id]
        addons_path = Path(client['addons_path'])
        
        if not addons_path.exists():
            print(f"    Error: AddOns path not found: {addons_path}")
            return False
        
        local_repo = self.get_repo_local_path(addon['name'])
        
        # Copy each addon folder
        for folder_name in addon['addon_folders']:
            src_folder = local_repo / folder_name
            dest_folder = addons_path / folder_name
            
            if not src_folder.exists():
                print(f"    Warning: Source folder not found: {src_folder}")
                continue
            
            # Remove existing folder
            if dest_folder.exists():
                shutil.rmtree(dest_folder)
            
            # Copy new version
            shutil.copytree(src_folder, dest_folder)
            print(f"    Installed: {folder_name}")
        
        return True
    
    def check_all_addons(self) -> List[Dict]:
        """Check status of all enabled addons."""
        print("Checking for addon updates...\n")
        
        results = []
        for addon in self.config['addons']:
            if not addon.get('enabled', True):
                continue
            
            print(f"Checking {addon['name']}...")
            status = self.check_addon_status(addon)
            status['addon_config'] = addon
            results.append(status)
            
            if status['error']:
                print(f"  Error: {status['error']}")
            elif status['has_update']:
                if status['local_commit'] is None:
                    print(f"  Status: Not installed (remote: {status['remote_commit']})")
                else:
                    print(f"  Status: Update available ({status['local_commit']} -> {status['remote_commit']})")
            else:
                print(f"  Status: Up to date ({status['local_commit']})")
            print()
        
        return results
    
    def select_addons_to_update(self, addon_statuses: List[Dict]) -> List[Dict]:
        """Interactive selection of addons to update."""
        # Filter to only addons with updates
        updateable = [s for s in addon_statuses if s['has_update'] and not s['error']]
        
        if not updateable:
            print("No updates available!")
            return []
        
        print(f"Found {len(updateable)} addon(s) with updates:\n")
        
        if HAS_INQUIRER:
            # Use inquirer for checkbox selection
            choices = []
            for status in updateable:
                addon = status['addon_config']
                label = f"{addon['name']}"
                if status['local_commit']:
                    label += f" ({status['local_commit']} -> {status['remote_commit']})"
                else:
                    label += f" (new install -> {status['remote_commit']})"
                choices.append((label, status))
            
            questions = [
                inquirer.Checkbox(
                    'addons',
                    message="Select addons to update (Space to select, Enter to confirm)",
                    choices=choices,
                )
            ]
            
            answers = inquirer.prompt(questions)
            if answers is None:
                return []
            
            return answers['addons']
        else:
            # Fallback to simple numbered selection
            for i, status in enumerate(updateable, 1):
                addon = status['addon_config']
                if status['local_commit']:
                    print(f"{i}. {addon['name']} ({status['local_commit']} -> {status['remote_commit']})")
                else:
                    print(f"{i}. {addon['name']} (new install -> {status['remote_commit']})")
            
            print("\nEnter addon numbers to update (comma-separated, or 'all' for all):")
            selection = input("> ").strip()
            
            if selection.lower() == 'all':
                return updateable
            
            try:
                indices = [int(x.strip()) - 1 for x in selection.split(',')]
                return [updateable[i] for i in indices if 0 <= i < len(updateable)]
            except (ValueError, IndexError):
                print("Invalid selection!")
                return []
    
    def update_addon(self, status: Dict) -> bool:
        """Update a single addon (backup + install)."""
        addon = status['addon_config']
        print(f"\nUpdating {addon['name']}...")
        
        # Clone/update repo
        if not self.clone_or_update_repo(addon):
            return False
        
        # Process each client
        for client_id in addon.get('clients', []):
            if client_id not in self.config['game_clients']:
                print(f"  Warning: Unknown client '{client_id}'")
                continue
            
            client = self.config['game_clients'][client_id]
            print(f"\n  Updating {client['name']}...")
            
            # Backup SavedVariables
            if addon.get('saved_variables'):
                print(f"  Backing up SavedVariables...")
                self.backup_saved_variables(addon, client_id)
            
            # Install addon
            if not self.install_addon(addon, client_id):
                print(f"  Failed to install to {client['name']}")
                continue
            
            print(f"  ✓ Updated {client['name']}")
        
        return True
    
    def run(self):
        """Main execution flow."""
        print("=" * 60)
        print("WoW Addon Updater for Ascension")
        print("=" * 60)
        print()
        
        # Check all addons
        addon_statuses = self.check_all_addons()
        
        # Select addons to update
        selected = self.select_addons_to_update(addon_statuses)
        
        if not selected:
            print("\nNo addons selected for update.")
            return
        
        # Confirm update
        print(f"\nReady to update {len(selected)} addon(s):")
        for status in selected:
            print(f"  - {status['addon_config']['name']}")
        
        confirm = input("\nProceed with update? (y/N): ").strip().lower()
        if confirm != 'y':
            print("Update cancelled.")
            return
        
        # Update each selected addon
        print("\n" + "=" * 60)
        success_count = 0
        for status in selected:
            if self.update_addon(status):
                success_count += 1
        
        # Summary
        print("\n" + "=" * 60)
        print(f"Update complete: {success_count}/{len(selected)} successful")
        print("=" * 60)


def main():
    """Deprecated entry point retained for compatibility messaging."""
    print("\n[DEPRECATED] addon_updater.py is no longer supported.")
    print("Use addon_manager as the canonical tool instead:")
    print("  cd addon_manager")
    print("  ./run.sh")
    print("\nThis script remains in the repository only for historical reference.")
    sys.exit(2)


if __name__ == "__main__":
    main()
