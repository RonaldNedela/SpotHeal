#import "SpotHealRootListController.h"
#import <CoreGraphics/CoreGraphics.h>
#import <CoreFoundation/CoreFoundation.h>
#import <sys/stat.h>

#define SPOTHEAL_PREFS_ID @"com.ronci.spotheal"
#define SPOTHEAL_NOTIFY "com.ronci.spotheal/prefsChanged"

static NSArray *getPrefPaths(void) {
    return @[
        @"/var/jb/var/mobile/Library/Preferences/com.ronci.spotheal.plist",
        @"/var/mobile/Library/Preferences/com.ronci.spotheal.plist"
    ];
}

static void savePrefDirect(NSString *key, id value) {
    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, (__bridge CFStringRef)SPOTHEAL_PREFS_ID);
    CFPreferencesAppSynchronize((__bridge CFStringRef)SPOTHEAL_PREFS_ID);
    
    for (NSString *p in getPrefPaths()) {
        NSString *dir = [p stringByDeletingLastPathComponent];
        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
        
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:p] ?: [NSMutableDictionary dictionary];
        dict[key] = value;
        [dict writeToFile:p atomically:YES];
        chmod([p UTF8String], 0666);
    }
}

static UISlider *findSliderInView(UIView *view) {
    if (!view) return nil;
    if ([view isKindOfClass:[UISlider class]]) return (UISlider *)view;
    if ([view respondsToSelector:@selector(control)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id c = [view performSelector:@selector(control)];
#pragma clang diagnostic pop
        if ([c isKindOfClass:[UISlider class]]) return (UISlider *)c;
    }
    for (UIView *sub in view.subviews) {
        UISlider *s = findSliderInView(sub);
        if (s) return s;
    }
    return nil;
}

static UITextField *findTextFieldInView(UIView *view) {
    if (!view) return nil;
    if ([view isKindOfClass:[UITextField class]]) return (UITextField *)view;
    if ([view respondsToSelector:@selector(textField)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id tf = [view performSelector:@selector(textField)];
#pragma clang diagnostic pop
        if ([tf isKindOfClass:[UITextField class]]) return (UITextField *)tf;
    }
    for (UIView *sub in view.subviews) {
        UITextField *tf = findTextFieldInView(sub);
        if (tf) return tf;
    }
    return nil;
}

#pragma mark - White Screen Calibration Controller

@interface SpotHealWhiteTestController : UIViewController
@end

@implementation SpotHealWhiteTestController

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (BOOL)prefersHomeIndicatorAutoHidden {
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissTest)];
    [self.view addGestureRecognizer:tap];
    
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = @"White Screen Calibration Test\n\nObserve if the bright spot is completely neutralized.\n\nTap anywhere on screen to return to Settings.";
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = [UIColor colorWithWhite:0.75 alpha:1.0];
    label.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
    [self.view addSubview:label];
    
    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [label.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [label.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:40.0],
        [label.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-40.0]
    ]];
}

- (void)dismissTest {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

#pragma mark - SpotHealRootListController

@implementation SpotHealRootListController

- (NSArray *)specifiers {
    NSArray *specs = [super specifiers];
    if (!specs || [specs count] == 0) {
        specs = [self loadSpecifiersFromPlistName:@"Root" target:self];
        if (!specs || [specs count] == 0) {
            specs = [self loadSpecifiersFromPlistName:@"SpotHeal" target:self];
        }
        [self setSpecifiers:specs];
    }
    return specs;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"SpotHeal";
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sh_textFieldDidEnd:)
                                                 name:UITextFieldTextDidEndEditingNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Table View Delegate & Data Source

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    // 1. Text field configuration
    UITextField *tf = findTextFieldInView(cell);
    if (tf) {
        tf.delegate = self;
        tf.returnKeyType = UIReturnKeyDone;
        tf.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
        [tf removeTarget:self action:@selector(sh_returnPressed:) forControlEvents:UIControlEventEditingDidEndOnExit];
        [tf addTarget:self action:@selector(sh_returnPressed:) forControlEvents:UIControlEventEditingDidEndOnExit];
        
        if ([cell respondsToSelector:@selector(specifier)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            PSSpecifier *spec = [cell performSelector:@selector(specifier)];
#pragma clang diagnostic pop
            NSString *key = [spec propertyForKey:@"key"];
            if (key && ![tf isFirstResponder]) {
                CFPropertyListRef propVal = CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)SPOTHEAL_PREFS_ID);
                if (propVal) {
                    CGFloat fVal = [(__bridge id)propVal floatValue];
                    if ([key isEqualToString:@"intensity"] || [key isEqualToString:@"softness"]) {
                        tf.text = [NSString stringWithFormat:@"%.1f", fVal];
                    } else {
                        tf.text = [NSString stringWithFormat:@"%.0f", fVal];
                    }
                    CFRelease(propVal);
                }
            }
        }
    }
    
    // 2. Slider configuration: Attach real-time valueChanged handler directly to UISlider
    UISlider *slider = findSliderInView(cell);
    if (slider) {
        [slider removeTarget:self action:@selector(sh_sliderMoved:) forControlEvents:UIControlEventValueChanged];
        [slider addTarget:self action:@selector(sh_sliderMoved:) forControlEvents:UIControlEventValueChanged];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self.view endEditing:YES];
    
    PSSpecifier *spec = nil;
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    if ([cell respondsToSelector:@selector(specifier)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        spec = [cell performSelector:@selector(specifier)];
#pragma clang diagnostic pop
    }
    
    if (!spec && [self respondsToSelector:@selector(specifierAtIndexPath:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        spec = [self performSelector:@selector(specifierAtIndexPath:) withObject:indexPath];
#pragma clang diagnostic pop
    }
    
    if (spec) {
        NSString *action = [spec propertyForKey:@"action"];
        if ([action isEqualToString:@"openWhiteTestScreen"] || [action isEqualToString:@"openWhiteTestScreen:"]) {
            [self openWhiteTestScreen:spec];
            return;
        }
        if ([action isEqualToString:@"resetDefaults"] || [action isEqualToString:@"resetDefaults:"]) {
            [self resetDefaults:spec];
            return;
        }
    }
    
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
}

#pragma mark - Slider Real-time Value Sync

- (void)sh_sliderMoved:(UISlider *)slider {
    if (!slider) return;
    
    UIView *v = slider;
    while (v && ![v isKindOfClass:[UITableViewCell class]]) {
        v = v.superview;
    }
    UITableViewCell *cell = (UITableViewCell *)v;
    if (!cell || ![cell respondsToSelector:@selector(specifier)]) return;
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    PSSpecifier *spec = [cell performSelector:@selector(specifier)];
#pragma clang diagnostic pop
    if (!spec) return;
    
    NSString *key = [spec propertyForKey:@"key"];
    if (!key) return;
    
    CGFloat val = slider.value;
    NSNumber *numVal = @(val);
    
    // Save to preferences & disk
    savePrefDirect(key, numVal);
    
    // Send Darwin notification immediately for live overlay response
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR(SPOTHEAL_NOTIFY),
        NULL,
        NULL,
        YES
    );
    
    // Update the companion text field in real time
    NSString *textVal = nil;
    if ([key isEqualToString:@"intensity"] || [key isEqualToString:@"softness"]) {
        textVal = [NSString stringWithFormat:@"%.1f", val];
    } else {
        textVal = [NSString stringWithFormat:@"%.0f", val];
    }
    
    UITableView *tv = [self table];
    if (tv) {
        for (UITableViewCell *c in tv.visibleCells) {
            if ([c respondsToSelector:@selector(specifier)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                PSSpecifier *s = [c performSelector:@selector(specifier)];
#pragma clang diagnostic pop
                NSString *sKey = [s propertyForKey:@"key"];
                NSString *sId = [s identifier] ?: @"";
                NSString *sCell = [s propertyForKey:@"cell"] ?: @"";
                
                if ([sKey isEqualToString:key] && ([sId hasSuffix:@"_text"] || [sCell isEqualToString:@"PSEditTextCell"])) {
                    UITextField *tf = findTextFieldInView(c);
                    if (tf && ![tf isFirstResponder]) {
                        tf.text = textVal;
                    }
                }
            }
        }
    }
}

#pragma mark - Text Field Return & Editing End

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [self commitValueFromTextField:textField];
    return YES;
}

- (void)sh_returnPressed:(UITextField *)textField {
    [textField resignFirstResponder];
    [self commitValueFromTextField:textField];
}

- (void)sh_textFieldDidEnd:(NSNotification *)note {
    if ([note.object isKindOfClass:[UITextField class]]) {
        [self commitValueFromTextField:(UITextField *)note.object];
    }
}

- (void)commitValueFromTextField:(UITextField *)tf {
    if (!tf) return;
    
    UIView *view = tf;
    while (view && ![view isKindOfClass:[UITableViewCell class]]) {
        view = view.superview;
    }
    UITableViewCell *cell = (UITableViewCell *)view;
    if (!cell || ![cell respondsToSelector:@selector(specifier)]) return;
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    PSSpecifier *spec = [cell performSelector:@selector(specifier)];
#pragma clang diagnostic pop
    if (!spec) return;
    
    NSString *key = [spec propertyForKey:@"key"];
    if (!key) return;
    
    CGFloat minVal = 0.0, maxVal = 100.0;
    BOOL isFloat = NO;
    
    if ([key isEqualToString:@"offsetY"]) {
        minVal = 20.0; maxVal = 350.0; isFloat = NO;
    } else if ([key isEqualToString:@"offsetX"]) {
        minVal = -150.0; maxVal = 150.0; isFloat = NO;
    } else if ([key isEqualToString:@"radiusX"]) {
        minVal = 10.0; maxVal = 200.0; isFloat = NO;
    } else if ([key isEqualToString:@"radiusY"]) {
        minVal = 10.0; maxVal = 200.0; isFloat = NO;
    } else if ([key isEqualToString:@"intensity"]) {
        minVal = 1.0; maxVal = 40.0; isFloat = YES;
    } else if ([key isEqualToString:@"softness"]) {
        minVal = 0.5; maxVal = 2.5; isFloat = YES;
    } else if ([key isEqualToString:@"colorTint"]) {
        minVal = -50.0; maxVal = 50.0; isFloat = NO;
    } else {
        return;
    }
    
    NSString *text = tf.text ?: @"";
    text = [text stringByReplacingOccurrencesOfString:@"," withString:@"."];
    text = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    CGFloat val = [text floatValue];
    if (val < minVal) val = minVal;
    if (val > maxVal) val = maxVal;
    
    if (isFloat) {
        tf.text = [NSString stringWithFormat:@"%.1f", val];
    } else {
        tf.text = [NSString stringWithFormat:@"%.0f", val];
    }
    
    NSNumber *numVal = @(val);
    savePrefDirect(key, numVal);
    
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR(SPOTHEAL_NOTIFY),
        NULL,
        NULL,
        YES
    );
    
    // Update matching slider
    NSString *sliderId = [NSString stringWithFormat:@"%@_slider", key];
    PSSpecifier *sliderSpec = [self specifierForID:sliderId];
    if (sliderSpec) {
        [self setPreferenceValue:numVal specifier:sliderSpec];
        [self reloadSpecifier:sliderSpec animated:YES];
    }
    
    UITableView *tv = [self table];
    if (tv) {
        for (UITableViewCell *c in tv.visibleCells) {
            if (c == cell) continue;
            if ([c respondsToSelector:@selector(specifier)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                PSSpecifier *s = [c performSelector:@selector(specifier)];
#pragma clang diagnostic pop
                if ([[s propertyForKey:@"key"] isEqualToString:key]) {
                    UISlider *slider = findSliderInView(c);
                    if (slider) {
                        [slider setValue:val animated:YES];
                    }
                }
            }
        }
    }
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    [super setPreferenceValue:value specifier:specifier];
    if (!specifier) return;
    
    NSString *key = [specifier propertyForKey:@"key"];
    NSString *specId = [specifier identifier];
    if (!key) return;
    
    savePrefDirect(key, value);
    
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR(SPOTHEAL_NOTIFY),
        NULL,
        NULL,
        YES
    );
    
    if ([specId hasSuffix:@"_slider"] && [value respondsToSelector:@selector(floatValue)]) {
        CGFloat fVal = [value floatValue];
        UITableView *tv = [self table];
        if (tv) {
            for (UITableViewCell *c in tv.visibleCells) {
                if ([c respondsToSelector:@selector(specifier)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    PSSpecifier *s = [c performSelector:@selector(specifier)];
#pragma clang diagnostic pop
                    NSString *sKey = [s propertyForKey:@"key"];
                    NSString *sId = [s identifier] ?: @"";
                    NSString *sCell = [s propertyForKey:@"cell"] ?: @"";
                    
                    if ([sKey isEqualToString:key] && ([sId hasSuffix:@"_text"] || [sCell isEqualToString:@"PSEditTextCell"])) {
                        UITextField *tf = findTextFieldInView(c);
                        if (tf && ![tf isFirstResponder]) {
                            if ([key isEqualToString:@"intensity"] || [key isEqualToString:@"softness"]) {
                                tf.text = [NSString stringWithFormat:@"%.1f", fVal];
                            } else {
                                tf.text = [NSString stringWithFormat:@"%.0f", fVal];
                            }
                        }
                    }
                }
            }
        }
    }
}

#pragma mark - Actions

- (void)openWhiteTestScreen {
    [self openWhiteTestScreen:nil];
}

- (void)openWhiteTestScreen:(id)sender {
    SpotHealWhiteTestController *testVC = [[SpotHealWhiteTestController alloc] init];
    testVC.modalPresentationStyle = UIModalPresentationFullScreen;
    testVC.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    
    UIViewController *presenter = self;
    if (self.navigationController) {
        presenter = self.navigationController;
    }
    if (self.view.window && self.view.window.rootViewController) {
        presenter = self.view.window.rootViewController;
    }
    while (presenter.presentedViewController) {
        presenter = presenter.presentedViewController;
    }
    [presenter presentViewController:testVC animated:YES completion:nil];
}

- (void)resetDefaults {
    [self resetDefaults:nil];
}

- (void)resetDefaults:(id)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset SpotHeal"
                                                                   message:@"Are you sure you want to restore default calibration settings?"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *resetAction = [UIAlertAction actionWithTitle:@"Reset"
                                                          style:UIAlertActionStyleDestructive
                                                        handler:^(UIAlertAction *action) {
        (void)action;
        savePrefDirect(@"enabled", @(YES));
        savePrefDirect(@"highlightMode", @(NO));
        savePrefDirect(@"offsetY", @(120.0));
        savePrefDirect(@"offsetX", @(0.0));
        savePrefDirect(@"radiusX", @(45.0));
        savePrefDirect(@"radiusY", @(45.0));
        savePrefDirect(@"intensity", @(12.0));
        savePrefDirect(@"softness", @(1.0));
        savePrefDirect(@"colorTint", @(0.0));
        
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFSTR(SPOTHEAL_NOTIFY),
            NULL,
            NULL,
            YES
        );
        
        [self reloadSpecifiers];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            UITableView *tv = [self table];
            if (tv) {
                [tv reloadData];
            }
        });
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    
    [alert addAction:resetAction];
    [alert addAction:cancelAction];
    
    UIViewController *presenter = self;
    while (presenter.presentedViewController) {
        presenter = presenter.presentedViewController;
    }
    [presenter presentViewController:alert animated:YES completion:nil];
}

@end
