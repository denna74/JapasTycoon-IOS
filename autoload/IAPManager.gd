extends Node

# Cross-platform IAP manager using OpenIAP (StoreKit 2 on iOS).
# Registered as the `IAPManager` autoload in project.godot.
#
# All OpenIAP types are accessed via ClassDB so the script parses correctly on
# desktop editors where the iOS plugin is absent.

signal purchase_successful(sku: String, token: String)
signal purchase_failed(sku: String)
signal billing_ready
signal purchases_restored

enum PurchaseResult { OK, NOT_INITIALIZED, NO_SKU, UNAVAILABLE }

var _initialized: bool = false
var _products_ready: bool = false
var _pending_restorations: Array[Dictionary] = []
var _purchases_by_token: Dictionary = {}

func _ready():
	if ClassDB.class_exists("GodotIap") or Engine.has_singleton("GodotIap"):
		var iap = _get_iap()
		if iap:
			iap.connected.connect(_on_connected)
			iap.disconnected.connect(_on_disconnected)
			iap.purchase_updated.connect(_on_purchase_updated)
			iap.purchase_error.connect(_on_purchase_error)
			iap.init_connection()
	else:
		print("OpenIAP plugin not found")

func _get_iap():
	if ClassDB.class_exists("GodotIap") and ClassDB.can_instantiate("GodotIap"):
		return ClassDB.instantiate("GodotIap")
	if Engine.has_singleton("GodotIap"):
		return Engine.get_singleton("GodotIap")
	return null

func is_available() -> bool:
	return _get_iap() != null

func is_initialized() -> bool:
	return _initialized

func is_products_ready() -> bool:
	return _products_ready

func get_pending_restorations() -> Array[Dictionary]:
	var result = _pending_restorations.duplicate()
	_pending_restorations.clear()
	return result

func _on_connected():
	_initialized = true
	print("OpenIAP connected")
	_fetch_products()

func _on_disconnected():
	_initialized = false
	_products_ready = false
	print("OpenIAP disconnected")

func _fetch_products():
	var iap = _get_iap()
	if not iap:
		return
	var request = {
		"skus": _get_all_skus(),
		"type": "in-app"
	}
	var products = await iap.fetch_products(request)
	if products.size() > 0:
		_products_ready = true
		print("Product details loaded: ", products.size(), " products")
		billing_ready.emit()
		_check_pending_restorations()
	else:
		print("Failed to load product details")

func _get_all_skus() -> Array:
	var skus := []
	for key in IAPConfig.SKUS:
		skus.append(IAPConfig.SKUS[key])
	return skus

func _check_pending_restorations():
	var iap = _get_iap()
	if not iap:
		return
	var result = await iap.restore_purchases()
	if result and result.get("success", false):
		var purchases = result.get("purchases", [])
		if purchases.is_empty():
			print("No pending purchases to restore")
			return
		print("Found ", purchases.size(), " purchase(s) to reconcile")
		for purchase in purchases:
			var product_id = purchase.get("productId", "")
			if product_id.is_empty():
				continue
			var state = purchase.get("state", -1)
			if state != 0:
				continue
			var token = purchase.get("transactionId", "")
			if token.is_empty():
				continue
			_purchases_by_token[token] = purchase
			if SaveManager.is_purchase_processed(token):
				print("Purchase already delivered, cleaning up: ", product_id, " token=", token)
				finalize_purchase(token, product_id)
			else:
				print("Pending delivery for: ", product_id, " token=", token)
				_pending_restorations.append({"sku": product_id, "token": token})
		if not _pending_restorations.is_empty():
			purchases_restored.emit()

func purchase(sku: String) -> int:
	var iap = _get_iap()
	if iap == null:
		return PurchaseResult.UNAVAILABLE
	if not _initialized:
		return PurchaseResult.NOT_INITIALIZED
	if not _products_ready:
		return PurchaseResult.NOT_INITIALIZED
	if sku.is_empty():
		return PurchaseResult.NO_SKU
	var props = {
		"requestPurchase": {
			"apple": {"sku": sku}
		},
		"type": "in-app"
	}
	iap.request_purchase(props)
	return PurchaseResult.OK

func finalize_purchase(token: String, sku: String):
	if token.is_empty() or sku.is_empty():
		return
	var purchase = _purchases_by_token.get(token, {})
	_purchases_by_token.erase(token)
	if purchase.is_empty():
		print("finalize_purchase: no stored purchase for token=", token, " sku=", sku)
		return
	var iap = _get_iap()
	if not iap:
		return
	var is_consumable: bool = IAPConfig.get_type(sku) == IAPConfig.SkuType.CONSUMABLE
	iap.finish_transaction(purchase, is_consumable)

func _on_purchase_updated(purchase: Dictionary):
	var product_id = purchase.get("productId", "")
	var token = purchase.get("transactionId", "")
	if product_id.is_empty() or token.is_empty():
		return
	print("Purchase updated: ", product_id, " token=", token)
	_purchases_by_token[token] = purchase
	purchase_successful.emit(product_id, token)

func _on_purchase_error(error: Dictionary):
	print("Purchase failed: ", error.get("message", "unknown"))
	var sku = error.get("sku", "")
	purchase_failed.emit(sku)