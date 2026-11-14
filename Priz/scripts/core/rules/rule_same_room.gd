extends PrizRule
## Oda kısıtı: cihaz yalnız kendi odasındaki prize takılır.
## params: reason (varsayılan "wrong_room").
## Üretici kancası yok: iskelet her odaya o odanın cihazları kadar yuva koyar ve gizli çözüm
## bu kuralla yerleştirilir.


func default_order() -> int:
	return 10


func check_plug(_level: PrizLevel, device: PrizDevice, socket: PrizSocket) -> StringName:
	if device.room != socket.room:
		return StringName(param_str("reason", String(PrizReason.WRONG_ROOM)))
	return PrizReason.OK
