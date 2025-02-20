# Funktion til at tjekke om Adobe Reader kører
function Check-AdobeReader {
    while (Get-Process -Name "AcroRd32" -ErrorAction SilentlyContinue) {
        Write-Host "Adobe Reader kører i øjeblikket. Luk den venligst for at fortsætte."
        Pause
    }
}

# Tjek for admin rettigheder
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Anmoder om administrative rettigheder..."
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Definer variabler
$installDir = "P:\adobe\Reader_dk_install.exe"
$tempDir = "$env:TEMP\AdobeInstaller"

# Opret en midlertidig mappe
if (-not (Test-Path -Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir | Out-Null
}

# Start kopiering af installationsprogrammet i en baggrundsjob
Write-Host "Kopierer installationsprogrammet til midlertidig mappe..."
$copyJob = Start-Job -ScriptBlock {
    param ($installDir, $tempDir)
    Copy-Item -Path $installDir -Destination "$tempDir\Reader_dk_install.exe"
} -ArgumentList $installDir, $tempDir

# Tjek om Adobe Acrobat Reader er installeret
Write-Host "Leder efter installationer af Adobe Acrobat."
$installed = Get-WmiObject -Query "SELECT * FROM Win32_Product WHERE Name LIKE 'Adobe Acrobat%'" -ErrorAction SilentlyContinue
if (-not $installed) {
    Write-Host "Adobe Acrobat Reader er ikke installeret. Springer afinstallations trin over."
} else {
    # Afinstaller eksisterende Adobe Acrobat Reader installationer
    Write-Host "Afinstallerer eksisterende Adobe Acrobat Reader installationer..."
    $installed | ForEach-Object { $_.Uninstall() }
    if (-not $?) {
        Write-Host "Fejl: Kunne ikke afinstallere eksisterende installationer."
        Pause
        exit 1
    }
    Write-Host "Afinstallation fuldført."
}

# Vent på at kopieringsjobbet fuldføres
if ($copyJob) { $copyJob | Wait-Job }

# Installer den nye version
Write-Host "Installerer Adobe Acrobat Reader..."
Start-Process -FilePath "$tempDir\Reader_dk_install.exe" -ArgumentList "/sAll /rs" -Wait
if (-not $?) {
    Write-Host "Fejl: Installation mislykkedes."
    exit 1
}
Write-Host "Installation fuldført."

# Ryd op i midlertidige filer
Write-Host "Rydder op i midlertidige filer..."
Remove-Item -Path "$tempDir\Reader_dk_install.exe" -Force
Remove-Item -Path $tempDir -Force -Recurse

Write-Host "Alle opgaver fuldført med succes!"
