#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>

@interface LocationManager : NSObject<CLLocationManagerDelegate>

@property(strong, nonatomic) CLLocation* currentLocation;
@property(strong, nonatomic) NSNumber* connected;
@property(strong, nonatomic) NSNumber* viewerCnt;
@property(nonatomic) BOOL isUpdatingLocation;
@property(nonatomic) BOOL isUpdatingHeading;

+ (LocationManager*)sharedManager;
- (void)startUpdatingLocation;
- (void)stopUpdatingLocation;
- (void)startUpdatingHeading;
- (void)stopUpdatingHeading;

@end
