#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <math.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

@class SpotHealWindow;
@class SpotHealViewController;
@class SpotHealOverlayView;

static SpotHealWindow *gOverlayWindow = nil;
static SpotHealViewController *gOverlayVC = nil;

static CGRect getEffectiveScreenBounds(void);
static void updateWindowFrames(void);
static void setupOverlayIfReady(void);
static void reloadPreferences(void);

#pragma mark - SpotDefectDotView

@interface SpotDefectDotView : UIView
@property (nonatomic, assign) CGFloat radiusX;
@property (nonatomic, assign) CGFloat radiusY;
@property (nonatomic, assign) CGFloat intensity;
@property (nonatomic, assign) CGFloat softness;
@property (nonatomic, assign) CGFloat colorTint;
@property (nonatomic, assign) BOOL highlightMode;
@end

@implementation SpotDefectDotView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.opaque = NO;
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    (void)point; (void)event;
    return nil;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    (void)point; (void)event;
    return NO;
}

- (void)drawRect:(CGRect)rect {
    (void)rect;
    if (self.hidden || self.alpha <= 0.001) return;
    
    CGRect bounds = self.bounds;
    CGFloat W = bounds.size.width;
    CGFloat H = bounds.size.height;
    if (W <= 0 || H <= 0) return;
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;
    
    CGFloat cx = W / 2.0;
    CGFloat cy = H / 2.0;
    CGFloat rx = self.radiusX;
    CGFloat ry = self.radiusY;
    if (rx <= 1.0) rx = 1.0;
    if (ry <= 1.0) ry = 1.0;
    
    if (self.highlightMode) {
        CGContextSaveGState(ctx);
        CGContextTranslateCTM(ctx, cx, cy);
        
        CGRect ovalRect = CGRectMake(-rx, -ry, rx * 2.0, ry * 2.0);
        
        // Translucent red fill
        CGContextSetRGBFillColor(ctx, 1.0, 0.15, 0.15, 0.40);
        CGContextFillEllipseInRect(ctx, ovalRect);
        
        // Solid bright red border
        CGContextSetRGBStrokeColor(ctx, 1.0, 0.1, 0.1, 0.95);
        CGContextSetLineWidth(ctx, 2.5);
        CGContextStrokeEllipseInRect(ctx, ovalRect);
        
        // Center crosshair
        CGContextSetRGBStrokeColor(ctx, 1.0, 1.0, 1.0, 0.95);
        CGContextSetLineWidth(ctx, 1.5);
        CGFloat chSize = 14.0;
        CGContextMoveToPoint(ctx, -chSize, 0);
        CGContextAddLineToPoint(ctx, chSize, 0);
        CGContextMoveToPoint(ctx, 0, -chSize);
        CGContextAddLineToPoint(ctx, 0, chSize);
        CGContextStrokePath(ctx);
        
        CGContextRestoreGState(ctx);
        return;
    }
    
    if (self.intensity <= 0.001) return;
    
    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, cx, cy);
    CGFloat scaleY = ry / rx;
    CGContextScaleCTM(ctx, 1.0, scaleY);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    if (!colorSpace) {
        CGContextRestoreGState(ctx);
        return;
    }
    
    // Color tint adjustments (-50.0 to +50.0)
    CGFloat tint = self.colorTint;
    CGFloat baseR = 0.0, baseG = 0.0, baseB = 0.0;
    if (tint > 0.0) {
        CGFloat factor = tint / 50.0;
        baseR = 0.16 * factor;
        baseG = 0.09 * factor;
        baseB = 0.0;
    } else if (tint < 0.0) {
        CGFloat factor = (-tint) / 50.0;
        baseR = 0.0;
        baseG = 0.05 * factor;
        baseB = 0.16 * factor;
    }
    
    const int numStops = 11;
    CGFloat locations[11];
    CGFloat components[44];
    
    CGFloat maxAlpha = self.intensity;
    CGFloat softness = self.softness;
    if (softness < 0.1) softness = 0.1;
    
    for (int i = 0; i < numStops; i++) {
        CGFloat t = (CGFloat)i / (CGFloat)(numStops - 1);
        locations[i] = t;
        
        CGFloat cosVal = cos(t * (M_PI / 2.0));
        CGFloat alphaFactor = pow(cosVal, 2.0 * softness);
        CGFloat currentAlpha = maxAlpha * alphaFactor;
        
        components[i * 4 + 0] = baseR;
        components[i * 4 + 1] = baseG;
        components[i * 4 + 2] = baseB;
        components[i * 4 + 3] = currentAlpha;
    }
    
    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, numStops);
    if (gradient) {
        CGContextDrawRadialGradient(ctx, gradient, CGPointZero, 0.0, CGPointZero, rx, 0);
        CGGradientRelease(gradient);
    }
    
    CGColorSpaceRelease(colorSpace);
    CGContextRestoreGState(ctx);
}

@end

#pragma mark - SpotHealOverlayView

@interface SpotHealOverlayView : UIView {
    SpotDefectDotView *_dotView;
}
@property (nonatomic, assign) BOOL isFilterEnabled;
@property (nonatomic, assign) CGFloat offsetY;
@property (nonatomic, assign) CGFloat offsetX;
@property (nonatomic, assign) CGFloat radiusX;
@property (nonatomic, assign) CGFloat radiusY;
@property (nonatomic, assign) CGFloat intensity;
@property (nonatomic, assign) CGFloat softness;
@property (nonatomic, assign) CGFloat colorTint;
@property (nonatomic, assign) BOOL highlightMode;

- (void)updateDotLayout;
@end

@implementation SpotHealOverlayView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.opaque = NO;
        
        // Defaults
        _isFilterEnabled = YES;
        _offsetY = 120.0;
        _offsetX = 0.0;
        _radiusX = 45.0;
        _radiusY = 45.0;
        _intensity = 0.12;
        _softness = 1.0;
        _colorTint = 0.0;
        _highlightMode = NO;
        
        _dotView = [[SpotDefectDotView alloc] initWithFrame:CGRectZero];
        _dotView.radiusX = _radiusX;
        _dotView.radiusY = _radiusY;
        _dotView.intensity = _intensity;
        _dotView.softness = _softness;
        _dotView.colorTint = _colorTint;
        _dotView.highlightMode = _highlightMode;
        [self addSubview:_dotView];
    }
    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    (void)point; (void)event;
    return nil;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    (void)point; (void)event;
    return NO;
}

- (void)setIsFilterEnabled:(BOOL)enabled {
    if (_isFilterEnabled != enabled) {
        _isFilterEnabled = enabled;
        _dotView.hidden = !enabled;
        [self updateDotLayout];
    }
}

- (void)setOffsetY:(CGFloat)offsetY {
    if (fabs(_offsetY - offsetY) > 0.01) {
        _offsetY = offsetY;
        [self updateDotLayout];
    }
}

- (void)setOffsetX:(CGFloat)offsetX {
    if (fabs(_offsetX - offsetX) > 0.01) {
        _offsetX = offsetX;
        [self updateDotLayout];
    }
}

- (void)setRadiusX:(CGFloat)radiusX {
    if (fabs(_radiusX - radiusX) > 0.01) {
        _radiusX = radiusX;
        [self updateDotLayout];
    }
}

- (void)setRadiusY:(CGFloat)radiusY {
    if (fabs(_radiusY - radiusY) > 0.01) {
        _radiusY = radiusY;
        [self updateDotLayout];
    }
}

- (void)setIntensity:(CGFloat)intensity {
    if (fabs(_intensity - intensity) > 0.001) {
        _intensity = intensity;
        _dotView.intensity = intensity;
        [_dotView setNeedsDisplay];
    }
}

- (void)setSoftness:(CGFloat)softness {
    if (fabs(_softness - softness) > 0.01) {
        _softness = softness;
        _dotView.softness = softness;
        [_dotView setNeedsDisplay];
    }
}

- (void)setColorTint:(CGFloat)colorTint {
    if (fabs(_colorTint - colorTint) > 0.01) {
        _colorTint = colorTint;
        _dotView.colorTint = colorTint;
        [_dotView setNeedsDisplay];
    }
}

- (void)setHighlightMode:(BOOL)highlightMode {
    if (_highlightMode != highlightMode) {
        _highlightMode = highlightMode;
        _dotView.highlightMode = highlightMode;
        [_dotView setNeedsDisplay];
    }
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    [self updateDotLayout];
}

- (void)setBounds:(CGRect)bounds {
    [super setBounds:bounds];
    [self updateDotLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self updateDotLayout];
}

- (void)updateDotLayout {
    if (!_isFilterEnabled) {
        _dotView.hidden = YES;
        return;
    }
    _dotView.hidden = NO;
    
    CGRect bounds = self.bounds;
    CGFloat W = bounds.size.width;
    CGFloat H = bounds.size.height;
    if (W <= 0 || H <= 0) return;
    
    // Resolve current interface orientation
    UIInterfaceOrientation orientation = UIInterfaceOrientationPortrait;
    if (self.window && self.window.windowScene) {
        orientation = self.window.windowScene.interfaceOrientation;
    }
    if (orientation == UIInterfaceOrientationUnknown) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        orientation = [UIApplication sharedApplication].statusBarOrientation;
#pragma clang diagnostic pop
    }
    if (orientation == UIInterfaceOrientationUnknown) {
        UIDeviceOrientation devOri = [UIDevice currentDevice].orientation;
        if (devOri == UIDeviceOrientationLandscapeLeft) {
            orientation = UIInterfaceOrientationLandscapeRight;
        } else if (devOri == UIDeviceOrientationLandscapeRight) {
            orientation = UIInterfaceOrientationLandscapeLeft;
        } else if (devOri == UIDeviceOrientationPortraitUpsideDown) {
            orientation = UIInterfaceOrientationPortraitUpsideDown;
        } else {
            orientation = (W > H) ? UIInterfaceOrientationLandscapeRight : UIInterfaceOrientationPortrait;
        }
    }
    
    // Physical coordinate mapping:
    // Pin defect to physical position above Home button across all rotations.
    CGFloat cx = 0;
    CGFloat cy = 0;
    CGFloat effectiveRadiusX = self.radiusX;
    CGFloat effectiveRadiusY = self.radiusY;
    
    switch (orientation) {
        case UIInterfaceOrientationPortrait:
        default:
            cx = W / 2.0 + self.offsetX;
            cy = H - self.offsetY;
            effectiveRadiusX = self.radiusX;
            effectiveRadiusY = self.radiusY;
            break;
            
        case UIInterfaceOrientationPortraitUpsideDown:
            cx = W / 2.0 - self.offsetX;
            cy = self.offsetY;
            effectiveRadiusX = self.radiusX;
            effectiveRadiusY = self.radiusY;
            break;
            
        case UIInterfaceOrientationLandscapeRight:
            cx = W - self.offsetY;
            cy = H / 2.0 - self.offsetX;
            effectiveRadiusX = self.radiusY;
            effectiveRadiusY = self.radiusX;
            break;
            
        case UIInterfaceOrientationLandscapeLeft:
            cx = self.offsetY;
            cy = H / 2.0 + self.offsetX;
            effectiveRadiusX = self.radiusY;
            effectiveRadiusY = self.radiusX;
            break;
    }
    
    if (effectiveRadiusX <= 1.0) effectiveRadiusX = 1.0;
    if (effectiveRadiusY <= 1.0) effectiveRadiusY = 1.0;
    
    CGSize targetSize = CGSizeMake(ceil(effectiveRadiusX * 2.0) + 2.0, ceil(effectiveRadiusY * 2.0) + 2.0);
    CGPoint targetCenter = CGPointMake(round(cx), round(cy));
    
    BOOL sizeChanged = !CGSizeEqualToSize(_dotView.bounds.size, targetSize);
    _dotView.center = targetCenter;
    
    if (sizeChanged || fabs(_dotView.radiusX - effectiveRadiusX) > 0.01 || fabs(_dotView.radiusY - effectiveRadiusY) > 0.01) {
        _dotView.bounds = CGRectMake(0, 0, targetSize.width, targetSize.height);
        _dotView.radiusX = effectiveRadiusX;
        _dotView.radiusY = effectiveRadiusY;
        [_dotView setNeedsDisplay];
    }
}

@end

#pragma mark - SpotHealContainerView

@interface SpotHealContainerView : UIView
@end

@implementation SpotHealContainerView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    (void)point; (void)event;
    return nil;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    (void)point; (void)event;
    return NO;
}

@end

#pragma mark - SpotHealViewController

@interface SpotHealViewController : UIViewController
@property (nonatomic, strong) SpotHealOverlayView *overlayView;
@end

@implementation SpotHealViewController

- (void)loadView {
    CGRect initialBounds = getEffectiveScreenBounds();
    SpotHealContainerView *container = [[SpotHealContainerView alloc] initWithFrame:initialBounds];
    self.view = container;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    self.view.userInteractionEnabled = NO;
    
    self.overlayView = [[SpotHealOverlayView alloc] initWithFrame:self.view.bounds];
    self.overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.overlayView.userInteractionEnabled = NO;
    [self.view addSubview:self.overlayView];
    
    reloadPreferences();
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    if (self.overlayView) {
        self.overlayView.frame = self.view.bounds;
        self.overlayView.bounds = self.view.bounds;
        [self.overlayView updateDotLayout];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (self.overlayView) {
        self.overlayView.frame = self.view.bounds;
        self.overlayView.bounds = self.view.bounds;
        [self.overlayView updateDotLayout];
    }
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (BOOL)prefersStatusBarHidden {
    return NO;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    CGRect newBounds = CGRectMake(0, 0, size.width, size.height);
    self.view.frame = newBounds;
    self.view.bounds = newBounds;
    if (self.overlayView) {
        self.overlayView.frame = newBounds;
        self.overlayView.bounds = newBounds;
        [self.overlayView updateDotLayout];
    }
    if (coordinator) {
        [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            (void)context;
            CGRect animBounds = CGRectMake(0, 0, size.width, size.height);
            self.view.frame = animBounds;
            self.view.bounds = animBounds;
            if (self.overlayView) {
                self.overlayView.frame = animBounds;
                self.overlayView.bounds = animBounds;
                [self.overlayView updateDotLayout];
            }
        } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            (void)context;
            updateWindowFrames();
        }];
    } else {
        updateWindowFrames();
    }
}

@end

#pragma mark - SpotHealWindow

@interface SpotHealWindow : UIWindow
@end

@implementation SpotHealWindow

- (void)commonInit {
    self.userInteractionEnabled = NO;
    self.backgroundColor = [UIColor clearColor];
    self.windowLevel = UIWindowLevelStatusBar + 50.0;
    self.opaque = NO;
    self.clipsToBounds = NO;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithWindowScene:(UIWindowScene *)windowScene API_AVAILABLE(ios(13.0)) {
    self = [super initWithWindowScene:windowScene];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (BOOL)_ignoresHitTest {
    return YES;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    (void)point; (void)event;
    return nil;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    (void)point; (void)event;
    return NO;
}

- (BOOL)_canBecomeKeyWindow {
    return NO;
}

- (BOOL)canBecomeKeyWindow {
    return NO;
}

- (BOOL)_canAffectStatusBarAppearance {
    return NO;
}

- (BOOL)_shouldControlAutorotation {
    return YES;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect targetBounds = getEffectiveScreenBounds();
    if (!CGRectIsEmpty(targetBounds)) {
        if (!CGRectEqualToRect(self.bounds, targetBounds)) {
            self.bounds = targetBounds;
        }
        if (!CGRectEqualToRect(self.frame, targetBounds)) {
            self.frame = targetBounds;
        }
    }
    if (self.rootViewController && self.rootViewController.view) {
        self.rootViewController.view.frame = self.bounds;
        self.rootViewController.view.bounds = self.bounds;
    }
    if (gOverlayVC && gOverlayVC.overlayView) {
        gOverlayVC.overlayView.frame = self.bounds;
        gOverlayVC.overlayView.bounds = self.bounds;
        [gOverlayVC.overlayView updateDotLayout];
    }
}

@end

#pragma mark - Screen Bounds & Window Setup

static CGRect getEffectiveScreenBounds(void) {
    CGRect bounds = [UIScreen mainScreen].bounds;
    if (gOverlayWindow && gOverlayWindow.windowScene) {
        bounds = gOverlayWindow.windowScene.coordinateSpace.bounds;
    }
    
    UIInterfaceOrientation orientation = UIInterfaceOrientationUnknown;
    if (gOverlayWindow && gOverlayWindow.windowScene) {
        orientation = gOverlayWindow.windowScene.interfaceOrientation;
    }
    if (orientation == UIInterfaceOrientationUnknown) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        orientation = [UIApplication sharedApplication].statusBarOrientation;
#pragma clang diagnostic pop
    }
    
    BOOL isLandscape = NO;
    if (UIInterfaceOrientationIsLandscape(orientation)) {
        isLandscape = YES;
    } else if (UIInterfaceOrientationIsPortrait(orientation)) {
        isLandscape = NO;
    } else {
        UIDeviceOrientation devOri = [UIDevice currentDevice].orientation;
        if (UIDeviceOrientationIsLandscape(devOri)) {
            isLandscape = YES;
        } else if (UIDeviceOrientationIsPortrait(devOri)) {
            isLandscape = NO;
        } else {
            isLandscape = (bounds.size.width > bounds.size.height);
        }
    }
    
    CGFloat w = bounds.size.width;
    CGFloat h = bounds.size.height;
    if (isLandscape) {
        bounds.size.width = MAX(w, h);
        bounds.size.height = MIN(w, h);
    } else {
        bounds.size.width = MIN(w, h);
        bounds.size.height = MAX(w, h);
    }
    bounds.origin = CGPointZero;
    return bounds;
}

static UIWindowScene *findActiveWindowScene(void) {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *ws = (UIWindowScene *)scene;
                if (ws.activationState == UISceneActivationStateForegroundActive) {
                    return ws;
                }
            }
        }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.windowScene && w.windowScene.activationState == UISceneActivationStateForegroundActive) {
                return w.windowScene;
            }
        }
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                return (UIWindowScene *)scene;
            }
        }
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.windowScene) {
                return w.windowScene;
            }
        }
#pragma clang diagnostic pop
    }
    return nil;
}

static void updateWindowFrames(void) {
    if (!gOverlayWindow) return;
    
    UIWindowScene *scene = findActiveWindowScene();
    if (scene && (!gOverlayWindow.windowScene || gOverlayWindow.windowScene != scene)) {
        gOverlayWindow.windowScene = scene;
    }
    
    CGRect screenBounds = getEffectiveScreenBounds();
    gOverlayWindow.frame = screenBounds;
    gOverlayWindow.bounds = screenBounds;
    if (gOverlayVC) {
        gOverlayVC.view.frame = screenBounds;
        gOverlayVC.view.bounds = screenBounds;
        if (gOverlayVC.overlayView) {
            gOverlayVC.overlayView.frame = screenBounds;
            gOverlayVC.overlayView.bounds = screenBounds;
            [gOverlayVC.overlayView updateDotLayout];
        }
    }
}

static void setupOverlayIfReady(void) {
    UIWindowScene *targetScene = findActiveWindowScene();
    
    if (gOverlayWindow) {
        if (!gOverlayWindow.windowScene && targetScene) {
            gOverlayWindow.windowScene = targetScene;
        } else if (targetScene && gOverlayWindow.windowScene != targetScene && targetScene.activationState == UISceneActivationStateForegroundActive) {
            gOverlayWindow.windowScene = targetScene;
        }
        updateWindowFrames();
        return;
    }
    
    CGRect initialBounds = getEffectiveScreenBounds();
    if (targetScene) {
        gOverlayWindow = [[SpotHealWindow alloc] initWithWindowScene:targetScene];
        gOverlayWindow.frame = initialBounds;
        gOverlayWindow.bounds = initialBounds;
    } else {
        gOverlayWindow = [[SpotHealWindow alloc] initWithFrame:initialBounds];
    }
    
    gOverlayVC = [[SpotHealViewController alloc] init];
    gOverlayWindow.rootViewController = gOverlayVC;
    if (@available(iOS 9.0, *)) {
        [gOverlayVC loadViewIfNeeded];
    } else {
        (void)gOverlayVC.view;
    }
    
    updateWindowFrames();
    NSLog(@"[SpotHeal] Overlay window initialized (scene: %@, bounds: %@)", targetScene, NSStringFromCGRect(initialBounds));
}

#pragma mark - Preferences Loading

static NSDictionary *loadPrefsDict(void) {
    NSArray *paths = @[
        @"/var/jb/var/mobile/Library/Preferences/com.ronci.spotheal.plist",
        @"/var/mobile/Library/Preferences/com.ronci.spotheal.plist"
    ];
    for (NSString *p in paths) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:p]) {
            NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:p];
            if (d && [d count] > 0) return d;
        }
    }
    return nil;
}

static id readPrefValue(NSString *key, NSDictionary **diskDictPtr) {
    CFPropertyListRef val = CFPreferencesCopyAppValue((CFStringRef)key, CFSTR("com.ronci.spotheal"));
    if (val) {
        return (__bridge_transfer id)val;
    }
    if (diskDictPtr) {
        if (!*diskDictPtr) {
            *diskDictPtr = loadPrefsDict();
        }
        if (*diskDictPtr && (*diskDictPtr)[key] != nil) {
            return (*diskDictPtr)[key];
        }
    }
    return nil;
}

static void reloadPreferences(void) {
    if (!gOverlayWindow || !gOverlayWindow.windowScene) {
        setupOverlayIfReady();
    }
    
    CFPreferencesAppSynchronize(CFSTR("com.ronci.spotheal"));
    
    BOOL enabled = YES;
    CGFloat offsetY = 120.0;
    CGFloat offsetX = 0.0;
    CGFloat radiusX = 45.0;
    CGFloat radiusY = 45.0;
    CGFloat intensity = 0.12;
    CGFloat softness = 1.0;
    CGFloat colorTint = 0.0;
    BOOL highlightMode = NO;
    
    NSDictionary *diskDict = nil;
    
    id enVal = readPrefValue(@"enabled", &diskDict);
    if (enVal != nil) enabled = [enVal boolValue];
    
    id oyVal = readPrefValue(@"offsetY", &diskDict);
    if (oyVal != nil) {
        CGFloat v = [oyVal floatValue];
        if (v < 20.0) v = 20.0;
        if (v > 350.0) v = 350.0;
        offsetY = v;
    }
    
    id oxVal = readPrefValue(@"offsetX", &diskDict);
    if (oxVal != nil) {
        CGFloat v = [oxVal floatValue];
        if (v < -150.0) v = -150.0;
        if (v > 150.0) v = 150.0;
        offsetX = v;
    }
    
    id rxVal = readPrefValue(@"radiusX", &diskDict);
    if (rxVal != nil) {
        CGFloat v = [rxVal floatValue];
        if (v < 10.0) v = 10.0;
        if (v > 200.0) v = 200.0;
        radiusX = v;
    }
    
    id ryVal = readPrefValue(@"radiusY", &diskDict);
    if (ryVal != nil) {
        CGFloat v = [ryVal floatValue];
        if (v < 10.0) v = 10.0;
        if (v > 200.0) v = 200.0;
        radiusY = v;
    }
    
    id intVal = readPrefValue(@"intensity", &diskDict);
    if (intVal != nil) {
        CGFloat v = [intVal floatValue]; // e.g. 1.0% to 40.0%
        v /= 100.0;                      // normalize to 0.01 - 0.40
        if (v < 0.01) v = 0.01;
        if (v > 0.40) v = 0.40;
        intensity = v;
    }
    
    id sfVal = readPrefValue(@"softness", &diskDict);
    if (sfVal != nil) {
        CGFloat v = [sfVal floatValue];
        if (v < 0.5) v = 0.5;
        if (v > 2.5) v = 2.5;
        softness = v;
    }
    
    id ctVal = readPrefValue(@"colorTint", &diskDict);
    if (ctVal != nil) {
        CGFloat v = [ctVal floatValue];
        if (v < -50.0) v = -50.0;
        if (v > 50.0) v = 50.0;
        colorTint = v;
    }
    
    id hlVal = readPrefValue(@"highlightMode", &diskDict);
    if (hlVal != nil) highlightMode = [hlVal boolValue];
    
    if (gOverlayVC && gOverlayVC.overlayView) {
        gOverlayVC.overlayView.isFilterEnabled = enabled;
        gOverlayVC.overlayView.offsetY = offsetY;
        gOverlayVC.overlayView.offsetX = offsetX;
        gOverlayVC.overlayView.radiusX = radiusX;
        gOverlayVC.overlayView.radiusY = radiusY;
        gOverlayVC.overlayView.intensity = intensity;
        gOverlayVC.overlayView.softness = softness;
        gOverlayVC.overlayView.colorTint = colorTint;
        gOverlayVC.overlayView.highlightMode = highlightMode;
        [gOverlayVC.overlayView updateDotLayout];
    }
    if (gOverlayWindow) {
        gOverlayWindow.hidden = !enabled;
    }
    [CATransaction flush];
}

static void onPrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    (void)center; (void)observer; (void)name; (void)object; (void)userInfo;
    dispatch_async(dispatch_get_main_queue(), ^{
        setupOverlayIfReady();
        reloadPreferences();
        [CATransaction flush];
    });
}

static void onSceneActivated(NSNotification *note) {
    (void)note;
    setupOverlayIfReady();
    reloadPreferences();
}

#pragma mark - Method Swizzling

static void safeSwizzle(Class cls, SEL sel, IMP newImp, IMP *origImpOut) {
    if (!cls || !sel || !newImp || !origImpOut) return;
    Method method = class_getInstanceMethod(cls, sel);
    if (!method) return;
    
    BOOL added = class_addMethod(cls, sel, newImp, method_getTypeEncoding(method));
    if (added) {
        *origImpOut = method_getImplementation(method);
    } else {
        *origImpOut = method_setImplementation(method, newImp);
    }
}

#pragma mark - Screenshot Interception & Clean Capture

static BOOL gOverlayHiddenForScreenshot = NO;
static uint64_t gScreenshotSeq = 0;

static void restoreOverlayAfterScreenshot(void) {
    if (!gOverlayHiddenForScreenshot) return;
    gOverlayHiddenForScreenshot = NO;
    
    BOOL enabled = YES;
    if (gOverlayVC && gOverlayVC.overlayView) {
        enabled = gOverlayVC.overlayView.isFilterEnabled;
        gOverlayVC.overlayView.hidden = NO;
    }
    if (gOverlayWindow) {
        gOverlayWindow.hidden = !enabled;
        gOverlayWindow.alpha = 1.0;
    }
    [CATransaction flush];
}

static void hideOverlayForScreenshot(void) {
    uint64_t seq = ++gScreenshotSeq;
    gOverlayHiddenForScreenshot = YES;
    
    if (gOverlayWindow) {
        gOverlayWindow.hidden = YES;
        gOverlayWindow.alpha = 0.0;
    }
    if (gOverlayVC && gOverlayVC.overlayView) {
        gOverlayVC.overlayView.hidden = YES;
    }
    [CATransaction flush];
    
    // Auto-restore safety fallback after 0.5s
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (gScreenshotSeq == seq && gOverlayHiddenForScreenshot) {
            restoreOverlayAfterScreenshot();
        }
    });
}

// 1. SSScreenCapturer - takeScreenshot
static void (*orig_SSScreenCapturer_takeScreenshot)(id, SEL) = NULL;
static void swizzled_SSScreenCapturer_takeScreenshot(id self, SEL _cmd) {
    hideOverlayForScreenshot();
    if (orig_SSScreenCapturer_takeScreenshot) {
        orig_SSScreenCapturer_takeScreenshot(self, _cmd);
    }
}

// 2. SSScreenCapturer - _preheatAndTakeScreenshotIfPossibleWithOptionsCollection:presentationOptions:appleInternalOptions:
static void (*orig_SSScreenCapturer_preheat)(id, SEL, id, id, id) = NULL;
static void swizzled_SSScreenCapturer_preheat(id self, SEL _cmd, id a1, id a2, id a3) {
    hideOverlayForScreenshot();
    if (orig_SSScreenCapturer_preheat) {
        orig_SSScreenCapturer_preheat(self, _cmd, a1, a2, a3);
    }
}

// 3. SBScreenshotManager - saveScreenshotsWithContext:completion:
static void (*orig_SBScreenshotManager_saveWithContext)(id, SEL, id, id) = NULL;
static void swizzled_SBScreenshotManager_saveWithContext(id self, SEL _cmd, id ctx, id completion) {
    hideOverlayForScreenshot();
    if (orig_SBScreenshotManager_saveWithContext) {
        orig_SBScreenshotManager_saveWithContext(self, _cmd, ctx, completion);
    }
}

// 4. SBScreenshotManager - saveScreenshotsWithCompletion:
static void (*orig_SBScreenshotManager_saveWithCompletion)(id, SEL, id) = NULL;
static void swizzled_SBScreenshotManager_saveWithCompletion(id self, SEL _cmd, id completion) {
    hideOverlayForScreenshot();
    if (orig_SBScreenshotManager_saveWithCompletion) {
        orig_SBScreenshotManager_saveWithCompletion(self, _cmd, completion);
    }
}

// 5. SBScreenshotManager - takeScreenshot
static void (*orig_SBScreenshotManager_takeScreenshot)(id, SEL) = NULL;
static void swizzled_SBScreenshotManager_takeScreenshot(id self, SEL _cmd) {
    hideOverlayForScreenshot();
    if (orig_SBScreenshotManager_takeScreenshot) {
        orig_SBScreenshotManager_takeScreenshot(self, _cmd);
    }
}

// 6. SBScreenshotManager - saveScreenshots
static void (*orig_SBScreenshotManager_saveScreenshots)(id, SEL) = NULL;
static void swizzled_SBScreenshotManager_saveScreenshots(id self, SEL _cmd) {
    hideOverlayForScreenshot();
    if (orig_SBScreenshotManager_saveScreenshots) {
        orig_SBScreenshotManager_saveScreenshots(self, _cmd);
    }
}

// 7. SBScreenFlash - flashWhiteWithCompletion:
static void (*orig_SBScreenFlash_flashWhiteWithCompletion)(id, SEL, id) = NULL;
static void swizzled_SBScreenFlash_flashWhiteWithCompletion(id self, SEL _cmd, id completion) {
    hideOverlayForScreenshot();
    if (orig_SBScreenFlash_flashWhiteWithCompletion) {
        orig_SBScreenFlash_flashWhiteWithCompletion(self, _cmd, completion);
    }
}

// 8. SBScreenFlash - flashColor:withCompletion:
static void (*orig_SBScreenFlash_flashColorWithCompletion)(id, SEL, id, id) = NULL;
static void swizzled_SBScreenFlash_flashColorWithCompletion(id self, SEL _cmd, id color, id completion) {
    hideOverlayForScreenshot();
    if (orig_SBScreenFlash_flashColorWithCompletion) {
        orig_SBScreenFlash_flashColorWithCompletion(self, _cmd, color, completion);
    }
}

// 9. SpringBoard - takeScreenshot
static void (*orig_SpringBoard_takeScreenshot)(id, SEL) = NULL;
static void swizzled_SpringBoard_takeScreenshot(id self, SEL _cmd) {
    hideOverlayForScreenshot();
    if (orig_SpringBoard_takeScreenshot) {
        orig_SpringBoard_takeScreenshot(self, _cmd);
    }
}

static BOOL gScreenshotHooksInstalled = NO;

static void installScreenshotHooks(void) {
    if (gScreenshotHooksInstalled) return;
    
    dlopen("/System/Library/PrivateFrameworks/ScreenshotServices.framework/ScreenshotServices", RTLD_NOW | RTLD_GLOBAL);
    dlopen("/System/Library/PrivateFrameworks/SpringBoard.framework/SpringBoard", RTLD_NOW | RTLD_GLOBAL);
    
    int hooksCount = 0;
    
    Class scClass = NSClassFromString(@"SSScreenCapturer");
    if (scClass) {
        safeSwizzle(scClass, @selector(takeScreenshot), (IMP)swizzled_SSScreenCapturer_takeScreenshot, (IMP *)&orig_SSScreenCapturer_takeScreenshot);
        safeSwizzle(scClass, @selector(_preheatAndTakeScreenshotIfPossibleWithOptionsCollection:presentationOptions:appleInternalOptions:), (IMP)swizzled_SSScreenCapturer_preheat, (IMP *)&orig_SSScreenCapturer_preheat);
        hooksCount++;
    }
    
    Class smClass = NSClassFromString(@"SBScreenshotManager");
    if (smClass) {
        safeSwizzle(smClass, @selector(saveScreenshotsWithContext:completion:), (IMP)swizzled_SBScreenshotManager_saveWithContext, (IMP *)&orig_SBScreenshotManager_saveWithContext);
        safeSwizzle(smClass, @selector(saveScreenshotsWithCompletion:), (IMP)swizzled_SBScreenshotManager_saveWithCompletion, (IMP *)&orig_SBScreenshotManager_saveWithCompletion);
        safeSwizzle(smClass, @selector(takeScreenshot), (IMP)swizzled_SBScreenshotManager_takeScreenshot, (IMP *)&orig_SBScreenshotManager_takeScreenshot);
        safeSwizzle(smClass, @selector(saveScreenshots), (IMP)swizzled_SBScreenshotManager_saveScreenshots, (IMP *)&orig_SBScreenshotManager_saveScreenshots);
        hooksCount++;
    }
    
    Class sfClass = NSClassFromString(@"SBScreenFlash");
    if (sfClass) {
        safeSwizzle(sfClass, @selector(flashWhiteWithCompletion:), (IMP)swizzled_SBScreenFlash_flashWhiteWithCompletion, (IMP *)&orig_SBScreenFlash_flashWhiteWithCompletion);
        safeSwizzle(sfClass, @selector(flashColor:withCompletion:), (IMP)swizzled_SBScreenFlash_flashColorWithCompletion, (IMP *)&orig_SBScreenFlash_flashColorWithCompletion);
        hooksCount++;
    }
    
    Class sbClass = NSClassFromString(@"SpringBoard");
    if (sbClass) {
        safeSwizzle(sbClass, @selector(takeScreenshot), (IMP)swizzled_SpringBoard_takeScreenshot, (IMP *)&orig_SpringBoard_takeScreenshot);
        hooksCount++;
    }
    
    if (hooksCount > 0) {
        gScreenshotHooksInstalled = YES;
        NSLog(@"[SpotHeal] %d screenshot classes hooked for clean capture.", hooksCount);
    }
}

#pragma mark - SpringBoard Initialization

static void initSpringBoard(void) {
    NSLog(@"[SpotHeal] Initializing SpotHeal tweak for SpringBoard...");
    
    installScreenshotHooks();
    
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        onPrefsChanged,
        CFSTR("com.ronci.spotheal/prefsChanged"),
        NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately
    );
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationUserDidTakeScreenshotNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        (void)note;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            restoreOverlayAfterScreenshot();
        });
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:NSBundleDidLoadNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        (void)note;
        if (!gScreenshotHooksInstalled) {
            installScreenshotHooks();
        }
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UISceneDidActivateNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        onSceneActivated(note);
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceOrientationDidChangeNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        (void)note;
        updateWindowFrames();
    }];
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidChangeStatusBarOrientationNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        (void)note;
        updateWindowFrames();
    }];
#pragma clang diagnostic pop
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIWindowDidBecomeVisibleNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        (void)note;
        updateWindowFrames();
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        (void)note;
        installScreenshotHooks();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            setupOverlayIfReady();
            reloadPreferences();
        });
    }];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        installScreenshotHooks();
        setupOverlayIfReady();
        reloadPreferences();
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        installScreenshotHooks();
        setupOverlayIfReady();
        reloadPreferences();
    });
}

__attribute__((constructor)) static void SpotHealInit(void) {
    @autoreleasepool {
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
        if ([bundleId isEqualToString:@"com.apple.springboard"]) {
            initSpringBoard();
        }
    }
}

#pragma clang diagnostic pop
