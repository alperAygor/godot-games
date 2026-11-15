extends RefCounted
class_name GameEvents
## Oyun olay yolu: sahnenin iç yapısına bağlanmadan dinlemek için (reklam akışı C8, görevler C7, juice C5).
## Dinleyici yokken yayın davranışı değiştirmez. Erişim: `scene.events` (game3d) ya da `ctx.events`.
##
## Kanca noktaları (SEAM) kodda `SEAM(...)` yorumuyla işaretlidir; bkz. docs/ARCHITECTURE.md §Kancalar.

## Koşu başladı (gemi kimliği, tohum; 0 = rastgele).
signal run_started(ship_id: String, run_seed: int)
## Düşman öldü (tür, elit mi, kazanılan puan dahil kombo çarpanı).
signal enemy_killed(kind: String, elite: bool, points: int)
## Oyuncu hasar aldı (kalkan kırılması hariç).
signal player_hurt(amount: float)
## Oyuncunun canı bitti. `revive_card` = İkinci Şans kartıyla kendiliğinden dirilecek mi.
## SEAM(ads: revive): reklamla diriltme bu noktada araya girer (RunFlow.on_player_died).
signal player_died(revive_card: bool)
## Oyuncu dirildi (kaynak: "card"; reklam akışı "ad" kullanır).
signal player_revived(source: String)
## Boss sahneye girdi / yenildi.
signal boss_spawned(kind: String)
signal boss_killed(kind: String)
## Seviye kartları gösterildi (SEAM(ads: reroll): `rerolls == 0` iken reklamla yenileme teklifi).
signal cards_shown(cards: Array, rerolls: int)
## Kart seçildi.
signal card_picked(card: Dictionary)
## Koşu sonu ödülü hesaplandı ve kayda işlendi (SEAM(ads: double cores)).
signal reward_computed(cores: int)
## Koşu bitti: {score, best, record, wave, level, kills, combo, time, cores, total_cores}.
## SEAM(ads: interstitial): koşu sonu geçiş reklamı buradan tetiklenir.
signal run_ended(summary: Dictionary)
