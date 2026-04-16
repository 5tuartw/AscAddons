"""
Git operations for addon repositories.
"""

import subprocess
import json
import urllib.request
import urllib.error
import os
from pathlib import Path
from typing import Optional, Tuple, List, Dict
from datetime import datetime


class GitOperations:
    """Handles git operations for addon repositories."""
    
    @staticmethod
    def _get_github_token() -> Optional[str]:
        """Get GitHub token from environment or gh CLI."""
        # Check environment variable first
        token = os.environ.get('GITHUB_TOKEN') or os.environ.get('GH_TOKEN')
        if token:
            return token
        
        # Try to get from gh CLI
        try:
            result = subprocess.run(
                ['gh', 'auth', 'token'],
                capture_output=True,
                text=True,
                timeout=5
            )
            if result.returncode == 0 and result.stdout.strip():
                return result.stdout.strip()
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass
        
        return None
    
    @staticmethod
    def run_command(cmd: List[str], cwd: Optional[str] = None) -> Tuple[int, str, str]:
        """Run a shell command and return (returncode, stdout, stderr)."""
        result = subprocess.run(
            cmd,
            cwd=cwd,
            capture_output=True,
            text=True
        )
        return result.returncode, result.stdout, result.stderr
    
    @staticmethod
    def get_github_releases(repo_url: str) -> Optional[List[Dict]]:
        """Get releases from GitHub repo API."""
        # Parse owner/repo from URL
        # e.g., https://github.com/owner/repo or https://github.com/owner/repo/
        parts = repo_url.rstrip('/').split('/')
        if len(parts) < 2:
            return None
        
        owner = parts[-2]
        repo = parts[-1].replace('.git', '')
        
        api_url = f"https://api.github.com/repos/{owner}/{repo}/releases"
        
        try:
            req = urllib.request.Request(api_url)
            req.add_header('Accept', 'application/vnd.github.v3+json')
            
            # Add authentication if available
            token = GitOperations._get_github_token()
            if token:
                req.add_header('Authorization', f'token {token}')
            
            with urllib.request.urlopen(req, timeout=10) as response:
                data = json.loads(response.read().decode())
                return data
        except (urllib.error.URLError, urllib.error.HTTPError, json.JSONDecodeError):
            return None
    
    @staticmethod
    def get_latest_release(repo_url: str) -> Optional[Dict]:
        """Get the latest (non-prerelease) release from GitHub."""
        releases = GitOperations.get_github_releases(repo_url)
        if not releases:
            return None
        
        # Filter out prereleases and drafts, find latest
        for release in releases:
            if not release.get('prerelease', False) and not release.get('draft', False):
                return {
                    'tag': release['tag_name'],
                    'name': release.get('name', release['tag_name']),
                    'published_at': release['published_at'],
                    'url': release['html_url']
                }
        
        return None
    
    @staticmethod
    def get_branch_commit_date(repo_url: str, branch: str = "master") -> Optional[str]:
        """Get commit date of branch HEAD via API."""
        parts = repo_url.rstrip('/').split('/')
        if len(parts) < 2:
            return None
        
        owner = parts[-2]
        repo = parts[-1].replace('.git', '')
        
        api_url = f"https://api.github.com/repos/{owner}/{repo}/commits/{branch}"
        
        try:
            req = urllib.request.Request(api_url)
            req.add_header('Accept', 'application/vnd.github.v3+json')
            
            # Add authentication if available
            token = GitOperations._get_github_token()
            if token:
                req.add_header('Authorization', f'token {token}')
            
            with urllib.request.urlopen(req, timeout=10) as response:
                data = json.loads(response.read().decode())
                return data['commit']['committer']['date']
        except (urllib.error.URLError, urllib.error.HTTPError, json.JSONDecodeError, KeyError):
            return None
    
    @staticmethod
    def should_prefer_release(repo_url: str, branch: str = "master") -> Optional[Dict]:
        """
        Check if latest release is newer than branch HEAD.
        Returns release info dict if release is newer, None otherwise.
        """
        latest_release = GitOperations.get_latest_release(repo_url)
        if not latest_release:
            return None
        
        branch_date_str = GitOperations.get_branch_commit_date(repo_url, branch)
        if not branch_date_str:
            # Can't compare, assume release is valid
            return latest_release
        
        try:
            release_date = datetime.fromisoformat(latest_release['published_at'].replace('Z', '+00:00'))
            branch_date = datetime.fromisoformat(branch_date_str.replace('Z', '+00:00'))
            
            if release_date > branch_date:
                return latest_release
        except (ValueError, KeyError):
            pass
        
        return None
    
    @staticmethod
    def get_remote_commit(repo_url: str, branch: str = "master") -> Optional[str]:
        """Get the latest commit hash from remote repo."""
        cmd = ["git", "ls-remote", repo_url, f"refs/heads/{branch}"]
        returncode, stdout, stderr = GitOperations.run_command(cmd)
        
        if returncode != 0:
            # Try 'main' branch if 'master' fails
            if branch == "master":
                cmd = ["git", "ls-remote", repo_url, "refs/heads/main"]
                returncode, stdout, stderr = GitOperations.run_command(cmd)
                if returncode == 0 and stdout.strip():
                    return stdout.split()[0][:8]
            return None
        
        if stdout.strip():
            return stdout.split()[0][:8]
        return None
    
    @staticmethod
    def get_local_commit(local_path: Path) -> Optional[str]:
        """Get the current commit hash from local repo."""
        if not (local_path / ".git").exists():
            return None
        
        cmd = ["git", "rev-parse", "--short=8", "HEAD"]
        returncode, stdout, stderr = GitOperations.run_command(cmd, cwd=str(local_path))
        
        if returncode != 0:
            return None
        
        return stdout.strip()
    
    @staticmethod
    def detect_branch(repo_url: str) -> str:
        """Detect the default branch of a repository."""
        # Try master first
        cmd = ["git", "ls-remote", "--symref", repo_url, "HEAD"]
        returncode, stdout, stderr = GitOperations.run_command(cmd)
        
        if returncode == 0 and stdout:
            # Parse output like: "ref: refs/heads/main	HEAD"
            for line in stdout.split('\n'):
                if line.startswith('ref:'):
                    parts = line.split('/')
                    if len(parts) >= 3:
                        return parts[-1].split()[0]
        
        # Fallback to checking common branches
        for branch in ['master', 'main']:
            if GitOperations.get_remote_commit(repo_url, branch):
                return branch
        
        return "master"  # Default fallback
    
    @staticmethod
    def clone_repo(repo_url: str, local_path: Path, branch_or_tag: str = "master", is_tag: bool = False) -> bool:
        """Clone a repository by branch or tag."""
        if is_tag:
            # For tags, use --branch (works with tags too)
            cmd = ["git", "clone", "--branch", branch_or_tag, "--depth", "1", repo_url, str(local_path)]
        else:
            cmd = ["git", "clone", "-b", branch_or_tag, "--depth", "1", repo_url, str(local_path)]
        returncode, stdout, stderr = GitOperations.run_command(cmd)
        return returncode == 0
    
    @staticmethod
    def update_repo(local_path: Path, branch_or_tag: str = "master", is_tag: bool = False) -> bool:
        """Update an existing repository."""
        if is_tag:
            # For tags, fetch all tags and checkout specific one
            cmd = ["git", "fetch", "--tags"]
            returncode, stdout, stderr = GitOperations.run_command(cmd, cwd=str(local_path))
            if returncode != 0:
                return False
            
            # Checkout the tag
            cmd = ["git", "checkout", f"tags/{branch_or_tag}"]
            returncode, stdout, stderr = GitOperations.run_command(cmd, cwd=str(local_path))
            return returncode == 0
        else:
            # Fetch latest
            cmd = ["git", "fetch", "origin", branch_or_tag]
            returncode, stdout, stderr = GitOperations.run_command(cmd, cwd=str(local_path))
            
            if returncode != 0:
                return False
            
            # Reset to latest
            cmd = ["git", "reset", "--hard", f"origin/{branch_or_tag}"]
            returncode, stdout, stderr = GitOperations.run_command(cmd, cwd=str(local_path))
            
            return returncode == 0
    
    @staticmethod
    def clone_or_update(repo_url: str, local_path: Path, branch_or_tag: str = "master", is_tag: bool = False) -> bool:
        """Clone repo if needed, or update if exists."""
        if local_path.exists():
            return GitOperations.update_repo(local_path, branch_or_tag, is_tag)
        else:
            return GitOperations.clone_repo(repo_url, local_path, branch_or_tag, is_tag)
    
    @staticmethod
    def detect_addon_folders(repo_path: Path) -> List[str]:
        """Auto-detect addon folders by looking for .toc files."""
        addon_folders = []
        
        # Look for .toc files in immediate subdirectories
        for item in repo_path.iterdir():
            if item.is_dir():
                # Check if this folder contains a .toc file
                toc_files = list(item.glob("*.toc"))
                if toc_files:
                    addon_folders.append(item.name)
        
        # If no subdirectories with .toc, check root level
        if not addon_folders:
            toc_files = list(repo_path.glob("*.toc"))
            if toc_files:
                # This repo IS the addon folder
                addon_folders.append(repo_path.name)
        
        return sorted(addon_folders)
    
    @staticmethod
    def detect_saved_variables(repo_path: Path, addon_folders: List[str]) -> List[str]:
        """Detect likely SavedVariables file names from .toc files."""
        saved_vars = set()
        
        for folder in addon_folders:
            folder_path = repo_path / folder
            if not folder_path.exists():
                folder_path = repo_path  # Try root if folder doesn't exist
            
            # Find .toc files
            toc_files = list(folder_path.glob("*.toc"))
            
            for toc_file in toc_files:
                try:
                    with open(toc_file, 'r', encoding='utf-8', errors='ignore') as f:
                        for line in f:
                            # Look for SavedVariables declarations
                            line = line.strip()
                            if line.startswith('## SavedVariables:'):
                                vars_line = line.split(':', 1)[1].strip()
                                # Split by comma and clean up
                                for var in vars_line.split(','):
                                    var = var.strip()
                                    if var:
                                        saved_vars.add(f"{var}.lua")
                            elif line.startswith('## SavedVariablesPerCharacter:'):
                                vars_line = line.split(':', 1)[1].strip()
                                for var in vars_line.split(','):
                                    var = var.strip()
                                    if var:
                                        saved_vars.add(f"{var}.lua")
                except Exception:
                    continue
        
        return sorted(list(saved_vars))
