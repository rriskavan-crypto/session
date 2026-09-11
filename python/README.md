# Python backtest muhiti

MT5 Strategy Tester o'rniga — men **o'zim** ishga tushira oladigan engine.
Bitta konfiguratsiya ~2 sekund, 50 ta konfiguratsiya ~1 daqiqa.

## Fayllar
| Fayl | Nima |
|---|---|
| `sbgold.py` | Engine — EA mantiqini aynan takrorlaydi |
| `data.py` | MT5 CSV yuklovchi + sintetik generator |
| `run.py` | Bitta backtest (CLI) |
| `sweep.py` | Ommaviy sinov — barcha g'oyalarni solishtiradi |

## Ma'lumot qayerdan
`MQL5/Experts/ExportBars.mq5` skriptini MT5 `MQL5\Scripts\` ga qo'yib
ishga tushiring. U `MQL5\Files\XAUUSD_PERIOD_M15.csv` yaratadi va
Journal ga broker ma'lumotlarini bosadi.

## Ishlatish
```bash
# bitta test
python3 run.py --csv XAUUSD_PERIOD_M15.csv --spread 0.30

# hamma g'oyalarni solishtirish
python3 sweep.py --csv XAUUSD_PERIOD_M15.csv --spread 0.30

# engine ni tekshirish (sintetik — natija ma'nosiz, faqat mexanika)
python3 sweep.py --synth 500
```

## Muhim
Sintetik ma'lumot **strategiya natijasini bildirmaydi** — u tasodifiy
yurish, unda haqiqiy bozor tuzilmasi yo'q. Faqat engine to'g'ri
ishlayotganini tekshirish uchun.

Engine tekshiruvi: `SL` chiqishlari aniq **−1.00R**, `TP` chiqishlari
aniq **+2.00R** berishi kerak. Bu SL/TP matematikasi to'g'ri
takrorlanganini isbotlaydi.
