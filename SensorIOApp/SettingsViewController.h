#import <UIKit/UIKit.h>

@interface SettingsViewController : UITableViewController {
    IBOutlet UISwitch* headingSwitch_;
}

@property(strong, nonatomic) UISwitch* headingSwitch;
- (IBAction)headingSettingValueChanged:(UISwitch*)uiSwitch;
@end
