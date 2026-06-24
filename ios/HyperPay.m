
#import <Foundation/Foundation.h>
#import "HyperPay.h"
#import <React/RCTLog.h>

@implementation HyperPay

OPPPaymentProvider *provider;
NSString *shopperResultURL = @"";
NSString *merchantIdentifier = @"";
NSString *countryCode = @"";
NSString *mode=@"TestMode";
NSArray *supportedNetworks;
NSString *companyName=@"";

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

      [provider submitTransaction:transaction completionHandler:^(OPPTransaction * _Nonnull transaction, NSError * _Nullable error) {
        NSDictionary *transactionResult;
        if (transaction.type == OPPTransactionTypeAsynchronous) {
            
           transactionResult = @{
          @"redirectURL":transaction.redirectURL.absoluteString,
          @"status":@"pending",
          @"checkoutId":transaction.paymentParams.checkoutID
          };
          resolve(transactionResult);

        }  else if (transaction.type == OPPTransactionTypeSynchronous) {

          transactionResult = @{
          @"status":@"completed",
          @"resourcePath":transaction.resourcePath ?: @"",
          @"checkoutId":transaction.paymentParams.checkoutID
          };
          resolve(transactionResult);
        } else {
          reject(@"createTransaction",error.localizedDescription, error);
        }
      }];
    }
}



RCT_EXPORT_METHOD(applePay:(NSDictionary*)params resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject){

  OPPCheckoutSettings *checkoutSettings = [[OPPCheckoutSettings alloc] init];
  checkoutSettings.shopperResultURL = shopperResultURL.length > 0 ? shopperResultURL : nil;

  PKPaymentRequest *paymentRequest = [OPPPaymentProvider paymentRequestWithMerchantIdentifier:merchantIdentifier countryCode:countryCode];
  paymentRequest.supportedNetworks = supportedNetworks;

    if ([params valueForKey:@"companyName"]){
        companyName=[params valueForKey:@"companyName"];
       }
        NSDecimalNumber *amount = [NSDecimalNumber decimalNumberWithMantissa:[[params valueForKey:@"amount"] intValue] exponent:-2 isNegative:NO];
        paymentRequest.paymentSummaryItems = @[[PKPaymentSummaryItem summaryItemWithLabel:companyName amount:amount]];
  
    
  checkoutSettings.applePayPaymentRequest = paymentRequest;
  self.checkoutProvider = [OPPCheckoutProvider checkoutProviderWithPaymentProvider:provider
                                                                                        checkoutID:[params valueForKey:@"checkoutID"]
                                                                                          settings:checkoutSettings];
  self.checkoutProvider.delegate = self;

  [self.checkoutProvider presentCheckoutWithPaymentBrand:@"APPLEPAY"
    loadingHandler:^(BOOL inProgress) {
      [self sendEventWithName:@"onProgress" body:@(inProgress)];
  } completionHandler:^(OPPTransaction * _Nullable transaction, NSError * _Nullable error) {
      if (error) {
        reject(@"applePay",error.localizedDescription, error);
      } else {
          if (transaction.redirectURL)
              resolve(@{@"redirectURL": transaction.redirectURL.absoluteString});
          else
              resolve(@{@"resourcePath": transaction.resourcePath});
      }
  } cancelHandler:^{
       reject(@"applePay",@"cancel",NULL);
  }];

}

RCT_EXPORT_METHOD(requestCheckoutInfo:(NSString*)checkoutID resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  [provider requestCheckoutInfoWithCheckoutID:checkoutID completionHandler:^(OPPCheckoutInfo * _Nullable checkoutInfo, NSError * _Nullable error) {
    if (error) {
      reject(@"requestCheckoutInfo", error.localizedDescription, error);
      return;
    }
    resolve([self checkoutInfoToDictionary:checkoutInfo]);
  }];
}

RCT_EXPORT_METHOD(requestCheckoutData:(NSString*)checkoutID resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  [provider requestCheckoutDataWithCheckoutID:checkoutID completionHandler:^(OPPCheckoutData * _Nullable checkoutData, NSError * _Nullable error) {
    if (error) {
      reject(@"requestCheckoutData", error.localizedDescription, error);
      return;
    }
    resolve(@{
      @"amount": checkoutData.amount ?: [NSNull null],
      @"currency": checkoutData.currency ?: [NSNull null],
      @"taxAmount": checkoutData.taxAmount ?: [NSNull null],
      @"merchantTransactionId": checkoutData.merchantTransactionID ?: [NSNull null]
    });
  }];
}

RCT_EXPORT_METHOD(getThreeDS2Warnings:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  [provider securityWarningsWithCompletionHandler:^(NSArray<Warning *> * _Nullable warnings, NSError * _Nullable error) {
    if (error) {
      reject(@"getThreeDS2Warnings", error.localizedDescription, error);
      return;
    }
    NSMutableArray *result = [NSMutableArray new];
    for (Warning *warning in warnings) {
      [result addObject:@{
        @"id": [warning getID] ?: [NSNull null],
        @"message": [warning getMessage] ?: [NSNull null],
        @"severity": [self severityToString:[warning getSeverity]]
      }];
    }
    resolve(result);
  }];
}

RCT_EXPORT_METHOD(validateBrands:(NSString*)checkoutID brands:(NSArray<NSString*>*)brands resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  [provider requestValidationsForPaymentBrands:brands checkoutID:checkoutID completionHandler:^(NSArray<OPPBrandInfo *> * _Nullable brandRules, NSError * _Nullable error) {
    if (error) {
      reject(@"validateBrands", error.localizedDescription, error);
      return;
    }
    NSMutableArray *brandList = [NSMutableArray new];
    for (OPPBrandInfo *brandInfo in brandRules) {
      [brandList addObject:@{
        @"brand": brandInfo.brand ?: [NSNull null],
        @"label": brandInfo.label ?: [NSNull null],
        @"renderType": brandInfo.renderType ?: [NSNull null],
        @"isCardBrand": @(brandInfo.cardBrandInfo != nil),
        @"isCustomUiRequired": @(brandInfo.isCustomUiRequired)
      }];
    }
    resolve(@{@"brands": brandList});
  }];
}

RCT_EXPORT_METHOD(requestImages:(NSArray<NSString*>*)brands resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  [provider requestLogoURLsForPaymentBrands:brands completionHandler:^(NSDictionary<NSString *,NSURL *> * _Nullable URLs, NSError * _Nullable error) {
    if (error) {
      reject(@"requestImages", error.localizedDescription, error);
      return;
    }
    NSMutableDictionary *result = [NSMutableDictionary new];
    for (NSString *brand in URLs) {
      NSURL *url = URLs[brand];
      result[brand] = @{
        @"type": @"url",
        @"width": [NSNull null],
        @"height": [NSNull null],
        @"url": url.absoluteString ?: [NSNull null],
        @"content": [NSNull null]
      };
    }
    resolve(result);
  }];
}

RCT_EXPORT_METHOD(requestBinInfo:(NSString*)checkoutID bin:(NSString*)bin resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  [provider requestBinInfoWithCheckoutID:checkoutID bin:bin completionHandler:^(OPPBinInfo * _Nullable binInfo, NSError * _Nullable error) {
    if (error) {
      reject(@"requestBinInfo", error.localizedDescription, error);
      return;
    }
    resolve(@{
      @"brands": binInfo.brands ?: @[],
      @"binType": binInfo.binType ?: [NSNull null],
      @"type": binInfo.type ?: [NSNull null]
    });
  }];
}

- (NSDictionary *)checkoutInfoToDictionary:(OPPCheckoutInfo *)checkoutInfo {
  return @{
    @"endpoint": checkoutInfo.endpoint ?: [NSNull null],
    @"resourcePath": checkoutInfo.resourcePath ?: [NSNull null],
    @"amount": checkoutInfo.amount ?: [NSNull null],
    @"currencyCode": checkoutInfo.currencyCode ?: [NSNull null],
    @"countryCode": checkoutInfo.bankAccountCountry ?: [NSNull null],
    @"shopBrandsOverridden": @(NO),
    @"brandsActivated": @(YES),
    @"collectRedShieldDeviceId": @(checkoutInfo.collectRedShieldDeviceId),
    @"visaInstallmentEnabled": @(checkoutInfo.visaInstallmentConfig != nil),
    @"logLevel": checkoutInfo.logLevel ?: [NSNull null],
    @"msdkUi": [self msdkUiTypeToString:checkoutInfo.msdkUiType],
    @"brands": @[],
    @"klarnaMerchantIds": checkoutInfo.klarnaMerchantIDs ?: @[]
  };
}

- (NSString *)severityToString:(Severity)severity {
  switch (severity) {
    case SeverityLOW:
      return @"LOW";
    case SeverityMEDIUM:
      return @"MEDIUM";
    case SeverityHIGH:
      return @"HIGH";
    default:
      return @"UNKNOWN";
  }
}

- (NSString *)msdkUiTypeToString:(OPPMsdkUiType)msdkUiType {
  switch (msdkUiType) {
    case OPPMsdkUiTypeNative:
      return @"NATIVE";
    case OPPMsdkUiTypeHybrid:
      return @"HYBRID";
    default:
      return @"UNKNOWN";
  }
}

#pragma mark - OPPCheckoutProviderDelegate

- (void)checkoutProvider:(OPPCheckoutProvider *)checkoutProvider
      continueSubmitting:(OPPTransaction *)transaction
              completion:(void (^)(NSString * _Nullable, BOOL))completion {
    completion(nil, YES);
}

@end
