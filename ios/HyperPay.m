
#import <Foundation/Foundation.h>
#import "HyperPay.h"
#import <React/RCTLog.h>
#import <UIKit/UIKit.h>

@interface HyperPay ()
@property (nonatomic, strong) UINavigationController *threeDSNavController;
@end

@implementation HyperPay

OPPPaymentProvider *provider;
NSString *shopperResultURL = @"";
NSString *merchantIdentifier = @"";
NSString *countryCode = @"";
NSString *mode=@"TestMode";
NSArray *supportedNetworks;
NSString *companyName=@"";
BOOL enable3DS = NO;

RCT_EXPORT_MODULE(HyperPay)

-(instancetype)init
{
  
    self = [super init];
    if (self) {
        provider = [OPPPaymentProvider paymentProviderWithMode:OPPProviderModeTest];
    }
    return self;
}

- (NSArray<NSString *> *)supportedEvents {
    return @[@"onTransactionComplete",@"onProgress"];
}

/**
 React Native functions
 */


RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(setup: (NSDictionary*)options) {
    shopperResultURL=[options valueForKey:@"shopperResultURL"];
    if ([options valueForKey:@"merchantIdentifier"])
        merchantIdentifier=[options valueForKey:@"merchantIdentifier"];
    if ([options valueForKey:@"companyName"])
        companyName=[options valueForKey:@"companyName"];
    if ([options valueForKey:@"countryCode"])
       countryCode=[options valueForKey:@"countryCode"];
    if ([options valueForKey:@"supportedNetworks"])
        supportedNetworks=[options valueForKey:@"supportedNetworks"];
    if ([options valueForKey:@"enable3DS"])
        enable3DS = [[options valueForKey:@"enable3DS"] boolValue];
    if ([[options valueForKey:@"mode"] isEqual:@"LiveMode"])
      provider = [OPPPaymentProvider paymentProviderWithMode:OPPProviderModeLive];
    else
      provider = [OPPPaymentProvider paymentProviderWithMode:OPPProviderModeTest];
    return options;
}


RCT_EXPORT_METHOD(createPaymentTransaction: (NSDictionary*)options resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  NSError * _Nullable error;

    OPPCardPaymentParams *params = [OPPCardPaymentParams cardPaymentParamsWithCheckoutID:[options valueForKey:@"checkoutID"]
                                                                        paymentBrand:[options valueForKey:@"paymentBrand"]
                                                                              holder:[options valueForKey:@"holderName"]
                                                                              number:[options valueForKey:@"cardNumber"]
                                                                         expiryMonth:[options valueForKey:@"expiryMonth"]
                                                                          expiryYear:[options valueForKey:@"expiryYear"]
                                                                                 CVV:[options valueForKey:@"cvv"]
                                                                               error:&error];

    if (error) {
      NSLog(@"%s", "error");
      reject(@"createTransaction",error.localizedDescription, error);

    } else {
        params.shopperResultURL = shopperResultURL;
      OPPTransaction *transaction = [OPPTransaction transactionWithPaymentParams:params];

      if (enable3DS) {
          provider.threeDSEventListener = self;
      }
      [provider submitTransaction:transaction completionHandler:^(OPPTransaction * _Nonnull transaction, NSError * _Nullable error) {
        NSDictionary *transactionResult;
        if (transaction.type == OPPTransactionTypeAsynchronous) {
            
           transactionResult = @{
          @"redirectURL":transaction.redirectURL.absoluteString,
          @"status":@"pending",
          @"checkoutId":transaction.paymentParams.checkoutID
          };
          [self dismissThreeDSNavController];
          resolve(transactionResult);

        }  else if (transaction.type == OPPTransactionTypeSynchronous) {

          transactionResult = @{
          @"status":@"completed",
          @"checkoutId":transaction.paymentParams.checkoutID
          };
          [self dismissThreeDSNavController];
          resolve(transactionResult);
        } else {
          [self dismissThreeDSNavController];
          reject(@"createTransaction",error.localizedDescription, error);
        }
      }];
    }
}



RCT_EXPORT_METHOD(applePay:(NSDictionary*)params resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject){
  
  OPPCheckoutSettings *checkoutSettings = [[OPPCheckoutSettings alloc] init];

  if (enable3DS) {
      OPPThreeDSConfig *threeDSConfig = [[OPPThreeDSConfig alloc] init];
      threeDSConfig.appBundleID = [[NSBundle mainBundle] bundleIdentifier];
      checkoutSettings.threeDSConfig = threeDSConfig;
  }
  checkoutSettings.shopperResultURL = shopperResultURL;

  PKPaymentRequest *paymentRequest = [OPPPaymentProvider paymentRequestWithMerchantIdentifier:merchantIdentifier countryCode:countryCode];
  paymentRequest.supportedNetworks = supportedNetworks;
  

    if ([params valueForKey:@"companyName"]){
        companyName=[params valueForKey:@"companyName"];
       }
        NSDecimalNumber *amount = [NSDecimalNumber decimalNumberWithMantissa:[[params valueForKey:@"amount"] intValue] exponent:-2 isNegative:NO];
        paymentRequest.paymentSummaryItems = @[[PKPaymentSummaryItem summaryItemWithLabel:companyName amount:amount]];
 
    
  checkoutSettings.applePayPaymentRequest = paymentRequest;
  OPPCheckoutProvider *checkoutProvider = [OPPCheckoutProvider checkoutProviderWithPaymentProvider:provider
                                                                                        checkoutID:[params valueForKey:@"checkoutID"]
                                                                                          settings:checkoutSettings];

  [checkoutProvider presentCheckoutWithPaymentBrand:@"APPLEPAY"
    loadingHandler:^(BOOL inProgress) {
      [self sendEventWithName:@"onProgress" body:@(inProgress)];
      // Executed whenever SDK sends request to the server or receives the response.
      // You can start or stop loading animation based on inProgress parameter.
  } completionHandler:^(OPPTransaction * _Nullable transaction, NSError * _Nullable error) {
      if (error) {
//          reject(@"applePay",checkoutID,error);
        reject(@"applePay",error.localizedDescription, error);
          // See code attribute (OPPErrorCode) and NSLocalizedDescription to identify the reason of failure.
      } else {
          if (transaction.redirectURL)
              resolve(@{@"redirectURL": transaction.redirectURL.absoluteString});
          else
              resolve(@{@"resourcePath": transaction.resourcePath});
      }
  } cancelHandler:^{
       reject(@"applePay",@"cancel",NULL);
      // Executed if the shopper closes the payment page prematurely.
  }];

}


- (void)dismissThreeDSNavController {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.threeDSNavController) {
            [self.threeDSNavController dismissViewControllerAnimated:YES completion:nil];
            self.threeDSNavController = nil;
        }
    });
}

#pragma mark - OPPThreeDSEventListener

- (void)onThreeDSConfigRequiredWithCompletion:(void (^)(OPPThreeDSConfig *config))completion {
    OPPThreeDSConfig *config = [[OPPThreeDSConfig alloc] init];
    config.appBundleID = [[NSBundle mainBundle] bundleIdentifier];
    config.clientConfigParams = @{@"AcceptAnyACSCert": @"true"};
    completion(config);
}

- (void)onThreeDSChallengeRequiredWithCompletion:(void (^)(UINavigationController *navController))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *rootVC = nil;
        if (@available(iOS 13.0, *)) {
            for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    UIWindowScene *windowScene = (UIWindowScene *)scene;
                    rootVC = windowScene.windows.firstObject.rootViewController;
                    break;
                }
            }
        }
        if (!rootVC) {
            rootVC = UIApplication.sharedApplication.keyWindow.rootViewController;
        }
        UINavigationController *nav = [[UINavigationController alloc] init];
        self.threeDSNavController = nav;
        if (rootVC) {
            [rootVC presentViewController:nav animated:YES completion:^{
                completion(nav);
            }];
        } else {
            completion(nav);
        }
    });
}

@end


