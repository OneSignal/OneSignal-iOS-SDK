/*
 Modified MIT License

 Copyright 2022 OneSignal

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 1. The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 2. All copies of substantial portions of the Software may only be used in connection
 with services provided by OneSignal.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import <Foundation/Foundation.h>

#import <OneSignalOutcomes/OneSignalOutcomes.h>

@interface OSInAppMessage : NSObject

@property (strong, nonatomic, nonnull) NSString *messageId;

// Convert the object into a NSDictionary
- (NSDictionary *_Nonnull)jsonRepresentation;

@end


@interface OSInAppMessageTag : NSObject

@property (strong, nonatomic, nullable) NSDictionary *tagsToAdd;
@property (strong, nonatomic, nullable) NSArray *tagsToRemove;

// Convert the class into a NSDictionary
- (NSDictionary *_Nonnull)jsonRepresentation;

@end

typedef NS_ENUM(NSUInteger, OSInAppMessageActionUrlType) {
    OSInAppMessageActionUrlTypeSafari,
    
    OSInAppMessageActionUrlTypeWebview,
    
    OSInAppMessageActionUrlTypeReplaceContent
};

@interface OSInAppMessageClickResult : NSObject

// The action name attached to the IAM action
@property (strong, nonatomic, nullable) NSString *actionId;

// The URL (if any) that should be opened when the action occurs
@property (strong, nonatomic, nullable) NSString *url;

// Whether or not the click action dismisses the message
@property (nonatomic) BOOL closingMessage;

// Determines where the URL is loaded, ie. app opens a webview
@property (nonatomic) OSInAppMessageActionUrlType urlTarget;

// Convert the class into a NSDictionary
- (NSDictionary *_Nonnull)jsonRepresentation;

@end

@interface OSInAppMessageWillDisplayEvent : NSObject
@property (nonatomic, readonly, nonnull) OSInAppMessage *message;
@end

@interface OSInAppMessageDidDisplayEvent : NSObject
@property (nonatomic, readonly, nonnull) OSInAppMessage *message;
@end

@interface OSInAppMessageWillDismissEvent : NSObject
@property (nonatomic, readonly, nonnull) OSInAppMessage *message;
@end

@interface OSInAppMessageDidDismissEvent : NSObject
@property (nonatomic, readonly, nonnull) OSInAppMessage *message;
@end

@protocol OSInAppMessageLifecycleListener <NSObject>
@optional
- (void)onWillDisplayInAppMessage:(OSInAppMessageWillDisplayEvent *_Nonnull)event
NS_SWIFT_NAME(onWillDisplay(event:));
- (void)onDidDisplayInAppMessage:(OSInAppMessageDidDisplayEvent *_Nonnull)event
NS_SWIFT_NAME(onDidDisplay(event:));
- (void)onWillDismissInAppMessage:(OSInAppMessageWillDismissEvent *_Nonnull)event
NS_SWIFT_NAME(onWillDismiss(event:));
- (void)onDidDismissInAppMessage:(OSInAppMessageDidDismissEvent *_Nonnull)event
NS_SWIFT_NAME(onDidDismiss(event:));
@end

@interface OSInAppMessageClickEvent : NSObject
@property (nonatomic, readonly, nonnull) OSInAppMessage *message;
@property (nonatomic, readonly, nonnull) OSInAppMessageClickResult *result;
// Convert the class into a NSDictionary
- (NSDictionary *_Nonnull)jsonRepresentation;
@end

@protocol OSInAppMessageClickListener <NSObject>
- (void)onClickInAppMessage:(OSInAppMessageClickEvent *_Nonnull)event
NS_SWIFT_NAME(onClick(event:));
@end

/**
 Public API for the InAppMessages namespace.
 */
@protocol OSInAppMessages <NSObject>

+ (void)addTrigger:(NSString * _Nonnull)key withValue:(NSString * _Nonnull)value;
+ (void)addTriggers:(NSDictionary<NSString *, NSString *> * _Nonnull)triggers;
+ (void)removeTrigger:(NSString * _Nonnull)key;
+ (void)removeTriggers:(NSArray<NSString *> * _Nonnull)keys;
+ (void)clearTriggers;
// Allows Swift users to: OneSignal.InAppMessages.paused = true
+ (BOOL)paused NS_REFINED_FOR_SWIFT;
+ (void)paused:(BOOL)pause NS_REFINED_FOR_SWIFT;

+ (void)addClickListener:(NSObject<OSInAppMessageClickListener> *_Nullable)listener NS_REFINED_FOR_SWIFT;
+ (void)removeClickListener:(NSObject<OSInAppMessageClickListener> *_Nullable)listener NS_REFINED_FOR_SWIFT;
+ (void)addLifecycleListener:(NSObject<OSInAppMessageLifecycleListener> *_Nullable)listener NS_REFINED_FOR_SWIFT;
+ (void)removeLifecycleListener:(NSObject<OSInAppMessageLifecycleListener> *_Nullable)listener NS_REFINED_FOR_SWIFT;
@end

@interface OneSignalInAppMessaging : NSObject <OSInAppMessages>

+ (Class<OSInAppMessages>_Nonnull)InAppMessages;
+ (void)start;

@end
