#import "AppController.h"
#import "LocationManager.h"
#import "NNReachability.h"
#import "SettingsViewController.h"

@interface AppController()
- (void)updateStatus;
@end

@implementation AppController {
    UIBackgroundTaskIdentifier bgTask_;
    NNReachability* reachability_;
    BOOL connected_;
    CLLocation* currentLocation_;
    NSUInteger viewerCnt_;
    NSDateFormatter* dateFormatter_;
}

static AppController* sharedController_;

@synthesize window = window_;
@synthesize io = io_;
@synthesize ioRootClient = ioRootClient_;
@synthesize networkAvailable = networkAvaiable_;
@synthesize headingEnabled = headingEnabled_;

+ (AppController*)sharedController
{
    return sharedController_;
}

- (id)init
{
    self = [super init];
    if (self) {
        sharedController_ = self;
        connected_ = false;
        currentLocation_ = nil;
        dateFormatter_ = [[NSDateFormatter alloc] init];
        [dateFormatter_ setDateFormat:@"yyyy/MM/dd HH:mm:ss"];
        viewerCnt_ = 0;
        headingEnabled_ = NO;
    }
    return self;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    reachability_ = [NNReachability reachabilityForInternetConnection];
    [reachability_ start];
    
    NSString *envPath = [[NSBundle mainBundle] pathForResource:@"env" ofType:@"plist"];
    NSDictionary* envDict = [[NSDictionary alloc] initWithContentsOfFile:envPath];
    NSURL* url = [NSURL URLWithString:[envDict objectForKey:@"url"]];    
    NSString* secretOrigin = [envDict objectForKey:@"origin"];
        
    NNSocketIOOptions* opts = [NNSocketIOOptions options];
    opts.enableBackgroundingOnSocket = YES;
    opts.retryDelayLimit = 60 * 3;
    opts.origin = secretOrigin;
    io_ = [NNSocketIO io];
    ioRootClient_ = [io_ connect:url options:opts];
    LocationManager* locationManager = [LocationManager sharedManager];
    [locationManager startUpdatingLocation];
    [locationManager addObserver:self forKeyPath:@"currentLocation" options:NSKeyValueObservingOptionNew context:nil];
    [locationManager addObserver:self forKeyPath:@"connected" options:NSKeyValueObservingOptionNew context:nil];
    [locationManager addObserver:self forKeyPath:@"viewerCnt" options:NSKeyValueObservingOptionNew context:nil];    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    /*
    void (^handler)(void)  = ^{
        UIApplication* app = [UIApplication sharedApplication];
        [app endBackgroundTask:bgTask_];
        bgTask_ = UIBackgroundTaskInvalid;
    };
    bgTask_ = [application beginBackgroundTaskWithExpirationHandler:handler];
    [application setKeepAliveTimeout:600 handler:^{
        if (!bgTask_ || bgTask_ == UIBackgroundTaskInvalid) {
            UIApplication* app = [UIApplication sharedApplication];
            bgTask_ = [app beginBackgroundTaskWithExpirationHandler:handler];                
        }
    }];
    */
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    [self updateStatus];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    LocationManager* locationManager = [LocationManager sharedManager];
    [locationManager stopUpdatingLocation];
    [locationManager stopUpdatingHeading];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    id val = [change objectForKey:NSKeyValueChangeNewKey];
    if ([keyPath isEqualToString:@"currentLocation"]) {
        currentLocation_ = val;
    } else if ([keyPath isEqualToString:@"connected"]) {
        connected_ = [val boolValue];
    } else if ([keyPath isEqualToString:@"viewerCnt"]) {
        viewerCnt_ = [val unsignedIntegerValue];
        LocationManager* lm = [LocationManager sharedManager];
        if (viewerCnt_ == 0) {
            [lm stopUpdatingHeading];
        } else if (headingEnabled_) {
            [lm startUpdatingHeading];
        }
    }
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
        [self updateStatus];
    }
}

- (void)updateStatus
{
    SettingsViewController* vc = (SettingsViewController*)self.window.rootViewController;
    UITableView* tableView = vc.tableView;
    UITableViewCell* connectCell = [tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    [connectCell.detailTextLabel setText:connected_ ? @"Connected" : @"Disconnected"];    

    UITableViewCell* headingStatusCell = [tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:1]];
    [headingStatusCell.detailTextLabel setText:[LocationManager sharedManager].isUpdatingHeading ? @"runing" : @"stop"];
     
    CLLocationCoordinate2D coordinate = currentLocation_.coordinate;
    UITableViewCell* latCell = [tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:2]];
    [latCell.detailTextLabel setText:[NSString stringWithFormat:@"%+.6f", coordinate.latitude]];
    UITableViewCell* lngCell = [tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:2]];
    [lngCell.detailTextLabel setText:[NSString stringWithFormat:@"%+.6f", coordinate.longitude]];
    UITableViewCell* accCell = [tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:2 inSection:2]];
    [accCell.detailTextLabel setText:[NSString stringWithFormat:@"%+.6f", currentLocation_.horizontalAccuracy]];
    UITableViewCell* timeCell = [tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:3 inSection:2]];
    [timeCell.detailTextLabel setText:[NSString stringWithFormat:@"%@", [dateFormatter_ stringFromDate:currentLocation_.timestamp]]];
    UITableViewCell* speedCell = [tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:4 inSection:2]];
    [speedCell.detailTextLabel setText:[NSString stringWithFormat:@"%.3f", currentLocation_.speed]];
    
    UITableViewCell* viewerCell = [tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:3]];
    [viewerCell.detailTextLabel setText:[NSString stringWithFormat:@"%d", viewerCnt_]];

    [tableView reloadData];    
}

- (void)setHeadingEnabled:(BOOL)headingEnabled
{
    headingEnabled_ = headingEnabled;
    if (headingEnabled) {
        if (viewerCnt_ > 0) {
            [[LocationManager sharedManager] startUpdatingHeading];            
        }
    } else {
        [[LocationManager sharedManager] stopUpdatingHeading];
    }
    [self updateStatus];
}

@end
