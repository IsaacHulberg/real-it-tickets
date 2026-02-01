param(
  [string]$Stage2Url = ""
)

$ErrorActionPreference = "Continue"

$BootstrapRoot = "C:\LabBootstrap"
$LogDir = Join-Path $BootstrapRoot "logs"
$LogFile = Join-Path $LogDir "stage1.log"
$Stage2Path = Join-Path $BootstrapRoot "stage2-create-mockusers.ps1"
$TaskName = "Lab-Stage2-CreateMockUsers"

function Ensure-Directory {
  param([string]$Path)
  if (-not (Test-Path -Path $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

function Write-Log {
  param(
    [string]$Message,
    [string]$Level = "INFO"
  )
  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  Add-Content -Path $LogFile -Value "$timestamp [$Level] $Message"
}

try {
  Ensure-Directory -Path $BootstrapRoot
  Ensure-Directory -Path $LogDir
  Write-Log "Stage1 bootstrap starting."

  if (-not (Test-Path -Path $Stage2Path)) {
    $localStage2 = Join-Path $PSScriptRoot "stage2-create-mockusers.ps1"
    if (Test-Path -Path $localStage2) {
      Copy-Item -Path $localStage2 -Destination $Stage2Path -Force
      Write-Log "Copied Stage2 script from $localStage2 to $Stage2Path."
    } elseif ($Stage2Url -ne "") {
      Write-Log "Downloading Stage2 script from $Stage2Url."
      Invoke-WebRequest -Uri $Stage2Url -OutFile $Stage2Path -UseBasicParsing
      Write-Log "Downloaded Stage2 script to $Stage2Path."
    } else {
      Write-Log "Stage2 script not found and no Stage2Url provided." "ERROR"
      return
    }
  } else {
    Write-Log "Stage2 script already present at $Stage2Path."
  }

  if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Log "Removed existing scheduled task $TaskName."
  }

  $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$Stage2Path`""
  $trigger = New-ScheduledTaskTrigger -AtStartup -Delay (New-TimeSpan -Seconds 60)
  $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
  $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

  Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
  Write-Log "Scheduled task $TaskName registered to run Stage2 at startup."

  Write-Log "Stage1 bootstrap completed successfully."
} catch {
  Write-Log "Stage1 bootstrap failed: $($_.Exception.Message)" "ERROR"
  return
}
