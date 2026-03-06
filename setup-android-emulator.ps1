# Android Emulator Setup Script for Flutter
# This script configures the Android SDK and creates an emulator

$SDK = "$env:LOCALAPPDATA\Android\Sdk"
$CMDLINE_TOOLS_VERSION = "12.0"
$CMDLINE_TOOLS_URL = "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"

Write-Host "=== Android Emulator Setup ===" -ForegroundColor Cyan

# 1. Download cmdline-tools if not present
if (-not (Test-Path "$SDK\cmdline-tools\$CMDLINE_TOOLS_VERSION")) {
    Write-Host "Downloading Android cmdline-tools..." -ForegroundColor Yellow
    
    $TempDir = "$env:TEMP\cmdline-tools-download"
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
    
    $ZipFile = "$TempDir\cmdline-tools.zip"
    
    try {
        # Download with progress
        $ProgressPreference = 'Continue'
        Invoke-WebRequest -Uri $CMDLINE_TOOLS_URL -OutFile $ZipFile -UseBasicParsing
        Write-Host "Download complete." -ForegroundColor Green
        
        # Extract
        Write-Host "Extracting cmdline-tools..." -ForegroundColor Yellow
        Expand-Archive -Path $ZipFile -DestinationPath $TempDir -Force
        
        # Move to correct location
        $ExtractedPath = "$TempDir\cmdline-tools"
        New-Item -ItemType Directory -Path "$SDK\cmdline-tools\$CMDLINE_TOOLS_VERSION" -Force | Out-Null
        Move-Item -Path "$ExtractedPath\*" -Destination "$SDK\cmdline-tools\$CMDLINE_TOOLS_VERSION" -Force
        
        # Create symlink for 'latest'
        if (Test-Path "$SDK\cmdline-tools\latest") {
            Remove-Item "$SDK\cmdline-tools\latest" -Force -Recurse
        }
        New-Item -ItemType SymbolicLink -Path "$SDK\cmdline-tools\latest" -Target "$SDK\cmdline-tools\$CMDLINE_TOOLS_VERSION" -Force | Out-Null
        
        Write-Host "cmdline-tools installed successfully." -ForegroundColor Green
        Remove-Item -Path $TempDir -Recurse -Force
    }
    catch {
        Write-Host "Failed to download cmdline-tools: $_" -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "cmdline-tools already installed." -ForegroundColor Green
}

# 2. Set environment variables
$env:ANDROID_SDK_ROOT = $SDK
$env:ANDROID_HOME = $SDK
[Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $SDK, "User")
[Environment]::SetEnvironmentVariable("ANDROID_HOME", $SDK, "User")

# 3. Add to PATH
$sdkManagerPath = "$SDK\cmdline-tools\latest\bin"
if ($sdkManagerPath -notin $env:Path.Split(";")) {
    $env:Path += ";$sdkManagerPath;$SDK\platform-tools;$SDK\emulator"
    [Environment]::SetEnvironmentVariable("Path", $env:Path, "User")
}

Write-Host "Environment variables set." -ForegroundColor Green

# 4. Accept Android SDK licenses
Write-Host "Accepting Android SDK licenses..." -ForegroundColor Yellow

$LICENSES_DIR = "$SDK\licenses"
New-Item -ItemType Directory -Path $LICENSES_DIR -Force | Out-Null

# Create license files (accepting)
@(
    "android-sdk-license",
    "android-sdk-preview-license",
    "android-googletv-license",
    "mips-android-system-image-license",
    "google-android-ndk-license",
    "ndk-license"
) | ForEach-Object {
    $LicenseFile = "$LICENSES_DIR\$_"
    if (-not (Test-Path $LicenseFile)) {
        @"
8933bad161af4038430b9d5731e91b04b850aabf
"@ | Out-File -FilePath $LicenseFile -Encoding ASCII -Force
    }
}

Write-Host "Licenses accepted." -ForegroundColor Green

# 5. Install required SDK packages
Write-Host "Installing SDK packages (platforms, system-images)..." -ForegroundColor Yellow

$sdkmanager = "$SDK\cmdline-tools\latest\bin\sdkmanager.bat"

if (Test-Path $sdkmanager) {
    & $sdkmanager --install "platform-tools" "platforms;android-35" "system-images;android-35;google_apis;x86_64" "emulator" 2>&1 | Out-Null
    Write-Host "SDK packages installed." -ForegroundColor Green
}
else {
    Write-Host "Warning: sdkmanager not found at $sdkmanager" -ForegroundColor Red
}

# 6. Create Android Virtual Device (AVD)
Write-Host "Creating Android Virtual Device (AVD)..." -ForegroundColor Yellow

$avdmanager = "$SDK\cmdline-tools\latest\bin\avdmanager.bat"
$avdName = "Pixel_API_35"

if (Test-Path $avdmanager) {
    # Delete existing AVD if present
    & $avdmanager delete avd -n $avdName 2>&1 | Out-Null
    
    # Create new AVD
    "yes" | & $avdmanager create avd -n $avdName -k "system-images;android-35;google_apis;x86_64" -d pixel 2>&1 | Out-Null
    
    Write-Host "AVD '$avdName' created successfully." -ForegroundColor Green
}
else {
    Write-Host "Warning: avdmanager not found at $avdmanager" -ForegroundColor Red
}

# 7. List available devices
Write-Host "`n=== Available Devices ===" -ForegroundColor Cyan
& flutter devices

Write-Host "`n=== Setup Complete ===" -ForegroundColor Green
Write-Host "To start the emulator, run:" -ForegroundColor Yellow
Write-Host "  flutter run -d $avdName" -ForegroundColor White
Write-Host "`nOr start it directly:" -ForegroundColor Yellow
Write-Host "  `$env:ANDROID_SDK_ROOT\emulator\emulator.exe -avd $avdName" -ForegroundColor White
