param(
  [string]$ApiBaseUrl = "http://95.174.93.191:8080",
  [string]$Version = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

Push-Location $repoRoot
try {
  if ([string]::IsNullOrWhiteSpace($Version)) {
    $versionLine = Select-String -Path "pubspec.yaml" -Pattern "^version:\s*([^\s]+)" | Select-Object -First 1
    if (-not $versionLine) {
      throw "Unable to read version from pubspec.yaml."
    }

    $rawVersion = $versionLine.Matches[0].Groups[1].Value.Trim()
    $Version = ($rawVersion -split "\+")[0]
  }

  flutter pub get
  flutter build windows -t lib/admin_main.dart --dart-define=API_BASE_URL=$ApiBaseUrl

  $isccPath = Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"
  if (-not (Test-Path $isccPath)) {
    throw "Inno Setup 6 was not found. Install it from https://jrsoftware.org/isdl.php"
  }

  & $isccPath "/DMyAppVersion=$Version" "installer\AdminCafe.iss"

  Write-Host ""
  Write-Host "Installer created: dist\\AdminCafe-Setup-$Version.exe"
}
finally {
  Pop-Location
}
