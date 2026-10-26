import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n.dart';

/// 앱스토어에 등록하는 Pro 상품 ID (한 번만 결제하는 "비소모품")
const String kProProductId = 'com.isla0x.yeobaek.pro';

/// Pro 로 열리는 것들 (안내 화면에 그대로 써요)
List<(String, String)> get kProPerks => <(String, String)>[
  (tl('백업 · 복원'), tl('색 · 프로젝트 · 할 일 · 이동시간을 파일로 보관하고 되돌려요')),
  (tl('폰을 바꿔도 그대로'), tl('새 폰에서 "가져오기" 한 번이면 돌아와요')),
];

/// 결제 쪽 일을 맡는 곳. 진짜(앱스토어)와 가짜(테스트)를 바꿔 끼울 수 있어요.
abstract class ProBackend {
  /// 이미 산 적이 있는지 (기기에 기억해 둔 값)
  bool get owned;

  /// 앱스토어에 보이는 가격 글자 (모르면 null)
  Future<String?> loadPrice();

  /// 결제창을 띄워요. 결제가 확인되면 [onOwned] 가 불려요. 시작하지 못하면 false.
  Future<bool> buy();

  /// 예전에 산 걸 다시 불러와요.
  Future<void> restore();

  /// 결제 결과를 받을 곳을 정해요.
  set onOwned(void Function() cb);

  /// 결제 실패 같은 안내 글을 받을 곳
  set onMessage(void Function(String m) cb);

  void dispose();
}

/// 테스트·샘플용: 눌러도 결제창 없이 바로 Pro 가 돼요.
class FakeProBackend implements ProBackend {
  FakeProBackend({this.owned = false, this.price = '₩2,200'});

  @override
  bool owned;
  final String? price;
  void Function()? _cb;

  @override
  Future<String?> loadPrice() async => price;

  @override
  Future<bool> buy() async {
    owned = true;
    _cb?.call();
    return true;
  }

  @override
  Future<void> restore() async {
    if (owned) _cb?.call();
  }

  @override
  set onOwned(void Function() cb) => _cb = cb;

  @override
  set onMessage(void Function(String m) cb) {}

  @override
  void dispose() {}
}

/// 앱스토어(StoreKit) 결제
class StoreProBackend implements ProBackend {
  StoreProBackend._(this._prefs, this.owned);

  static const String _key = 'pro_owned_v1';

  static Future<ProBackend> open() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return StoreProBackend._(prefs, prefs.getBool(_key) ?? false);
    } catch (_) {
      return FakeProBackend();
    }
  }

  final SharedPreferences _prefs;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? _product;
  void Function()? _ownedCb;
  void Function(String)? _msgCb;

  @override
  bool owned;

  void _listen() {
    _sub ??= _iap.purchaseStream.listen(
      (list) async {
        for (final p in list) {
          if (p.productID != kProProductId) continue;
          if (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored) {
            owned = true;
            try {
              await _prefs.setBool(_key, true);
            } catch (_) {}
            _ownedCb?.call();
          } else if (p.status == PurchaseStatus.error) {
            _msgCb?.call(tl('결제하지 못했어요. 잠시 뒤에 다시 해 주세요.'));
          }
          if (p.pendingCompletePurchase) {
            await _iap.completePurchase(p);
          }
        }
      },
      onError: (_) => _msgCb?.call(tl('결제 상태를 확인하지 못했어요.')),
    );
  }

  Future<ProductDetails?> _load() async {
    if (_product != null) return _product;
    try {
      if (!await _iap.isAvailable()) return null;
      final r = await _iap.queryProductDetails({kProProductId});
      if (r.productDetails.isEmpty) return null;
      _product = r.productDetails.first;
      return _product;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> loadPrice() async {
    _listen();
    return (await _load())?.price;
  }

  @override
  Future<bool> buy() async {
    _listen();
    final d = await _load();
    if (d == null) {
      _msgCb?.call(tl('앱스토어에서 상품을 불러오지 못했어요. 잠시 뒤에 다시 해 주세요.'));
      return false;
    }
    try {
      return await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: d));
    } catch (_) {
      _msgCb?.call(tl('결제를 시작하지 못했어요.'));
      return false;
    }
  }

  @override
  Future<void> restore() async {
    _listen();
    try {
      await _iap.restorePurchases();
    } catch (_) {
      _msgCb?.call(tl('구매를 복원하지 못했어요.'));
    }
  }

  @override
  set onOwned(void Function() cb) => _ownedCb = cb;

  @override
  set onMessage(void Function(String m) cb) => _msgCb = cb;

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}

/// Pro 상태 (화면이 이걸 보고 잠금을 풀어요)
class ProState extends ChangeNotifier {
  ProState([ProBackend? backend]) : _b = backend ?? FakeProBackend() {
    _b.onOwned = _gotOwned;
    _b.onMessage = (m) {
      message = m;
      busy = false;
      notifyListeners();
    };
  }

  final ProBackend _b;

  bool busy = false;
  String? price;

  /// 결제·복원 중 마지막 안내 글 (화면에서 한 번 보여주고 지워요)
  String? message;

  bool get isPro => _b.owned;

  void _gotOwned() {
    busy = false;
    message = null;
    notifyListeners();
  }

  Future<void> loadPrice() async {
    final p = await _b.loadPrice();
    if (p != price) {
      price = p;
      notifyListeners();
    }
  }

  Future<void> buy() async {
    if (busy) return;
    busy = true;
    message = null;
    notifyListeners();
    final ok = await _b.buy();
    if (!ok) {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> restore() async {
    if (busy) return;
    busy = true;
    message = null;
    notifyListeners();
    await _b.restore();
    // 복원할 게 없으면 스트림에 아무것도 안 와요. 잠시 뒤 안내하고 풀어요.
    Future<void>.delayed(const Duration(seconds: 4), () {
      if (busy) {
        busy = false;
        message = isPro ? null : tl('복원할 구매 내역이 없어요.');
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _b.dispose();
    super.dispose();
  }
}
