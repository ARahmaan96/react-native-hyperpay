package com.reactnativehyperpay;

import android.app.Activity;
import android.util.Log;

import androidx.annotation.NonNull;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.module.annotations.ReactModule;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.nsoftware.ipworks3ds.sdk.Warning;
import com.oppwa.mobile.connect.payment.BrandInfo;
import com.oppwa.mobile.connect.exception.PaymentError;
import com.oppwa.mobile.connect.exception.PaymentException;
import com.oppwa.mobile.connect.payment.BrandsValidation;
import com.oppwa.mobile.connect.payment.CheckoutData;
import com.oppwa.mobile.connect.payment.CheckoutInfo;
import com.oppwa.mobile.connect.payment.ImageDetail;
import com.oppwa.mobile.connect.payment.ImagesRequest;
import com.oppwa.mobile.connect.payment.PaymentParams;
import com.oppwa.mobile.connect.payment.card.CardPaymentParams;
import com.oppwa.mobile.connect.provider.Connect;
import com.oppwa.mobile.connect.provider.ITransactionListener;
import com.oppwa.mobile.connect.provider.OppPaymentProvider;
import com.oppwa.mobile.connect.provider.ThreeDSWorkflowListener;
import com.oppwa.mobile.connect.provider.threeds.v2.model.ThreeDSConfig;
import com.oppwa.mobile.connect.provider.Transaction;
import com.oppwa.mobile.connect.provider.TransactionType;
import com.oppwa.mobile.connect.provider.listener.BinInfoListener;
import com.oppwa.mobile.connect.provider.listener.ResponseListener;
import com.oppwa.mobile.connect.provider.model.BinInfo;

import java.util.List;
import java.util.Map;

@ReactModule(name = HyperPayModule.NAME)
public class HyperPayModule extends ReactContextBaseJavaModule implements ITransactionListener {
    public static final String NAME = "HyperPay";

    private Promise promisePaymentTransaction;
    private String shopperResultURL;
    private String merchantIdentifier;
    private String countryCode;
    private String mode;

    public HyperPayModule(ReactApplicationContext reactContext) {
        super(reactContext);
    }

    @Override
    @NonNull
    public String getName() {
        return NAME;
    }

    @ReactMethod(isBlockingSynchronousMethod = true)
    public WritableMap setup(ReadableMap params) {
        WritableMap config = Arguments.createMap();
        if (params.hasKey("shopperResultURL") && !params.isNull("shopperResultURL"))
            shopperResultURL = params.getString("shopperResultURL");
        shopperResultURL = getAndroidShopperResultURL(shopperResultURL);
        if (params.hasKey("merchantIdentifier"))
            merchantIdentifier = params.getString("merchantIdentifier");
        if (params.hasKey("countryCode"))
            countryCode = params.getString("countryCode");
        if (params.hasKey("mode"))
            mode = params.getString("mode");
        config.putString("shopperResultURL", shopperResultURL);
        config.putString("merchantIdentifier", merchantIdentifier);
        config.putString("countryCode", countryCode);
        config.putString("mode", mode);
        return config;
    }

    @ReactMethod
    public void createPaymentTransaction(ReadableMap params, Promise promise) {
        promisePaymentTransaction = promise;
        this.emitListeners("onProgress", true);

        try {
            CardPaymentParams paymentParams = new CardPaymentParams(
                    params.getString("checkoutID"),
                    params.getString("paymentBrand"),
                    params.getString("cardNumber"),
                    params.getString("holderName"),
                    params.getString("expiryMonth"),
                    params.getString("expiryYear"),
                    params.getString("cvv"));

            if (params.hasKey("shopperResultURL") && !params.isNull("shopperResultURL")) {
                shopperResultURL = params.getString("shopperResultURL");
            }
            shopperResultURL = getAndroidShopperResultURL(shopperResultURL);
            if (!isNullOrEmpty(shopperResultURL)) {
                paymentParams.setShopperResultUrl(shopperResultURL);
            }

            Activity currentActivity = getCurrentActivity();
            if (currentActivity == null) {
                this.emitListeners("onProgress", false);
                promisePaymentTransaction.reject("NO_ACTIVITY", "No foreground activity available");
                return;
            }

            Connect.ProviderMode providerMode = "LiveMode".equals(mode)
                    ? Connect.ProviderMode.LIVE
                    : Connect.ProviderMode.TEST;
            OppPaymentProvider paymentProvider = new OppPaymentProvider(currentActivity, providerMode);
            paymentProvider.setThreeDSWorkflowListener(createThreeDSWorkflowListener());

            Transaction transaction = new Transaction(paymentParams);
            paymentProvider.submitTransaction(transaction, this);
        } catch (PaymentException e) {
            this.emitListeners("onProgress", false);
            promisePaymentTransaction.reject(e);
        }
    }

    @ReactMethod
    public void requestCheckoutInfo(String checkoutID, Promise promise) {
        try {
            OppPaymentProvider paymentProvider = createPaymentProvider();
            paymentProvider.requestCheckoutInfo(checkoutID, new DefaultTransactionListener() {
                @Override
                public void paymentConfigRequestSucceeded(@NonNull CheckoutInfo checkoutInfo) {
                    promise.resolve(checkoutInfoToMap(checkoutInfo));
                }

                @Override
                public void paymentConfigRequestFailed(@NonNull PaymentError paymentError) {
                    rejectPaymentError(promise, paymentError);
                }
            });
        } catch (PaymentException e) {
            promise.reject(e);
        }
    }

    @ReactMethod
    public void requestCheckoutData(String checkoutID, Promise promise) {
        try {
            OppPaymentProvider paymentProvider = createPaymentProvider();
            paymentProvider.requestCheckoutData(checkoutID, new ResponseListener<CheckoutData>() {
                @Override
                public void onResult(CheckoutData checkoutData, PaymentError paymentError) {
                    if (paymentError != null) {
                        rejectPaymentError(promise, paymentError);
                        return;
                    }
                    WritableMap result = Arguments.createMap();
                    result.putString("amount", checkoutData.getAmount());
                    result.putString("currency", checkoutData.getCurrency());
                    result.putString("taxAmount", checkoutData.getTaxAmount());
                    result.putString("merchantTransactionId", checkoutData.getMerchantTransactionId());
                    promise.resolve(result);
                }
            });
        } catch (PaymentException e) {
            promise.reject(e);
        }
    }

    @ReactMethod
    public void getThreeDS2Warnings(Promise promise) {
        try {
            OppPaymentProvider paymentProvider = createPaymentProvider();
            List<Warning> warnings = paymentProvider.getThreeDS2Warnings();
            WritableArray result = Arguments.createArray();
            for (Warning warning : warnings) {
                WritableMap warningMap = Arguments.createMap();
                warningMap.putString("id", warning.getID());
                warningMap.putString("message", warning.getMessage());
                warningMap.putString("severity", String.valueOf(warning.getSeverity()));
                result.pushMap(warningMap);
            }
            promise.resolve(result);
        } catch (PaymentException e) {
            promise.reject(e);
        }
    }

    @ReactMethod
    public void validateBrands(String checkoutID, ReadableArray brands, Promise promise) {
        try {
            OppPaymentProvider paymentProvider = createPaymentProvider();
            paymentProvider.requestBrandsValidation(checkoutID, readableArrayToStringArray(brands), new DefaultTransactionListener() {
                @Override
                public void brandsValidationRequestSucceeded(@NonNull BrandsValidation brandsValidation) {
                    WritableMap result = Arguments.createMap();
                    WritableArray brandList = Arguments.createArray();
                    for (Map.Entry<String, BrandInfo> entry : brandsValidation.getBrandInfoMap().entrySet()) {
                        BrandInfo brandInfo = entry.getValue();
                        WritableMap brandMap = Arguments.createMap();
                        brandMap.putString("brand", brandInfo.getBrand());
                        brandMap.putString("label", brandInfo.getLabel());
                        brandMap.putString("renderType", brandInfo.getRenderType());
                        brandMap.putBoolean("isCardBrand", brandInfo.isCardBrand());
                        brandMap.putBoolean("isCustomUiRequired", brandInfo.isCustomUiRequired());
                        brandList.pushMap(brandMap);
                    }
                    result.putArray("brands", brandList);
                    promise.resolve(result);
                }

                @Override
                public void brandsValidationRequestFailed(@NonNull PaymentError paymentError) {
                    rejectPaymentError(promise, paymentError);
                }
            });
        } catch (PaymentException e) {
            promise.reject(e);
        }
    }

    @ReactMethod
    public void requestImages(ReadableArray brands, Promise promise) {
        try {
            OppPaymentProvider paymentProvider = createPaymentProvider();
            paymentProvider.requestImages(readableArrayToStringArray(brands), new DefaultTransactionListener() {
                @Override
                public void imagesRequestSucceeded(@NonNull ImagesRequest imagesRequest) {
                    WritableMap result = Arguments.createMap();
                    for (Map.Entry<String, ImageDetail> entry : imagesRequest.getImagesRequestMap().entrySet()) {
                        ImageDetail detail = entry.getValue();
                        WritableMap imageMap = Arguments.createMap();
                        imageMap.putString("type", detail.getType());
                        imageMap.putString("width", detail.getWidth());
                        imageMap.putString("height", detail.getHeight());
                        imageMap.putString("url", detail.getUrl());
                        imageMap.putString("content", detail.getContent());
                        result.putMap(entry.getKey(), imageMap);
                    }
                    promise.resolve(result);
                }

                @Override
                public void imagesRequestFailed() {
                    promise.reject("IMAGES_REQUEST_FAILED", "Images request failed");
                }
            });
        } catch (PaymentException e) {
            promise.reject(e);
        }
    }

    @ReactMethod
    public void requestBinInfo(String checkoutID, String bin, Promise promise) {
        OppPaymentProvider paymentProvider;
        try {
            paymentProvider = createPaymentProvider();
        } catch (PaymentException e) {
            promise.reject(e);
            return;
        }
        paymentProvider.requestBinInfo(checkoutID, bin, new BinInfoListener() {
            @Override
            public void onResult(BinInfo binInfo, PaymentError paymentError) {
                if (paymentError != null) {
                    rejectPaymentError(promise, paymentError);
                    return;
                }
                WritableMap result = Arguments.createMap();
                result.putArray("brands", stringArrayToWritableArray(binInfo.getBrands()));
                result.putString("binType", binInfo.getBinType());
                result.putString("type", binInfo.getType());
                promise.resolve(result);
            }
        });
    }

    private void emitListeners(String eventName, boolean isLoading) {
        getReactApplicationContext()
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit("onProgress", isLoading);
    }

    private OppPaymentProvider createPaymentProvider() throws PaymentException {
        Activity currentActivity = getCurrentActivity();
        if (currentActivity == null) {
            throw new PaymentException(PaymentError.getUnexpectedExceptionError(
                    new IllegalStateException("No foreground activity available")));
        }
        Connect.ProviderMode providerMode = "LiveMode".equals(mode)
                ? Connect.ProviderMode.LIVE
                : Connect.ProviderMode.TEST;
        OppPaymentProvider paymentProvider = new OppPaymentProvider(currentActivity, providerMode);
        paymentProvider.setThreeDSWorkflowListener(createThreeDSWorkflowListener());
        return paymentProvider;
    }

    private void emitThreeDSChallenge(boolean isActive) {
        getReactApplicationContext()
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit("onThreeDSChallenge", isActive);
    }

    private ThreeDSWorkflowListener createThreeDSWorkflowListener() {
        return new ThreeDSWorkflowListener() {
            @Override
            public Activity onThreeDSChallengeRequired() {
                emitThreeDSChallenge(true);
                return getCurrentActivity();
            }

            @Override
            public ThreeDSConfig onThreeDSConfigRequired() {
                ThreeDSConfig.Builder builder = new ThreeDSConfig.Builder();
                if (countryCode != null && !countryCode.isEmpty()) {
                    builder.addClientConfigParam("OverrideCountryCode", countryCode);
                }
                builder.addClientConfigParam("AcceptAnyACSCert", "true");
                return builder.build();
            }
        };
    }

    private WritableMap checkoutInfoToMap(CheckoutInfo checkoutInfo) {
        WritableMap result = Arguments.createMap();
        result.putString("endpoint", checkoutInfo.getEndpoint());
        result.putString("resourcePath", checkoutInfo.getResourcePath());
        result.putDouble("amount", checkoutInfo.getAmount());
        result.putString("currencyCode", checkoutInfo.getCurrencyCode());
        result.putString("countryCode", checkoutInfo.getCountryCode());
        result.putBoolean("shopBrandsOverridden", checkoutInfo.isShopBrandsOverridden());
        result.putBoolean("brandsActivated", checkoutInfo.isBrandsActivated());
        result.putBoolean("collectRedShieldDeviceId", checkoutInfo.isCollectRedShieldDeviceId());
        result.putBoolean("visaInstallmentEnabled", checkoutInfo.isVisaInstallmentEnabled());
        result.putString("logLevel", checkoutInfo.getLogLevel());
        result.putString("msdkUi", checkoutInfo.getMsdkUi() != null ? checkoutInfo.getMsdkUi().name() : null);
        result.putArray("brands", stringArrayToWritableArray(checkoutInfo.getBrands()));
        result.putArray("klarnaMerchantIds", stringArrayToWritableArray(checkoutInfo.getKlarnaMerchantIds()));
        return result;
    }

    private String[] readableArrayToStringArray(ReadableArray readableArray) {
        String[] values = new String[readableArray.size()];
        for (int i = 0; i < readableArray.size(); i++) {
            values[i] = readableArray.getString(i);
        }
        return values;
    }

    private WritableArray stringArrayToWritableArray(String[] values) {
        WritableArray result = Arguments.createArray();
        if (values == null) {
            return result;
        }
        for (String value : values) {
            result.pushString(value);
        }
        return result;
    }

    private void rejectPaymentError(Promise promise, PaymentError paymentError) {
        promise.reject("PAYMENT_ERROR", paymentError.getErrorInfo());
    }

    private abstract class DefaultTransactionListener implements ITransactionListener {
        @Override
        public void transactionCompleted(@NonNull Transaction transaction) {
        }

        @Override
        public void transactionFailed(@NonNull Transaction transaction, @NonNull PaymentError paymentError) {
        }
    }

    private String getDefaultShopperResultURL() {
        return "oppwacheckout://" + getReactApplicationContext().getPackageName() + ".result";
    }

    private String getAndroidShopperResultURL(String value) {
        if (isNullOrEmpty(value) || value.startsWith("http://") || value.startsWith("https://")) {
            return getDefaultShopperResultURL();
        }
        return value;
    }

    private boolean isNullOrEmpty(String value) {
        return value == null || value.isEmpty();
    }

    @Override
    public void transactionCompleted(@NonNull Transaction transaction) {
        this.emitListeners("onProgress", false);
        this.emitThreeDSChallenge(false);

        WritableMap paymentResponse = Arguments.createMap();
        paymentResponse.putString("checkoutId", transaction.getPaymentParams().getCheckoutId());

        if (transaction.getTransactionType() == TransactionType.SYNC) {
            paymentResponse.putString("status", "completed");
        } else {
            paymentResponse.putString("status", "pending");
            paymentResponse.putString("redirectURL", transaction.getRedirectUrl());
        }

        if (promisePaymentTransaction != null) {
            promisePaymentTransaction.resolve(paymentResponse);
            promisePaymentTransaction = null;
        }
    }

    @Override
    public void transactionFailed(@NonNull Transaction transaction, @NonNull PaymentError paymentError) {
        this.emitListeners("onProgress", false);
        this.emitThreeDSChallenge(false);
        if (promisePaymentTransaction != null) {
            promisePaymentTransaction.reject(paymentError.getErrorInfo());
            promisePaymentTransaction = null;
        }
    }

    @Override
    public void brandsValidationRequestSucceeded(@NonNull BrandsValidation brandsValidation) {
        ITransactionListener.super.brandsValidationRequestSucceeded(brandsValidation);
    }

    @Override
    public void brandsValidationRequestFailed(@NonNull PaymentError paymentError) {
        ITransactionListener.super.brandsValidationRequestFailed(paymentError);
    }

    @Override
    public void paymentConfigRequestSucceeded(@NonNull CheckoutInfo checkoutInfo) {
        Log.d("paymentCond", checkoutInfo.getResourcePath());
        ITransactionListener.super.paymentConfigRequestSucceeded(checkoutInfo);
    }

    @Override
    public void paymentConfigRequestFailed(@NonNull PaymentError paymentError) {
        ITransactionListener.super.paymentConfigRequestFailed(paymentError);
    }

    @Override
    public void imagesRequestSucceeded(@NonNull ImagesRequest imagesRequest) {
        ITransactionListener.super.imagesRequestSucceeded(imagesRequest);
    }

    @Override
    public void imagesRequestFailed() {
        ITransactionListener.super.imagesRequestFailed();
    }

    @Override
    public void binRequestSucceeded(@NonNull String[] strings) {
        ITransactionListener.super.binRequestSucceeded(strings);
    }

    @Override
    public void binRequestFailed() {
        ITransactionListener.super.binRequestFailed();
    }
}
