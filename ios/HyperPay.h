#ifndef Hyperpay_h
#define Hyperpay_h
#import <OPPWAMobile/OPPWAMobile.h>
@import OPPWAMobile.Swift;
@import ipworks3ds_sdk.Swift;
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface HyperPay : RCTEventEmitter <RCTBridgeModule, OPPCheckoutProviderDelegate>

@property(nonatomic, strong) OPPCheckoutProvider *checkoutProvider;

@end

#endif /* Hyperpay */
