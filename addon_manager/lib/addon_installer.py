"""
Addon installation and management.
"""

import shutil
from pathlib import Path
from typing import List, Dict


class AddonInstaller:
    """Handles addon installation to game directories."""

    @staticmethod
    def inspect_addon_installation(addon_folders: List[str], addons_path: Path) -> Dict[str, object]:
        """Inspect whether an addon is present and complete in a game directory."""
        if not addons_path.exists():
            return {
                "path_exists": False,
                "installed": False,
                "complete": False,
                "existing_folders": [],
                "missing_folders": list(addon_folders),
            }

        existing_folders = []
        missing_folders = []

        for folder_name in addon_folders:
            folder_path = addons_path / folder_name
            if folder_path.exists():
                existing_folders.append(folder_name)
            else:
                missing_folders.append(folder_name)

        installed = bool(existing_folders)
        complete = installed and not missing_folders

        return {
            "path_exists": True,
            "installed": installed,
            "complete": complete,
            "existing_folders": existing_folders,
            "missing_folders": missing_folders,
        }
    
    @staticmethod
    def install_addon(addon_folders: List[str], repo_path: Path, 
                     addons_path: Path) -> bool:
        """Install addon folders to game directory."""
        if not addons_path.exists():
            print(f"    Error: AddOns path not found: {addons_path}")
            return False
        
        success = True
        
        for folder_name in addon_folders:
            src_folder = repo_path / folder_name
            
            # Check if this is a single-folder repo (repo itself is the addon)
            if not src_folder.exists() and repo_path.name == folder_name:
                src_folder = repo_path
            
            if not src_folder.exists():
                print(f"    Warning: Source folder not found: {folder_name}")
                continue
            
            dest_folder = addons_path / folder_name
            
            # Remove existing folder
            if dest_folder.exists():
                try:
                    shutil.rmtree(dest_folder)
                except Exception as e:
                    print(f"    Error removing old version: {e}")
                    success = False
                    continue
            
            # Copy new version
            try:
                shutil.copytree(src_folder, dest_folder)
            except Exception as e:
                print(f"    Error installing {folder_name}: {e}")
                success = False
                continue
        
        return success
    
    @staticmethod
    def uninstall_addon(addon_folders: List[str], addons_path: Path) -> bool:
        """Remove addon folders from game directory."""
        if not addons_path.exists():
            return False
        
        for folder_name in addon_folders:
            folder_path = addons_path / folder_name
            if folder_path.exists():
                try:
                    shutil.rmtree(folder_path)
                except Exception as e:
                    print(f"    Error removing {folder_name}: {e}")
                    return False
        
        return True
    
    @staticmethod
    def is_addon_installed(addon_folders: List[str], addons_path: Path) -> bool:
        """Check if addon is currently installed."""
        installation = AddonInstaller.inspect_addon_installation(addon_folders, addons_path)
        return bool(installation["complete"])
