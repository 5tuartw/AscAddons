# PowerShell script to create Windows junctions for multi-folder addons
# Run this from Windows (not WSL)

$AddonsDir = "D:\Games\Ascension Launcher\resources\client\Interface\AddOns"
$GitReposDir = "$AddonsDir\.git-repos"

Write-Host "=== Creating Windows Junctions for Multi-Folder Addons ===" -ForegroundColor Cyan
Write-Host ""

function Create-Junction {
    param(
        [string]$LinkName,
        [string]$RepoName,
        [string]$SubFolder
    )
    
    $LinkPath = Join-Path $AddonsDir $LinkName
    $TargetPath = Join-Path $GitReposDir "$RepoName\$SubFolder"
    
    if (Test-Path $TargetPath) {
        if (Test-Path $LinkPath) {
            Remove-Item $LinkPath -Force -Recurse -ErrorAction SilentlyContinue
        }
        
        try {
            New-Item -ItemType Junction -Path $LinkPath -Target $TargetPath -Force | Out-Null
            Write-Host "  ✓ $LinkName" -ForegroundColor Green
        } catch {
            Write-Host "  ✗ $LinkName - $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "  ✗ $LinkName - Target not found: $SubFolder" -ForegroundColor Red
    }
}

# AtlasLoot
Write-Host "AtlasLoot:" -ForegroundColor Yellow
$folders = @("AtlasLoot", "AtlasLoot_BurningCrusade", "AtlasLoot_Cache", 
             "AtlasLoot_Crafting_OriginalWoW", "AtlasLoot_Crafting_TBC", 
             "AtlasLoot_Crafting_Wrath", "AtlasLoot_OriginalWoW", 
             "AtlasLoot_Vanity", "AtlasLoot_WorldEvents", "AtlasLoot_WrathoftheLichKing")
foreach ($folder in $folders) {
    Create-Junction $folder "AtlasLoot" $folder
}

# Bagnon
Write-Host "`nBagnon:" -ForegroundColor Yellow
$folders = @("Bagnon", "Bagnon_Config", "Bagnon_Forever", "Bagnon_GuildBank", "Bagnon_Tooltips")
foreach ($folder in $folders) {
    Create-Junction $folder "Bagnon" $folder
}

# MikScrollingBattleText
Write-Host "`nMikScrollingBattleText:" -ForegroundColor Yellow
Create-Junction "MikScrollingBattleText" "MikScrollingBattleText" "MikScrollingBattleText"
Create-Junction "MSBTOptions" "MikScrollingBattleText" "MSBTOptions"

# OmniCC
Write-Host "`nOmniCC:" -ForegroundColor Yellow
Create-Junction "OmniCC" "OmniCC" "OmniCC"
Create-Junction "OmniCC_Config" "OmniCC" "OmniCC_Config"

# pfQuest
Write-Host "`npfQuest:" -ForegroundColor Yellow
Create-Junction "pfQuest" "pfQuest" "pfQuest"
Create-Junction "pfQuest-ascension" "pfQuest" "pfQuest-ascension"

# WeakAuras
Write-Host "`nWeakAuras:" -ForegroundColor Yellow
$folders = @("WeakAuras", "WeakAurasArchive", "WeakAurasModelPaths", 
             "WeakAurasOptions", "WeakAurasStopMotion", "WeakAurasTemplates")
foreach ($folder in $folders) {
    Create-Junction $folder "WeakAuras-Ascension" $folder
}

# DBM - auto-detect
Write-Host "`nDeadlyBossMods:" -ForegroundColor Yellow
$dbmRepoPath = Join-Path $GitReposDir "DeadlyBossMods"
if (Test-Path $dbmRepoPath) {
    $dbmFolders = Get-ChildItem -Path $dbmRepoPath -Directory | Where-Object { $_.Name -like "DBM*" }
    foreach ($folder in $dbmFolders) {
        Create-Junction $folder.Name "DeadlyBossMods" $folder.Name
    }
}

Write-Host "`n=== Complete! ===" -ForegroundColor Green
Write-Host "`nAll multi-folder addons are now using Windows junctions." -ForegroundColor Cyan
Write-Host "Your sync tool should now properly detect these folders." -ForegroundColor Cyan
