import { NativeModules, Platform } from 'react-native';
import { getPaymentStatus } from './paymentStatus'

const LINKING_ERROR =
  `The package 'react-native-hyperpay' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo managed workflow\n';

const HyperPaySDK = NativeModules.HyperPay
  ? NativeModules.HyperPay
  : new Proxy(
    {},
    {
      get() {
        throw new Error(LINKING_ERROR);
      },
    }
  );
export function init(params) {
  return HyperPaySDK.setup(params);
}

export function createPaymentTransaction(params) {
  return HyperPaySDK.createPaymentTransaction(params);
}

export function applePay(checkoutID) {
  return HyperPaySDK.applePay(checkoutID);
}

export function requestCheckoutInfo(checkoutID) {
  return HyperPaySDK.requestCheckoutInfo(checkoutID);
}

export function requestCheckoutData(checkoutID) {
  return HyperPaySDK.requestCheckoutData(checkoutID);
}

export function getThreeDS2Warnings() {
  return HyperPaySDK.getThreeDS2Warnings();
}

export function validateBrands(checkoutID, brands) {
  return HyperPaySDK.validateBrands(checkoutID, brands);
}

export function requestImages(brands) {
  return HyperPaySDK.requestImages(brands);
}

export function requestBinInfo(checkoutID, bin) {
  return HyperPaySDK.requestBinInfo(checkoutID, bin);
}

const Hyperpay = {
  init,
  applePay,
  createPaymentTransaction,
  requestCheckoutInfo,
  requestCheckoutData,
  getThreeDS2Warnings,
  validateBrands,
  requestImages,
  requestBinInfo,
  getPaymentStatus
}

export default Hyperpay
