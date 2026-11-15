class_name ShopSheet
extends Sheet

## "Reklamları kaldır" sayfası: başlık + satın alma satırı + Tamam. Ana ekrandaki küçük düğmeden açılır.


static func open(parent: Node) -> ShopSheet:
	var sheet: ShopSheet = ShopSheet.new()
	sheet.build(parent, false)
	sheet.dismiss_on_dim = true
	sheet.add_title(UiStrings.shop_remove_ads())
	sheet.content().add_child(UiShopRow.new())
	sheet.add_gap(UiKit.SPACE_XL)
	var ok: Button = sheet.add_action(UiStrings.ok(), false)
	ok.pressed.connect(sheet.close)
	sheet.play_intro()
	return sheet
