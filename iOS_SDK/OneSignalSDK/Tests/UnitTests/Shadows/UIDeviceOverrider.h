#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface UIDeviceOverrider : NSObject
+ (NSString *)systemName;
+ (NSString *)model;
+ (void)setSystemName:(NSString*) name;
+ (void)setModel:(NSString*) model;
+ (void)reset;
@end
