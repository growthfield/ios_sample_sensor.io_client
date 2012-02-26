#import <CoreLocation/CoreLocation.h>
#import "LocationManager.h"
#import "NNSocketIO.h"
#import "AppController.h"
#import "NNDispatch.h"
#import "JSONKit.h"

@interface LocationManager()
- (void)send:(CLLocation*) location;
@end

@implementation LocationManager
{
    __weak id<NNSocketIOClient> ioDeviceClient_;
    CLLocationManager* clmanager_;
    CLLocation* currentLocation_;
    CLLocation* tmpLocation_;
    NNDispatch* timer_;
    NSNumber* connected_;
    NSNumber* viewerCnt_;
    BOOL isUpdatingLocation_;
    BOOL isUpdatingHeading_;
}

@synthesize currentLocation = currentLocation_;
@synthesize connected = connected_;
@synthesize viewerCnt = viewerCnt_;
@synthesize isUpdatingLocation = isUpdatingLocation_;
@synthesize isUpdatingHeading = isUpdatingHeading_;

+ (LocationManager*)sharedManager
{
    static dispatch_once_t onceToken;
    static LocationManager* instance = nil;
    dispatch_once(&onceToken, ^{
        instance = [[LocationManager alloc] init];
    });
    return instance;
}

- (id)init
{
    self = [super init];
    if (self) {
        isUpdatingLocation_ = NO;
        isUpdatingHeading_ = NO;
        AppController* ac = [AppController sharedController];
        clmanager_ = [[CLLocationManager alloc] init];
        clmanager_.delegate = self;
        clmanager_.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
        clmanager_.distanceFilter = kCLDistanceFilterNone;
        //clmanager_.distanceFilter = 5.0;
        clmanager_.headingFilter = 10.0;
        ioDeviceClient_ = [ac.ioRootClient of:@"/device"];
        [ioDeviceClient_ on:@"connect" listener:^(NNArgs *args) {
            [self setValue:[NSNumber numberWithBool:YES] forKey:@"connected"];
            UILocalNotification* notif = [[UILocalNotification alloc] init];
            notif.alertBody = @"Connected";
            [[UIApplication sharedApplication] presentLocalNotificationNow:notif];            
        }];
        [ioDeviceClient_ on:@"disconnect" listener:^(NNArgs* args) {
            [self setValue:[NSNumber numberWithBool:NO] forKey:@"connected"];
            currentLocation_ = nil;
            tmpLocation_ = nil;
            UILocalNotification* notif = [[UILocalNotification alloc] init];
            notif.alertBody = @"Disconnected";
            [[UIApplication sharedApplication] presentLocalNotificationNow:notif];
        }];
        [ioDeviceClient_ on:@"viewer" listener:^(NNArgs* args) {
            NSNumber* cnt = [args get:0];
            [self setValue:cnt forKey:@"viewerCnt"];
        }];
    }
    return self;
}

- (void)startUpdatingLocation
{
    if (!isUpdatingLocation_) {
        [clmanager_ startUpdatingLocation];
        isUpdatingLocation_ = YES;
    }
    
}

- (void)stopUpdatingLocation
{
    if (isUpdatingLocation_) {
        [clmanager_ stopUpdatingLocation];
        isUpdatingLocation_ = NO;
    }
}

- (void)startUpdatingHeading
{
    if (!isUpdatingHeading_) {
        [clmanager_ startUpdatingHeading];
        isUpdatingHeading_ = YES;
    }
}

- (void)stopUpdatingHeading
{
    if (isUpdatingHeading_) {
        [clmanager_ stopUpdatingHeading];
        isUpdatingHeading_ = NO;
    }
}

- (void)locationManager:(CLLocationManager*)manager didUpdateToLocation:(CLLocation*)newLocation fromLocation:(CLLocation*)oldLocation
{
    /*
    NSLog(@"==================================");
    NSLog(@"Old LatLng：%+.6f, %+.6f \n", oldLocation.coordinate.latitude, oldLocation.coordinate.longitude);
    NSLog(@"New LatLng：%+.6f, %+.6f \n", newLocation.coordinate.latitude, newLocation.coordinate.longitude);
    NSLog(@"New vertical accuracy：%+.6f", newLocation.verticalAccuracy);
    NSLog(@"New horizontal accuracy：%+.6f", newLocation.horizontalAccuracy);    
    NSLog(@"New altitude：%+.6f \n", newLocation.altitude);
    NSLog(@"New description：%@ \n", [newLocation description]);
    NSLog(@"New timestamp：%.4f \n", [newLocation.timestamp timeIntervalSinceNow]);
    */
    
    NSDate* now = [NSDate date];
    CLLocationAccuracy newAccuracy = newLocation.horizontalAccuracy;
    if (abs([now timeIntervalSinceDate:newLocation.timestamp]) > 60 || newAccuracy >= 200.0) {
        return;
    }
    if (newAccuracy <= 20) {
        if (!currentLocation_ || [newLocation distanceFromLocation:currentLocation_] >= 20.0) {
            [self send:newLocation];            
        }
        return;
    }
    if (currentLocation_ &&  [newLocation distanceFromLocation:currentLocation_] <= 100) {
        return;
    }
    if (!tmpLocation_ || !currentLocation_ || tmpLocation_.horizontalAccuracy > newAccuracy) {
        tmpLocation_ = newLocation;
        if (!timer_) {
            timer_ = [NNDispatch dispatchAfter:dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 15) queue:dispatch_get_main_queue() block:^{
                if (tmpLocation_) {
                    [self send:tmpLocation_];
                }
            }];
        }
    }
}

- (void)send:(CLLocation *)location
{
    [self setValue:location forKey:@"currentLocation"];
    CLLocationCoordinate2D coordinate = location.coordinate;
    NSNumber* latitude = [NSNumber numberWithDouble:coordinate.latitude];
    NSNumber* longitude = [NSNumber numberWithDouble:coordinate.longitude];
    NSNumber* time = [NSNumber numberWithDouble:floor(location.timestamp.timeIntervalSince1970 * 1000)];
    NSMutableDictionary* json = [NSMutableDictionary dictionary];
    [json setObject:[NSArray arrayWithObjects:longitude, latitude, nil] forKey:@"coordinate"];
    [json setObject:time forKey:@"timestamp"];
    [ioDeviceClient_ emit:@"location" args:[[NNArgs args] add:json]];
    tmpLocation_ = nil; 
    [timer_ cancel];
    timer_ = nil;
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    UILocalNotification* notif = [[UILocalNotification alloc] init];
    notif.alertBody = @"Failed to update location";
    [[UIApplication sharedApplication] presentLocalNotificationNow:notif];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading
{
    CLLocationDirection d = newHeading.trueHeading > 0 ? newHeading.trueHeading : newHeading.magneticHeading;
    NSMutableDictionary* json = [NSMutableDictionary dictionary];
    [json setObject:[NSNumber numberWithDouble:(double)d] forKey:@"value"];
    [ioDeviceClient_ emit:@"heading" args:[[NNArgs args] add:json]];    
}

@end
