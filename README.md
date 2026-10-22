# WazePatch

Tweak pentru Waze pe iOS, pentru **telefon și CarPlay**. Merge pe **jailbreak**
(rootless, de exemplu Dopamine) și ca **IPA injectat** (sideload, TrollStore).

## Funcții (v0.2.0)

| Funcție | Telefon | CarPlay |
|---|:-:|:-:|
| Vitezometru GPS: km/h sau mph, 4 poziții, mărime 50–200% | ✅ (implicit oprit) | ✅ |
| Avertizare peste prag: badge roșu, vibrație, sunet | ✅ | ✅ |
| Buton pe hartă pentru ascunderea vitezometrului | – | ✅ |
| Ecran mereu aprins | ✅ | – |
| Activ în fundal | ✅ | ✅ |
| 120 Hz pe ecranele ProMotion | ✅ | – |
| Dimmer OLED de noapte (strat propriu, atingeri trec prin el) | ✅ | ✅ |
| Jurnal de călătorii local, cu export GPX | ✅ | – |
| Mesaj „WazePatch activ” la pornire | ✅ | – |

### Setări
Setările se deschid cu o **apăsare lungă cu 3 degete** oriunde în Waze. Se aplică
imediat (cu excepția opțiunii 120 Hz) și se păstrează în containerul aplicației,
deci funcționează la fel pe jailbreak și pe sideload.

### De ce funcționează pe orice versiune de Waze
Tweak-ul folosește doar API-uri publice Apple (UIKit, CarPlay, CoreLocation,
QuartzCore), nu clase interne Waze.

## Instalare

### Repo Sileo (recomandat)
Adaugă repo-ul și primești actualizările automat:

**`https://abace18.github.io/waze-patch/`**

Pe iPhone deschide [pagina repo-ului](https://abace18.github.io/waze-patch/) și apasă
„Adaugă în Sileo” (sau Zebra). Apoi caută **WazePatch** și instalează.

> Prima dată: în GitHub, *Settings → Pages → Build and deployment → Source: GitHub Actions*.
> Workflow-ul **Build** publică repo-ul pe Pages la fiecare push pe `main`.

### Jailbreak (manual)
Alternativ, descarcă `.deb`-ul din *Actions → Build → Artifacts* și instalează-l din
Sileo sau Zebra.

### IPA injectat
1. *Actions → Inject IPA → Run workflow*.
2. Pune un link **direct** către un IPA Waze **decriptat**.
3. Descarcă rezultatul din *Artifacts*.

**Limitările re-semnării** (sideload cu certificat, de exemplu Feather):
- Waze nu își poate salva sesiunea în Keychain, deci te delogează și Google
  Sign-In nu funcționează.
- Se pierde entitlement-ul CarPlay.

Cu **fakesign** (TrollStore / AppSync) sau pe **jailbreak** nu există aceste
probleme.

## Compilare

Fiecare push e compilat de GitHub Actions. Local, cu [Theos](https://theos.dev)
și `iPhoneOS16.5.sdk` în `$THEOS/sdks`:

```sh
make package FINALPACKAGE=1
```

## Roadmap
- [ ] Reverse engineering pe motorul de configurare Waze: reclame, distanțe de
      alertare, limita de viteză, AMOLED, skin-uri de hartă, mood-uri și altele
- [ ] Intrare WazePatch în meniul lateral Waze
