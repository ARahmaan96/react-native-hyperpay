# react-native-hyperpay

React Native payment SDK for Hyperpay / OP-Payment services using **OPPWA Mobile SDK v7.11.0**. Supports credit/debit cards, Apple Pay, bank transfers, and virtual/alternative payment methods across iOS and Android.

## Installation

```sh
npm install react-native-hyperpay
```

<details>
<summary><strong>iOS additional setup</strong></summary>

1. Run `pod install` in the `ios/` directory:
   ```sh
   cd ios && pod install
   ```

2. Add the required URL schemes to `Info.plist`:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>YOUR_APP_SCHEME</string>
       </array>
     </dict>
   </array>
   <key>LSApplicationQueriesSchemes</key>
   <array>
     <string>com.oppwa.mobile</string>
     <string>itms-apps</string>
   </array>
   ```

3. Enable Apple Pay capability in Xcode and add your merchant identifier.

**Note:** Minimum iOS deployment target must be **12.0** or higher.
</details>

<details>
<summary><strong>Android additional setup</strong></summary>

1. Use the OPPWA Android callback URL as your Android `shopperResultURL`:
   ```ts
   shopperResultURL: 'oppwacheckout://YOUR_ANDROID_APPLICATION_ID.result'
   ```

   Example for application id `com.example.app`:
   ```ts
   shopperResultURL: 'oppwacheckout://com.example.app.result'
   ```

   The OPPWA Android SDK already contributes the required callback activity through manifest merging. Do not add `com.hyperpay.activities.PaymentActivity`; this package does not provide that activity.

2. Make sure the exact Android callback URL is whitelisted/used when creating the checkout on your backend.
</details>

## Quick Start

```ts
import HyperPay, { useTransactionLoading } from 'react-native-hyperpay';

// 1. Initialize the SDK
HyperPay.init({
  shopperResultURL: 'myapp://result',
  countryCode: 'SA',
  merchantIdentifier: 'merchant.com.example', // Apple Pay only
  mode: 'TestMode', // or 'LiveMode'
});

// 2. Create a checkout ID on your backend via Hyperpay/OPP API
// Then use it in the SDK:

// Apple Pay
const appleResult = await HyperPay.applePay({
  checkoutID: 'CHECKOUT_ID',
});

// Card payment
const cardResult = await HyperPay.createPaymentTransaction({
  paymentBrand: 'VISA',
  holderName: 'John Doe',
  cardNumber: '4111111111111111',
  expiryYear: '2027',
  expiryMonth: '12',
  cvv: '123',
  checkoutID: 'CHECKOUT_ID',
  shopperResultURL: 'myapp://result',
});

// 3. Check payment status
const status = HyperPay.getPaymentStatus('000.000.000');
// { code: '000.000.000', description: 'Transaction succeeded', status: 'successfully' }
```

## API Reference

### `HyperPay.init(config)`

Initializes the SDK with global configuration. Should be called once at app startup.

| Param | Type | Required | Description |
|---|---|---|---|
| `shopperResultURL` | `string` | Yes | URL scheme to redirect to after payment completes |
| `countryCode` | `keyof CountryCodes` | Only for Apple Pay | ISO alpha-2 country code (e.g. `'SA'`, `'AE'`, `'US'`) |
| `merchantIdentifier` | `string` | Only for Apple Pay | Apple Pay merchant identifier from your Apple Developer account |
| `mode` | `'TestMode' \| 'LiveMode'` | No | Defaults to `TestMode` |
| `companyName` | `string` | No | Prepended with "Pay " for Apple Pay sheet (e.g. "Pay Sportswear $100.00") |
| `supportedNetworks` | `SupportedNetworks[]` | No | Restrict Apple Pay to specific card networks (iOS only) |

```ts
HyperPay.init({
  shopperResultURL: 'myapp://payment',
  countryCode: 'SA',
  merchantIdentifier: 'merchant.com.example',
  mode: 'TestMode',
  companyName: 'Sportswear',
  supportedNetworks: ['mada', 'Visa', 'MasterCard'],
});
```

---

### `HyperPay.applePay(params, onProgress?)`

Initiates an Apple Pay transaction.

**Parameters**

| Param | Type | Required | Description |
|---|---|---|---|
| `params.checkoutID` | `string` | Yes | Checkout ID from Hyperpay OPP API |
| `params.companyName` | `string` | No | Overrides the company name set in `init()` |
| `params.amount` | `string` | No | Overrides the amount in the Apple Pay sheet |
| `onProgress` | `(isProgress: boolean) => void` | No | Callback fired when loading starts (`true`) and ends (`false`) |

**Returns**: `Promise<ApplePayCallback>`

```ts
type ApplePayCallback = {
  redirectURL?: string;
  resourcePath?: string;
};
```

```ts
const { redirectURL, resourcePath } = await HyperPay.applePay(
  { checkoutID: 'CHECKOUT_ID' },
  (loading) => console.log('Apple Pay loading:', loading)
);
```

---

### `HyperPay.createPaymentTransaction(params, onProgress?)`

Processes a card payment.

**Parameters**

| Param | Type | Required | Description |
|---|---|---|---|
| `params.paymentBrand` | `CardAccountBrands` | Yes | Card brand (e.g. `'VISA'`, `'MASTER'`, `'MADA'`) |
| `params.holderName` | `string` | Yes | Cardholder name |
| `params.cardNumber` | `string` | Yes | Card number |
| `params.expiryYear` | `string` | Yes | Expiry year (e.g. `'2027'`) |
| `params.expiryMonth` | `string` | Yes | Expiry month (e.g. `'12'`) |
| `params.cvv` | `string` | Yes | CVV/CVC code |
| `params.checkoutID` | `string` | Yes | Checkout ID from Hyperpay OPP API |
| `params.shopperResultURL` | `string` | No | Overrides the shopper result URL set in `init()` |
| `onProgress` | `(isProgress: boolean) => void` | No | Callback fired when loading starts (`true`) and ends (`false`) |

**Returns**: `Promise<CreateTransactionResponseType>`

```ts
type CreateTransactionResponseType = {
  status: 'pending' | 'rejected' | 'risk' | 'chargeback' | 'declines' | 'successfully';
  checkoutId: string;
  redirectURL: string;
};
```

```ts
const result = await HyperPay.createPaymentTransaction(
  {
    paymentBrand: 'VISA',
    holderName: 'John Doe',
    cardNumber: '4111111111111111',
    expiryYear: '2027',
    expiryMonth: '12',
    cvv: '123',
    checkoutID: 'CHECKOUT_ID',
  },
  (loading) => setLoading(loading)
);
```

---

### `HyperPay.getPaymentStatus(code)`

Looks up a Hyperpay result code and returns a human-readable description and status category.

| Param | Type | Required | Description |
|---|---|---|---|
| `code` | `string` | Yes | Result code (e.g. `'000.000.000'`) |

**Returns**: `PaymentStatus`

```ts
type PaymentStatus = {
  code: string;
  description: string;
  status: 'successfully' | 'rejected' | 'Chargeback' | 'pending' | 'error';
};
```

```ts
const status = HyperPay.getPaymentStatus('000.000.000');
// { code: '000.000.000', description: 'Transaction succeeded', status: 'successfully' }
```

---

### `useTransactionLoading()`

React hook that returns the current transaction loading state by subscribing to the internal `onProgress` event.

```tsx
import { useTransactionLoading } from 'react-native-hyperpay';

function PaymentScreen() {
  const loading = useTransactionLoading();

  return <ActivityIndicator animating={loading} />;
}
```

## Type Reference

### `Config`

```ts
interface Config {
  shopperResultURL: string;
  countryCode?: keyof CountryCodes;
  merchantIdentifier?: string;
  mode?: 'TestMode' | 'LiveMode';
  companyName?: string;
  supportedNetworks?: Array<SupportedNetworks>;
}
```

### `CardAccountBrands`

Card brands accepted by `createPaymentTransaction`:

```
AMEX | APPLEPAY | CARTEBANCAIRE | DINERS | DISCOVER | ELO | GOOGLEPAY |
JCB | MADA | MAESTRO | MASTER | MEEZA | VISA | VISAELECTRON | VPAY |
-- and more (40+ brands)
```

### `BankAccountBrands`

Bank transfer / online banking brands:

```
BITCOIN | BOLETO | DIRECTDEBIT_SEPA | GIROPAY | IDEAL |
INTERAC_ONLINE | OXXO | POLI | PREPAYMENT | SOFORTUEBERWEISUNG | TRUSTPAY_VA
```

### `VirtualAccountBrands`

Alternative payment methods (92+ brands):

```
AFTERPAY | ALIPAY | BANCONTACT | KLARNA | PAYPAL | SEPA_DIRECT_DEBIT |
STC_PAY | TABBY | TAMARA | TRUSTLY | WECHATPAY | -- and more
```

### `SupportedNetworks`

Apple Pay supported network identifiers:

```
mada | Visa | MasterCard | AmEx | Mada | JCB | Elo | Discover | Maestro |
ChinaUnionPay | CarteBancaires | Interac | Electron | girocard | -- and more
```

## Payment Result Codes

The SDK includes a comprehensive database of Hyperpay result codes. Use `getPaymentStatus()` to look up any code. Codes are categorized into groups for easier handling:

| Status | Example Code | Meaning |
|---|---|---|
| `successfully` | `000.000.000` | Transaction succeeded |
| `pending` | `000.200.000` | Transaction pending |
| `rejected` | `800.100.150` | Various rejection reasons |
| `Chargeback` | `000.100.201` | Chargeback initiated |
| `error` | (unmatched) | Invalid or unknown code |

See full documentation at [Hyperpay Result Codes](https://docs.oppwa.com/tutorials/result-codes).

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT
