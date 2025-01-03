# NYCU-ICLAB-2024-Autumn-場外篇
## Image Signal Processor (ISP)
### Performance
- Clock Period : 2.4 ns
- Total Latency : 40303 cycles
- RTL Area (03_gate_sim) : 251327.664931  μ𝑚<sup>2 </sup>
- Performance : (Total Cycle x Clock Period)<sup>2</sup> x Area = 2.35146 E+15
- Rank : 2 / 173

![截圖 2025-01-03 下午11 51 06](https://github.com/user-attachments/assets/8ac81f9e-4e8c-49d6-90eb-35957ff65693)

![截圖 2025-01-03 下午11 50 52](https://github.com/user-attachments/assets/ed5e634f-de7e-4f8f-9df6-e9441d23246d)

### 實驗概述
相較往年是一個非常佛心的 final project，主要就是實現以下四個功能。
1. AXI 讀寫 DRAM 。
2. 瑣碎但簡單的運算（加減、除法、比大小）。
3. 切 pipeline 壓低 Clock Period 。
4. 預判圖片內資訊（後面詳述），減少 DRAM 讀寫需求。


### 實驗評論
1. 這是一個看起來非常簡單，實際上也非常簡單的實驗。
2. 學不太到東西。
3. 這屆學生面試可能會擔心沒東西放。

### 開發
我大概花了五天時間完成這份實驗，

### Tips


### APR

