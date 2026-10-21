# SpotHeal

**Subtractive Luminance Compensation Mask for iPad Display Hotspots**  
*Targeted optical defect elimination for iPad Pro 10.5" (2017), iPad Air 3, and iOS laminated displays.*

![iOS 12.0 - 18+](https://img.shields.io/badge/iOS-12.0--18%2B-blue?style=flat-square)
![Architecture](https://img.shields.io/badge/Architecture-arm64%20%7C%20arm64e-success?style=flat-square)
![Jailbreak](https://img.shields.io/badge/Jailbreak-Rootless%20%26%20Rootful-orange?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-lightgrey?style=flat-square)

---

## Background: Hardware Hotspot Defect

A prevalent hardware defect affecting the iPad Pro 10.5-inch (2017) and iPad Air (3rd generation) is the formation of a localized, unevenly bright luminance hotspot situated roughly 1 to 2 inches directly above the physical Home button.

### Root Cause
The defect originates from internal mechanical pressure:
1. **Component Positioning**: Motherboard logic connectors and battery contact tabs sit directly beneath the display assembly in this specific region.
2. **Thermal and Pressure Cycling**: Repeated thermal expansion, combined with normal handling pressure, causes these internal structures to press into the optical backlight diffuser sheets.
3. **Diffuser Deformation**: Micro-deformations in the reflective diffuser concentrate backlight photon scatter, creating an area of elevated luminance (Delta L > 0) that is visibly distracting against light backgrounds, documents, and canvas applications.

Panel replacements are financially inefficient, and replacement assemblies typically develop identical deformation over extended use.

---

## Technical Approach: Subtractive Luminance Attenuation

SpotHeal neutralizes the hotspot purely in software at the compositor level through inverse radial luminance attenuation:

```
[ Localized Backlight Hotspot: +Delta L ] + [ SpotHeal Inverse Radial Mask: -Delta L ] = [ Uniform Luminance Surface ]
```

1. **Subtractive Radial Masking**:  
   An inverse elliptical gradient mask is composited directly above the physical defect inside the `SpringBoard` render tree. By attenuating pixel values within the hotspot perimeter by the precise excess percentage emitted by the diffuser deformation, perceived luminance matches the surrounding screen surface. On uniform white backgrounds, the defect is eliminated.
2. **Preservation of Contrast and Dynamic Range**:  
   Because the attenuation is non-opaque and subtractive, black levels and dark mode interfaces remain untouched. Video playback and dark media retain full dynamic range.
3. **Physical Hardware Rotation Tracking**:  
   The physical deformation remains stationary relative to the Home button regardless of software orientation. SpotHeal observes `UIWindowScene` interface orientation events and calculates transformation matrices across all four device orientations:
   - **Portrait** (Home button at bottom): Pinned to lower screen quadrant.
   - **Portrait Upside Down** (Home button at top): Pinned to upper screen quadrant.
   - **Landscape Right** (Home button on right): Pinned to right screen margin.
   - **Landscape Left** (Home button on left): Pinned to left screen margin.  
   The elliptical axes ($R_x$ and $R_y$) rotate in hardware space to preserve the physical defect geometry.

---

## Features

- **Alignment Mode (Calibration Overlay)**: Toggles a high-visibility translucent red ellipse with an optical crosshair, allowing exact spatial alignment over the defect center.
- **Full-Screen White Canvas Test**: Built-in full-screen uniform white verification canvas within Settings to confirm complete neutralization. Tap anywhere to dismiss.
- **Granular Position and Geometry Controls**:
  - **Distance from Home Button (Y Offset)**: 20 pt to 350 pt (nominal default: 120 pt).
  - **Horizontal Shift (X Offset)**: -150 pt to +150 pt for off-center alignment.
  - **Ellipse Radii (Radius X and Radius Y)**: 10 pt to 200 pt independent dual-axis scaling.
- **Optical Matching Parameters**:
  - **Darkening Intensity**: 1.0% to 40.0% precision attenuation factor.
  - **Edge Softness**: 0.5 to 2.5 smooth falloff exponent to prevent perimeter halos.
  - **Color Tint Adjustment**: -50 (Cool Slate) to +50 (Warm Amber) chromatic compensation for backlight tint shifts.
- **Bidirectional Control Synchronization**: Direct live synchronization between Settings text fields, sliders, and the SpringBoard compositor window.
- **Clean Screenshot Interception**: Intercepts `SSScreenCapturer`, `SBScreenshotManager`, and `SBScreenFlash` to automatically dismiss the mask during screenshots, keeping captured images unblemished.
- **Zero Input Latency**: Operates inside a non-interactive overlay window (`UIWindowLevelStatusBar + 50.0`) implementing `_ignoresHitTest` and `userInteractionEnabled = NO`. Zero interference with touches, Apple Pencil, or system gestures.

---

## Installation

### Requirements
- **Hardware**: iPad Pro 10.5" (2017), iPad Air 3, or any iOS device with localized backlight hotspots.
- **Firmware**: iOS/iPadOS 12.0 up to iOS/iPadOS 18.x.
- **Jailbreak**: Dopamine, palera1n, XinaA15, checkra1n, unc0ver, Taurine.
- **Dependencies**: `preferenceloader`, `mobilesubstrate` (or ElleKit).

### Package Deployment
1. Download the Debian package matching your bootstrap:
   - **Rootless (Dopamine / palera1n rootless):**  
     `com.ronci.spotheal_1.0.1_iphoneos-arm64.deb`
   - **Rootful (checkra1n / unc0ver / Taurine):**  
     `com.ronci.spotheal_1.0.1_iphoneos-arm.deb`
2. Install via Sileo, Zebra, or Filza.
3. Perform a respring.

---

## Performance and Resource Optimization (v1.0.1)

In v1.0.0, the radial gradient mask was rendered across a full-screen `UIView` with `UIViewContentModeRedraw`. On high-resolution displays (such as the 2224x1668 iPad Pro 10.5" canvas), this required allocating a 14.8 MB (up to 30 MB double-buffered) software bitmap backing store and re-evaluating trigonometric falloff algorithms across millions of pixels on every rotation event.

In v1.0.1, the rendering pipeline was completely redesigned:
- **Localized Geometry Backing Store**: The full-screen overlay view has been stripped of software backing store allocation (`opaque = NO`, `clearColor`). Attenuation rendering is now confined strictly to a localized micro-view (`SpotDefectDotView`) sized precisely to `(2 * radiusX) x (2 * radiusY)` points (~90x90 pt at nominal settings).
- **99.78% Memory Footprint Reduction**: Backing buffer memory dropped from 14.8 MB to ~32 KB.
- **Zero-CPU Hardware Rotation Handling**: When the device rotates, interface orientation updates only translate the subview's `center` coordinates on the GPU compositor. Zero CPU gradient re-rasterization occurs during rotation or scrolling.
- **Notification Debouncing**: Eliminated redundant multi-stage redraw dispatches on device orientation and status bar updates.

---

## Calibration Guide

1. Open **Settings -> SpotHeal**.
2. Toggle **Enabled** to active.
3. Toggle **Highlight Mask (Red)** to active. A red target oval with a center crosshair will appear on the display.
4. Adjust **Distance from Home Button (Y Offset)** and **Horizontal Shift (X Offset)** until the crosshair aligns with the center of the hotspot.
5. Scale **Spot Width (Radius X)** and **Spot Height (Radius Y)** until the ellipse boundaries encompass the defect area.
6. Toggle **Highlight Mask (Red)** to inactive.
7. Tap **Test on White Screen** to enter the pure white inspection canvas:
   - If the hotspot is still brighter than surrounding pixels: increase **Darkening Intensity**.
   - If a dark shadow is visible: decrease **Darkening Intensity**.
   - If boundary lines are perceptible: increase **Edge Softness**.
   - If the area displays chromatic aberration: tune **Color Tint**.
8. Tap anywhere on the canvas to exit. Calibration parameters persist across resprings and reboots.

---

## Compilation and Packaging

To compile fat Mach-O binaries (`arm64` + `arm64e`) and generate both rootless and rootful Debian packages:

```bash
cd SpotHeal
chmod +x build.sh
./build.sh
```

Pipeline tasks:
1. Compiles `SpotHeal.dylib` for `SpringBoard` with entitlement signing via `ldid -S`.
2. Compiles the `SpotHeal` PreferenceBundle against the private Preferences framework.
3. Generates multi-scale application icons.
4. Packages `com.ronci.spotheal_1.0.1_iphoneos-arm64.deb` and `com.ronci.spotheal_1.0.1_iphoneos-arm.deb`.

---

## Repository Structure

```
SpotHeal/
├── build.sh                                # Automated build script
├── README.md                               # Technical documentation
├── com.ronci.spotheal_1.0.1_iphoneos-arm.deb   # Pre-compiled rootful package
├── com.ronci.spotheal_1.0.1_iphoneos-arm64.deb # Pre-compiled rootless package
└── src/
    ├── SpotHeal.m                          # SpringBoard hook and rotation transform engine
    ├── SpotHeal.plist                      # MobileSubstrate filter
    └── pref_bundle/
        ├── Preferences.tbd                 # Private framework linker stub
        ├── SpotHealRootListController.h    # Settings list controller interface
        ├── SpotHealRootListController.m    # Slider synchronization and canvas controller
        └── Resources/
            ├── Info.plist                  # Bundle property list
            ├── Root.plist                  # Settings specifier layout
            ├── entry.plist                 # PreferenceLoader registration
            └── icon*.png                   # High-resolution preference icons
```

---

## Author

- **Developer**: Ronald Nedela ([@RonaldNedela](https://github.com/RonaldNedela))
- **Target Platform**: iPad Pro 10.5" (2017), iPad Air 3, iOS/iPadOS 12.0 - 18+

---

## License

This project is licensed under the MIT License.
