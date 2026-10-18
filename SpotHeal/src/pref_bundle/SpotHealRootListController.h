#import <UIKit/UIKit.h>

@interface PSSpecifier : NSObject
- (id)propertyForKey:(NSString *)key;
- (void)setProperty:(id)property forKey:(NSString *)key;
- (NSString *)identifier;
@end

@interface PSTableCell : UITableViewCell
- (PSSpecifier *)specifier;
- (id)target;
- (id)control;
- (id)value;
- (void)setValue:(id)value;
@end

@interface PSListController : UIViewController <UITableViewDataSource, UITableViewDelegate>
- (id)loadSpecifiersFromPlistName:(NSString *)name target:(id)target;
- (NSArray *)specifiers;
- (void)setSpecifiers:(NSArray *)specifiers;
- (PSSpecifier *)specifierForID:(NSString *)identifier;
- (void)reloadSpecifier:(PSSpecifier *)specifier animated:(BOOL)animated;
- (void)reloadSpecifier:(PSSpecifier *)specifier;
- (void)reloadSpecifiers;
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier;
- (id)readPreferenceValue:(PSSpecifier *)specifier;
- (UITableView *)table;
- (PSSpecifier *)specifierAtIndexPath:(NSIndexPath *)indexPath;
- (NSInteger)indexForIndexPath:(NSIndexPath *)indexPath;
- (PSSpecifier *)specifierAtIndex:(NSInteger)index;
@end

@interface SpotHealRootListController : PSListController <UITextFieldDelegate>
- (void)openWhiteTestScreen;
- (void)openWhiteTestScreen:(id)sender;
- (void)resetDefaults;
- (void)resetDefaults:(id)sender;
- (void)sh_sliderMoved:(UISlider *)slider;
@end
