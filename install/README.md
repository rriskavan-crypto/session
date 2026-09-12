# O'rnatish

## Windows (MT5 shu yerda)

PowerShell'ni oching va:

```powershell
powershell -ExecutionPolicy Bypass -File install_windows.ps1
```

Skript nima qiladi:
1. MT5 ma'lumot papkangizni **avtomatik topadi** (bir nechta terminal bo'lsa hammasiga)
2. EA fayllarini `MQL5\Experts\SessionBreakout\` ga qo'yadi
3. `ExportBars.mq5` ni `MQL5\Scripts\SessionBreakout\` ga qo'yadi ← **skript, Experts emas**
4. Python backtest muhitini tayyorlaydi va tekshirib ko'radi

### Agar avtomatik topilmasa
MT5 → `File` → `Open Data Folder` → yo'lni nusxalang:
```powershell
powershell -ExecutionPolicy Bypass -File install_windows.ps1 -MT5Path "C:\Users\...\Terminal\XXXX"
```

### Agar GitHub'dan yuklay olmasa (repo yopiq)
GitHub'dan ZIP yuklab oling, chiqaring, keyin:
```powershell
powershell -ExecutionPolicy Bypass -File install_windows.ps1 -Source "C:\yuklangan\papka"
```

### Parametrlar
| Parametr | Vazifasi |
|---|---|
| `-Source <yo'l>` | Loyiha papkasi (bo'sh = GitHub'dan klon) |
| `-MT5Path <yo'l>` | MT5 papkasi (avtomatik topilmasa) |
| `-SkipPython` | Python qismini o'tkazib yuborish |

---

## Mac / Linux

```bash
chmod +x install_mac_linux.sh
./install_mac_linux.sh
```

---

## O'rnatgandan keyin — 7 qadam

1. **MT5 ni qayta ishga tushiring** (yangi fayllar ko'rinishi uchun)
2. MetaEditor (`F4`) → `Experts\SessionBreakout` → har bir `.mq5` ni oching, **F7**
3. `Scripts\SessionBreakout\ExportBars.mq5` ni ham **F7**
4. `Tools` → `Options` → `Charts` → **Max bars in chart = Unlimited**
5. **XAUUSD M15** chartini oching → **Home** bosing → tarix yuklansin
6. `Navigator` → `Scripts` → **ExportBars** ni chartga tashlang
7. Menga yuboring:
   - `MQL5\Files\XAUUSD_PERIOD_M15.csv`
   - Journal'dagi **BROKER MA'LUMOTLARI** bloki

---

## Qaysi fayl nima uchun

| Fayl | Joyi | Vazifasi |
|---|---|---|
| `Session_Breakout_Gold.mq5` | Experts | Sizning asl kodingiz (o'zgarishsiz) |
| `SB_MultiSession_v40.mq5` | Experts | Asl matematika + 4 sessiya |
| `SB_Lab_v41.mq5` | Experts | Optimizatsiya laboratoriyasi |
| `SB_Gold_v30..v34` | Experts | 5 bosqichli versiyalar (arxiv) |
| `ExportBars.mq5` | **Scripts** | Ma'lumot eksporti — EA emas, skript |

---

## Tekshiruv

Loyiha papkasida (Mac/Linux):
```bash
./verify.sh
```
Hamma narsa joyida bo'lsa `HAMMA NARSA JOYIDA` chiqadi.
