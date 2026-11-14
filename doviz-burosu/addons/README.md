# Üçüncü taraf eklentiler (Faz 11)

| Eklenti | Sürüm | Kaynak | Lisans |
|---|---|---|---|
| AdMob (`AdmobPlugin`, `GMPShared`) | v7.0 (Godot 4.7 ile test edilmiş) | https://github.com/godot-sdk-integrations/godot-admob | MIT |
| Google Play Billing (`GodotGooglePlayBilling`) | 3.3.0 (Billing Library 9.1.0, Godot 4.2+) | https://github.com/godot-sdk-integrations/godot-google-play-billing | MIT |

- İkisi de yalnızca Android bölümüyle kullanılır (AdMob'un iOS dosyaları pakette var ama kullanılmıyor).
- Elle düzenleme: yalnızca `AdmobPlugin/android_export.cfg` (araçla üretilir: `python3 tools/sync_ads_config.py`).
- Oyun kodu eklentileri doğrudan çağırmaz; `scripts/services/admob_ads_provider.gd` ve `playbilling_iap_provider.gd` sarmalar.
