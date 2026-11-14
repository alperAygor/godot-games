class_name DocumentViews
extends RefCounted
## Kimlik ve kaynak beyanının ayrıntı görünümleri (inceleme sayfasının içeriği). Veriyi olduğu gibi gösterir; hiçbir kontrol yapmaz.


## Kimlik kartı: fotoğraf (yüz numarası), ad, numara, imza, son geçerlilik günü.
static func build_id(card: Documents.IdCard) -> Control:
	var box := VBoxContainer.new()
	box.name = "IdView"
	box.add_theme_constant_override("separation", 8)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var face := FaceView.new()
	face.name = "IdPhoto"
	face.setup(card.face_id, card.holder_name)
	row.add_child(face)
	var lines := VBoxContainer.new()
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lines)
	lines.add_child(UiKit.label(card.holder_name, &"SheetTitle", "IdName"))
	lines.add_child(UiKit.label(box.tr("DOC_PHOTO") % card.face_id, &"SheetInfo", "IdPhotoNo"))
	box.add_child(UiKit.label(box.tr("DOC_NUMBER") % card.number, &"BigNumber", "IdNumber"))
	box.add_child(UiKit.label(box.tr("DOC_SIGNATURE") % card.signature, &"GoalLabel", "IdSignature"))
	box.add_child(UiKit.label(box.tr("DOC_VALID_UNTIL") % card.expiry_day, &"GoalLabel", "IdExpiry"))
	return box


## Kaynak beyanı: ad, beyan edilen tutar, imza.
static func build_declaration(declaration: Documents.SourceDeclaration) -> Control:
	var box := VBoxContainer.new()
	box.name = "DeclarationView"
	box.add_theme_constant_override("separation", 8)
	box.add_child(UiKit.label(declaration.holder_name, &"SheetTitle", "DeclName"))
	box.add_child(UiKit.label(box.tr("DOC_AMOUNT") % UiKit.money(declaration.amount_minor, "PL"), &"BigNumber", "DeclAmount"))
	box.add_child(UiKit.label(box.tr("DOC_SIGNATURE") % declaration.signature, &"GoalLabel", "DeclSignature"))
	return box
