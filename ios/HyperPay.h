#ifndef Hyperpay_h
#define Hyperpay_h

#import <OPPWAMobile/OPPWAMobile.h>
@import OPPWAMobile.Swift;
@import ipworks3ds_sdk.Swift;
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <PassKit/PassKit.h>

@interface HyperPay : RCTEventEmitter <RCTBridgeModule, OPPThreeDSEventListener, PKPaymentAuthorizationViewControllerDelegate>

@property(nonatomic, strong) OPPPaymentProvider *provider;
@property(nonatomic, strong) NSString *checkoutID;
@property(nonatomic, strong) OPPTransaction *transaction;
@property(nonatomic, strong) NSString *resourcePath;
@property(nonatomic, strong) NSString *shopperResultURL;
@property(nonatomic, strong) NSString *merchantIdentifier;
@property(nonatomic, strong) NSString *countryCode;
@property(nonatomic, strong) NSString *companyName;
@property(nonatomic, strong) NSArray *supportedNetworks;
@property(nonatomic, strong) NSString *mode;
@property(nonatomic, copy) RCTPromiseResolveBlock applePayResolve;
@property(nonatomic, copy) RCTPromiseRejectBlock applePayReject;

@end

#endif
