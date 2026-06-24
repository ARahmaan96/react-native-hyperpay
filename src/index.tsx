import type {
  CreateTransactionResponseType,
  CreateTransactionParams,
  Config,
  ApplyPayParams,
  CheckoutInfoResponse,
  CheckoutDataResponse,
  ThreeDS2Warning,
  BrandsValidationResponse,
  ImagesResponse,
  BinInfoResponse,
} from '../lib/typescript'
import {
  getPaymentStatus
} from './paymentStatus'
import type { ApplePayCallback } from '../'
import { HyperPaySDK, eventEmitter } from './utils';

export function init(params: Config): Config {
  return HyperPaySDK.setup(params);
}

export function createPaymentTransaction(params: CreateTransactionParams, onProgress?: (isProgress: boolean) => void):
  Promise<CreateTransactionResponseType> {
  if (onProgress) {
    eventEmitter.removeAllListeners("onProgress")
    const _event = eventEmitter.addListener('onProgress', (isLoading: boolean) => {
      onProgress(isLoading)
      if (!isLoading) _event.remove()
    });
  }
  return HyperPaySDK.createPaymentTransaction(params);
}



export function applePay(params: ApplyPayParams,
  onProgress?: (isProgress: boolean) => void): Promise<ApplePayCallback> {

  if (onProgress) {
    const _event = eventEmitter.addListener('onProgress', (isLoading: boolean) => {
      onProgress(isLoading)
      if (!isLoading) _event.remove()
    });
  }

  return HyperPaySDK.applePay(params);
}

export function requestCheckoutInfo(checkoutID: string): Promise<CheckoutInfoResponse> {
  return HyperPaySDK.requestCheckoutInfo(checkoutID);
}

export function requestCheckoutData(checkoutID: string): Promise<CheckoutDataResponse> {
  return HyperPaySDK.requestCheckoutData(checkoutID);
}

export function getThreeDS2Warnings(): Promise<ThreeDS2Warning[]> {
  return HyperPaySDK.getThreeDS2Warnings();
}

export function validateBrands(checkoutID: string, brands: string[]): Promise<BrandsValidationResponse> {
  return HyperPaySDK.validateBrands(checkoutID, brands);
}

export function requestImages(brands: string[]): Promise<ImagesResponse> {
  return HyperPaySDK.requestImages(brands);
}

export function requestBinInfo(checkoutID: string, bin: string): Promise<BinInfoResponse> {
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
  getPaymentStatus,
}
export {
  useTransactionLoading,
  useThreeDSChallenge,
} from './hooks'


export default Hyperpay
