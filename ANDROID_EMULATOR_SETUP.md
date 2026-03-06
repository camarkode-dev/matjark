# Android Emulator Setup - Manual Steps

## Quick Setup Option: Use Android Studio

The easiest way to create an Android emulator is using Android Studio GUI:

1. Open Android Studio
2. Go to **Tools → Device Manager**
3. Click **Create Device**
4. Select **Pixel 6** (or your preferred device)
5. Select **Android 35** release
6. Click **Next** → **Finish**

This will create an AVD named something like "Pixel_6_API_35"

---

## Manual CLI Setup (if you prefer command line)

### Step 1: Accept Android SDK Licenses
```powershell
$SDK = "$env:LOCALAPPDATA\Android\Sdk"
$LICENSES = "$SDK\licenses"

# Create licenses directory
New-Item -Path $LICENSES -ItemType Directory -Force | Out-Null

# Accept all licenses
"8933bad161af4038430b9d5731e91b04b850aabf" | Out-File -Path "$LICENSES\android-sdk-license" -Encoding ASCII -Force
"84831b9409646a918e30573bab4c9c91346d8abd" | Out-File -Path "$LICENSES\android-sdk-preview-license" -Encoding ASCII -Force
"d975f751698a77b662f1254631fd67f2b4b50044" | Out-File -Path "$LICENSES\google-android-ndk-license" -Encoding ASCII -Force

Write-Host "Licenses accepted" -ForegroundColor Green
```

### Step 2: Manually Create AVD Configuration
```powershell
$ANDROID_SDK_ROOT = "$env:LOCALAPPDATA\Android\Sdk"
$AVD_HOME = "$env:USERPROFILE\.android\avd"
$AVD_NAME = "Pixel_6_API_35"

# Create AVD directory
$AVD_DIR = "$AVD_HOME\$AVD_NAME.avd"
New-Item -Path $AVD_DIR -ItemType Directory -Force | Out-Null

# Create config.ini
@"
AvdId=$AVD_NAME
PlayStore.Enabled=false
abi.type=x86_64
abi.use2ndzip=no
avd.ini.displayname=$AVD_NAME
avd.ini.encoding=UTF-8
backup.enabled=true
baseImage.enabled=true
boot.prop.qemu.diskext=qcow2
cpu.acceleration=off
disk.dataPartition.size=1600M
disk.wipedata.enabled=false
fastboot.forceChosenSnapshotBoot=no
fastboot.forceColdBoot=no
fastboot.forceFastBoot=yes
hw.accelerometer=yes
hw.arc=false
hw.audioInput=yes
hw.battery=yes
hw.camera.back=emulated
hw.camera.front=emulated
hw.cpu.cores=4
hw.dPad=no
hw.device.hash=0
hw.device.hash2=unknown
hw.device.manufacturer=Google
hw.device.model=Pixel 6
hw.device.name=Pixel 6
hw.gps=yes
hw.gpu.enabled=yes
hw.gpu.mode=auto
hw.initialOrientation=Portrait
hw.keyboard=yes
hw.keyboard.lid=no
hw.lcd.density=420
hw.lcd.height=2400
hw.lcd.width=1080
hw.mainKeys=no
hw.ramSize=3072
hw.sdCard=no
hw.sensors.orientation=yes
hw.sensors.proximity=yes
hw.speaker=yes
hw.trackBall=no
hw.useext4=yes
image.sysdir.1=/system
kernel.dir=$ANDROID_SDK_ROOT/system-images/android-35/google_apis/x86_64
kernel.newDeviceNaming=yes
kernel.parameters=
kernel.supportsYaffs2=no
showDeviceFrame=yes
skin.dynamic=yes
skin.name=pixel_6
skin.path=$ANDROID_SDK_ROOT/skins/pixel_6
snapshots.autosave=yes
tag.display=Google APIs
tag.id=google_apis
vm.heapSize=512
"@ | Out-File -Path "$AVD_DIR\config.ini" -Encoding ASCII -Force

# Create quickbootChoice.ini
@"
choice=cold
"@ | Out-File -Path "$AVD_DIR\quickbootChoice.ini" -Encoding ASCII -Force

Write-Host "AVD configuration created at: $AVD_DIR" -ForegroundColor Green
```

### Step 3: Start the Emulator
```powershell
$SDK = "$env:LOCALAPPDATA\Android\Sdk"
& "$SDK\emulator\emulator.exe" -avd "Pixel_6_API_35" -no-snapshot-load
```

---

## The Real Issue: System Images Missing

To use the manual method, you need to **install system images** first. Unfortunately, without working sdkmanager, this is difficult via CLI.

### Solution:
1. **Recommended**: Use Android Studio to create the AVD (most reliable)
2. **Alternative**: Download system images:
   - Visit: https://developer.android.com/studio/releases/sdk-tools
   - Get the system-images package
   - Extract to `$env:LOCALAPPDATA\Android\Sdk\system-images\`

---

## Quick Test - Run on Chrome First

While you set up Android, test your Flutter app on Chrome:

```powershell
cd d:\matjark
flutter run -d chrome
```

This will help verify the app compiles and Firebase is working.

