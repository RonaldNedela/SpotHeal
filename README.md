# SpotHeal 🩹

**Subtractive Luminance Compensation Mask for iPad Display Hotspots**  
*Targeted hardware defect elimination for iPad Pro 10.5" (2017), iPad Air 3, and all iOS devices.*

![iOS 12.0 - 18+](https://img.shields.io/badge/iOS-12.0--18%2B-blue?style=flat-square)
![Architecture](https://img.shields.io/badge/Architecture-arm64%20%7C%20arm64e-success?style=flat-square)
![Jailbreak](https://img.shields.io/badge/Jailbreak-Rootless%20%26%20Rootful-orange?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-lightgrey?style=flat-square)

---

## 📌 Background: The "White Spot" Defect

A notorious hardware flaw affecting the **iPad Pro 10.5-inch (2017)** and **iPad Air 3rd Gen** is the sudden appearance of an unevenly bright "white spot" (hotspot) located approximately 1–2 inches directly above the physical Home button. 

### Why Does It Happen?
The defect is physical: internal motherboard power connectors and battery tabs sit right beneath the display assembly. Over years of thermal cycles and handling pressure, these components press against the LCD backlight diffuser sheets, creating micro-deformation. This deformation concentrates light output, causing a localized zone with higher luminance ($\Delta L > 0$) that glares distractingly on white backgrounds, documents, websites, and drawing canvases.

Replacing the screen is costly, and replacement panels often develop the exact same flaw over time.

---

## 💡 The Solution: How SpotHeal Works

SpotHeal solves the problem entirely in software through **optical subtractive luminance masking**:

1. **Subtractive Masking**:  
   An inverse elliptical radial gradient is projected precisely over the hotspot at the `SpringBoard` compositor level. By attenuating display pixels in the defect zone by the exact excess percentage of light emitted by the backlight, the combined perceived luminance matches the surrounding screen surface. On white backgrounds, the spot completely vanishes.
2. **True Contrast Preservation**:  
   Because the mask is subtractive and non-opaque, dark and black pixels remain completely untouched. Dark mode contrast and movie viewing are 100% preserved.
3. **Hardware-Locked Physical Rotation Tracking**:  
   The physical hotspot remains fixed to the LCD panel above the Home button regardless of how the iPad is oriented. SpotHeal continuously observes `UIWindowScene` interface orientation and calculates coordinate transformation matrices for all 4 device orientations:
   - **Portrait** (Home button bottom): Pinned near screen bottom.
   - **Portrait Upside Down** (Home button top): Pinned near screen top.
   - **Landscape Right** (Home button right): Pinned near screen right edge.
   - **Landscape Left** (Home button left): Pinned near screen left edge.  
   The ellipse axes ($R_x$ and $R_y$) rotate in tandem with the physical defect geometry.

---

## ✨ Features

- 🎯 **Alignment Mode (Highlight Mask)**:
  Toggling this switch turns the mask into a high-visibility translucent red oval with a center crosshair, allowing you to position the mask right over the defect in seconds.
- ⬜ **Test on White Screen**:
  An instant full-screen calibration canvas inside Settings. Tap anywhere to dismiss and verify if the spot has disappeared against a pure white background.
- 📐 **Granular Position & Shape Controls**:
  - **Distance from Home Button (Y Offset)**: `20` to `350 pt` (default `120 pt`).
  - **Horizontal Shift (X Offset)**: `-150` to `+150 pt` (to compensate for off-center spots).
  - **Spot Width & Height (Radius X & Y)**: `10` to `200 pt` (independent axis scaling).
- 🎚️ **Luminance & Optical Matching**:
  - **Darkening Intensity**: `1.0%` to `40.0%` (optical attenuation factor).
  - **Edge Softness**: `0.5` to `2.5` (smooth cosine falloff feathering exponent).
  - **Color Tint**: `-50` (Cool Slate) to `+50` (Warm Amber) balance adjustment for chromatic backlight shifts.
- ⚡ **Real-Time Bidirectional Sync**:
  Dragging any slider updates the companion numerical text box and the SpringBoard overlay live in real time. You can also type exact numbers directly.
- 📸 **Clean Screenshot Capture**:
  Hooks into `SBScreenshotManager`, `SSScreenCapturer`, and `SBScreenFlash` to hide the mask during screen captures and recordings. Your screenshots remain pristine and defect-free.
- 👆 **Transparent Touch Pass-Through**:
  Implements `- (BOOL)_ignoresHitTest` and `userInteractionEnabled = NO` on a dedicated container window (`UIWindowLevelStatusBar + 50.0`). Zero interference with touches, Apple Pencil, or system gestures.

---

## 🚀 Installation

### Requirements
- **Device**: Any iPad or iPhone suffering from localized display hotspots (specifically tested on iPad Pro 10.5" 2017).
- **Firmware**: iOS 12.0 up to iOS 18+.
- **Jailbreak**: Dopamine, palera1n, XinaA15, unc0ver, checkra1n, Taurine, etc.
- **Dependencies**: `mobilesubstrate` (or ElleKit), `preferenceloader`.

### Package Manager (Sileo / Zebra / Filza)
1. Download the appropriate `.deb` for your jailbreak environment:
   - **Rootless (Dopamine / palera1n rootless):**  
     `com.ronci.spotheal_1.0.0_iphoneos-arm64.deb`
   - **Rootful (checkra1n / unc0ver / Taurine):**  
     `com.ronci.spotheal_1.0.0_iphoneos-arm.deb`
2. Open in **Sileo** / **Zebra** / **Filza** and tap **Install**.
3. Respring your device.

---

## 🛠️ Step-by-Step Calibration Guide

1. Open **Settings ➔ SpotHeal**.
2. Switch **Enabled** to `ON`.
3. Switch **Highlight Mask (Red)** to `ON`. A red oval with a crosshair target will appear on your screen.
4. Adjust **Distance from Home Button (Y Offset)** and **Horizontal Shift (X Offset)** until the white crosshair sits directly in the center of your display's white spot.
5. Adjust **Spot Width (Radius X)** and **Spot Height (Radius Y)** until the red ellipse matches the shape of the hotspot.
6. Switch **Highlight Mask (Red)** back to `OFF`.
7. Tap **Test on White Screen** to enter the pure white testing canvas:
   - If the spot is still brighter than the surroundings: increase **Darkening Intensity**.
   - If the spot looks like a dark smudge: decrease **Darkening Intensity**.
   - If the edges of the spot are noticeable: increase **Edge Softness**.
   - If the spot has a slight blue or yellow fringe: tune **Color Tint**.
8. Tap anywhere on screen to return to Settings. Your calibration is saved permanently across resprings and reboots!

---

## 🏗️ Building from Source

To compile the Fat Mach-O binaries (`arm64` + `arm64e`) and package both rootless and rootful Debian archives:

```bash
# Clone or navigate to the repository
cd SpotHeal

# Ensure build script is executable
chmod +x build.sh

# Run compilation & packaging
./build.sh
```

The script compiles:
- `SpotHeal.dylib`: SpringBoard dynamic library signed with `ldid -S`.
- `SpotHeal`: PreferenceBundle Mach-O bundle linked with `Preferences.tbd`.
- Generates high-resolution multi-scale preference icons.
- Stages and outputs `com.ronci.spotheal_1.0.0_iphoneos-arm64.deb` and `com.ronci.spotheal_1.0.0_iphoneos-arm.deb` to your `Downloads` directory.

---

## 📂 Project Structure

```
SpotHeal/
├── build.sh                                # Fat compiler & dual-package builder
├── README.md                               # Documentation
└── src/
    ├── SpotHeal.m                          # SpringBoard hook, rotation math & gradient drawing
    ├── SpotHeal.plist                      # MobileSubstrate filter (com.apple.springboard)
    └── pref_bundle/
        ├── Preferences.tbd                 # Linker stub for Preferences.framework
        ├── SpotHealRootListController.h    # Native Settings list controller header
        ├── SpotHealRootListController.m    # Bidirectional slider sync & white test canvas
        └── Resources/
            ├── Info.plist                  # Bundle identification
            ├── Root.plist                  # Specifier schema definition
            ├── entry.plist                 # PreferenceLoader entry configuration
            └── icon*.png                   # High-DPI Settings icons
```

---

## 👤 Author

- **Developer**: Ronci
- **Compatibility**: iPad Pro 10.5" (2017) • iPad Air 3 • iOS 12.0 – 18+

---

## 📄 License

This project is licensed under the MIT License - feel free to modify, distribute, and integrate.
