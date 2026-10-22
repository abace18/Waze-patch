# WazePatch

Tweak de jailbreak pentru Waze pe iOS, axat pe **CarPlay**.

- Țintă: iOS 15–16+, jailbreak rootless (testat pentru **Dopamine pe iOS 16.7**).
- Pachet: `com.abace.wazepatch` (`iphoneos-arm64`).

## Funcții (v0.1.0)

| Funcție | Detalii |
|---|---|
| Vitezometru pe CarPlay | Viteza GPS afișată peste harta Waze; km/h sau mph, 4 poziții, mărime 50–200%. |
| Avertizare de viteză | Fundalul devine roșu peste pragul ales de tine. |
| Buton pe harta CarPlay | Ascunde sau afișează vitezometrul din mașină. Se adaugă doar dacă există loc (CarPlay permite maximum 4 butoane). |
| Ecran mereu aprins | Ecranul telefonului nu se blochează cât timp Waze este deschis. |
| Setări live | Opțiunile sunt în **Settings → WazePatch** și se aplică fără repornirea Waze. |

### De ce funcționează pe orice versiune de Waze
Tweak-ul folosește numai API-uri publice Apple (`CPMapTemplate`, `CPWindow`,
`CPTemplateApplicationScene`, `CLLocationManager`, `UIApplication`), nu clase interne
Waze. Update-urile Waze nu ar trebui deci să strice funcțiile de mai sus.

## Compilare

Fiecare push este compilat automat de **GitHub Actions** (`.github/workflows/build.yml`).
Fișierul `.deb` apare în tab-ul *Actions → Build → Artifacts*.

Local, cu [Theos](https://theos.dev) și SDK-ul `iPhoneOS16.5.sdk` instalat în `$THEOS/sdks`:

```sh
make package FINALPACKAGE=1
```

## Instalare
Copiază fișierul `.deb` pe telefon și instalează-l din Sileo sau Zebra. Ca alternativă: `dpkg -i` și apoi `killall Waze`.

### IPA injectat (fără jailbreak)
1. *Actions → Inject IPA → Run workflow*.
2. Pune un link **direct** către un IPA Waze **decriptat**. Opțional: nume, Bundle ID, fakesign, ștergerea extensiilor.
3. Descarcă IPA-ul din *Artifacts*. Se păstrează 7 zile.

Tweak-ul se injectează cu [cyan](https://github.com/asdfzxcvbn/pyzule-rw), care adaugă și ElleKit în aplicație.

- **Fakesign** (implicit pornit) generează un fișier `.tipa` pentru TrollStore sau AppSync. Acesta păstrează entitlement-ul CarPlay.
- Semnat cu un cont Apple obișnuit (Sideloadly, AltStore), IPA-ul pierde entitlement-ul CarPlay. Pe jailbreak, CarBridge rezolvă asta.
- În varianta IPA nu există panou în Settings, deci se folosesc valorile implicite.

## Roadmap
- [ ] Limita legală de viteză lângă vitezometru (necesită reverse engineering pe motorul Waze)
- [ ] Ascunderea reclamelor și a pin-urilor sponsorizate
- [ ] Filtre pentru tipurile de alerte
- [ ] Pornirea automată a Waze la conectarea CarPlay (hook în SpringBoard)
- [ ] Teme: OLED, culori pentru rută
- [ ] Jurnal local al călătoriilor cu export GPX
