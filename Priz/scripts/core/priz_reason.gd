class_name PrizReason
extends RefCounted
## `PrizBoard.can_plug` / `plug` dönüş kodları. Arayüz bunları metin yerine görsel
## geri bildirime çevirir (ör. oda kısıtında prizi kapı simgesiyle soldurmak).
## Öğe dosyaları kendi kodlarını da tanımlayabilir (kural parametresindeki "reason").

const OK: StringName = &"ok"
## Bilinmeyen cihaz ya da priz kimliği.
const UNKNOWN: StringName = &"unknown"
## Tahta planlama durumunda değil (kazanıldı ya da kaybedildi).
const NOT_PLANNING: StringName = &"not_planning"
## Oda kısıtı: cihaz yalnız kendi odasındaki prize takılır.
const WRONG_ROOM: StringName = &"wrong_room"
## Topraklı priz isteyen cihaz topraksız prize takılamaz.
const NEEDS_GROUND: StringName = &"needs_ground"
## Prizin (ya da çoklu prizin) tüm yuvaları dolu.
const SOCKET_FULL: StringName = &"socket_full"
## Düz kip: cihaz takılırsa hat taşar, fiş oturmaz.
const WOULD_OVERFLOW: StringName = &"would_overflow"
