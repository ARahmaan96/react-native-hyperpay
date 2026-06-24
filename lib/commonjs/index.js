"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.applePay = applePay;
exports.createPaymentTransaction = createPaymentTransaction;
exports.default = void 0;
exports.getThreeDS2Warnings = getThreeDS2Warnings;
exports.init = init;
exports.requestBinInfo = requestBinInfo;
exports.requestCheckoutData = requestCheckoutData;
exports.requestCheckoutInfo = requestCheckoutInfo;
exports.requestImages = requestImages;
exports.validateBrands = validateBrands;

var _reactNative = require("react-native");

const LINKING_ERROR = `The package 'react-native-hyperpay' doesn't seem to be linked. Make sure: \n\n` + _reactNative.Platform.select({
  ios: "- You have run 'pod install'\n",
  default: ''
}) + '- You rebuilt the app after installing the package\n' + '- You are not using Expo managed workflow\n';
const HyperPaySDK = _reactNative.NativeModules.HyperPay ? _reactNative.NativeModules.HyperPay : new Proxy({}, {
  get() {
    throw new Error(LINKING_ERROR);
  }

});

function init(params) {
  return HyperPaySDK.setup(params);
}

function createPaymentTransaction(params) {
  return HyperPaySDK.createPaymentTransaction(params);
}

function applePay(checkoutID) {
  return HyperPaySDK.applePay(checkoutID);
}

function requestCheckoutInfo(checkoutID) {
  return HyperPaySDK.requestCheckoutInfo(checkoutID);
}

function requestCheckoutData(checkoutID) {
  return HyperPaySDK.requestCheckoutData(checkoutID);
}

function getThreeDS2Warnings() {
  return HyperPaySDK.getThreeDS2Warnings();
}

function validateBrands(checkoutID, brands) {
  return HyperPaySDK.validateBrands(checkoutID, brands);
}

function requestImages(brands) {
  return HyperPaySDK.requestImages(brands);
}

function requestBinInfo(checkoutID, bin) {
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
  requestBinInfo
};
var _default = Hyperpay;
exports.default = _default;
