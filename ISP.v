/*
in_ratio_mode :
0 -> 0.25
1 -> 0.5
2 -> 1
3 -> 2

in mode :
0 Auto Focus
1 Auto Exposure
2 Average of min max value
*/

// 32 * 32 = 4*8 * 4*8 = 2*2 * 2*2*2 * 2*2 * 2*2*2 (>>10)
// R , B -> 0.25
// G -> 0.5

// TODO : 1l35/4rup4jo4ru4gj4rfu4


module ISP(
    // Input Signals
    input clk,
    input rst_n,
    input in_valid,
    input [3:0] in_pic_no,
    input [1:0] in_mode,
    input [1:0] in_ratio_mode,
    // Output Signals
    output reg out_valid,
    output reg [7:0] out_data,
    // DRAM Signals
    // axi write address channel
    // src master
    output [3:0]  awid_s_inf,
    output reg [31:0] awaddr_s_inf,
    output reg [2:0]  awsize_s_inf,
    output reg [1:0]  awburst_s_inf,
    output reg [7:0]  awlen_s_inf,
    output reg    awvalid_s_inf,
    // src slave
    input         awready_s_inf,
    // -----------------------------
    // axi write data channel 
    // src master
    output reg [127:0] wdata_s_inf,
    output reg         wlast_s_inf,
    output reg         wvalid_s_inf,
    // src slave
    input          wready_s_inf,
    // axi write response channel 
    // src slave
    input [3:0]    bid_s_inf,
    input [1:0]    bresp_s_inf,
    input          bvalid_s_inf,
    // src master 
    output reg     bready_s_inf,
    // -----------------------------
    // axi read address channel 
    // src master
    output [3:0]   arid_s_inf,
    output [31:0]  araddr_s_inf,
    output reg [7:0]   arlen_s_inf,
    output reg [2:0]   arsize_s_inf,
    output reg [1:0]   arburst_s_inf,
    output reg     arvalid_s_inf,
    // src slave
    input          arready_s_inf,
    // -----------------------------
    // axi read data channel 
    // slave
    input [3:0]    rid_s_inf,
    input [127:0]  rdata_s_inf,
    input [1:0]    rresp_s_inf,
    input          rlast_s_inf,
    input          rvalid_s_inf,
    // master
    output reg     rready_s_inf
);

// -------------  parameter declaration ------------- // 
// delay
reg delay_q[0:5]  ;


//* input DFF
reg [3:0] in_pic_no_q;
enum logic [1:0] {Focus = 2'b00 , Exposure = 2'b01, Max_Min = 2'b10} in_mode_q;
enum logic [1:0] {x0_25 = 2'b00 , x0_5 = 2'b01, x1 = 2'b10, x2 = 2'b11} in_ratio_mode_q;

//* info <pic_no>
reg [7:0] exp_reg [0:15] , max_min_reg [0:15] , focus_reg [0:15];
reg dead_reg [0:15] , empty_reg [0:15];
reg [3:0] magnification_reg [0:15] ;
reg [2:0] max_magnification_reg [0:15] ;

//* info_cal
reg [7:0] info_exp , info_max_min , info_focus;
reg info_dead , info_empty;
reg [3:0] info_magnification ;
reg [2:0] info_max_magnification ;
reg info_change_magnification ;

//* info update 
reg whether_dead;
reg [3:0] n_magnification ;
wire n_empty = 0 ;

//* FSM : state, n_state
enum logic [2:0] {WAIT = 3'd0, DECODE = 3'd1, CHECKandUPDATE = 3'd2, READ = 3'd3 , OUTPUT = 3'd4 , UPDATE_ANS = 3'd5 } state, n_state ;

//* FSM : control signal
reg decode_done;
reg need_read;

//* reduce critical path 
reg state_is_checkandupdate;
reg state_go_output_from_decode ;
reg state_is_read;
reg idx_is_n [0:15];

//* AXI 
enum logic [31:0] { Zero = 32'd0 ,
                    A_00 = 32'b0000_0000_0000_0001_0000_0000_0000_0000 ,
                    A_01 = 32'b0000_0000_0000_0001_0000_1100_0000_0000 ,
                    A_02 = 32'b0000_0000_0000_0001_0001_1000_0000_0000 ,
                    A_03 = 32'b0000_0000_0000_0001_0010_0100_0000_0000 ,
                    A_04 = 32'b0000_0000_0000_0001_0011_0000_0000_0000 ,
                    A_05 = 32'b0000_0000_0000_0001_0011_1100_0000_0000 ,
                    A_06 = 32'b0000_0000_0000_0001_0100_1000_0000_0000 ,
                    A_07 = 32'b0000_0000_0000_0001_0101_0100_0000_0000 , 
                    A_08 = 32'b0000_0000_0000_0001_0110_0000_0000_0000 ,
                    A_09 = 32'b0000_0000_0000_0001_0110_1100_0000_0000 ,
                    A_10 = 32'b0000_0000_0000_0001_0111_1000_0000_0000 ,
                    A_11 = 32'b0000_0000_0000_0001_1000_0100_0000_0000 ,
                    A_12 = 32'b0000_0000_0000_0001_1001_0000_0000_0000 ,
                    A_13 = 32'b0000_0000_0000_0001_1001_1100_0000_0000 ,
                    A_14 = 32'b0000_0000_0000_0001_1010_1000_0000_0000 ,
                    A_15 = 32'b0000_0000_0000_0001_1011_0100_0000_0000 } AR_addr_q , AW_addr_q ;

reg [7:0] R_data [0:15] , R_data_q [0:15] , R_data_qq [0:15];

reg rvalid_q , rvalid_qq , rvalid_qqq ;
reg rlast_q ;
reg rready_q , rready_qq , rready_qqq , rready_qqqq , rready_qqqqq  ;
reg acc_start ;

//* computing resourse
reg [6:0] cnt127 ; //! 0~63
reg cnt255_flag ;

// black magic
// reg cnt255_flag ;

wire pic_is_G = cnt127[6] ;
reg cnt127_is_3 ;

// Focus
reg data_is_valid ;
reg [7:0] gray [0:11][0:2];
reg [6:0] captured_data [0:2];
reg [6:0] captured_data_weight [0:2] ;
// reg [6:0] focus_buffer_0 [0:3] , focus_buffer_1 [0:3] , focus_buffer_2 [0:3] ;
reg [7:0] horizontal_diff_a [0:1] , horizontal_diff_b [0:1] , h_diff[0:1];
reg [7:0] horizontal_diff_cross_a , horizontal_diff_cross_b , h_diff_cross ;
reg [7:0] vertical_diff_a [0:2] , vertical_diff_b [0:2] , v_diff[0:2];

reg [8:0] D_2x2_h_acc , D_2x2_v_acc ;
wire [9:0] D_2x2_sum = D_2x2_h_acc + D_2x2_v_acc ;
reg [7:0] D_2x2_ans ;

reg [9:0] D_4x4_h_mid_acc ;
reg [9:0] D_4x4_h_12_acc , D_4x4_h_01_acc;
reg cnt127_is_29 , cnt127_is_30 , cnt127_is_31 , cnt127_is_32 , cnt127_is_33 , cnt127_is_34 , cnt127_is_35 , cnt127_is_36 , cnt127_is_37 , cnt127_is_38 , cnt127_is_39 , cnt127_is_40 ;
reg [10:0] D_4x4_v_mid_acc ;
reg [10:0] D_4x4_v_corner_acc ;

reg [10:0] D_4x4_sum_p0 ;
reg [7:0] D_4x4_ans ;
reg D_4x4_period , D_4x4_period_q , D_4x4_period_odd , D_4x4_period_even ;
reg [11:0] D_4x4_v_sum ;
reg [11:0] D_4x4_v_h_sum ;
wire [11:0] D_4x4_sum  = D_4x4_h_mid_acc + D_4x4_v_h_sum ;

reg [11:0] D_6x6_total_div4 ;
reg D_6x6_period , D_6x6_period_even ;
reg [11:0] D_6x6_h_acc_01 , D_6x6_h_acc_12 , D_6x6_h_acc_mid ;
reg [11:0] D_6x6_v_acc_0 , D_6x6_v_acc_1 , D_6x6_v_acc_2 ;
reg [12:0] D_6x6_sum_0 , D_6x6_sum_1 , D_6x6_sum_2 ;
reg [13:0] D_6x6_sum_01 ;
wire [13:0] D_6x6_total_sum = D_6x6_sum_01 + D_6x6_sum_2 ;

reg [1:0] focus_candidate_idx , focus_max_one_idx ;
reg [7:0] focus_candidate ;
wire [7:0] focus_ans = {6'd0 , focus_max_one_idx} ;

// Exposure
reg [7:0] exp_sum_0 [0:7] ; 
reg [8:0] exp_sum_1 [0:3] ;
reg [9:0] exp_sum_2 [0:1] ;
reg [10:0] exp_sum_3 ;
reg [17:0] accumulator ;
wire [7:0] exp_avg_ans = accumulator [17:10] ;
wire [7:0] exp_ans = exp_avg_ans ; //! just renamed

// Max_Min
reg [7:0] max_list_0 [0:7], min_list_0 [0:7] , max_list_1 [0:3], min_list_1 [0:3] , max_list_2 [0:1] , min_list_2 [0:1] , max_one , min_one ;
reg [7:0] max_RGB , min_RGB ;
reg [9:0] max_sum , min_sum ;
wire [8:0] max_sum_div3 , min_sum_div3 ;
reg [8:0] max_min_sum ;
wire [7:0] max_min_ans = max_min_sum [8:1] ;

// ------------- input DFF ------------- //
always @(posedge clk or negedge rst_n) begin:FF_input_DFF
    if (!rst_n) begin
        in_pic_no_q <= 4'd0;
        in_mode_q <= 2'd0;
    end else if (in_valid) begin
        in_pic_no_q <= in_pic_no;
        in_mode_q <= in_mode;
    end
end

// always @(posedge clk or negedge rst_n) begin:FF_in_ratio_mode_q
//     if (!rst_n) begin
//         in_ratio_mode_q <= 2'd0;
//     end else if (in_valid & in_mode[0]) begin
//         in_ratio_mode_q <= in_ratio_mode;
//     end
// end

always @(posedge clk) begin:FF_in_ratio_mode_q
    if (in_valid) begin
        if (in_mode[0]) 
            in_ratio_mode_q <= in_ratio_mode;
        else 
            in_ratio_mode_q <= x1 ;
    end
end

// ------------- FSM ------------- //

always @(posedge clk or negedge rst_n) begin:FF_decode_done
    if (!rst_n)  decode_done <= 1'b0;
    else decode_done <= (state == DECODE);
end

// timing of need_read 
// first time access a picture or the picture's magnification is changed
// and the picture is not going to be dead
always @(*) begin:comb_need_read
    if ((info_empty || info_change_magnification) && ~( ~n_magnification[3] && (n_magnification[2:0] == info_max_magnification))) begin
        need_read = 1 ;
    end else begin
        need_read = 0 ;
    end
end

always @(posedge clk or negedge rst_n) begin:FF_state 
    if (!rst_n) begin
        state <= WAIT;
    end else begin
        state <= n_state;
    end
end

always @(*) begin:comb_n_state
    case (state)
        WAIT: begin
            if (in_valid) begin
                n_state = DECODE;
            end else begin
                n_state = WAIT;
            end
        end
        DECODE: begin
            if (decode_done) begin
                if (~info_dead) begin
                    n_state = CHECKandUPDATE;
                end else begin
                    n_state = OUTPUT;
                end
            end else begin
                n_state = DECODE;
            end
        end
        CHECKandUPDATE: begin
            if (need_read) begin 
                // (info_empty || info_change_magnification) && 
                // ~( ~n_magnification[3] && (n_magnification[2:0] == info_max_magnification))
                n_state = READ;
            end else begin
                n_state = OUTPUT ;
            end
        end
        OUTPUT: begin
            n_state = WAIT;
        end
        READ: begin
            if (delay_q[5]) begin
                n_state = OUTPUT ;
            end else begin
                n_state = READ ;
            end
        end
        // UPDATE_ANS: begin
        //     n_state = OUTPUT ;
        // end
        default: n_state = WAIT;
    endcase
end



always @(posedge clk or negedge rst_n) begin:FF_delay
    if (!rst_n) begin
        delay_q[0] <= 0 ;
        delay_q[1] <= 0 ;
        delay_q[2] <= 0 ;
        delay_q[3] <= 0 ;
        delay_q[4] <= 0 ;
        delay_q[5] <= 0 ;
    end else begin
        delay_q[0] <= ~rready_qqqq & rready_qqqqq ;
        delay_q[1] <= delay_q[0] ;
        delay_q[2] <= delay_q[1] ;
        delay_q[3] <= delay_q[2] ;
        delay_q[4] <= delay_q[3] ;
        delay_q[5] <= delay_q[4] ;
    end
end
// -------------  picture info ------------- // 

// dead_reg means a picture is dead. 
// That is the elements of the picture are all 0.
always @(posedge clk or negedge rst_n) begin:FF_dead_reg
    if (!rst_n) begin
        for (int i = 0; i < 16; i++) begin
            dead_reg[i] <= 1'b0;
        end
    end else begin
        if (/*state == CHECKandUPDATE*/ state_is_checkandupdate && whether_dead) begin
            for (int i = 0; i < 16; i++) begin
                if (idx_is_n[i]) begin
                    dead_reg[i] <= 1'b1;
                end
            end
        end
    end
end

// empty_reg means a picture is brand new. 
// So there is no answer for "focus" , "max_min" and "exp".
always @(posedge clk or negedge rst_n) begin:FF_empty_reg
    if (!rst_n) begin
        for (int i = 0; i < 16; i++) begin
            empty_reg[i] <= 1'b1;
        end
    end else begin
        if (/*state == CHECKandUPDATE*/ state_is_checkandupdate) begin
            for (int i = 0; i < 16; i++) begin
                if (idx_is_n[i]) begin
                    empty_reg[i] <= n_empty;
                end
            end
        end
    end
end

// magnification_reg means the magnification of a picture.
always @(posedge clk or negedge rst_n) begin:FF_magnification_reg
    if (!rst_n) begin
        for (int i = 0; i < 16; i++) begin
            magnification_reg[i] <= 4'd8;
        end
    end else begin
        if (/*state == CHECKandUPDATE*/ state_is_checkandupdate) begin
            for (int i = 0; i < 16; i++) begin
                if (idx_is_n[i]) begin
                    magnification_reg[i] <= n_magnification;
                end
            end
        end
    end
end

// max_magnification_reg means the maximum magnification of a picture.
always @(posedge clk or negedge rst_n) begin:FF_max_magnification_reg
    if (!rst_n) begin
        for (int i = 0; i < 16; i++) begin
            max_magnification_reg[i] <= 3'd0;
        end
    end else begin
        if (/*state == CHECKandUPDATE*/ state_is_checkandupdate) begin
            if (n_magnification[3] && (n_magnification[2:0] > info_max_magnification)) begin
                for (int i = 0; i < 16; i++) begin
                    if (idx_is_n[i]) begin
                        max_magnification_reg[i] <= n_magnification[2:0];
                    end
                end
            end
        end
    end
end

always @(posedge clk or negedge rst_n) begin:FF_info_change_magnification
    if (!rst_n) begin
        info_change_magnification <= 1'b0;
    end else begin
        info_change_magnification <= (in_mode_q[0] && (in_ratio_mode_q != 2) ) ;
    end
end

always @(posedge clk) begin:FF_info_magnification
    info_magnification <= magnification_reg[in_pic_no_q];
end

always @(posedge clk or negedge rst_n) begin:FF_info_max_magnification
    if (!rst_n) begin
        info_max_magnification <= 3'b000;
    end else begin
        info_max_magnification <= max_magnification_reg[in_pic_no_q];
    end
end

always @(posedge clk or negedge rst_n) begin:FF_info_empty
    if (!rst_n) begin
        info_empty <= 1'b1;
    end else begin
        info_empty <= empty_reg[in_pic_no_q];
    end
end

always @(posedge clk or negedge rst_n) begin:FF_info_dead
    if (!rst_n) info_dead <= 0 ;
    else info_dead <= dead_reg[in_pic_no_q];
end

always @(posedge clk) begin:FF_info_exp_max_min_focus
    info_exp <= exp_reg[in_pic_no_q];
    info_max_min <= max_min_reg[in_pic_no_q];
    info_focus <= focus_reg[in_pic_no_q];
end

// -------------  picture info update ------------- // 

always @(*) begin:comb_whether_dead
    whether_dead = ~n_magnification[3] && (n_magnification[2:0] == info_max_magnification) ;
end

always @(posedge clk or negedge rst_n) begin:FF_n_magnification
    if (!rst_n) begin
        n_magnification <= 0 ;
    end else begin
        case (in_ratio_mode_q)
            0: begin 
                if (info_magnification[3:1] == 0) begin // overflow prevent
                    n_magnification <= 0 ;
                end else begin 
                    n_magnification <= info_magnification - 2 ;
                end 
            end 
            1: begin
                if (info_magnification[3:1] == 0) begin // overflow prevent
                    n_magnification <= 0 ;
                end else begin 
                    n_magnification <= info_magnification - 1 ;
                end
            end 
            2: n_magnification <= info_magnification ;
            3: begin 
                if (info_magnification[3:1] == 3'b111) begin
                    n_magnification <= 15 ;
                end else begin 
                    n_magnification <= info_magnification + 1 ;
                end
            end
        endcase
    end
end

always @(posedge clk) begin:FF_info_ans_update
    if (state_is_read) begin 
        for (int i = 0; i < 16; i++) begin
            if (idx_is_n[i]) begin
                exp_reg[i] <= exp_ans;
                max_min_reg[i] <= max_min_ans;
                focus_reg[i] <= focus_ans;
            end
        end
    end
end

// always @(posedge clk) begin:FF_info_ans_update
//     if (stare == READ) begin 
//         focus_reg[in_pic_no_q] <= focus_ans;
//     end
// end

// -------------  AXI ------------- // 
//* const signals */
assign awid_s_inf = 0 ;
assign arid_s_inf = 0 ;
always @(posedge clk or negedge rst_n) awsize_s_inf     <= (!rst_n)? 0 : 3'b100;
always @(posedge clk or negedge rst_n) awburst_s_inf    <= (!rst_n)? 0 : 2'b01 ;
always @(posedge clk or negedge rst_n) awlen_s_inf      <= (!rst_n)? 0 : 'd191 ;
always @(posedge clk or negedge rst_n) arsize_s_inf     <= (!rst_n)? 0 : 3'b100;
always @(posedge clk or negedge rst_n) arburst_s_inf    <= (!rst_n)? 0 : 2'b01 ;

//* READ *// 
// read request 
always @(posedge clk or negedge rst_n) begin:FF_arvalid_s_inf
    if (!rst_n) begin
        arvalid_s_inf <= 0;
    end else begin
        arvalid_s_inf <= need_read && state_is_checkandupdate ;
    end
end

assign araddr_s_inf = AR_addr_q;
always @(posedge clk or negedge rst_n) begin:FF_AR_addr_q
    if (!rst_n) begin
        AR_addr_q <= Zero;
    end else begin
        case (in_pic_no_q)
            0 : AR_addr_q <= A_00;
            1 : AR_addr_q <= A_01;
            2 : AR_addr_q <= A_02;
            3 : AR_addr_q <= A_03;
            4 : AR_addr_q <= A_04;
            5 : AR_addr_q <= A_05;
            6 : AR_addr_q <= A_06;
            7 : AR_addr_q <= A_07;
            8 : AR_addr_q <= A_08;
            9 : AR_addr_q <= A_09;
            10: AR_addr_q <= A_10;
            11: AR_addr_q <= A_11;
            12: AR_addr_q <= A_12;
            13: AR_addr_q <= A_13;
            14: AR_addr_q <= A_14;
            15: AR_addr_q <= A_15;
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin:FF_arlen_s_inf
    if (!rst_n) arlen_s_inf <= 0 ;
    else arlen_s_inf <=  191 ;
end

// read data 

always @(posedge clk or negedge rst_n) begin:FF_rready_s_inf
    if (!rst_n) rready_s_inf <= 0 ;
    else rready_s_inf <= rvalid_qqq ;
end

// R_data[0] = rdata_s_inf[7:0]
// R_data[15] =  rdata_s_inf[127:120]
always @(*) begin:comb_R_data
    for (int i = 0; i < 16; i++) begin
        R_data[i] = rdata_s_inf[127-8*(15-i)-:8];
    end
end

always @(posedge clk) begin:FF_R_data_q
    if (in_mode_q[0] & ~in_ratio_mode_q[1]) begin 
        for (int i = 0; i < 16; i++) begin
            R_data_q[i] <= {1'b0 , R_data[i][7:1]};
        end
    end else begin 
        for (int i = 0; i < 16; i++) begin
            R_data_q[i] <= R_data[i];
        end
    end 
end

always @(posedge clk or negedge rst_n) begin:FF_R_data_qq
    if (!rst_n) begin
        for (int i = 0; i < 16; i++) begin
            R_data_qq[i] <= 8'b0 ;
        end
    end
    else begin 
        if (in_mode_q[0] && in_ratio_mode_q==0) begin // x0.25
            for (int i = 0; i < 16; i++) begin
                R_data_qq[i] <= {1'b0 , R_data_q[i][7:1]};
            end
        end else if (in_mode_q[0] && in_ratio_mode_q==3) begin // x2
            for (int i = 0; i < 16; i++) begin
                if (R_data_q[i][7]) begin
                    R_data_qq[i] <= 8'b1111_1111 ;
                end else begin
                    R_data_qq[i] <= {R_data_q[i][6:0],1'b0};
                end
            end
        end else begin
            for (int i = 0; i < 16; i++) begin
                R_data_qq[i] <= R_data_q[i];
            end
        end
    end
end

// read control ----------------

// rready_qq is equal to 
always @(posedge clk or negedge rst_n) begin:FF_rready_qq
    if (!rst_n) begin 
        rready_q <= 0 ;
        rready_qq <= 0 ;
    end else begin
        rready_q <= rready_s_inf ;
        rready_qq <= rready_q ;
    end
end

always @(posedge clk or negedge rst_n) begin:FF_rready_qqq
    if (!rst_n) begin 
        rready_qqq <= 0 ;
        rready_qqqq <= 0 ;
        rready_qqqqq <= 0 ;
    end else begin 
        rready_qqq <= rready_qq ;
        rready_qqqq <= rready_qqq ;
        rready_qqqqq <= rready_qqqq ;
    end
end

always @(posedge clk) begin:FF_cnt127;
    // if (!rst_n) cnt127 <= 0 ;
    // else 
    if (rready_qq) begin
        cnt127 <= cnt127 + 1 ;
    end else begin
        cnt127 <= 0 ;
    end
end

// reg cnt255_flag ;
// always @(posedge clk) begin:FF_cnt255_flag
//     if (&cnt127) begin
//         cnt255_flag <= 1 ;
//     end else if (~rready_qq) begin
//         cnt255_flag <= 0 ;
//     end
// end
always @(posedge clk) begin:FF_cnt255_flag
    if (&cnt127) begin
        cnt255_flag <= 1 ;
    end else if (~rready_qq) begin
        cnt255_flag <= 0 ;
    end
end

//* WRITE *//

// write request 

always @(posedge clk or negedge rst_n) begin:FF_rvalid_q
    if (!rst_n) begin
        rvalid_q <= 0;
        rvalid_qq <= 0;
        rvalid_qqq <= 0;
    end else begin 
        rvalid_q <= rvalid_s_inf ;
        rvalid_qq <= rvalid_q ;
        rvalid_qqq <= rvalid_qq ;
    end 
end

always @(*) begin:comb_awvalid_s_inf
    awvalid_s_inf = rvalid_q & ~rvalid_qqq ;
end

always @(*) AW_addr_q = AR_addr_q ;
always @(*) awaddr_s_inf = AR_addr_q ;

// write data 

always @(*) begin:comb_wdata_s_inf
    wdata_s_inf = {R_data_qq[15],R_data_qq[14],R_data_qq[13],R_data_qq[12],R_data_qq[11],R_data_qq[10],R_data_qq[9],R_data_qq[8],R_data_qq[7],R_data_qq[6],R_data_qq[5],R_data_qq[4],R_data_qq[3],R_data_qq[2],R_data_qq[1],R_data_qq[0]};
end

always @(*) begin:comb_wvalid_s_inf
    wvalid_s_inf = rvalid_qq ;
end

always @(posedge clk or negedge rst_n) begin:FF_rlast_q
    if (!rst_n) begin 
        rlast_q <= 0 ;
    end else begin
        rlast_q <= rlast_s_inf ;
    end
end

always @(posedge clk or negedge rst_n) begin:FF_wlast_s_inf
    if (!rst_n) begin 
        wlast_s_inf <= 0 ;
    end else begin 
        wlast_s_inf <= rlast_q ;
    end
end

// write response 
always @(posedge clk or negedge rst_n) bready_s_inf = (!rst_n)? 0 : 1 ;

// write control ----------------

// -------------  Auto Focus ------------- //
// control 
always @(posedge clk or negedge rst_n) begin:FF_data_is_valid
    if (!rst_n) begin
        data_is_valid <= 0 ;
    end else begin 
        if (cnt127[5:0] == 25) begin
            data_is_valid <= 1 ;
        end else if (cnt127[5:0] == 37) begin 
            data_is_valid <= 0 ;
        end
    end 
end

// data buffer 
always @(*) begin:comb_captured_data
    if (cnt127[0]) begin
        captured_data[0] = R_data_qq[0][7:1] ;
        captured_data[1] = R_data_qq[1][7:1] ;
        captured_data[2] = R_data_qq[2][7:1] ;
    end else begin
        captured_data[0] = R_data_qq[13][7:1] ;
        captured_data[1] = R_data_qq[14][7:1] ;
        captured_data[2] = R_data_qq[15][7:1] ;
    end
end

always @(*) begin:comb_captured_data_weight
    if (cnt127[6]) begin // G 
        captured_data_weight[0] = captured_data[0] ;
        captured_data_weight[1] = captured_data[1] ;
        captured_data_weight[2] = captured_data[2] ;
    end else begin // R and B
        captured_data_weight[0] = {1'b0,captured_data[0][6:1]};
        captured_data_weight[1] = {1'b0,captured_data[1][6:1]};
        captured_data_weight[2] = {1'b0,captured_data[2][6:1]};
    end
end

always @(posedge clk) begin:FF_gray_shift
    if (data_is_valid) begin 
        for (int i = 0; i < 11; i++) begin
            gray[i][0] <= gray[i+1][0] ;
            gray[i][1] <= gray[i+1][1] ;
            gray[i][2] <= gray[i+1][2] ;
        end
    end
end

reg cnt255_flag_or_cnt127_6 ;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cnt255_flag_or_cnt127_6 <= 0 ;
    end else begin
        cnt255_flag_or_cnt127_6 <= cnt255_flag | cnt127[6] ;
    end
end

always @(posedge clk) begin:FF_gray_head 
    if (data_is_valid) begin
        if (cnt255_flag_or_cnt127_6) begin // G and B
            // critical path
            gray[11][0] <= captured_data_weight[0] + gray[0][0];
            gray[11][1] <= captured_data_weight[1] + gray[0][1];
            gray[11][2] <= captured_data_weight[2] + gray[0][2];
        end else begin // R 
            gray[11][0] <= captured_data_weight[0] ;
            gray[11][1] <= captured_data_weight[1] ;
            gray[11][2] <= captured_data_weight[2] ;
        end
    end
end

// vertical diff 
always @(posedge clk) begin:FF_vertical_diff_a_b
    for (int i = 0; i < 3; i++) begin
        if (gray[11][i] >= gray[9][i]) begin 
            vertical_diff_a[i] <= gray[11][i] ;
            vertical_diff_b[i] <= gray[9][i] ;
        end else begin 
            vertical_diff_a[i] <= gray[9][i] ;
            vertical_diff_b[i] <= gray[11][i] ;
        end 
    end
end

always @(posedge clk) begin:FF_v_diff
    for (int i = 0; i < 3; i++) begin
        v_diff[i] <= vertical_diff_a[i] - vertical_diff_b[i] ;
    end
end

// horizontal diff 
always @(posedge clk) begin:FF_horizontal_diff_a_b
    for (int i = 0; i < 2; i++) begin
        if (gray[11][i] >= gray[11][i+1]) begin
            horizontal_diff_a[i] <= gray[11][i] ;
            horizontal_diff_b[i] <= gray[11][i+1] ;
        end else begin
            horizontal_diff_a[i] <= gray[11][i+1] ;
            horizontal_diff_b[i] <= gray[11][i] ;
        end
    end
end

always @(posedge clk) begin:FF_h_diff
    for (int i = 0; i < 2; i++) begin
        h_diff[i] <= horizontal_diff_a[i] - horizontal_diff_b[i] ;
    end
end

always @(posedge clk) begin:FF_horizontal_diff_a_b_c
    if (gray[11][0] >= gray[10][2]) begin
        horizontal_diff_cross_a <= gray[11][0] ;
        horizontal_diff_cross_b <= gray[10][2] ;
    end else begin
        horizontal_diff_cross_a <= gray[10][2] ;
        horizontal_diff_cross_b <= gray[11][0] ;
    end
end

always @(posedge clk) begin:FF_h_diff_cross
    h_diff_cross <= horizontal_diff_cross_a - horizontal_diff_cross_b ;
end

// D_2x2 
// TODO reduse compare
always @(posedge clk) begin:FF_cnt127_is_34_36
    cnt127_is_29 <= cnt127[5:0] == 28 ; //y 
    cnt127_is_30 <= cnt127_is_29 ; //y
    cnt127_is_31 <= cnt127_is_30 ; //y
    cnt127_is_32 <= cnt127_is_31 ; //y
    cnt127_is_33 <= cnt127_is_32 ; //y
    cnt127_is_34 <= cnt127_is_33 ; //y
    cnt127_is_35 <= cnt127_is_34 ; //y
    cnt127_is_36 <= cnt127_is_35 ; //y
    cnt127_is_40 <= cnt127[5:0] == 39 ; // y
end

always @(posedge clk) begin:FF_D_2x2_h_acc
    if (cnt127_is_34) begin
        D_2x2_h_acc <= h_diff_cross ;
    end
    if (cnt127_is_36) begin
        D_2x2_h_acc <= D_2x2_h_acc + h_diff_cross ;
    end
end

always @(posedge clk) begin:FF_D_2x2_v_acc
    if (cnt127_is_35) begin 
        D_2x2_v_acc <= v_diff[2] ;
    end 
    if (cnt127_is_36) begin 
        D_2x2_v_acc <= D_2x2_v_acc + v_diff[0] ;
    end 
end

always @(posedge clk) begin:FF_D_2x2_ans
    D_2x2_ans <= D_2x2_sum[9:2] ;
end

// D_4x4 

// control 
always @(posedge clk) begin:FF_D_4x4_period
    if (cnt127[5:0] == 31) begin 
        D_4x4_period <= 1 ;
    end else if (cnt127[5:0] == 37) begin
        D_4x4_period <= 0 ;
    end
end

always @(posedge clk) begin:FF_D_4x4_period_q
    D_4x4_period_q <= D_4x4_period ;
end

always @(posedge clk) begin:FF_D_4x4_period_odd_even
    D_4x4_period_odd <= D_4x4_period & ~cnt127[0] ;
    D_4x4_period_even <= D_4x4_period & cnt127[0] ;
end

always @(posedge clk) begin:FF_D_4x4_h_mid_acc
    if (cnt127_is_32) begin
        D_4x4_h_mid_acc <= h_diff_cross ;
    end
    else if (D_4x4_period_even) begin
        D_4x4_h_mid_acc <= D_4x4_h_mid_acc + h_diff_cross ;
    end
end

always @(posedge clk) begin:FF_D_4x4_h_12_acc
    if (cnt127_is_31) begin 
        D_4x4_h_12_acc <= h_diff[1] ;
    end
    if (D_4x4_period_odd) begin 
        D_4x4_h_12_acc <= D_4x4_h_12_acc + h_diff[1] ;
    end
end

always @(posedge clk) begin:FF_D_4x4_h_01_acc
    if (cnt127_is_32) begin 
        D_4x4_h_01_acc <= h_diff[0] ;
    end 
    if (D_4x4_period_even) begin
        D_4x4_h_01_acc <= D_4x4_h_01_acc + h_diff[0] ;
    end
end

always @(posedge clk) begin:FF_D_4x4_sum_p0
    D_4x4_sum_p0 <= D_4x4_h_12_acc + D_4x4_h_01_acc ;
end

always @(posedge clk) begin:FF_D_4x4_v_mid_acc
    if (cnt127_is_33) begin 
        D_4x4_v_mid_acc <= v_diff[1] ;
    end else if (D_4x4_period_q) begin
        D_4x4_v_mid_acc <= D_4x4_v_mid_acc + v_diff[1] ;
    end
end

always @(posedge clk) begin:FF_D_4x4_v_corner_acc
    if (cnt127_is_33) begin
        D_4x4_v_corner_acc <= v_diff[2] ;
    end else if (D_4x4_period_even) begin
        D_4x4_v_corner_acc <= D_4x4_v_corner_acc + v_diff[0] ;
    end else if (D_4x4_period_odd) begin 
        D_4x4_v_corner_acc <= D_4x4_v_corner_acc + v_diff[2] ;
    end
end

always @(posedge clk) begin:FF_D_4x4_v_sum
    D_4x4_v_sum <= D_4x4_v_mid_acc + D_4x4_v_corner_acc ;
end

always @(posedge clk) begin:FF_D_4x4_v_h_sum
    D_4x4_v_h_sum <= D_4x4_v_sum + D_4x4_sum_p0 ; 
end

always @(posedge clk) begin:FF_D_4x4_ans
    D_4x4_ans <= D_4x4_sum[11:4] ;
end

// -------------  Auto Exposure ------------- //

always @(posedge clk) begin:FF_exp_sum_0
    if (pic_is_G) begin // 0.5
        for (int i = 0; i < 8; i++) begin
            exp_sum_0[i] <= R_data_qq[2*i][7:1] + R_data_qq[2*i+1][7:1] ;
        end
    end else begin // 0.25
        for (int i = 0; i < 8; i++) begin
            exp_sum_0[i] <= R_data_qq[2*i][7:2] + R_data_qq[2*i+1][7:2] ;
        end
    end
end

always @(posedge clk) begin:FF_exp_sum_1
    for (int i = 0; i < 4; i++) begin
        exp_sum_1[i] <= exp_sum_0[2*i] + exp_sum_0[2*i+1] ;
    end
end

always @(posedge clk) begin:FF_exp_sum_2
    for (int i = 0; i < 2; i++) begin
        exp_sum_2[i] <= exp_sum_1[2*i] + exp_sum_1[2*i+1] ;
    end
end

always @(posedge clk) begin:FF_exp_sum_3
    exp_sum_3 <= exp_sum_2[0] + exp_sum_2[1] ;
end
always @(posedge clk) begin:FF_acc_start
    acc_start <= rready_qqqq & ~rready_qqqqq ; 
end

always @(posedge clk) begin:FF_accumulator
    if (acc_start) begin
        accumulator <= 0 ;
    end else begin
        accumulator <= accumulator + exp_sum_3 ;
    end
end

// 6x6 
// control 
always @(posedge clk) begin:FF_D_6x6_period
    if (cnt127_is_29) begin 
        D_6x6_period <= 1 ;
    end else if (cnt127_is_40) begin 
        D_6x6_period <= 0 ;
    end
end

always @(posedge clk) begin:FF_D_6x6_h_acc_01
    if (cnt127_is_29) begin 
        D_6x6_h_acc_01 <= h_diff[0] ;
    end else if (D_6x6_period) begin 
        D_6x6_h_acc_01 <= D_6x6_h_acc_01 + h_diff[0] ;
    end
end

always @(posedge clk) begin:FF_D_6x6_h_acc_12
    if (cnt127_is_29) begin 
        D_6x6_h_acc_12 <= h_diff[1] ;
    end else if (D_6x6_period) begin 
        D_6x6_h_acc_12 <= D_6x6_h_acc_12 + h_diff[1] ;
    end
end

always @(posedge clk) begin:FF_D_6x6_period_even
    D_6x6_period_even <= D_6x6_period & cnt127[0] ;
end

always @(posedge clk) begin:FF_D_6x6_h_acc_mid
    if (cnt127_is_30) begin 
        D_6x6_h_acc_mid <= h_diff_cross ;
    end else if (D_6x6_period_even) begin 
        D_6x6_h_acc_mid <= D_6x6_h_acc_mid + h_diff_cross ;
    end
end

always @(posedge clk) begin:FF_D_6x6_v_acc_012
    if (cnt127_is_31) begin
        D_6x6_v_acc_0 <= v_diff[0] ;
        D_6x6_v_acc_1 <= v_diff[1] ;
        D_6x6_v_acc_2 <= v_diff[2] ;
    end else if (D_6x6_period) begin
        D_6x6_v_acc_0 <= D_6x6_v_acc_0 + v_diff[0] ;
        D_6x6_v_acc_1 <= D_6x6_v_acc_1 + v_diff[1] ;
        D_6x6_v_acc_2 <= D_6x6_v_acc_2 + v_diff[2] ;
    end
end

always @(posedge clk) begin:FF_D_6x6_sum_012
    D_6x6_sum_0 <= D_6x6_h_acc_01 + D_6x6_h_acc_12 ;
    D_6x6_sum_1 <= D_6x6_h_acc_mid + D_6x6_v_acc_0 ;
    D_6x6_sum_2 <= D_6x6_v_acc_1 + D_6x6_v_acc_2 ;
    D_6x6_sum_01 <= D_6x6_sum_0 + D_6x6_sum_1 ;
    D_6x6_total_div4 <= D_6x6_total_sum[13:2];
    //  <= D_6x6_total_div4 / 9 ;
end

wire [3:0] div9_in_0 = D_6x6_total_div4[11:8] ;
wire div9_ans_0 = div9_in_0 >= 4'd9 ;
reg [3:0] remainder_0 ;
always @(posedge clk) begin
    if (div9_ans_0) remainder_0 <= div9_in_0 - 9 ;  
    else remainder_0 <= div9_in_0 ;
end

wire [4:0] div9_in_1 = {remainder_0 , D_6x6_total_div4[7]};
wire div9_ans_1 = div9_in_1 >= 4'd9 ;
reg [3:0] remainder_1 ;
always @(posedge clk) begin
    if (div9_ans_1) remainder_1 <= div9_in_1 - 9 ; 
    else remainder_1 <= div9_in_1 ;
end

wire [4:0] div9_in_2 = {remainder_1 , D_6x6_total_div4[6]};
wire div9_ans_2 = div9_in_2 >= 4'd9 ;
reg [3:0] remainder_2 ;
always @(posedge clk) begin
    if (div9_ans_2) remainder_2 <= div9_in_2 - 9 ; 
    else remainder_2 <= div9_in_2 ;
end

wire [4:0] div9_in_3 = {remainder_2 , D_6x6_total_div4[5]};
wire div9_ans_3 = div9_in_3 >= 4'd9 ;
reg [3:0] remainder_3 ;
always @(posedge clk) begin
    if (div9_ans_3) remainder_3 <= div9_in_3 - 9 ; 
    else remainder_3 <= div9_in_3 ;
end

wire [4:0] div9_in_4 = {remainder_3 , D_6x6_total_div4[4]};
wire div9_ans_4 = div9_in_4 >= 4'd9 ;
reg [3:0] remainder_4 ;
always @(posedge clk) begin
    if (div9_ans_4) remainder_4 <= div9_in_4 - 9 ; 
    else remainder_4 <= div9_in_4 ;
end

wire [4:0] div9_in_5 = {remainder_4 , D_6x6_total_div4[3]};
wire div9_ans_5 = div9_in_5 >= 4'd9 ;
reg [3:0] remainder_5 ;
always @(posedge clk) begin
    if (div9_ans_5) remainder_5 <= div9_in_5 - 9 ; 
    else remainder_5 <= div9_in_5 ;
end

wire [4:0] div9_in_6 = {remainder_5 , D_6x6_total_div4[2]};
wire div9_ans_6 = div9_in_6 >= 4'd9 ;
reg [3:0] remainder_6 ;
always @(posedge clk) begin
    if (div9_ans_6) remainder_6 <= div9_in_6 - 9 ; 
    else remainder_6 <= div9_in_6 ;
end

wire [4:0] div9_in_7 = {remainder_6 , D_6x6_total_div4[1]};
wire div9_ans_7 = div9_in_7 >= 4'd9 ;
reg [3:0] remainder_7 ;
always @(posedge clk) begin
    if (div9_ans_7) remainder_7 <= div9_in_7 - 9 ; 
    else remainder_7 <= div9_in_7 ;
end

wire [4:0] div9_in_8 = {remainder_7 , D_6x6_total_div4[0]};
wire div9_ans_8 = div9_in_8 >= 4'd9 ;
// reg [3:0] remainder_8 ;
// always @(posedge clk) begin
//     if (div9_ans_8) remainder_8 <= div9_in_8 - 9 ; 
//     else remainder_8 <= div9_in_8 ;
// end

wire [8:0] D_6x6_ans = {div9_ans_0 , div9_ans_1 , div9_ans_2 , div9_ans_3 , div9_ans_4 , div9_ans_5 , div9_ans_6 , div9_ans_7 , div9_ans_8} ;


always @(posedge clk) begin:FF_focus_candidate
    if (D_2x2_ans >= D_4x4_ans) begin
        focus_candidate_idx <= 0 ;
        focus_candidate <= D_2x2_ans ;
    end else begin
        focus_candidate_idx <= 1 ;
        focus_candidate <= D_4x4_ans ;
    end
end

always @(posedge clk) begin:FF_focus_max_one
    if (focus_candidate >= D_6x6_ans) begin
        focus_max_one_idx <= focus_candidate_idx ;
    end else begin 
        focus_max_one_idx <= 2 ;
    end 
end

// -------------  Average of min max value ------------- //

// Sorting network
// [(0,13),(1,12),(2,15),(3,14),(4,8),(5,6),(7,11),(9,10)] 8 comparators
// [(0,5),(1,7),(2,9),(3,4),(6,13),(8,14),(10,15),(11,12)] 8 comparators
// [(0,1),(2,3),(12,13),(14,15)] 4 comparators
// [(0,2),(13,15)] 2 comparators

// 8 comparators
always @(posedge clk) begin:FF_max_min_list_0
    for (int i = 0; i < 8; i++) begin
        if (R_data_qq[2*i] >= R_data_qq[2*i+1]) begin
            max_list_0[i] <= R_data_qq[2*i] ;
            min_list_0[i] <= R_data_qq[2*i+1] ;
        end else begin
            max_list_0[i] <= R_data_qq[2*i+1] ;
            min_list_0[i] <= R_data_qq[2*i] ;
        end
    end
end

// 4 comparators
always @(posedge clk) begin:FF_max_list_1
    for (int i = 0; i < 4; i++) begin
        if (max_list_0[2*i] >= max_list_0[2*i+1]) begin
            max_list_1[i] <= max_list_0[2*i] ;
        end else begin 
            max_list_1[i] <= max_list_0[2*i+1] ;
        end
    end
end

// 2 comparators
always @(posedge clk) begin:FF_max_list_2
    for (int i = 0; i < 2; i++) begin
        if (max_list_1[2*i] >= max_list_1[2*i+1]) begin
            max_list_2[i] <= max_list_1[2*i] ;
        end else begin
            max_list_2[i] <= max_list_1[2*i+1] ;
        end
    end
end

// 1 comparator
always @(posedge clk) begin:FF_max_one
    if (max_list_2[0] >= max_list_2[1]) begin
        max_one <= max_list_2[0] ;
    end else begin
        max_one <= max_list_2[1] ;
    end
end

// 4 comparators
always @(posedge clk) begin:FF_min_list_1
    for (int i = 0; i < 4; i++) begin
        if (min_list_0[2*i] <= min_list_0[2*i+1]) begin
            min_list_1[i] <= min_list_0[2*i] ;
        end else begin 
            min_list_1[i] <= min_list_0[2*i+1] ;
        end 
    end 
end

// 2 comparators
always @(posedge clk) begin:FF_min_list_2
    for (int i = 0; i < 2; i++) begin
        if (min_list_1[2*i] <= min_list_1[2*i+1]) begin
            min_list_2[i] <= min_list_1[2*i] ;
        end else begin
            min_list_2[i] <= min_list_1[2*i+1] ;
        end
    end
end

// 1 comparator
always @(posedge clk) begin:FF_min_one
    if (min_list_2[0] <= min_list_2[1]) begin
        min_one <= min_list_2[0] ;
    end else begin
        min_one <= min_list_2[1] ;
    end
end

always @(posedge clk) begin:FF_cnt127_is_3
    cnt127_is_3 <= cnt127[5:0] == 2 ;
end

always @(posedge clk) begin:FF_max_RGB
    if (cnt127_is_3) begin
        max_RGB <= 0 ;
    end else begin 
        if (max_one >= max_RGB) begin 
            max_RGB <= max_one ;
        end
    end
end

always @(posedge clk) begin:FF_max_sum
    if (acc_start) begin 
        max_sum <= 0 ;
    end else if (cnt127_is_3) begin
        max_sum <= max_sum + max_RGB ;
    end 
end

always @(posedge clk) begin:FF_min_RGB
    if (cnt127_is_3) begin
        min_RGB <= 255 ;
    end else begin 
        if (min_one <= min_RGB) begin 
            min_RGB <= min_one ;
        end
    end
end

always @(posedge clk) begin:FF_min_sum
    if (acc_start) begin 
        min_sum <= 0 ;
    end else if (cnt127_is_3) begin
        min_sum <= min_sum + min_RGB ;
    end 
end

// always @(posedge clk) begin:FF_max_min_sum_div3
//     max_sum_div3 <= max_sum / 3 ;
//     min_sum_div3 <= min_sum / 3 ;
// end

wire [1:0] max_div3_in_0 = max_sum[9:8] ;
wire max_div3_ans_0 = max_div3_in_0 >= 2'd3 ;
reg [1:0] max_remainder_0 ;
always @(posedge clk) begin
    if (max_div3_ans_0) max_remainder_0 <= max_div3_in_0 - 2'd3 ;
    else max_remainder_0 <= max_div3_in_0 ;
end

wire [2:0] max_div3_in_1 = {max_remainder_0 , max_sum[7]} ;
wire max_div3_ans_1 = max_div3_in_1 >= 2'd3 ;
reg [1:0] max_remainder_1 ;
always @(posedge clk) begin
    if (max_div3_ans_1) max_remainder_1 <= max_div3_in_1 - 2'd3 ;
    else max_remainder_1 <= max_div3_in_1 ;
end

wire [2:0] max_div3_in_2 = {max_remainder_1 , max_sum[6]} ;
wire max_div3_ans_2 = max_div3_in_2 >= 2'd3 ;
reg [1:0] max_remainder_2 ;
always @(posedge clk) begin
    if (max_div3_ans_2) max_remainder_2 <= max_div3_in_2 - 2'd3 ;
    else max_remainder_2 <= max_div3_in_2 ;
end

wire [2:0] max_div3_in_3 = {max_remainder_2 , max_sum[5]} ;
wire max_div3_ans_3 = max_div3_in_3 >= 2'd3 ;
reg [1:0] max_remainder_3 ;
always @(posedge clk) begin
    if (max_div3_ans_3) max_remainder_3 <= max_div3_in_3 - 2'd3 ;
    else max_remainder_3 <= max_div3_in_3 ;
end

wire [2:0] max_div3_in_4 = {max_remainder_3 , max_sum[4]} ;
wire max_div3_ans_4 = max_div3_in_4 >= 2'd3 ;
reg [1:0] max_remainder_4 ;
always @(posedge clk) begin
    if (max_div3_ans_4) max_remainder_4 <= max_div3_in_4 - 2'd3 ;
    else max_remainder_4 <= max_div3_in_4 ;
end

wire [2:0] max_div3_in_5 = {max_remainder_4 , max_sum[3]} ;
wire max_div3_ans_5 = max_div3_in_5 >= 2'd3 ;
reg [1:0] max_remainder_5 ;
always @(posedge clk) begin
    if (max_div3_ans_5) max_remainder_5 <= max_div3_in_5 - 2'd3 ;
    else max_remainder_5 <= max_div3_in_5 ;
end

wire [2:0] max_div3_in_6 = {max_remainder_5 , max_sum[2]} ;
wire max_div3_ans_6 = max_div3_in_6 >= 2'd3 ;
reg [1:0] max_remainder_6 ;
always @(posedge clk) begin
    if (max_div3_ans_6) max_remainder_6 <= max_div3_in_6 - 2'd3 ;
    else max_remainder_6 <= max_div3_in_6 ;
end

wire [2:0] max_div3_in_7 = {max_remainder_6 , max_sum[1]} ;
wire max_div3_ans_7 = max_div3_in_7 >= 2'd3 ;
reg [1:0] max_remainder_7 ;
always @(posedge clk) begin
    if (max_div3_ans_7) max_remainder_7 <= max_div3_in_7 - 2'd3 ;
    else max_remainder_7 <= max_div3_in_7 ;
end

wire [2:0] max_div3_in_8 = {max_remainder_7 , max_sum[0]} ;
wire max_div3_ans_8 = max_div3_in_8 >= 2'd3 ;
// reg [1:0] max_remainder_8 ;
// always @(posedge clk) begin
//     if (max_div3_ans_8) max_remainder_8 <= max_div3_in_8 - 2'd3 ;
//     else max_remainder_8 <= max_div3_in_8 ;
// end

assign max_sum_div3 = {max_div3_ans_0 , max_div3_ans_1 , max_div3_ans_2 , max_div3_ans_3 , max_div3_ans_4 , max_div3_ans_5 , max_div3_ans_6 , max_div3_ans_7 , max_div3_ans_8} ;

wire [1:0] min_div3_in_0 = min_sum[9:8] ;
wire min_div3_ans_0 = min_div3_in_0 >= 2'd3 ;
reg [1:0] min_remainder_0 ;
always @(posedge clk) begin
    if (min_div3_ans_0) min_remainder_0 <= min_div3_in_0 - 2'd3 ;
    else min_remainder_0 <= min_div3_in_0 ;
end

wire [2:0] min_div3_in_1 = {min_remainder_0 , min_sum[7]} ;
wire min_div3_ans_1 = min_div3_in_1 >= 2'd3 ;
reg [1:0] min_remainder_1 ;
always @(posedge clk) begin
    if (min_div3_ans_1) min_remainder_1 <= min_div3_in_1 - 2'd3 ;
    else min_remainder_1 <= min_div3_in_1 ;
end

wire [2:0] min_div3_in_2 = {min_remainder_1 , min_sum[6]} ;
wire min_div3_ans_2 = min_div3_in_2 >= 2'd3 ;
reg [1:0] min_remainder_2 ;
always @(posedge clk) begin
    if (min_div3_ans_2) min_remainder_2 <= min_div3_in_2 - 2'd3 ;
    else min_remainder_2 <= min_div3_in_2 ;
end

wire [2:0] min_div3_in_3 = {min_remainder_2 , min_sum[5]} ;
wire min_div3_ans_3 = min_div3_in_3 >= 2'd3 ;
reg [1:0] min_remainder_3 ;
always @(posedge clk) begin
    if (min_div3_ans_3) min_remainder_3 <= min_div3_in_3 - 2'd3 ;
    else min_remainder_3 <= min_div3_in_3 ;
end

wire [2:0] min_div3_in_4 = {min_remainder_3 , min_sum[4]} ;
wire min_div3_ans_4 = min_div3_in_4 >= 2'd3 ;
reg [1:0] min_remainder_4 ;
always @(posedge clk) begin
    if (min_div3_ans_4) min_remainder_4 <= min_div3_in_4 - 2'd3 ;
    else min_remainder_4 <= min_div3_in_4 ;
end

wire [2:0] min_div3_in_5 = {min_remainder_4 , min_sum[3]} ;
wire min_div3_ans_5 = min_div3_in_5 >= 2'd3 ;
reg [1:0] min_remainder_5 ;
always @(posedge clk) begin
    if (min_div3_ans_5) min_remainder_5 <= min_div3_in_5 - 2'd3 ;
    else min_remainder_5 <= min_div3_in_5 ;
end

wire [2:0] min_div3_in_6 = {min_remainder_5 , min_sum[2]} ;
wire min_div3_ans_6 = min_div3_in_6 >= 2'd3 ;
reg [1:0] min_remainder_6 ;
always @(posedge clk) begin
    if (min_div3_ans_6) min_remainder_6 <= min_div3_in_6 - 2'd3 ;
    else min_remainder_6 <= min_div3_in_6 ;
end

wire [2:0] min_div3_in_7 = {min_remainder_6 , min_sum[1]} ;
wire min_div3_ans_7 = min_div3_in_7 >= 2'd3 ;
reg [1:0] min_remainder_7 ;
always @(posedge clk) begin
    if (min_div3_ans_7) min_remainder_7 <= min_div3_in_7 - 2'd3 ;
    else min_remainder_7 <= min_div3_in_7 ;
end

wire [2:0] min_div3_in_8 = {min_remainder_7 , min_sum[0]} ;
wire min_div3_ans_8 = min_div3_in_8 >= 2'd3 ;
// reg [1:0] min_remainder_8 ;
// always @(posedge clk) begin
//     if (min_div3_ans_8) min_remainder_8 <= min_div3_in_8 - 2'd3 ;
//     else min_remainder_8 <= min_div3_in_8 ;
// end

assign min_sum_div3 = {min_div3_ans_0 , min_div3_ans_1 , min_div3_ans_2 , min_div3_ans_3 , min_div3_ans_4 , min_div3_ans_5 , min_div3_ans_6 , min_div3_ans_7 , min_div3_ans_8} ;

always @(posedge clk) begin:FF_max_min_sum
    max_min_sum <= max_sum_div3 + min_sum_div3 ;
end

// -------------  reduce critical path ------------- // 
always @(posedge clk or negedge rst_n) begin:FF_state_is_checkandupdate
    if (!rst_n) state_is_checkandupdate <= 0;
    else state_is_checkandupdate <= (decode_done && ~info_dead);
end

always @(posedge clk or negedge rst_n) begin:FF_state_is_read
    if (!rst_n) state_is_read <= 0;
    else state_is_read <= (state == READ);
end

always @(posedge clk) begin:FF_idx_is_n
    for (int i = 0; i < 16; i++) begin
        idx_is_n[i] <= i == in_pic_no_q ;
    end
end

// -------------  test output ------------- // 
// always @(posedge clk or negedge rst_n) begin:FF_test_output
//     if (!rst_n) begin
//         out_valid <= 1'b0;
//     end else begin
//         out_valid <= 1'b0;
//     end
// end

always @(*) begin:comb_out_valid
    if (state == OUTPUT) begin
        out_valid = 1'b1;
    end else begin
        out_valid = 1'b0;
    end
end

reg [7:0] out_exp , out_max_min , out_focus ;
always @(*) begin:cpmb_out_exp_max_min_focus
    if (delay_q[5] ) begin
        out_exp = exp_ans ;
        out_max_min = max_min_ans ;
        out_focus = focus_ans ;
    end else if (state_is_checkandupdate & ~need_read) begin
        out_exp = info_exp ;
        out_max_min = info_max_min ;
        out_focus = info_focus ;
    end else begin
        out_exp = 8'd0 ;
        out_max_min = 8'd0 ;
        out_focus = 8'd0 ;
    end
end


always @(posedge clk or negedge rst_n) begin:FF_out_data
    if (!rst_n) begin
        out_data <= 8'd0;
    end else begin
        if (info_dead) begin
            out_data <= 8'd0;
        end else if (in_mode_q[0]) begin // exp
            out_data <= out_exp ;
        end else if (in_mode_q[1]) begin // max_min
            out_data <= out_max_min ;
        end else begin // focus
            out_data <= out_focus ;
        end 
    end
end


// ------------- only for testing ------------- //
// remove when 02
// amount of write data 
// reg [31:0] write_amount , read_amount ;
// always @(posedge clk or negedge rst_n) begin:FF_write_amount
//     if (!rst_n) begin
//         write_amount <= 0 ;
//         read_amount <= 0 ;
//     end else begin
//         if (rvalid_s_inf && rready_s_inf) begin
//             read_amount <= read_amount + 1 ;
//         end else begin 
//             read_amount <= 0 ;
//         end
//         if (wready_s_inf && wvalid_s_inf) begin
//             write_amount <= write_amount + 1 ;
//         end else begin 
//             write_amount <= 0 ;
//         end
//     end
// end

// // time line 
// reg [31:0] timeline ;
// always @(posedge clk or negedge rst_n) begin:FF_timeline
//     if (!rst_n) begin
//         timeline <= 0 ;
//     end else begin
//         timeline <= timeline + 1 ;
//     end
// end

// reg [7:0] full_captured_data [0:2] ;
// always @(*) begin:comb_full_captured_data
//     if (cnt127[0]) begin
//         full_captured_data[0] = R_data_qq[0] ;
//         full_captured_data[1] = R_data_qq[1] ;
//         full_captured_data[2] = R_data_qq[2] ;
//     end else begin
//         full_captured_data[0] = R_data_qq[13] ;
//         full_captured_data[1] = R_data_qq[14] ;
//         full_captured_data[2] = R_data_qq[15] ;
//     end
// end

// wire [7:0] cnt_255 = {cnt255_flag, cnt127} ;
// wire cnt_is_34or36or38 = cnt127_is_34|cnt127_is_36|cnt127_is_38 ;

// reg [7:0] focus_max_one ;
// always @(posedge clk) begin:FF_focus_max_one_test
//     if (focus_candidate >= D_6x6_ans) begin
//         focus_max_one <= focus_candidate ;
//     end else begin 
//         focus_max_one <= D_6x6_ans ;
//     end 
// end

// wire next_is_dead = ~( ~n_magnification[3] && (n_magnification[2:0] == info_max_magnification) );

// wire [8:0] gloden_div9 = D_6x6_total_div4 / 9 ;


// wire [8:0] golden_max_sum_div3 = max_sum / 3 ;
// wire [8:0] golden_min_sum_div3 = min_sum / 3 ;


endmodule
