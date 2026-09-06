# v4.x — Optimizatsiya rejasi

## Nima uchun v3.x ishlamadi

Mening v3.x versiyalarimdagi asosiy mexanik xato:

```
ASL:      SL masofasi = range kengligi + buffer          (QAT'IY)
MENING:   SL masofasi = (entry - rangeHigh) + range + buffer   (KATTAROQ)
```

Natijada **SL kengaydi**, **TP uzoqlashdi**, qat'iy 0.10 lot bilan
**har savdoda ko'proq zarar** va **TP ga yetish qiyinlashdi**.

Ustiga 8 ta filtr birgalikda savdolar sonini keskin kamaytirdi. Ayniqsa:
- Break-even @ +1R — RR 2.0 tizimida 2R ga boradigan savdolarni +0.15R da chiqaradi
- Spread 350 → 60 punkt — savdolarning katta qismi jimgina rad etilgan bo'lishi mumkin
- Kuniga 1 savdo

**v4.x da bu qaytarib olindi.**

---

## Fayllar

| Fayl | Nima |
|---|---|
| `SB_MultiSession_v40.mq5` | Asl v2.00 matematikasi + 4 sessiya. Filtr yo'q. |
| `SB_Lab_v41.mq5` | v40 + SL/TP/kirish rejimlari + optimizatsiya uchun filtrlar |

**Ikkalasining standart sozlamalari = sizning asl kodingiz.**

---

## 0-QADAM: PARITET (eng muhim!)

Avval `SB_MultiSession_v40.mq5` ni **hech nima o'zgartirmasdan** test qiling.

Natija asl `Session_Breakout_Gold.mq5` bilan **deyarli bir xil** bo'lishi kerak.

| Agar | Demak |
|---|---|
| Bir xil ✓ | Baza to'g'ri, davom etamiz |
| Farq bor | Menga ayting — sabab topamiz (asl kodda yashirin xato bor edi) |

Bu qadamsiz keyingi natijalarga ishonib bo'lmaydi.

---

## 1-QADAM: KO'P SESSIYA (sizning g'oyangiz)

`SB_MultiSession_v40.mq5`, faqat sessiyalarni yoqing:

| Test | S1 | S2 | S3 | Kutilayotgan |
|---|---|---|---|---|
| A | ✓ | ✗ | ✗ | baza |
| B | ✓ | ✓ | ✗ | savdolar ~2x, foyda ~2x (agar strategiya ishlasa) |
| C | ✓ | ✓ | ✓ | savdolar ~3x |
| D | ✗ | ✓ | ✗ | S2 alohida qanchalik yaxshi? |
| E | ✗ | ✗ | ✓ | S3 alohida qanchalik yaxshi? |

**D va E juda muhim** — ba'zan bitta sessiya butun foydani beradi,
qolganlari faqat zarar qo'shadi. Buni bilmasdan hammasini yoqish xato.

Sessiya vaqtlari **broker server vaqtiga** bog'liq. Journal dagi
`Digits/Point` qatorini va server vaqtini menga yuboring — to'g'rilaymiz.

---

## 2-QADAM: SL/TP GEOMETRIYASI (mening asosiy g'oyam)

`SB_Lab_v41.mq5` bilan. **Bu eng katta potensialga ega qadam.**

### Muammo
Asl: SL = 1× range, TP = 2× range. Ya'ni narx **entry dan 2.1× range**
masofani bosib o'tishi kerak. Oltinda London breakouti odatda Osiyo
range ining **0.5–1.5 barobari** ga cho'ziladi. Ya'ni TP statistik
jihatdan erishish qiyin joyda.

### Yechim
SL ni ham, TP ni ham kichraytirish — RR o'sha 2.0 qoladi, lekin TP
erishiladigan masofaga tushadi.

```
InpSL_Mode      = SL_RANGE_FRACTION
InpSL_RangeFrac = 0.50        →  SL = 0.5 × range + buffer
InpTP_Mode      = TP_RR
InpRR_Ratio     = 2.0         →  TP = 2 × SL = 1.0 × range
```

Misol (range $8.50, buffer $0.50):
| | SL | TP | Kerakli harakat | Zarar (0.10 lot) |
|---|---|---|---|---|
| Asl | $9.00 | $18.00 | 2.1× range | $90 |
| Frac 0.5 | $4.75 | $9.50 | 1.1× range | **$47** |
| Frac 0.35 | $3.48 | $6.95 | 0.8× range | $35 |

### Optimizatsiya (Strategy Tester → Optimization)

| Parametr | Start | Step | Stop |
|---|---|---|---|
| `InpSL_RangeFrac` | 0.30 | 0.10 | 1.00 |
| `InpRR_Ratio` | 1.0 | 0.25 | 3.0 |

`InpSL_Mode = SL_RANGE_FRACTION` qilib qo'ying (bu optimizatsiya qilinmaydi).

**Optimizatsiya mezoni:** `Custom max` emas, **`Balance + max Profit Factor`**
yoki `Complex Criterion max`. Faqat Net Profit bo'yicha optimizatsiya
qilmang — u overfitting ga olib keladi.

### Muqobil: TP ni to'g'ridan-to'g'ri belgilash
```
InpTP_Mode      = TP_RANGE_MULT
InpTP_RangeMult = 0.75 ... 1.50    →  TP = breakout leveli + range × k
```
Bu yanada tabiiy: "narx range kengligining 1 barobariga cho'ziladi" degan
gipotezani to'g'ridan-to'g'ri sinaydi.

---

## 3-QADAM: PENDING STOP ORDER (mening ikkinchi g'oyam)

```
InpEntryMode = ENTRY_PENDING_STOP
```

### Nima o'zgaradi

**Asl (market):** bar yopiladi → close1 > rangeHigh → keyingi bar
ochilishida market order. Bu vaqtga narx allaqachon leveldan **$1–3**
uzoqda bo'lishi mumkin.

**Pending:** `rangeHigh + 10 punkt` da BuyStop turadi. Narx levelga
tegishi bilan darhol kiradi.

### Nima uchun bu ikki tomondan yaxshi

| | Market | Pending |
|---|---|---|
| Entry narxi | rangeHigh + $1–3 | rangeHigh + $0.10 |
| TP gacha masofa | +$1–3 uzoqroq | **yaqinroq** |
| SL leveldan | yaqinroq (xavfliroq) | **uzoqroq** |
| 07:00–08:00 breakouti | o'tkazib yuboriladi | **ushlanadi** |

### Kamchiligi
Soya (wick) bilan ham ishga tushadi — bar ichida $0.20 ga chiqib
qaytgan harakat ham savdo ochadi. Market rejim buni o'tkazib yuborardi.

Bu **empirik savol** — faqat backtest javob beradi. Shuning uchun rejim.

`InpPendingOffPts` ni ham sinang: 5 / 10 / 20 / 30 punkt.
Katta offset = kam yolg'on ishga tushish, lekin yomonroq entry.

---

## 4-QADAM: Filtrlarni BITTA-BITTADAN

Faqat 1–3 qadamlar tugagach. Har birini **alohida** yoqing va o'lchang:

| Filtr | Parametr | Sinov diapazoni |
|---|---|---|
| Range kengligi | `InpUseRangeFilter=true` | Min 0.2–0.5, Max 1.5–2.5 |
| Penetratsiya | `InpMinBreakPct` | 0 / 3 / 5 / 10 |
| Bar tanasi | `InpMinBodyPct` | 0 / 25 / 40 |
| Kech kirish | `InpMaxEntryDistPct` | 0 / 30 / 50 / 75 |
| Kunlik limit | `InpMaxTradesPerDay` | 0 / 2 / 3 |
| Hafta kuni | `InpMon`…`InpFri` | Dushanba/Jumani alohida o'chirib ko'ring |

**Qoida:** filtr savdolar sonini 20% dan ko'p kamaytirsa va Profit Factor
ni oshirmasa — **o'chirib tashlang**. U faqat overfitting.

---

## 5-QADAM: Break-even / Trailing — EHTIYOT BO'LING

```
InpUseBreakEven = true
InpBE_TriggerR  = 1.5    ← 1.0 EMAS! (1.0 da foydali savdolar o'ldiriladi)
InpBE_LockR     = 0.30
```

RR 2.0 tizimida BE ni **+1.5R** dan oldin yoqmang. +1.0R da yoqish
2R ga boradigan savdolarning yarmini +0.15R ga aylantiradi — bu mening
v3.3 dagi asosiy xatoim edi.

Trailing ni faqat `TP_RANGE_MULT` bilan birga sinang (TP yaqin bo'lganda
trailing kam zarar keltiradi).

---

## Optimizatsiya sozlamalari (Strategy Tester)

| | |
|---|---|
| Simvol / TF | XAUUSD / **M15** |
| Model | `Every tick based on real ticks` |
| Davr | **In-sample:** 2 yil, **Out-of-sample:** keyingi 1 yil |
| Optimization | `Slow complete algorithm` yoki `Fast genetic` |
| Criterion | **`Complex Criterion max`** (Net Profit emas!) |
| `InpVerboseLog` | **false** (log optimizatsiyani sekinlashtiradi) |

### Overfitting dan saqlanish
1. Optimizatsiyani **faqat 2 yilda** qiling
2. Eng yaxshi 5 ta natijani oling
3. Ularni **ko'rmagan 1 yilda** test qiling
4. Ikkala davrda ham ishlaydiganini tanlang
5. Parametr **platosini** qidiring: 0.45/0.50/0.55 hammasi yaxshi bo'lsa —
   ishonchli. Faqat 0.50 yaxshi bo'lsa — bu shovqin.

---

## Menga kerak bo'lgan ma'lumot

Keyingi qadamni aniq ayta olishim uchun:

1. **0-qadam natijasi** — v40 va asl kod bir xilmi?
2. **Asl kodning aniq raqamlari:** savdolar soni, Win%, Profit Factor,
   Max DD%, Net Profit, test davri
3. **v3.x raqamlari** (bittasi ham bo'ladi) — qanchalik yomon edi
4. **Journal ning birinchi bloki:** `Digits`, `Point`, `1 punkt=`,
   `Max spread = ... = $X` qatorlari
5. **Broker/server vaqti** — sessiya soatlarini to'g'rilash uchun

Ayniqsa **2-punkt** muhim. "Ishlaydi" degan baza raqamsiz bo'lsa,
biz nimani yaxshilayotganimizni bilmaymiz.
