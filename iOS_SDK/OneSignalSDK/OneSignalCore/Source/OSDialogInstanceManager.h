//
//  OSDialogPresenter.h
//  OneSignal
//
//  Created by Elliot Mawby on 11/2/22.
//  Copyright © 2022 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^OSDialogActionCompletion)(int tappedActionIndex);

@protocol OSDialogPresenter <NSObject>
- (void)presentDialogWithTitle:(NSString * _Nonnull)title withMessage:(NSString * _Nonnull)message withActions:(NSArray<NSString *> * _Nullable)actionTitles cancelTitle:(NSString * _Nonnull)cancelTitle withActionCompletion:(OSDialogActionCompletion _Nullable)completion;
- (void)clearQueue;
@end

@interface OSDialogInstanceManager : NSObject
+ (void)setSharedInstance:(NSObject<OSDialogPresenter> *_Nonnull)instance;
+ (NSObject<OSDialogPresenter> *_Nonnull)sharedInstance;
@end
