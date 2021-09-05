library flutter_paymob;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart';

typedef CardCallBack = Future<bool> Function(String iFrameURL);
typedef WalletCallBack = Future<bool> Function(String redirectURL);

enum PayMobMode { card, wallet }

class FlutterPayMob {
  static FlutterPayMob _instance;

  static FlutterPayMob get instance {
    if (_instance == null) {
      _instance = FlutterPayMob();
    }
    return _instance;
  }

  Future<bool> init({
    @required PayMobMode mode,
    @required String apiToken,
    @required String price,
    @required String integrationId,
    @required List<ItemModel> items,
    @required BillingModel billingModel,
    @required CardModel cardModel,
    @required WalletModel walletModel,
  }) async {
    print('FlutterPayMob.init');
    print('mode $mode');
    print('apiToken $apiToken');
    print('integrationId $integrationId');
    print('price $price');
    print('items : ');
    items.forEach((e) {
      e.toJson.entries.forEach((e) {
        print('${e.key} ${e.value}');
      });
      print('\n');
    });
    print('billingModel.firstName ${billingModel.firstName}');
    print('billingModel.lastName ${billingModel.lastName}');
    print('billingModel.email ${billingModel.email}');
    print('billingModel.phone ${billingModel.phone}');
    try {
      final String authToken = await _authenticate(apiToken);
      print('authToken $authToken');
      final orderId = await _order(authToken, price, items);
      print('orderId $orderId');
      final payKey = await _request(authToken, price, orderId?.toString(), integrationId, billingModel);
      print('payKey $payKey');
      switch (mode) {
        case PayMobMode.card:
          if (cardModel == null) {
            return false;
          }
          return await _card(payKey, cardModel.iFrameID, cardModel.callBack);
        case PayMobMode.wallet:
          if (walletModel == null) {
            return false;
          }
          return await _wallet(payKey, walletModel.mobileNumber, walletModel.walletCallBack);
      }
      return false;
    } catch (e, s) {
      print('FlutterPayMob.ERROR');
      print(e);
      print(s);
      return false;
    }
  }

  Future<String> _authenticate(String apiToken) async {
    final f = await _call(
      'https://accept.paymob.com/api/auth/tokens',
      {
        'api_key': apiToken,
      },
    );
    return f['token'];
  }

  Future<dynamic> _order(
    String authToken,
    String price,
    List<ItemModel> items,
  ) async {
    final f = await _call(
      'https://accept.paymob.com/api/ecommerce/orders',
      {
        "auth_token": authToken,
        "delivery_needed": "false",
        "amount_cents": price?.convertCents,
        "currency": "EGP",
        "items": items.map((e) => e.toJson).toList(),
      },
    );
    return f['id'];
  }

  Future<String> _request(
    String authToken,
    String price,
    String orderId,
    String integrationId,
    BillingModel billingModel,
  ) async {
    final f = await _call(
      'https://accept.paymob.com/api/acceptance/payment_keys',
      {
        "auth_token": authToken,
        "amount_cents": price?.convertCents,
        "expiration": 3600,
        "order_id": orderId,
        "billing_data": {
          "first_name": billingModel.firstName,
          "last_name": billingModel.lastName,
          "email": billingModel.email,
          "phone_number": billingModel.phone,
          "apartment": "NA",
          "floor": "NA",
          "street": "NA",
          "building": "NA",
          "shipping_method": "NA",
          "postal_code": "NA",
          "city": "NA",
          "country": "NA",
          "state": "NAh"
        },
        "currency": "EGP",
        "integration_id": int.parse(integrationId ?? '', onError: (_) => 1),
        "lock_order_when_paid": "false",
      },
    );
    return f['token'];
  }

  Future<bool> _card(
    String payKey,
    String iFrameId,
    CardCallBack cardIFrameCallback,
  ) async {
    if (payKey == null) {
      return false;
    }
    final url = "https://accept.paymob.com/api/acceptance/iframes/$iFrameId?payment_token=$payKey";
    return await cardIFrameCallback(url);
  }

  Future<bool> _wallet(
    String payKey,
    String mobileNumber,
    WalletCallBack walletIFrameCallback,
  ) async {
    if (payKey == null) {
      return false;
    }
    final f = await _call(
      'https://accept.paymob.com/api/acceptance/payments/pay',
      {
        "source": {
          "identifier": mobileNumber,
          "subtype": "WALLET",
        },
        "payment_token": payKey,
      },
    );
    final url = f['redirect_url'];
    if (url == null) {
      return false;
    }
    return await walletIFrameCallback(url);
  }
}

Future<Map> _call(String url, Map body) async {
  print('PAYMOB REQUEST URL : $url');
  print('<PAYMOB REQUEST BODY>');
  body.entries.toList().forEach((e) {
    print('${e.key} ${e.value}');
  });
  print('</PAYMOB REQUEST BODY>');
  final f = await post(
    url,
    headers: {
      'Content-Type': 'application/json',
    },
    body: jsonEncode(body),
  );
  return jsonDecode(f.body);
}

class ItemModel {
  final String name;
  final String amountCents;
  final String description;
  final String quantity;

  ItemModel({
    @required this.name,
    @required this.amountCents,
    @required this.description,
    @required this.quantity,
  });

  Map<String, String> get toJson => {
        "name": name,
        "amount_cents": amountCents?.convertCents,
        "description": description,
        "quantity": quantity,
      };
}

class CardModel {
  final String iFrameID;
  final CardCallBack callBack;

  CardModel(this.iFrameID, this.callBack);
}

class WalletModel {
  final String mobileNumber;
  final WalletCallBack walletCallBack;

  WalletModel(this.mobileNumber, this.walletCallBack);
}

class BillingModel {
  final String firstName;
  final String lastName;
  final String email;
  final String phone;

  BillingModel({
    @required this.firstName,
    @required this.lastName,
    @required this.email,
    @required this.phone,
  });
}

extension StringX on dynamic {
  String get convertCents => (double.parse(this, (_) => 1.0) * 100)?.toString();
}
