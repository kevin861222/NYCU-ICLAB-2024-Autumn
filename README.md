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

Auto Focus : 算出圖片正中心的 2x2 灰階、4x4 灰階、6x6 灰階，然後計算任兩個元素間的差值絕對值，加總後除上權重，找出答案最大的 idx。聽起來有點艱澀，不過看了題目就知道了。

Auto Exposure : 獲得一個權重(x0.25 / x0.5 / x1 / x2)，將所有元素乘上該權重後算出整張圖片的灰階，除上 32*32。

Average of Min and Max in the Picture : 分別找出 R , G , B 中的最大值以及最小值，將 R_max , G_max , B_max 相加除三，將 R_min , G_min , B_min 相加除三，再將結果相加除二。

### 時程
我大概花了五天時間完成這份實驗，看題目想架構花了兩天，兩天寫 code 、debug ，最後一天優化，pattern 是用管神的加上 max_min avg 功能，所以五天的時程不包含寫 pattern 。

### Tips
1. 資料共用
除非遇上 Auto Exposure 導致圖片內元素改變，否則 Average of Min and Max in the Picture 、 Auto Focus 的答案不會更動。因此只在倍率改變時訪問 DRAM ，並一次計算出三種功能的答案，將其存放於 DFF 中。

備註：每張圖片首次訪問若不是 Auto Exposure 功能，則以 Auto Exposure x1 的方式訪問。
   
2. 預判 0 圖

一張圖片遇上多次 x0.5 / x0.25 後會將所有元素歸零，此時不論如何所有功能的答案都是 0 ，將不再需要訪問 DRAM 。

4. 解 critical path
Clock Period 決勝負，把所有能切的東西切一遍就完事了。

此部分比較瑣碎，講個大概意思有到就好。

1. critical path 發生在 cnt 判斷式上
```verilog
always @(posedge clk) begin
   if (cnt == 30) begin
     // do something
   end else begin 
     // do something
   end
end
```

可以改成這樣

```verilog
always @(posedge clk) cnt_is_30 <= (cny == 29);
always @(posedge clk) begin
   if (cnt_is_30) begin
     // do something
   end else begin 
     // do something
   end
end
```

2. critical path 發生在 demux / mux 上

```verilog
always @(posedge clk) begin
   if (in_valid)
      in_pic_no_q <= in_pic_no;
end

always @(posedge clk) begin
   info[in_pic_no_q] <= info_n;
end
```

此處的程式很簡潔，但是合成出來的電路卻很大一包，" info[in_pic_no_q] <= info_n; " 隱含由比較器構成的索引功能，相當於
```verilog
always @(posedge clk) begin
   for (int i = 0; i < 16; i++) begin
       if (in_pic_no_q == i) begin
           info[i] <= info_n;
       end
   end
end
```

此處的 "in_pic_no_q == i" 也可用同樣的方法擋一顆 DFF。


3. critical path 發生在運算單元上。

```verilog
always @(posedge clk) begin
   div_result <= div_in / 3 ;
end
```

發生在這種地方就非常頭痛了，能用 DW_ip 的話就直接叫一顆 multi-stages 除法器，但偏偏這次不能用，就只能手刻 pipeline 除法器了。

除法、乘法可以切 pipeline ，若是加減法，可以改成較低位元的運算，以多個 cycle 完成。

4. critical path 發生在 input/output。

通常都是切到走火入魔才會遇到這種問題。

```verilog
always @(posedge clk) begin
   if (awready_s_inf)
      // do something
end
```

這邊的 awready_s_inf 是 input 訊號，會有 0.5T input slack，解法就是找其他等價訊號替代掉 awready_s_inf 。

```verilog
always @(posedge clk) begin
   awvalid_q <= awvalid;
   awvalid_qq <= awvalid_q;
end
always @(posedge clk) begin
   if (awvalid_qq)
      // do something
end
```
不過這種情況應該只有 iclab 會遇到，不太實際。

### 鳴謝
特別感謝 

Bonbodii  -> [GitHub Home Page](https://github.com/Bonbodii) <-

chance-chhong -> [GitHub Home Page](https://github.com/chance-chhong) <-

Anonymous A -> [GitHub Home Page](https://github.com/aelog134256) <- 

Allen Kuan -> [GitHub Home Page](https://github.com/c20kyo1827/) <-

### 備註

1. RANK 是我自己換算出來的
2. 2.4ns 版本 critical path 長在加法器上，繼續切可以壓到 1.8 ns ，但是控制訊號也要爆改，我就玩玩沙，差不多就行了。
