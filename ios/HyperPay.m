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
    _shopperResultURL = [self stringFromValue:[options valueForKey:@"shopperResultURL"]] ?: @"";
    _merchantIdentifier = [self stringFromValue:[options valueForKey:@"merchantIdentifier"]] ?: @"";
    _companyName = [self stringFromValue:[options valueForKey:@"companyName"]] ?: @"";
    _countryCode = [self stringFromValue:[options valueForKey:@"countryCode"]] ?: @"";

    id supportedNetworks = [options valueForKey:@"supportedNetworks"];
    _supportedNetworks = [supportedNetworks isKindOfClass:[NSArray class]] ? supportedNetworks : @[];

    NSString *newMode = [self stringFromValue:[options valueForKey:@"mode"]];
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
    if (![_checkoutID isKindOfClass:[NSString class]] || _checkoutID.length == 0) {
        reject(@"applePay", @"checkoutID is required", nil);
        return;
    }

    NSString *companyName = [self stringFromValue:[params valueForKey:@"companyName"]];
    if (companyName) {
        _companyName = companyName;
    }

    [_provider requestCheckoutDataWithCheckoutID:_checkoutID completionHandler:^(OPPCheckoutData * _Nullable checkoutData, NSError * _Nullable error) {
        if (error) {
            reject(@"applePay", error.localizedDescription ?: @"Unable to load Apple Pay checkout data", error);
            return;
        }

        NSDecimalNumber *amount = [self decimalAmountFromValue:[params valueForKey:@"amount"]] ?: [self decimalAmountFromValue:checkoutData.amount];
        if (!amount) {
            reject(@"applePay", @"Apple Pay amount is required", nil);
            return;
        }

        NSString *checkoutCurrency = [self stringFromValue:checkoutData.currency];
        if (checkoutCurrency.length == 0) {
            reject(@"applePay", @"Apple Pay currency is required", nil);
            return;
        }

        [self presentApplePayWithAmount:amount currencyCode:checkoutCurrency resolver:resolve rejecter:reject];
    }];
}

- (void)presentApplePayWithAmount:(NSDecimalNumber *)amount currencyCode:(NSString *)currencyCode resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject {
    if (_merchantIdentifier.length == 0) {
        reject(@"applePay", @"merchantIdentifier is required", nil);
        return;
    }

    if (_countryCode.length == 0) {
        reject(@"applePay", @"countryCode is required", nil);
        return;
    }

    if ([amount compare:[NSDecimalNumber zero]] != NSOrderedDescending) {
        reject(@"applePay", @"Apple Pay amount must be greater than zero", nil);
        return;
    }

    if (currencyCode.length == 0) {
        reject(@"applePay", @"Apple Pay currency is required", nil);
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            PKPaymentRequest *request = [OPPPaymentProvider paymentRequestWithMerchantIdentifier:_merchantIdentifier
                                                                                     countryCode:_countryCode];
            if (_supportedNetworks.count > 0) {
                request.supportedNetworks = _supportedNetworks;
            } else {
                request.supportedNetworks = @[PKPaymentNetworkVisa, PKPaymentNetworkMasterCard, PKPaymentNetworkAmex, PKPaymentNetworkDiscover];
            }
            request.merchantCapabilities = PKMerchantCapability3DS;
            request.currencyCode = currencyCode;
            NSString *summaryLabel = _companyName.length > 0 ? _companyName : @"Total";
            request.paymentSummaryItems = @[[PKPaymentSummaryItem summaryItemWithLabel:summaryLabel amount:amount]];

            PKPaymentAuthorizationViewController *vc = [[PKPaymentAuthorizationViewController alloc] initWithPaymentRequest:request];
            if (vc) {
                vc.delegate = self;
                UIViewController *rootViewController = [self currentViewController];
                if (!rootViewController) {
                    reject(@"applePay", @"Unable to present Apple Pay", nil);
                    return;
                }

                _applePayResolve = resolve;
                _applePayReject = reject;
                [rootViewController presentViewController:vc animated:YES completion:nil];
            } else {
                reject(@"applePay", @"Apple Pay is not available", nil);
            }
        } @catch (NSException *exception) {
            _applePayResolve = nil;
            _applePayReject = nil;
            reject(@"applePay", exception.reason ?: exception.name, nil);
        }
    });
}

- (UIViewController *)currentViewController {
    UIWindow *keyWindow = UIApplication.sharedApplication.keyWindow;

    if (!keyWindow) {
        if (@available(iOS 13.0, *)) {
            for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
                if (scene.activationState != UISceneActivationStateForegroundActive || ![scene isKindOfClass:[UIWindowScene class]]) {
                    continue;
                }

                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *window in windowScene.windows) {
                    if (window.isKeyWindow) {
                        keyWindow = window;
                        break;
                    }
                }

                if (keyWindow) {
                    break;
                }
            }
        }
    }

    UIViewController *viewController = keyWindow.rootViewController;
    while (viewController.presentedViewController) {
        viewController = viewController.presentedViewController;
    }

    return viewController;
}

- (NSString *)stringFromValue:(id)value {
    if ([value isKindOfClass:[NSString class]]) {
        return value;
    }

    return nil;
}

- (NSDecimalNumber *)decimalAmountFromValue:(id)value {
    if (!value || value == [NSNull null]) {
        return nil;
    }

    NSDecimalNumber *amount = nil;
    if ([value isKindOfClass:[NSDecimalNumber class]]) {
        amount = value;
    } else if ([value isKindOfClass:[NSNumber class]]) {
        amount = [NSDecimalNumber decimalNumberWithDecimal:[value decimalValue]];
    } else if ([value isKindOfClass:[NSString class]]) {
        NSString *trimmedValue = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmedValue.length == 0) {
            return nil;
        }
        amount = [NSDecimalNumber decimalNumberWithString:trimmedValue];
    }

    if (!amount || [amount isEqualToNumber:[NSDecimalNumber notANumber]]) {
        return nil;
    }

    return amount;
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
        params.shopperResultURL = _shopperResultURL;
        OPPTransaction *transaction = [OPPTransaction transactionWithPaymentParams:params];
        __weak HyperPay *weakSelf = self;
        [self.provider submitTransaction:transaction completionHandler:^(OPPTransaction * _Nonnull transaction, NSError * _Nullable error) {
            __strong HyperPay *strongSelf = weakSelf;
            [strongSelf sendEventWithName:@"onProgress" body:@(NO)];
            if (error) {
                if (strongSelf.applePayResolve) {
                    strongSelf.applePayReject(@"applePay", error.localizedDescription ?: @"Apple Pay transaction failed", error);
                    strongSelf.applePayResolve = nil;
                    strongSelf.applePayReject = nil;
                }
                completion(PKPaymentAuthorizationStatusFailure);
                return;
            }
            if (strongSelf.applePayResolve) {
                if (transaction.redirectURL) {
                    strongSelf.applePayResolve(@{@"redirectURL": transaction.redirectURL.absoluteString});
                } else if (transaction.resourcePath) {
                    strongSelf.applePayResolve(@{@"resourcePath": transaction.resourcePath});
                } else {
                    strongSelf.applePayResolve(@{});
                }
                strongSelf.applePayResolve = nil;
                strongSelf.applePayReject = nil;
            }
            completion(PKPaymentAuthorizationStatusSuccess);
        }];
    } else {
        [self sendEventWithName:@"onProgress" body:@(NO)];
        if (self.applePayResolve) {
            self.applePayReject(@"applePay", error.localizedDescription ?: @"Invalid Apple Pay payment data", error);
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
