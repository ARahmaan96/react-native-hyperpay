#import <Foundation/Foundation.h>
#import "HyperPay.h"
#import <React/RCTLog.h>


@implementation HyperPay

RCT_EXPORT_MODULE(HyperPay)

-(instancetype)init
{
    self = [super init];
    if (self) {
        _provider = [OPPPaymentProvider paymentProviderWithMode:OPPProviderModeTest];
        _shopperResultURL = @"";
        _merchantIdentifier = @"";
        _countryCode = @"";
        _mode = @"TestMode";
        _supportedNetworks = @[];
        _companyName = @"";
    }
    return self;
}

- (NSArray<NSString *> *)supportedEvents {
    return @[@"onTransactionComplete", @"onProgress"];
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(setup:(NSDictionary*)options) {
    _shopperResultURL = [options valueForKey:@"shopperResultURL"] ?: @"";
    _merchantIdentifier = [options valueForKey:@"merchantIdentifier"] ?: @"";
    _companyName = [options valueForKey:@"companyName"] ?: @"";
    _countryCode = [options valueForKey:@"countryCode"] ?: @"";
    _supportedNetworks = [options valueForKey:@"supportedNetworks"] ?: @[];

    NSString *newMode = [options valueForKey:@"mode"];
    if ([newMode isEqual:@"LiveMode"]) {
        _mode = @"LiveMode";
        _provider = [OPPPaymentProvider paymentProviderWithMode:OPPProviderModeLive];
    } else {
        _mode = @"TestMode";
        _provider = [OPPPaymentProvider paymentProviderWithMode:OPPProviderModeTest];
    }
    return options;
}

RCT_EXPORT_METHOD(createPaymentTransaction:(NSDictionary*)options resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    [self sendEventWithName:@"onProgress" body:@(YES)];

    NSError *error = nil;
    OPPCardPaymentParams *params = [OPPCardPaymentParams cardPaymentParamsWithCheckoutID:[options valueForKey:@"checkoutID"]
                                                                          paymentBrand:[options valueForKey:@"paymentBrand"]
                                                                                holder:[options valueForKey:@"holderName"]
                                                                                number:[options valueForKey:@"cardNumber"]
                                                                           expiryMonth:[options valueForKey:@"expiryMonth"]
                                                                            expiryYear:[options valueForKey:@"expiryYear"]
                                                                                   CVV:[options valueForKey:@"cvv"]
                                                                                 error:&error];
    if (error) {
        [self sendEventWithName:@"onProgress" body:@(NO)];
        reject(@"createTransaction", error.localizedDescription, error);
        return;
    }

    params.shopperResultURL = _shopperResultURL;

    OPPTransaction *transaction = [OPPTransaction transactionWithPaymentParams:params];

    __weak HyperPay *weakSelf = self;
    [_provider submitTransaction:transaction completionHandler:^(OPPTransaction * _Nonnull transaction, NSError * _Nullable error) {
        __strong HyperPay *strongSelf = weakSelf;
        [strongSelf sendEventWithName:@"onProgress" body:@(NO)];

        if (error) {
            reject(@"createTransaction", error.localizedDescription, error);
            return;
        }

        if (transaction.type == OPPTransactionTypeAsynchronous) {
            resolve(@{
                @"redirectURL": transaction.redirectURL.absoluteString ?: @"",
                @"status": @"pending",
                @"checkoutId": transaction.paymentParams.checkoutID
            });
        } else if (transaction.type == OPPTransactionTypeSynchronous) {
            resolve(@{
                @"status": @"completed",
                @"resourcePath": transaction.resourcePath ?: @"",
                @"checkoutId": transaction.paymentParams.checkoutID
            });
        } else {
            reject(@"createTransaction", @"Unknown transaction type", nil);
        }
    }];
}

RCT_EXPORT_METHOD(applePay:(NSDictionary*)params resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    _checkoutID = [params valueForKey:@"checkoutID"];
    if ([params valueForKey:@"companyName"]) {
        _companyName = [params valueForKey:@"companyName"];
    }

    PKPaymentRequest *request = [OPPPaymentProvider paymentRequestWithMerchantIdentifier:_merchantIdentifier
                                                                             countryCode:_countryCode];
    request.supportedNetworks = _supportedNetworks;
    request.merchantCapabilities = PKMerchantCapability3DS;
    request.currencyCode = [[NSLocale currentLocale] objectForKey:NSLocaleCurrencyCode] ?: @"USD";
    NSDecimalNumber *amount = [NSDecimalNumber decimalNumberWithMantissa:[[params valueForKey:@"amount"] intValue] exponent:-2 isNegative:NO];
    request.paymentSummaryItems = @[[PKPaymentSummaryItem summaryItemWithLabel:_companyName amount:amount]];

    _applePayResolve = resolve;
    _applePayReject = reject;
    PKPaymentAuthorizationViewController *vc = [[PKPaymentAuthorizationViewController alloc] initWithPaymentRequest:request];
    if (vc) {
        vc.delegate = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            UIViewController *rootViewController = UIApplication.sharedApplication.keyWindow.rootViewController;
            [rootViewController presentViewController:vc animated:YES completion:nil];
        });
    } else {
        reject(@"applePay", @"Apple Pay is not available", nil);
    }
}

- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
                       didAuthorizePayment:(PKPayment *)payment
                                completion:(void (^)(PKPaymentAuthorizationStatus))completion {
    [self sendEventWithName:@"onProgress" body:@(YES)];
    NSError *error;
    OPPApplePayPaymentParams *params = [[OPPApplePayPaymentParams alloc] initWithCheckoutID:_checkoutID
                                                                                 tokenData:payment.token.paymentData
                                                                                     error:&error];
    if (params) {
        OPPTransaction *transaction = [OPPTransaction transactionWithPaymentParams:params];
        __weak HyperPay *weakSelf = self;
        [self.provider submitTransaction:transaction completionHandler:^(OPPTransaction * _Nonnull transaction, NSError * _Nullable error) {
            __strong HyperPay *strongSelf = weakSelf;
            [strongSelf sendEventWithName:@"onProgress" body:@(NO)];
            if (error) {
                if (strongSelf.applePayResolve) {
                    strongSelf.applePayReject(@"applePay", error.localizedDescription, error);
                    strongSelf.applePayResolve = nil;
                    strongSelf.applePayReject = nil;
                }
                completion(PKPaymentAuthorizationStatusFailure);
                return;
            }
            if (strongSelf.applePayResolve) {
                if (transaction.redirectURL) {
                    strongSelf.applePayResolve(@{@"redirectURL": transaction.redirectURL.absoluteString});
                } else {
                    strongSelf.applePayResolve(@{@"resourcePath": transaction.resourcePath});
                }
                strongSelf.applePayResolve = nil;
                strongSelf.applePayReject = nil;
            }
            completion(PKPaymentAuthorizationStatusSuccess);
        }];
    } else {
        [self sendEventWithName:@"onProgress" body:@(NO)];
        if (self.applePayResolve) {
            self.applePayReject(@"applePay", error.localizedDescription, error);
            self.applePayResolve = nil;
            self.applePayReject = nil;
        }
        completion(PKPaymentAuthorizationStatusFailure);
    }
}

- (void)paymentAuthorizationViewControllerDidFinish:(PKPaymentAuthorizationViewController *)controller {
    __weak HyperPay *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong HyperPay *strongSelf = weakSelf;
        [controller dismissViewControllerAnimated:YES completion:nil];
        if (strongSelf.applePayResolve) {
            strongSelf.applePayReject(@"applePay", @"User cancelled", nil);
            strongSelf.applePayResolve = nil;
            strongSelf.applePayReject = nil;
        }
    });
}

RCT_EXPORT_METHOD(requestCheckoutInfo:(NSString*)checkoutID resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    [_provider requestCheckoutInfoWithCheckoutID:checkoutID completionHandler:^(OPPCheckoutInfo * _Nullable checkoutInfo, NSError * _Nullable error) {
        if (error) {
            reject(@"requestCheckoutInfo", error.localizedDescription, error);
            return;
        }
        resolve([self checkoutInfoToDictionary:checkoutInfo]);
    }];
}

RCT_EXPORT_METHOD(requestCheckoutData:(NSString*)checkoutID resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    [_provider requestCheckoutDataWithCheckoutID:checkoutID completionHandler:^(OPPCheckoutData * _Nullable checkoutData, NSError * _Nullable error) {
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
    [_provider securityWarningsWithCompletionHandler:^(NSArray<Warning *> * _Nullable warnings, NSError * _Nullable error) {
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
    [_provider requestValidationsForPaymentBrands:brands checkoutID:checkoutID completionHandler:^(NSArray<OPPBrandInfo *> * _Nullable brandRules, NSError * _Nullable error) {
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
    [_provider requestLogoURLsForPaymentBrands:brands completionHandler:^(NSDictionary<NSString *,NSURL *> * _Nullable URLs, NSError * _Nullable error) {
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
    [_provider requestBinInfoWithCheckoutID:checkoutID bin:bin completionHandler:^(OPPBinInfo * _Nullable binInfo, NSError * _Nullable error) {
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

#pragma mark - Helpers

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
        case SeverityLOW:    return @"LOW";
        case SeverityMEDIUM: return @"MEDIUM";
        case SeverityHIGH:   return @"HIGH";
        default:             return @"UNKNOWN";
    }
}

- (NSString *)msdkUiTypeToString:(OPPMsdkUiType)msdkUiType {
    switch (msdkUiType) {
        case OPPMsdkUiTypeNative: return @"NATIVE";
        case OPPMsdkUiTypeHybrid: return @"HYBRID";
        default:                  return @"UNKNOWN";
    }
}

@end
