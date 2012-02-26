#import <Foundation/Foundation.h>
#import <NNSocketIO.h>

@interface AppController : UIResponder<UIApplicationDelegate>

@property(strong, nonatomic) UIWindow *window;
@property(strong, nonatomic, readonly) NNSocketIO* io;
@property(weak, nonatomic, readonly) id<NNSocketIOClient> ioRootClient;
@property(nonatomic) BOOL networkAvailable;
@property(nonatomic) BOOL headingEnabled;

+ (AppController*)sharedController;

@end
