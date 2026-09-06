# Session Breakout Gold — 5 bosqichli test qo'llanmasi

## Fayllar

| Fayl | Versiya | Bosqich | Qatorlar |
|---|---|---|---|
| `Session_Breakout_Gold.mq5` | 2.00 | **BASELINE** (asl kodingiz) | 129 |
| `SB_Gold_v30_Stage1_SL.mq5` | 3.00 | 1 — SL mexanikasi | 530 |
| `SB_Gold_v31_Stage2_Risk.mq5` | 3.10 | 2 — Risk nazorati | 649 |
| `SB_Gold_v32_Stage3_Filters.mq5` | 3.20 | 3 — Signal sifati | 810 |
| `SB_Gold_v33_Stage4_Manage.mq5` | 3.30 | 4 — Pozitsiya boshqaruvi | 1015 |
| `SB_Gold_v34_Stage5_Final.mq5` | 3.40 | 5 — Barqarorlik + vizual | 1337 |

Har bir bosqich oldingisining **hammasini** o'z ichiga oladi.

---

## O'rnatish

1. MetaTrader 5 → `File` → `Open Data Folder`
2. `MQL5\Experts\` papkasiga 5 ta `.mq5` faylni ko'chiring
3. MetaEditor da har birini oching → **F7** (Compile)
4. Xato bo'lmasligi kerak. Ogohlantirishlar (warnings) bo'lishi normal.

---

## Backtest sozlamalari (hammasi uchun bir xil)

| Parametr | Qiymat |
|---|---|
| Simvol | XAUUSD |
| Timeframe | **M15** (M5 ham bo'ladi) |
| Model | **Every tick based on real ticks** (agar bo'lsa) yoki `Every tick` |
| Davr | Kamida **1 yil**, ideali 2–3 yil |
| Deposit | $5000 |
| Leverage | 1:100 |
| Optimizatsiya | **YO'Q** — avval standart parametrlar bilan |

> ⚠️ `Open prices only` rejimini ISHLATMANG — 4-bosqichdan boshlab
> break-even/trailing har tickda ishlaydi va bu rejimda noto'g'ri natija beradi.

---

## Test tartibi

Har bosqichdan keyin quyidagi ko'rsatkichlarni yozib boring:

```
Bosqich | Savdolar | Win% | Profit Factor | Max DD% | Net Profit | Sharpe
--------|----------|------|---------------|---------|------------|-------
Baseline|          |      |               |         |            |
   1    |          |      |               |         |            |
   2    |          |      |               |         |            |
   3    |          |      |               |         |            |
   4    |          |      |               |         |            |
   5    |          |      |               |         |            |
```

### Nimaga e'tibor berish kerak

**Bosqich 1 dan keyin** — asosiy ta'sir shu yerda:
- Win% sezilarli oshishi kerak (SL endi range ichida emas)
- Savdolar soni biroz kamayadi (kech kirishlar rad etiladi)
- Journal da `[FILTR] KECH KIRISH rad etildi` xabarlarini sanang

**Bosqich 2 dan keyin:**
- Savdolar soni keskin kamayadi (kuniga 1 ta)
- Max DD sezilarli kamayishi kerak
- Net Profit ham kamayishi mumkin — bu **normal**, muhimi DD/Profit nisbati

**Bosqich 3 dan keyin:**
- Savdolar yana ~30% kamayadi
- Profit Factor oshishi kerak (sifatsiz savdolar filtrlandi)
- Agar savdolar juda kam qolsa → `InpMinRangeATR` ni 0.25 ga tushiring

**Bosqich 4 dan keyin:**
- Win% sezilarli oshadi (BE savdolar hisobiga)
- O'rtacha foyda kamayishi mumkin (BE erta chiqarib yuboradi)
- Max DD eng katta yaxshilanish shu yerda

**Bosqich 5 dan keyin:**
- Natija 4-bosqichga yaqin bo'lishi kerak
- Agar KESKIN farq qilsa → chart TF/range TF muammosi bor edi (bu yaxshi xabar)
- Visual mode da chartda range qutisi va SL levellarini ko'ring

---

## Journal (log) ni o'qish

Har bir EA batafsil log yozadi. Muhim teglar:

| Teg | Ma'nosi |
|---|---|
| `[RANGE]` | Asian range qurildi / tozalandi |
| `[RANGE-FILTR]` | Range kengligi qabul/rad qilindi |
| `[BREAK-FILTR]` | Breakout sifati tekshiruvi |
| `[FILTR]` | Kirish rad etildi (spread, kech kirish, va h.k.) |
| `[SIGNAL]` | Savdo ochilmoqda — barcha hisoblar |
| `[YUBORILDI]` | Order serverga yuborildi |
| `[TASDIQ]` | SL/TP to'g'ri o'rnatilgani tasdiqlandi |
| `[SLIPPAGE]` | Rejalashtirilgan va haqiqiy narx farqi |
| `[TUZATILDI]` | SL/TP qayta o'rnatildi |
| `[KRITIK]` | **Broker SL ni qabul qilmadi!** |
| `[BREAK-EVEN]` `[TRAILING]` | SL ko'chirildi |
| `[VAQT-CHIQISH]` | Vaqt bo'yicha yopildi |
| `[LIMIT]` | Kunlik limit ishga tushdi |
| `[XATO]` | Xato — retcode bilan |

**Eng muhim:** agar `[KRITIK]` yoki ko'p `[XATO]` ko'rsangiz — darhol menga ayting,
bu brokeringiz bilan bog'liq va sozlash kerak.

---

## Real hisobda test (demo)

Backtest tugagach, **demo hisobda** kamida 2 hafta:

1. `SB_Gold_v34_Stage5_Final.mq5` ni chartga tashlang
2. `InpVerboseLog = true` qoldiring
3. `InpShowDashboard = true` — ekranda holat ko'rinadi
4. Har kuni Journal ni tekshiring

Demo da tekshiriladigan narsalar (backtest ko'rsatmaydi):
- Broker SL ni qabul qiladimi (`[KRITIK]` yo'qmi)
- Filling mode ishlayaptimi
- Haqiqiy slippage qancha
- Real spread qancha (`InpMaxSpreadPoints` to'g'rimi)

---

## Muhim sozlamalar

### Broker digits ni tekshiring
Journal da `Digits / punkt` qatoriga qarang:
- `Digits=2` → `InpSL_BufferPoints=50` = **$0.50** ✓
- `Digits=3` → avtomatik x10 qilinadi, natija ham **$0.50** ✓

Agar noto'g'ri bo'lsa → `InpAutoAdjustPoints=false` qilib qo'lda sozlang.

### Server vaqt zonasi (5-bosqich)
Journal da `Server GMT offset` qatoriga qarang. Agar `+2` yoki `+3` bo'lsa,
standart sozlamalar (Asian 0-7, London 8-11) to'g'ri. Boshqa bo'lsa —
soatlarni siljiting.

### Lot
Barcha versiyalarda `InpLotSize = 0.10` qat'iy.
Risk asosida lot kerak bo'lsa: `InpUseRiskSizing = true` + `InpRiskPercent = 1.0`.

---

## Muammo bo'lsa

| Belgi | Sabab | Yechim |
|---|---|---|
| Umuman savdo yo'q | Range qurilmayapti | Journal da `[RANGE][XATO]` qidiring |
| `unsupported filling mode` | Broker FOK qabul qilmaydi | 1-bosqich buni avtomatik hal qiladi |
| `invalid stops` | SL normalizatsiya | 1-bosqich hal qiladi; qolsa STOPS_LEVEL ni ayting |
| Juda kam savdo (3-bosqichdan keyin) | Filtrlar qattiq | `InpMinRangeATR=0.25`, `InpMinBodyPct=25` |
| Juda ko'p savdo | Limit o'chiq | `InpMaxTradesPerDay=1` ekanini tekshiring |
| EA ishga tushmadi | Input xatosi | Alert oynasida sabab yozilgan |
