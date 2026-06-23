#ifndef Hyperpay_h
#define Hyperpay_h
#import <OPPWAMobile/OPPWAMobile.h>
@import OPPWAMobile.Swift;
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface HyperPay : RCTEventEmitter <RCTBridgeModule, OPPThreeDSEventListener>

@end

#endif /* Hyperpay */
