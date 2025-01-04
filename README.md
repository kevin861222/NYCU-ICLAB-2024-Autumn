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

### 電路功能摘要
1. DRAM 存放 16 張 32x32x3 圖片，每張圖由 R , G , B 三張子圖組成。
2. 共有三個功能：Auto Focus , Auto Exposure , Average of Min and Max in the Picture

Auto Focus : 算出圖片正中心的 2x2 灰階、4x4 灰階、6x6 灰階，然後計算任兩個元素間的差值絕對值，加總後除上權重，找出答案最大的 idx 。
<br> 聽起來有點艱澀，不過看了題目就知道了。

Auto Exposure : 獲得一個權重(x0.25 / x0.5 / x1 / x2)，將所有元素乘上該權重後算出整張圖片的灰階，除上 32*32。

Average of Min and Max in the Picture : 分別找出 R , G , B 中的最大值以及最小值，將 R_max , G_max , B_max 相加除三，將 R_min , G_min , B_min 相加除三，再將結果相加除二。

### 時程
我大概花了五天時間完成這份實驗，看題目想架構花了兩天，兩天寫 code 、debug ，最後一天優化，pattern 是用管神的加上 max_min avg 功能，所以五天的時程不包含寫 pattern 。

### Tips
1. 資料共用

   
3. 預判 0 圖
4. 切爛


### APR

