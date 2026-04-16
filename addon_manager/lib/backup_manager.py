"""
Backup and restore management for SavedVariables.
"""

import shutil
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Optional


class BackupManager:
    """Manages SavedVariables backups."""
    
    def __init__(self, backup_dir: str = "./backups/savedvariables"):
        self.backup_dir = Path(backup_dir)
        self.backup_dir.mkdir(parents=True, exist_ok=True)
    
    def create_backup(self, wtf_path: Path, addon_name: str, 
                     saved_vars: List[str], client_id: str) -> Optional[Path]:
        """Create backup of SavedVariables for an addon."""
        if not wtf_path.exists():
            print(f"    Warning: WTF path not found: {wtf_path}")
            return None
        
        # Create timestamped backup directory
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_path = self.backup_dir / timestamp / client_id / addon_name
        backup_path.mkdir(parents=True, exist_ok=True)
        
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
                
                for sv_file in saved_vars:
                    sv_path = sv_dir / sv_file
                    if sv_path.exists():
                        dest = backup_path / "Account" / account_folder.name / sv_file
                        dest.parent.mkdir(parents=True, exist_ok=True)
                        shutil.copy2(sv_path, dest)
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
                        
                        for sv_file in saved_vars:
                            sv_path = char_sv_dir / sv_file
                            if sv_path.exists():
                                dest = backup_path / "Characters" / realm_folder.name / char_folder.name / sv_file
                                dest.parent.mkdir(parents=True, exist_ok=True)
                                shutil.copy2(sv_path, dest)
                                backed_up = True
        
        if backed_up:
            return backup_path
        else:
            # Clean up empty backup directory
            try:
                backup_path.rmdir()
            except:
                pass
            return None
    
    def backup_all_addons(self, addons: List[Dict], clients: List[tuple]) -> Dict[str, List[Path]]:
        """Backup SavedVariables for all addons across all clients."""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        results = {}
        
        for client_id, client_config in clients:
            wtf_path = Path(client_config['wtf_path'])
            client_name = client_config['name']
            
            if not wtf_path.exists():
                print(f"⚠️  {client_name}: WTF path not found")
                continue
            
            print(f"\n📦 Backing up {client_name}...")
            client_backups = []
            
            for addon in addons:
                if not addon.get('enabled', True):
                    continue
                
                if client_id not in addon.get('clients', []):
                    continue
                
                saved_vars = addon.get('saved_variables', [])
                if not saved_vars:
                    continue
                
                print(f"  • {addon['name']}...", end=" ")
                
                backup_path = self.create_backup(
                    wtf_path, 
                    addon['name'], 
                    saved_vars, 
                    client_id
                )
                
                if backup_path:
                    client_backups.append(backup_path)
                    print("✓")
                else:
                    print("(no data)")
            
            if client_backups:
                results[client_id] = client_backups
        
        return results
    
    def backup_all_savedvariables(self, wtf_path: Path, client_id: str, client_name: str) -> Optional[Path]:
        """Backup ALL SavedVariables files from a game client."""
        if not wtf_path.exists():
            print(f"⚠️  {client_name}: WTF path not found")
            return None
        
        # Create timestamped backup directory
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_path = self.backup_dir / timestamp / client_id / "_ALL_ADDONS"
        backup_path.mkdir(parents=True, exist_ok=True)
        
        backed_up = False
        file_count = 0
        
        # Backup account-level SavedVariables
        account_sv_dir = wtf_path / "Account"
        if account_sv_dir.exists():
            for account_folder in account_sv_dir.iterdir():
                if not account_folder.is_dir():
                    continue
                
                sv_dir = account_folder / "SavedVariables"
                if not sv_dir.exists():
                    continue
                
                # Backup all .lua files
                for sv_file in sv_dir.glob("*.lua"):
                    dest = backup_path / "Account" / account_folder.name / sv_file.name
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(sv_file, dest)
                    backed_up = True
                    file_count += 1
                
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
                        
                        for sv_file in char_sv_dir.glob("*.lua"):
                            dest = backup_path / "Characters" / realm_folder.name / char_folder.name / sv_file.name
                            dest.parent.mkdir(parents=True, exist_ok=True)
                            shutil.copy2(sv_file, dest)
                            backed_up = True
                            file_count += 1
        
        if backed_up:
            print(f"  ✓ Backed up {file_count} file(s)")
            return backup_path
        else:
            # Clean up empty backup directory
            try:
                backup_path.rmdir()
            except:
                pass
            return None
    
    def list_backups(self, limit: int = 10) -> List[Dict]:
        """List recent backups."""
        backups = []
        
        for timestamp_dir in sorted(self.backup_dir.iterdir(), reverse=True):
            if not timestamp_dir.is_dir():
                continue
            
            # Parse timestamp
            try:
                timestamp = datetime.strptime(timestamp_dir.name, "%Y%m%d_%H%M%S")
            except ValueError:
                continue
            
            # Count clients and addons
            clients = []
            addon_count = 0
            
            for client_dir in timestamp_dir.iterdir():
                if not client_dir.is_dir():
                    continue
                clients.append(client_dir.name)
                addon_count += len([d for d in client_dir.iterdir() if d.is_dir()])
            
            backups.append({
                'timestamp': timestamp,
                'path': timestamp_dir,
                'clients': clients,
                'addon_count': addon_count
            })
            
            if len(backups) >= limit:
                break
        
        return backups
    
    def restore_backup(self, backup_path: Path, wtf_path: Path) -> bool:
        """Restore SavedVariables from a backup."""
        if not backup_path.exists():
            return False
        
        # Restore account SavedVariables
        account_backup = backup_path / "Account"
        if account_backup.exists():
            dest_account = wtf_path / "Account"
            for account_folder in account_backup.iterdir():
                if not account_folder.is_dir():
                    continue
                
                for sv_file in account_folder.iterdir():
                    dest = dest_account / account_folder.name / "SavedVariables" / sv_file.name
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(sv_file, dest)
        
        # Restore character SavedVariables
        char_backup = backup_path / "Characters"
        if char_backup.exists():
            for realm_folder in char_backup.iterdir():
                if not realm_folder.is_dir():
                    continue
                
                for char_folder in realm_folder.iterdir():
                    if not char_folder.is_dir():
                        continue
                    
                    for sv_file in char_folder.iterdir():
                        # Find the first account folder (we don't know which one)
                        account_sv_dir = wtf_path / "Account"
                        if account_sv_dir.exists():
                            accounts = [d for d in account_sv_dir.iterdir() if d.is_dir()]
                            if accounts:
                                dest = accounts[0] / realm_folder.name / char_folder.name / "SavedVariables" / sv_file.name
                                dest.parent.mkdir(parents=True, exist_ok=True)
                                shutil.copy2(sv_file, dest)
        
        return True
