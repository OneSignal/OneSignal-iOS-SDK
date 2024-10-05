#import <XCTest/XCTest.h>
#import <OneSignalUser/OneSignalUser-Swift.h>
#import <OneSignalOSCore/OneSignalOSCore-Swift.h>
#import <OneSignalCore/OneSignalCore.h>
#import <OneSignalCoreMocks/OneSignalCoreMocks-Swift.h>
#import <OneSignalUserMocks/OneSignalUserMocks-Swift.h>

@interface OneSignalUserObjcTests : XCTestCase

@end

@implementation OneSignalUserObjcTests

- (void)setUp {
    // TODO: Something like the existing [UnitTestCommonMethods beforeEachTest:self];
    // TODO: Need to clear all data between tests for client, user manager, models, etc.
    [OneSignalCoreMocks clearUserDefaults];
    [OneSignalUserMocks reset];
    // App ID is set because User Manager has guards against nil App ID
    [OneSignalConfigManager setAppId:@"test-app-id"];
    // Temp. logging to help debug during testing
    [OneSignalLog setLogLevel:ONE_S_LL_VERBOSE];
}

- (void)tearDown { }

/**
 Tests passing purchase data to the User Manager to process and send.
 It is written in Objective-C as the data comes from Objective-C code.
 */
- (void)testSendPurchases {
    /* Setup */

    MockOneSignalClient* client = [MockOneSignalClient new];

    // 1. Set up mock responses for the anonymous user
    [MockUserRequests setDefaultCreateAnonUserResponsesWith:client];
    [OneSignalCoreImpl setSharedClient:client];

    /* When */

    NSMutableArray* arrayOfPurchases = [NSMutableArray new];
    // SKProduct.price is an NSDecimalNumber, but the backend expects a String
    NSNumberFormatter *formatter = [NSNumberFormatter new];
    [formatter setMinimumFractionDigits:2];
    
    NSString *formattedPrice1 = [formatter stringFromNumber:[NSDecimalNumber numberWithFloat:3.0]];
    NSString *formattedPrice2 = [formatter stringFromNumber:[NSDecimalNumber numberWithFloat:4.05]];
    
    NSDictionary* purchase1 = @{
        @"sku": @"productSku1",
        @"amount": formattedPrice1,
        @"iso": @"EUR"
    };
    [arrayOfPurchases addObject:purchase1];

    NSDictionary* purchase2 = @{
        @"sku": @"productSku2",
        @"amount": formattedPrice2,
        @"iso": @"USD"
    };
    [arrayOfPurchases addObject:purchase2];

    // Set JWT to off, before accessing the User Manager
    [OneSignalUserManagerImpl.sharedInstance setRequiresUserAuth:false];
    [OneSignalUserManagerImpl.sharedInstance sendPurchases:arrayOfPurchases];
    
    // Run background threads
    [OneSignalCoreMocks waitForBackgroundThreadsWithSeconds:0.5];

    /* Then */

    NSString* path = [NSString stringWithFormat:@"apps/test-app-id/users/by/onesignal_id/%@", @"test_anon_user_onesignal_id"];
    NSDictionary *payload = [NSDictionary dictionaryWithObject:[NSDictionary dictionaryWithObject:arrayOfPurchases forKey:@"purchases"] forKey:@"deltas"];

    XCTAssertTrue([client onlyOneRequestWithContains:path contains:payload]);
}

@end
