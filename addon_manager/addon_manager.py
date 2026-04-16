#!/usr/bin/env python3
"""
WoW Addon Manager for Ascension
Menu-driven interface for managing GitHub-hosted addons.
"""

import os
import sys
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Optional

# Add lib directory to path
sys.path.insert(0, str(Path(__file__).parent))

from lib.config_manager import ConfigManager
from lib.git_operations import GitOperations
from lib.backup_manager import BackupManager
from lib.addon_installer import AddonInstaller
from lib.state_manager import StateManager

# Try to import inquirer for interactive CLI
try:
    import inquirer
    HAS_INQUIRER = True
except ImportError:
    HAS_INQUIRER = False


class AddonManager:
    """Main addon manager application."""
    
    def __init__(self):
        # Change to script directory
        os.chdir(Path(__file__).parent)
        
        self.config = ConfigManager()
        self.git = GitOperations()
        self.backup = BackupManager(self.config.get_setting('backup_directory'))
        self.state = StateManager()
        self.temp_dir = Path(self.config.get_setting('temp_directory'))
        self.temp_dir.mkdir(parents=True, exist_ok=True)

    def get_client_addon_status(self, addon: Dict, client_id: str, client_config: Dict, remote_version: str) -> Dict:
        """Resolve addon status for a client from disk first, then tracked state."""
        addons_path = Path(client_config['addons_path'])
        installation = AddonInstaller.inspect_addon_installation(addon['addon_folders'], addons_path)
        recorded_version = self.state.get_installed_version(client_id, addon['name'])

        if not installation['path_exists']:
            return {
                'needs_update': True,
                'reason': 'invalid_path',
                'recorded_version': recorded_version,
                'installation': installation,
            }

        if not installation['installed']:
            if recorded_version:
                self.state.remove_installed_version(client_id, addon['name'])
            return {
                'needs_update': True,
                'reason': 'missing',
                'recorded_version': None,
                'installation': installation,
            }

        if not installation['complete']:
            return {
                'needs_update': True,
                'reason': 'partial',
                'recorded_version': recorded_version,
                'installation': installation,
            }

        if not recorded_version:
            return {
                'needs_update': True,
                'reason': 'untracked',
                'recorded_version': None,
                'installation': installation,
            }

        if recorded_version != remote_version:
            return {
                'needs_update': True,
                'reason': 'outdated',
                'recorded_version': recorded_version,
                'installation': installation,
            }

        return {
            'needs_update': False,
            'reason': 'current',
            'recorded_version': recorded_version,
            'installation': installation,
        }

    def format_client_status_summary(self, client_ids: List[str], all_clients: Dict[str, Dict], status_by_client: Dict[str, Dict]) -> str:
        """Build a concise status summary for clients needing attention."""
        if not client_ids:
            return ""

        def format_client_name(client_id: str) -> str:
            client_config = all_clients.get(client_id, {})
            return client_config.get('name', client_id)

        reason_groups = {
            'invalid_path': [],
            'missing': [],
            'partial': [],
            'untracked': [],
            'outdated': [],
        }

        for client_id in client_ids:
            reason = status_by_client[client_id]['reason']
            reason_groups.setdefault(reason, []).append(format_client_name(client_id))

        summary_parts = []
        if reason_groups['invalid_path']:
            summary_parts.append(f"path missing: {', '.join(reason_groups['invalid_path'])}")
        if reason_groups['missing']:
            summary_parts.append(f"not installed: {', '.join(reason_groups['missing'])}")
        if reason_groups['partial']:
            summary_parts.append(f"partial install: {', '.join(reason_groups['partial'])}")
        if reason_groups['untracked']:
            summary_parts.append(f"installed but untracked: {', '.join(reason_groups['untracked'])}")
        if reason_groups['outdated']:
            summary_parts.append(f"outdated: {', '.join(reason_groups['outdated'])}")

        return '; '.join(summary_parts)
    
    def show_welcome(self):
        """Display welcome message and stats."""
        print("\n" + "=" * 70)
        print("  WoW Addon Manager for Ascension")
        print("=" * 70)
        
        addons = self.config.get_addons()
        enabled_addons = [a for a in addons if a.get('enabled', True)]
        
        print(f"\n📦 Currently tracking {len(enabled_addons)} addon(s)")
        
        if enabled_addons:
            print("\n  Tracked addons:")
            for addon in enabled_addons:
                status = "✓" if addon.get('enabled', True) else "○"
                print(f"    {status} {addon['name']}")
        
        print()
    
    def show_main_menu(self) -> Optional[str]:
        """Display main menu and get user choice."""
        choices = [
            ('Check for updates', 'check_updates'),
            ('Force reinstall from local', 'force_reinstall'),
            ('Scan AddOns inventory (report only)', 'scan_inventory'),
            ('Add addon to tracking', 'add_addon'),
            ('Remove addon from tracking', 'remove_addon'),
            ('List tracked addons', 'list_addons'),
            ('Create SavedVariables backup', 'backup_all'),
            ('View backup history', 'view_backups'),
            ('Settings', 'settings'),
            ('Exit', 'exit')
        ]
        
        if HAS_INQUIRER:
            questions = [
                inquirer.List(
                    'action',
                    message="What would you like to do?",
                    choices=choices,
                )
            ]
            
            answers = inquirer.prompt(questions)
            if answers is None:
                return 'exit'
            return answers['action']
        else:
            print("\n" + "=" * 70)
            print("Main Menu:")
            print("=" * 70)
            for i, (label, _) in enumerate(choices, 1):
                print(f"{i}. {label}")
            
            choice = input("\nSelect option (1-{}): ".format(len(choices))).strip()
            try:
                idx = int(choice) - 1
                if 0 <= idx < len(choices):
                    return choices[idx][1]
            except ValueError:
                pass
            
            return None
    
    def select_clients(self, all_clients: List[tuple], message: str = "Select clients") -> List[tuple]:
        """Let user select which game clients to use."""
        if not all_clients:
            return []
        
        if HAS_INQUIRER:
            choices = [(f"{cfg['name']} ({cid})", (cid, cfg)) for cid, cfg in all_clients]
            questions = [
                inquirer.Checkbox(
                    'clients',
                    message=message,
                    choices=choices,
                    default=choices  # All selected by default
                )
            ]
            answers = inquirer.prompt(questions)
            if answers is None or not answers['clients']:
                return []
            return answers['clients']
        else:
            print(f"\n{message}:")
            for i, (cid, cfg) in enumerate(all_clients, 1):
                print(f"  {i}. {cfg['name']} ({cid})")
            
            print("\nEnter client numbers (comma-separated) or 'all':")
            selection = input("> ").strip().lower()
            
            if selection == 'all' or not selection:
                return all_clients
            
            try:
                indices = [int(x.strip()) - 1 for x in selection.split(',')]
                return [all_clients[i] for i in indices if 0 <= i < len(all_clients)]
            except (ValueError, IndexError):
                return all_clients
    
    def check_for_updates(self):
        """Check all addons for available updates."""
        print("\n" + "=" * 70)
        print("Checking for updates...")
        print("=" * 70 + "\n")
        
        addons = [a for a in self.config.get_addons() if a.get('enabled', True)]
        
        if not addons:
            print("❌ No addons tracked. Add some first!")
            input("\nPress Enter to continue...")
            return
        
        # Check each addon
        updates_available = []
        
        # Get all clients to check installation status
        all_clients = [(cid, cfg) for cid, cfg in self.config.config.get('game_clients', {}).items() if cfg.get('enabled', True)]
        client_lookup = dict(all_clients)
        
        for addon in addons:
            print(f"Checking {addon['name']}...", end=" ")
            
            repo_path = self.temp_dir / addon['name']
            
            # Determine if using tag or branch
            if 'tag' in addon:
                ref = addon['tag']
                is_using_tag = True
                # If tag is "latest", resolve it to actual latest release tag
                if ref == "latest":
                    latest_release = self.git.get_latest_release(addon['repo'])
                    if latest_release:
                        ref = latest_release['tag']
                    else:
                        # Fallback to branch if can't get release
                        ref = addon.get('branch', 'main')
                        is_using_tag = False
                # For tags, use the tag name as the "version" for tracking
                remote_version = ref
            else:
                ref = addon.get('branch', 'master')
                is_using_tag = False
                # Get remote commit for branch
                remote_commit = self.git.get_remote_commit(addon['repo'], ref)
                if not remote_commit:
                    print("❌ Failed to fetch")
                    continue
                remote_version = remote_commit
            
            # Get local commit (always stored as commit hash in git)
            local_commit = self.git.get_local_commit(repo_path)
            
            # Check which clients need this addon installed/updated
            needs_update = False
            clients_needing_update = []
            client_statuses = {}
            installed_versions = []

            for client_id, client_config in all_clients:
                if client_id not in addon.get('clients', []):
                    continue

                client_status = self.get_client_addon_status(addon, client_id, client_config, remote_version)
                client_statuses[client_id] = client_status

                if client_status['recorded_version']:
                    installed_versions.append(client_status['recorded_version'])

                if client_status['needs_update']:
                    needs_update = True
                    clients_needing_update.append(client_id)
            
            if not local_commit:
                print(f"🆕 New addon (install: {remote_version})")
                updates_available.append({
                    'addon': addon,
                    'local': None,
                    'remote': remote_version,
                    'status': 'new',
                    'clients_needing_update': clients_needing_update
                })
            elif needs_update:
                status_msg = self.format_client_status_summary(clients_needing_update, client_lookup, client_statuses)
                display_local = installed_versions[0] if installed_versions else local_commit[:8]
                if display_local != remote_version:
                    status_msg = f"{status_msg} ({display_local} → {remote_version})"
                print(f"📥 {status_msg}")
                status = 'update'
                if clients_needing_update and all(
                    client_statuses[client_id]['reason'] in {'missing', 'partial', 'untracked', 'invalid_path'}
                    for client_id in clients_needing_update
                ):
                    status = 'not_installed'
                updates_available.append({
                    'addon': addon,
                    'local': local_commit,
                    'remote': remote_version,
                    'status': status,
                    'clients_needing_update': clients_needing_update
                })
            else:
                print(f"✓ Up to date on all clients ({remote_version})")
        
        if not updates_available:
            print("\n✨ All addons are up to date!")
            input("\nPress Enter to continue...")
            return
        
        # Select addons to update
        print(f"\n{len(updates_available)} addon(s) can be updated:\n")
        
        selected = self.select_addons_to_update(updates_available)
        
        if not selected:
            return
        
        # Confirm update
        print(f"\n📥 Ready to update/install {len(selected)} addon(s):")
        for item in selected:
            addon = item['addon']
            if item['status'] == 'new':
                print(f"  • {addon['name']} (new install)")
            elif item['status'] == 'not_installed':
                print(f"  • {addon['name']} (install to game)")
            else:
                print(f"  • {addon['name']} ({item['local']} → {item['remote']})")
        
        if not self.confirm("Proceed with update/install?"):
            return
        
        # Select clients to update
        all_clients = [(cid, cfg) for cid, cfg in self.config.config.get('game_clients', {}).items()]
        selected_clients = self.select_clients(all_clients, "Select clients to update")
        
        if not selected_clients:
            return
        
        # Perform updates
        print("\n" + "=" * 70)
        print("Updating addons...")
        print("=" * 70 + "\n")
        
        success_count = 0
        for item in selected:
            if self.update_addon(item, selected_clients):
                success_count += 1
        
        print("\n" + "=" * 70)
        print(f"✨ Update complete: {success_count}/{len(selected)} successful")
        print("=" * 70)
        
        input("\nPress Enter to continue...")
    
    def select_addons_to_update(self, updates: List[Dict]) -> List[Dict]:
        """Let user select which addons to update."""
        if HAS_INQUIRER:
            choices = []
            for item in updates:
                addon = item['addon']
                if item['status'] == 'new':
                    label = f"{addon['name']} (new install → {item['remote']})"
                elif item['status'] == 'not_installed':
                    label = f"{addon['name']} (install to game → {item['local']})"
                else:
                    label = f"{addon['name']} ({item['local']} → {item['remote']})"
                choices.append((label, item))
            
            # Add "All" option
            choices.insert(0, ("Update/Install all addons", "ALL"))
            
            questions = [
                inquirer.Checkbox(
                    'addons',
                    message="Select addons to update/install (Space to toggle, Enter to confirm)",
                    choices=choices,
                )
            ]
            
            answers = inquirer.prompt(questions)
            if answers is None or not answers['addons']:
                return []
            
            # Check if "ALL" was selected
            if "ALL" in answers['addons']:
                return updates
            
            return answers['addons']
        else:
            print("\nOptions:")
            for i, item in enumerate(updates, 1):
                addon = item['addon']
                if item['status'] == 'new':
                    print(f"  {i}. {addon['name']} (new install → {item['remote']})")
                elif item['status'] == 'not_installed':
                    print(f"  {i}. {addon['name']} (install to game → {item['local']})")
                else:
                    print(f"  {i}. {addon['name']} ({item['local']} → {item['remote']})")
            
            print("\nEnter addon numbers (comma-separated) or 'all':")
            selection = input("> ").strip().lower()
            
            if selection == 'all':
                return updates
            
            try:
                indices = [int(x.strip()) - 1 for x in selection.split(',')]
                return [updates[i] for i in indices if 0 <= i < len(updates)]
            except (ValueError, IndexError):
                print("❌ Invalid selection!")
                return []
    
    def update_addon(self, update_item: Dict, selected_clients: List[tuple]) -> bool:
        """Update a single addon."""
        addon = update_item['addon']
        print(f"\n📦 Updating {addon['name']}...")
        
        repo_path = self.temp_dir / addon['name']
        
        # Determine if using tag or branch
        if 'tag' in addon:
            ref = addon['tag']
            is_tag = True
            # If tag is "latest", resolve it to actual latest release tag
            if ref == "latest":
                latest_release = self.git.get_latest_release(addon['repo'])
                if latest_release:
                    ref = latest_release['tag']
                    print(f"  ℹ️  Resolving 'latest' to {ref}")
                else:
                    print("  ⚠️  Could not resolve 'latest' tag, falling back to main branch")
                    ref = addon.get('branch', 'main')
                    is_tag = False
        else:
            ref = addon.get('branch', 'master')
            is_tag = False
            
            # Check if using branch and if a newer release exists
            print("  • Checking for newer releases...", end=" ")
            newer_release = self.git.should_prefer_release(addon['repo'], ref)
            if newer_release:
                print(f"⚠️")
                print(f"    ℹ️  A newer release exists: {newer_release['tag']} (published {newer_release['published_at'][:10]})")
                print(f"    ℹ️  Currently using branch '{ref}' which may be older")
                print(f"    💡 Tip: Update config.json to use '\"tag\": \"latest\"' instead of '\"branch\": \"{ref}\"' to get this release")
            else:
                print("✓")
        
        # Clone or update repo
        print("  • Fetching latest version...", end=" ")
        if not self.git.clone_or_update(addon['repo'], repo_path, ref, is_tag):
            print("❌")
            return False
        
        # Get the version to track - use tag name if using tags, otherwise commit hash
        if is_tag:
            tracked_version = ref
        else:
            tracked_version = self.git.get_local_commit(repo_path)
        print("✓")
        
        # Filter to selected clients that this addon is configured for
        clients = [(cid, cfg) for cid, cfg in selected_clients if cid in addon.get('clients', [])]
        
        if not clients:
            print("  ⚠️  No matching clients configured for this addon")
            return False
        
        # Track overall success
        any_success = False
        
        # Process each client
        for client_id, client_config in clients:
            client_name = client_config['name']
            print(f"\n  📂 {client_name}:")
            
            # Backup SavedVariables
            if addon.get('saved_variables'):
                print(f"    • Backing up SavedVariables...", end=" ")
                wtf_path = Path(client_config['wtf_path'])
                backup_path = self.backup.create_backup(
                    wtf_path,
                    addon['name'],
                    addon['saved_variables'],
                    client_id
                )
                if backup_path:
                    print("✓")
                else:
                    print("(no data)")
            
            # Install addon
            print(f"    • Installing addon files...", end=" ")
            addons_path = Path(client_config['addons_path'])
            
            if AddonInstaller.install_addon(addon['addon_folders'], repo_path, addons_path):
                print("✓")
                # Record successful installation with version (tag name or commit hash)
                if tracked_version:
                    self.state.set_installed_version(client_id, addon['name'], tracked_version)
                any_success = True
            else:
                print("❌")
        
        if any_success:
            print(f"\n  ✨ {addon['name']} updated successfully!")
        
        return any_success
    
    def force_reinstall(self):
        """Force reinstall addons from local temp folder to game directories."""
        print("\n" + "=" * 70)
        print("Force Reinstall from Local")
        print("=" * 70)
        print("\nThis will copy addons from the local temp/ folder to game directories,")
        print("overwriting any game-updated versions.\n")
        
        addons = [a for a in self.config.get_addons() if a.get('enabled', True)]
        
        if not addons:
            print("❌ No addons tracked. Add some first!")
            input("\nPress Enter to continue...")
            return
        
        # Filter addons that exist in temp folder
        available_addons = []
        for addon in addons:
            repo_path = self.temp_dir / addon['name']
            if repo_path.exists() and (repo_path / ".git").exists():
                # Get current version
                if 'tag' in addon:
                    version = addon['tag']
                    if version == "latest":
                        latest_release = self.git.get_latest_release(addon['repo'])
                        if latest_release:
                            version = latest_release['tag']
                else:
                    version = self.git.get_local_commit(repo_path) or "unknown"
                
                available_addons.append({
                    'addon': addon,
                    'path': repo_path,
                    'version': version
                })
        
        if not available_addons:
            print("❌ No addons available in temp/ folder.")
            print("   Run 'Check for updates' first to download addons.")
            input("\nPress Enter to continue...")
            return
        
        # Show available addons
        print(f"Available addons to reinstall ({len(available_addons)}):\n")
        for i, item in enumerate(available_addons, 1):
            addon = item['addon']
            print(f"  {i}. {addon['name']} (version: {item['version']})")
        
        # Select addons
        if HAS_INQUIRER:
            choices = [(f"{item['addon']['name']} ({item['version']})", item) 
                      for item in available_addons]
            questions = [
                inquirer.Checkbox(
                    'addons',
                    message="Select addons to reinstall",
                    choices=choices,
                    default=choices
                )
            ]
            answers = inquirer.prompt(questions)
            if answers is None or not answers['addons']:
                return
            selected = answers['addons']
        else:
            print("\nEnter addon numbers (comma-separated) or 'all':")
            selection = input("> ").strip().lower()
            
            if selection == 'all':
                selected = available_addons
            else:
                try:
                    indices = [int(x.strip()) - 1 for x in selection.split(',')]
                    selected = [available_addons[i] for i in indices if 0 <= i < len(available_addons)]
                except (ValueError, IndexError):
                    print("❌ Invalid selection!")
                    input("\nPress Enter to continue...")
                    return
        
        if not selected:
            return
        
        # Get all enabled clients
        all_clients = [(cid, cfg) for cid, cfg in self.config.config.get('game_clients', {}).items() 
                      if cfg.get('enabled', True)]
        
        if not all_clients:
            print("\n❌ No game clients configured.")
            input("\nPress Enter to continue...")
            return
        
        # Select clients
        selected_clients = self.select_clients(all_clients, "Select clients to reinstall to")
        
        if not selected_clients:
            return
        
        # Confirm
        print(f"\n📥 Ready to force reinstall {len(selected)} addon(s) to {len(selected_clients)} client(s):")
        for item in selected:
            print(f"  • {item['addon']['name']} ({item['version']})")
        print("\nClients:")
        for cid, cfg in selected_clients:
            print(f"  • {cfg['name']}")
        
        if not self.confirm("\n⚠️  This will overwrite existing addon files. Proceed?"):
            return
        
        # Perform reinstall
        print("\n" + "=" * 70)
        print("Reinstalling addons...")
        print("=" * 70 + "\n")
        
        success_count = 0
        for item in selected:
            addon = item['addon']
            repo_path = item['path']
            version = item['version']
            
            print(f"\n📦 Reinstalling {addon['name']}...")
            
            # Filter to clients this addon is configured for
            clients = [(cid, cfg) for cid, cfg in selected_clients if cid in addon.get('clients', [])]
            
            if not clients:
                print("  ⚠️  No matching clients configured for this addon")
                continue
            
            any_success = False
            
            for client_id, client_config in clients:
                client_name = client_config['name']
                print(f"\n  📂 {client_name}:")
                
                # Backup SavedVariables
                if addon.get('saved_variables'):
                    print(f"    • Backing up SavedVariables...", end=" ")
                    wtf_path = Path(client_config['wtf_path'])
                    backup_path = self.backup.create_backup(
                        wtf_path,
                        addon['name'],
                        addon['saved_variables'],
                        client_id
                    )
                    if backup_path:
                        print("✓")
                    else:
                        print("(no data)")
                
                # Install addon
                print(f"    • Installing addon files...", end=" ")
                addons_path = Path(client_config['addons_path'])
                
                if AddonInstaller.install_addon(addon['addon_folders'], repo_path, addons_path):
                    print("✓")
                    # Update state to reflect current version
                    self.state.set_installed_version(client_id, addon['name'], version)
                    any_success = True
                else:
                    print("❌")
            
            if any_success:
                print(f"\n  ✨ {addon['name']} reinstalled successfully!")
                success_count += 1
        
        print("\n" + "=" * 70)
        print(f"✨ Reinstall complete: {success_count}/{len(selected)} successful")
        print("=" * 70)
        
        input("\nPress Enter to continue...")
    
    def add_addon(self):
        """Add a new addon to tracking."""
        print("\n" + "=" * 70)
        print("Add New Addon")
        print("=" * 70 + "\n")
        
        # Get repo URL
        repo_url = input("Enter GitHub repository URL: ").strip()
        if not repo_url:
            return
        
        # Extract addon name from URL
        addon_name = repo_url.rstrip('/').split('/')[-1]
        if addon_name.endswith('.git'):
            addon_name = addon_name[:-4]
        
        print(f"\nDetected addon name: {addon_name}")
        custom_name = input("Press Enter to use this name, or type a custom name: ").strip()
        if custom_name:
            addon_name = custom_name
        
        # Check if already exists
        if self.config.get_addon_by_name(addon_name):
            print(f"\n❌ Addon '{addon_name}' is already tracked!")
            input("\nPress Enter to continue...")
            return
        
        # Detect branch
        print("\n🔍 Detecting repository details...")
        branch = self.git.detect_branch(repo_url)
        print(f"   ✓ Branch: {branch}")
        
        # Check if should prefer releases
        print(f"   • Checking for releases...", end=" ")
        release_info = self.git.should_prefer_release(repo_url, branch)
        use_releases = release_info is not None
        
        if use_releases:
            print(f"✓\n   • Latest release: {release_info['tag']} ({release_info['name']})")
            print(f"   • Release is newer than {branch} branch - will track releases")
            tracking_method = "latest"
            tracking_ref = release_info['tag']
        else:
            print(f"No releases or branch is newer")
            print(f"   • Will track {branch} branch")
            tracking_method = branch
            tracking_ref = branch
        
        # Clone repo to detect structure
        temp_repo = self.temp_dir / addon_name
        print(f"\n   Cloning repository...", end=" ")
        is_tag = use_releases
        if not self.git.clone_repo(repo_url, temp_repo, tracking_ref, is_tag):
            print("❌")
            print("\n❌ Failed to clone repository!")
            input("\nPress Enter to continue...")
            return
        print("✓")
        
        # Auto-detect addon folders
        addon_folders = self.git.detect_addon_folders(temp_repo)
        print(f"\n📁 Detected addon folders: {', '.join(addon_folders) if addon_folders else 'None'}")
        
        if not addon_folders:
            print("\n⚠️  Could not auto-detect addon folders.")
            folder_input = input("Enter folder names (comma-separated): ").strip()
            if folder_input:
                addon_folders = [f.strip() for f in folder_input.split(',')]
            else:
                print("❌ No addon folders specified!")
                input("\nPress Enter to continue...")
                return
        
        # Auto-detect SavedVariables
        saved_vars = self.git.detect_saved_variables(temp_repo, addon_folders)
        print(f"💾 Detected SavedVariables: {', '.join(saved_vars) if saved_vars else 'None'}")
        
        # Select clients
        all_clients = list(self.config.config.get('game_clients', {}).keys())
        
        if HAS_INQUIRER:
            questions = [
                inquirer.Checkbox(
                    'clients',
                    message="Select game clients to install this addon to",
                    choices=[(cid, cid) for cid in all_clients],
                    default=all_clients
                )
            ]
            answers = inquirer.prompt(questions)
            if answers is None:
                return
            selected_clients = answers['clients']
        else:
            print("\nAvailable clients:")
            for i, cid in enumerate(all_clients, 1):
                print(f"  {i}. {cid}")
            print("\nEnter client numbers (comma-separated) or 'all':")
            selection = input("> ").strip().lower()
            
            if selection == 'all':
                selected_clients = all_clients
            else:
                try:
                    indices = [int(x.strip()) - 1 for x in selection.split(',')]
                    selected_clients = [all_clients[i] for i in indices if 0 <= i < len(all_clients)]
                except (ValueError, IndexError):
                    selected_clients = all_clients
        
        # Create addon config
        addon_config = {
            'name': addon_name,
            'repo': repo_url,
            'addon_folders': addon_folders,
            'saved_variables': saved_vars,
            'enabled': True,
            'clients': selected_clients
        }
        
        # Set tracking method (releases or branch)
        if use_releases:
            addon_config['tag'] = 'latest'
        else:
            addon_config['branch'] = tracking_method
        
        # Show summary
        print("\n" + "=" * 70)
        print("Addon Configuration:")
        print("=" * 70)
        print(f"Name: {addon_name}")
        print(f"Repository: {repo_url}")
        if use_releases:
            print(f"Tracking: Latest releases (tag: {tracking_ref})")
        else:
            print(f"Tracking: {tracking_method} branch")
        print(f"Folders: {', '.join(addon_folders)}")
        print(f"SavedVariables: {', '.join(saved_vars) if saved_vars else 'None'}")
        print(f"Clients: {', '.join(selected_clients)}")
        
        if self.confirm("\nAdd this addon?"):
            self.config.add_addon(addon_config)
            print(f"\n✅ Added {addon_name} to tracking!")
        
        input("\nPress Enter to continue...")
    
    def remove_addon(self):
        """Remove an addon from tracking."""
        addons = self.config.get_addons()
        
        if not addons:
            print("\n❌ No addons to remove!")
            input("\nPress Enter to continue...")
            return
        
        print("\n" + "=" * 70)
        print("Remove Addon from Tracking")
        print("=" * 70 + "\n")
        
        if HAS_INQUIRER:
            choices = [(a['name'], a) for a in addons]
            questions = [
                inquirer.List(
                    'addon',
                    message="Select addon to remove",
                    choices=choices,
                )
            ]
            
            answers = inquirer.prompt(questions)
            if answers is None:
                return
            
            addon = answers['addon']
        else:
            for i, addon in enumerate(addons, 1):
                print(f"{i}. {addon['name']}")
            
            choice = input("\nSelect addon number: ").strip()
            try:
                idx = int(choice) - 1
                if 0 <= idx < len(addons):
                    addon = addons[idx]
                else:
                    return
            except ValueError:
                return
        
        if self.confirm(f"\nRemove '{addon['name']}' from tracking?\n(This will not uninstall the addon from game)"):
            self.config.remove_addon(addon['name'])
            print(f"\n✅ Removed {addon['name']} from tracking")
        
        input("\nPress Enter to continue...")
    
    def list_addons(self):
        """List all tracked addons with details."""
        print("\n" + "=" * 70)
        print("Tracked Addons")
        print("=" * 70 + "\n")
        
        addons = self.config.get_addons()
        
        if not addons:
            print("❌ No addons tracked")
        else:
            for addon in addons:
                status = "✅" if addon.get('enabled', True) else "❌"
                print(f"{status} {addon['name']}")
                print(f"   Repository: {addon['repo']}")
                if 'tag' in addon:
                    print(f"   Tracking: tag={addon['tag']}")
                else:
                    print(f"   Tracking: branch={addon.get('branch', 'master')}")
                print(f"   Folders: {', '.join(addon['addon_folders'])}")
                print(f"   Clients: {', '.join(addon.get('clients', []))}")
                
                # Check local status
                repo_path = self.temp_dir / addon['name']
                local_commit = self.git.get_local_commit(repo_path)
                if local_commit:
                    print(f"   Local version: {local_commit}")
                else:
                    print(f"   Local version: Not downloaded")
                print()
        
        input("Press Enter to continue...")

    def _get_installed_addon_folders(self, addons_path: Path) -> List[str]:
        """Return visible addon folder names in a client AddOns directory."""
        if not addons_path.exists():
            return []

        folders = []
        for item in sorted(addons_path.iterdir(), key=lambda p: p.name.lower()):
            if item.name.startswith('.'):
                continue

            try:
                if item.is_dir():
                    folders.append(item.name)
            except OSError:
                # Ignore unreadable entries and continue scanning.
                continue

        return folders

    def _build_client_inventory(self, client_id: str, client_config: Dict, addons: List[Dict]) -> Dict[str, object]:
        """Build inventory comparison for one client."""
        addons_path = Path(client_config['addons_path'])
        report: Dict[str, object] = {
            'client_id': client_id,
            'client_name': client_config.get('name', client_id),
            'addons_path': str(addons_path),
            'path_exists': addons_path.exists(),
            'tracked_complete': [],
            'tracked_partial': [],
            'tracked_missing': [],
            'tracked_count': 0,
            'installed_folders': [],
            'configured_folders': [],
            'untracked_folders': [],
            'duplicate_folder_assignments': {},
        }

        if not report['path_exists']:
            return report

        installed_folders = self._get_installed_addon_folders(addons_path)
        installed_set = set(installed_folders)

        folder_to_addons: Dict[str, set] = {}
        tracked_complete = []
        tracked_partial = []
        tracked_missing = []

        for addon in addons:
            if client_id not in addon.get('clients', []):
                continue

            folder_names = addon.get('addon_folders', [])
            installation = AddonInstaller.inspect_addon_installation(folder_names, addons_path)
            entry = {
                'name': addon['name'],
                'existing_folders': installation['existing_folders'],
                'missing_folders': installation['missing_folders'],
            }

            if not installation['installed']:
                tracked_missing.append(entry)
            elif not installation['complete']:
                tracked_partial.append(entry)
            else:
                tracked_complete.append(entry)

            for folder_name in folder_names:
                folder_to_addons.setdefault(folder_name, set()).add(addon['name'])

        duplicate_assignments = {
            folder: sorted(list(owners))
            for folder, owners in folder_to_addons.items()
            if len(owners) > 1
        }

        configured_set = set(folder_to_addons.keys())
        untracked_folders = sorted(installed_set - configured_set)

        report['tracked_complete'] = sorted(tracked_complete, key=lambda item: item['name'].lower())
        report['tracked_partial'] = sorted(tracked_partial, key=lambda item: item['name'].lower())
        report['tracked_missing'] = sorted(tracked_missing, key=lambda item: item['name'].lower())
        report['tracked_count'] = len(tracked_complete) + len(tracked_partial) + len(tracked_missing)
        report['installed_folders'] = installed_folders
        report['configured_folders'] = sorted(configured_set)
        report['untracked_folders'] = untracked_folders
        report['duplicate_folder_assignments'] = duplicate_assignments

        return report

    def _append_inventory_report_lines(self, lines: List[str], report: Dict[str, object]) -> None:
        """Append one client inventory report to text output lines."""
        lines.append(f"Client: {report['client_name']} ({report['client_id']})")
        lines.append(f"AddOns path: {report['addons_path']}")

        if not report['path_exists']:
            lines.append("Result: INVALID PATH")
            lines.append("")
            return

        lines.append(
            "Summary: tracked="
            f"{report['tracked_count']} complete={len(report['tracked_complete'])} "
            f"partial={len(report['tracked_partial'])} missing={len(report['tracked_missing'])} "
            f"installed_folders={len(report['installed_folders'])} "
            f"untracked_folders={len(report['untracked_folders'])}"
        )

        if report['duplicate_folder_assignments']:
            lines.append("Duplicate folder assignments:")
            for folder_name, owners in sorted(report['duplicate_folder_assignments'].items()):
                lines.append(f"  - {folder_name}: {', '.join(owners)}")

        if report['tracked_missing']:
            lines.append("Tracked addons missing:")
            for entry in report['tracked_missing']:
                missing = ', '.join(entry['missing_folders'])
                lines.append(f"  - {entry['name']} (missing: {missing})")

        if report['tracked_partial']:
            lines.append("Tracked addons partially installed:")
            for entry in report['tracked_partial']:
                have = ', '.join(entry['existing_folders']) if entry['existing_folders'] else 'none'
                missing = ', '.join(entry['missing_folders']) if entry['missing_folders'] else 'none'
                lines.append(f"  - {entry['name']} (have: {have}; missing: {missing})")

        if report['untracked_folders']:
            lines.append("Installed but untracked folders:")
            for folder_name in report['untracked_folders']:
                lines.append(f"  - {folder_name}")

        lines.append("")

    def scan_addon_inventory(self):
        """Scan AddOns directories and compare with tracked configuration without modifying config."""
        print("\n" + "=" * 70)
        print("Scan AddOns Inventory (Report Only)")
        print("=" * 70)
        print("\nThis report does not change config or install/remove addons.")

        addons = [addon for addon in self.config.get_addons() if addon.get('enabled', True)]
        if not addons:
            print("\n❌ No enabled addons are currently tracked.")
            input("\nPress Enter to continue...")
            return

        enabled_clients = self.config.get_enabled_clients()
        if not enabled_clients:
            print("\n❌ No enabled clients configured.")
            input("\nPress Enter to continue...")
            return

        selected_clients = self.select_clients(enabled_clients, "Select clients to scan")
        if not selected_clients:
            return

        report_lines = [
            "WoW Addon Inventory Report",
            f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            "",
        ]

        for client_id, client_config in selected_clients:
            report = self._build_client_inventory(client_id, client_config, addons)
            client_name = report['client_name']

            print(f"\n📂 {client_name} ({client_id})")
            print(f"   Path: {report['addons_path']}")

            if not report['path_exists']:
                print("   ❌ AddOns path does not exist")
                self._append_inventory_report_lines(report_lines, report)
                continue

            print(
                "   Summary: "
                f"tracked={report['tracked_count']}, "
                f"complete={len(report['tracked_complete'])}, "
                f"partial={len(report['tracked_partial'])}, "
                f"missing={len(report['tracked_missing'])}, "
                f"installed folders={len(report['installed_folders'])}, "
                f"untracked folders={len(report['untracked_folders'])}"
            )

            if report['duplicate_folder_assignments']:
                print("   ⚠️  Duplicate folder assignments in config:")
                for folder_name, owners in sorted(report['duplicate_folder_assignments'].items()):
                    print(f"      - {folder_name}: {', '.join(owners)}")

            if report['tracked_missing']:
                print("   ❌ Tracked addons missing from game:")
                for entry in report['tracked_missing']:
                    print(f"      - {entry['name']} (missing: {', '.join(entry['missing_folders'])})")

            if report['tracked_partial']:
                print("   ⚠️  Tracked addons partially installed:")
                for entry in report['tracked_partial']:
                    have = ', '.join(entry['existing_folders']) if entry['existing_folders'] else 'none'
                    missing = ', '.join(entry['missing_folders']) if entry['missing_folders'] else 'none'
                    print(f"      - {entry['name']} (have: {have}; missing: {missing})")

            if report['untracked_folders']:
                preview_limit = 20
                print("   ℹ️  Installed but untracked folders:")
                for folder_name in report['untracked_folders'][:preview_limit]:
                    print(f"      - {folder_name}")
                remaining = len(report['untracked_folders']) - preview_limit
                if remaining > 0:
                    print(f"      ... and {remaining} more")

            self._append_inventory_report_lines(report_lines, report)

        print("\n" + "=" * 70)
        if self.confirm("Save a timestamped scan report to temp/ inventory_reports?"):
            report_dir = self.temp_dir / "inventory_reports"
            report_dir.mkdir(parents=True, exist_ok=True)
            report_name = f"inventory_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
            report_path = report_dir / report_name
            report_path.write_text("\n".join(report_lines), encoding='utf-8')
            print(f"✅ Report saved: {report_path}")

        input("\nPress Enter to continue...")
    
    def backup_all_savedvars(self):
        """Create backup of all SavedVariables."""
        print("\n" + "=" * 70)
        print("Create SavedVariables Backup")
        print("=" * 70 + "\n")
        
        # Ask what to backup
        if HAS_INQUIRER:
            questions = [
                inquirer.List(
                    'scope',
                    message="What would you like to backup?",
                    choices=[
                        ('Tracked addons only', 'tracked'),
                        ('ALL SavedVariables (complete backup)', 'all'),
                    ],
                )
            ]
            answers = inquirer.prompt(questions)
            if answers is None:
                return
            scope = answers['scope']
        else:
            print("Backup options:")
            print("  1. Tracked addons only")
            print("  2. ALL SavedVariables (complete backup)")
            choice = input("\nSelect option (1-2): ").strip()
            scope = 'all' if choice == '2' else 'tracked'
        
        # Select clients to backup
        all_clients = [(cid, cfg) for cid, cfg in self.config.config.get('game_clients', {}).items()]
        selected_clients = self.select_clients(all_clients, "Select clients to backup")
        
        if not selected_clients:
            return
        
        clients = selected_clients
        
        if scope == 'all':
            # Backup ALL SavedVariables
            print(f"\n💾 Creating complete backup of all SavedVariables...")
            
            if not self.confirm(f"Backup ALL SavedVariables for {len(clients)} client(s)?"):
                return
            
            success_count = 0
            for client_id, client_config in clients:
                client_name = client_config['name']
                wtf_path = Path(client_config['wtf_path'])
                
                print(f"\n📦 {client_name}:")
                backup_path = self.backup.backup_all_savedvariables(wtf_path, client_id, client_name)
                
                if backup_path:
                    success_count += 1
            
            if success_count > 0:
                print(f"\n✅ Complete backup finished for {success_count}/{len(clients)} client(s)!")
            else:
                print("\n⚠️  No SavedVariables found to backup")
        
        else:
            # Backup tracked addons only
            addons = [a for a in self.config.get_addons() if a.get('enabled', True)]
            
            if not addons:
                print("❌ No addons tracked to backup!")
                input("\nPress Enter to continue...")
                return
            
            if self.confirm(f"Backup SavedVariables for {len(addons)} tracked addon(s) across {len(clients)} client(s)?"):
                results = self.backup.backup_all_addons(addons, clients)
                
                if results:
                    print(f"\n✅ Backup complete!")
                    for client_id, paths in results.items():
                        print(f"   {client_id}: {len(paths)} addon(s) backed up")
                else:
                    print("\n⚠️  No SavedVariables found to backup")
        
        input("\nPress Enter to continue...")
    
    def view_backup_history(self):
        """View recent backups."""
        print("\n" + "=" * 70)
        print("Backup History")
        print("=" * 70 + "\n")
        
        backups = self.backup.list_backups(limit=20)
        
        if not backups:
            print("❌ No backups found")
        else:
            for backup_info in backups:
                timestamp = backup_info['timestamp'].strftime("%Y-%m-%d %H:%M:%S")
                print(f"📅 {timestamp}")
                print(f"   Clients: {', '.join(backup_info['clients'])}")
                print(f"   Addons: {backup_info['addon_count']}")
                print(f"   Path: {backup_info['path']}")
                print()
        
        input("Press Enter to continue...")
    
    def settings_menu(self):
        """Settings configuration."""
        while True:
            print("\n" + "=" * 70)
            print("Settings")
            print("=" * 70 + "\n")
            
            print("Game Clients:")
            for client_id, client_config in self.config.config.get('game_clients', {}).items():
                status = "✅ Enabled" if client_config.get('enabled', True) else "❌ Disabled"
                print(f"  [{status}] {client_config['name']} ({client_id})")
                print(f"     AddOns: {client_config['addons_path']}")
                print(f"     WTF: {client_config['wtf_path']}")
            
            print("\nGeneral Settings:")
            for key, value in self.config.get_setting('', {}).items():
                print(f"  {key}: {value}")
            
            print("\nOptions:")
            print("  1. Toggle client enabled/disabled")
            print("  2. Back to main menu")
            
            choice = input("\nSelect option: ").strip()
            
            if choice == '1':
                self.toggle_client_enabled()
            elif choice == '2':
                break
    
    def toggle_client_enabled(self):
        """Toggle a game client enabled/disabled status."""
        clients = list(self.config.config.get('game_clients', {}).items())
        
        if not clients:
            print("\n❌ No clients configured!")
            input("\nPress Enter to continue...")
            return
        
        print("\nSelect client to toggle:")
        for i, (cid, cfg) in enumerate(clients, 1):
            status = "Enabled" if cfg.get('enabled', True) else "Disabled"
            print(f"  {i}. {cfg['name']} ({cid}) - {status}")
        
        choice = input("\nSelect client number (or Enter to cancel): ").strip()
        
        if not choice:
            return
        
        try:
            idx = int(choice) - 1
            if 0 <= idx < len(clients):
                client_id, client_config = clients[idx]
                current_status = client_config.get('enabled', True)
                self.config.config['game_clients'][client_id]['enabled'] = not current_status
                self.config.save()
                
                new_status = "enabled" if not current_status else "disabled"
                print(f"\n✅ {client_config['name']} is now {new_status}")
                input("\nPress Enter to continue...")
        except ValueError:
            pass
    
    def confirm(self, message: str) -> bool:
        """Ask for yes/no confirmation."""
        response = input(f"{message} (y/N): ").strip().lower()
        return response == 'y'
    
    def run(self):
        """Main application loop."""
        # Check for updates on startup
        self.check_for_updates()
        
        while True:
            self.show_welcome()
            action = self.show_main_menu()
            
            if action == 'exit' or action is None:
                print("\n👋 Goodbye!\n")
                break
            elif action == 'check_updates':
                self.check_for_updates()
            elif action == 'force_reinstall':
                self.force_reinstall()
            elif action == 'scan_inventory':
                self.scan_addon_inventory()
            elif action == 'add_addon':
                self.add_addon()
            elif action == 'remove_addon':
                self.remove_addon()
            elif action == 'list_addons':
                self.list_addons()
            elif action == 'backup_all':
                self.backup_all_savedvars()
            elif action == 'view_backups':
                self.view_backup_history()
            elif action == 'settings':
                self.settings_menu()


def main():
    """Entry point."""
    if not HAS_INQUIRER:
        print("\n⚠️  Note: Install 'inquirer' for better experience:")
        print("   pip3 install inquirer\n")
    
    try:
        manager = AddonManager()
        manager.run()
    except KeyboardInterrupt:
        print("\n\n👋 Interrupted by user. Goodbye!\n")
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
