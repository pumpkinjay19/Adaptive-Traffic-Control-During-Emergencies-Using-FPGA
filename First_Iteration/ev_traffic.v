// ev_traffic.v
// Pedestrian-aware emergency vehicle preemption, DE10-Lite (MAX 10)
// Top-level entity name in Quartus must be: ev_traffic
//
// GPIO map (code name = Terasic GPIO name):
//  0 N_R  1 N_Y  2 N_G   3 E_R  4 E_Y  5 E_G
//  6 S_R  7 S_Y  8 S_G   9 W_R 10 W_Y 11 W_G
// 12 P1_R 13 P1_G 14 P2_R 15 P2_G
// 16 ped button 1 (in, active low)  17 ped button 2 (in, active low)
// 18 UART RX (in, from ESP32 TX2)   19 EV mode LED (out)
//
// Ped 1 crosses the N/S legs (walks during E/W green)
// Ped 2 crosses the E/W legs (walks during N/S green)
//
// UART 9600 8N1 bytes: 'N' 'E' 'S' 'W' = EV from that side, 'X' = clear

module ev_traffic #(
    parameter TICK_DIV     = 50_000_000, // clocks per 1 s tick (make small for sim)
    parameter GREEN_T      = 10,         // normal green seconds
    parameter YELLOW_T     = 3,
    parameter ALLRED_T     = 2,
    parameter PED_CLR_T    = 4,          // ped clearance (ped red before vehicles change)
    parameter EV_MIN_T     = 3,          // min EV green seconds
    parameter EV_HOLD_T    = 8,          // seconds EV request stays after last UART byte
    parameter CLKS_PER_BIT = 5208        // 50 MHz / 9600
)(
    input         MAX10_CLK1_50,
    input  [1:0]  KEY,
    input  [9:0]  SW,
    output [9:0]  LEDR,
    inout  [19:0] GPIO
);

    wire clk = MAX10_CLK1_50;

    // ---------------- reset + input sync ----------------
    reg [1:0] rst_sync = 2'b00;
    always @(posedge clk) rst_sync <= {rst_sync[0], KEY[0]};
    wire rst_n = rst_sync[1];                 // KEY0 pressed = reset

    reg [1:0] p1_s = 2'b11, p2_s = 2'b11, rx_s = 2'b11;
    reg [3:0] sw_ev_s1 = 0, sw_ev_s2 = 0;
    reg       sw_f_s1 = 0,  sw_f_s2 = 0;
    always @(posedge clk) begin
        p1_s     <= {p1_s[0], GPIO[16]};
        p2_s     <= {p2_s[0], GPIO[17]};
        rx_s     <= {rx_s[0], GPIO[18]};
        sw_ev_s1 <= SW[3:0];  sw_ev_s2 <= sw_ev_s1;
        sw_f_s1  <= SW[9];    sw_f_s2  <= sw_f_s1;
    end

    // ---------------- 1 Hz tick ----------------
    reg [25:0] tick_cnt = 0;
    reg        tick = 0;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin tick_cnt <= 0; tick <= 0; end
        else if (tick_cnt == TICK_DIV-1) begin tick_cnt <= 0; tick <= 1; end
        else begin tick_cnt <= tick_cnt + 1; tick <= 0; end
    end

    // ---------------- UART receiver ----------------
    localparam R_IDLE = 2'd0, R_START = 2'd1, R_DATA = 2'd2, R_STOP = 2'd3;
    reg [1:0]  r_st = R_IDLE;
    reg [12:0] r_cnt = 0;
    reg [2:0]  r_bit = 0;
    reg [7:0]  r_shift = 0;
    reg [7:0]  rx_byte = 0;
    reg        rx_valid = 0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_st <= R_IDLE; r_cnt <= 0; r_bit <= 0;
            r_shift <= 0; rx_byte <= 0; rx_valid <= 0;
        end else begin
            rx_valid <= 1'b0;
            case (r_st)
                R_IDLE: if (!rx_s[1]) begin r_cnt <= 0; r_st <= R_START; end
                R_START: begin
                    if (r_cnt == (CLKS_PER_BIT/2)-1) begin
                        r_cnt <= 0;
                        if (!rx_s[1]) begin r_bit <= 0; r_st <= R_DATA; end
                        else r_st <= R_IDLE;      // false start
                    end else r_cnt <= r_cnt + 1;
                end
                R_DATA: begin
                    if (r_cnt == CLKS_PER_BIT-1) begin
                        r_cnt   <= 0;
                        r_shift <= {rx_s[1], r_shift[7:1]};  // LSB first
                        if (r_bit == 3'd7) r_st <= R_STOP;
                        else r_bit <= r_bit + 1;
                    end else r_cnt <= r_cnt + 1;
                end
                R_STOP: begin
                    if (r_cnt == CLKS_PER_BIT-1) begin
                        r_cnt <= 0;
                        r_st  <= R_IDLE;
                        if (rx_s[1]) begin rx_byte <= r_shift; rx_valid <= 1'b1; end
                    end else r_cnt <= r_cnt + 1;
                end
            endcase
        end
    end

    // ---------------- EV request from UART (with hold timer) ----------------
    reg [3:0] st = 4'd0, st_prev = 4'd0;   // declared here, used by the hold timer below
    reg [3:0] uart_ev = 0;      // [0]=N [1]=E [2]=S [3]=W
    reg [5:0] uart_hold = 0;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin uart_ev <= 0; uart_hold <= 0; end
        else if (rx_valid) begin
            case (rx_byte)
                "N", "n": begin uart_ev <= 4'b0001; uart_hold <= EV_HOLD_T; end
                "E", "e": begin uart_ev <= 4'b0010; uart_hold <= EV_HOLD_T; end
                "S", "s": begin uart_ev <= 4'b0100; uart_hold <= EV_HOLD_T; end
                "W", "w": begin uart_ev <= 4'b1000; uart_hold <= EV_HOLD_T; end
                "X", "x": begin uart_ev <= 4'b0000; uart_hold <= 0; end
                default: ;
            endcase
        end else if (tick && uart_hold != 0 && st == 4'd9) begin   // 4'd9 = EV_G: hold counts only while EV has green
            uart_hold <= uart_hold - 1;
            if (uart_hold == 1) uart_ev <= 4'b0000;
        end
    end

    wire [3:0] ev_req = sw_ev_s2 | uart_ev;
    wire ev_ns  = ev_req[0] | ev_req[2];
    wire ev_ew  = ev_req[1] | ev_req[3];
    wire ev_any = ev_ns | ev_ew;

    // ---------------- main FSM ----------------
    localparam NS_G = 4'd0, NS_Y = 4'd1, AR_A = 4'd2,
               EW_G = 4'd3, EW_Y = 4'd4, AR_B = 4'd5,
               EV_PEDCLR = 4'd6, EV_Y = 4'd7, EV_AR = 4'd8, EV_G = 4'd9;

    reg [5:0] t = 0;
    reg       cur_axis = 0;               // 0 = NS, 1 = EW (axis that has/had green)
    reg       ped1_req = 0, ped2_req = 0, ped1_act = 0, ped2_act = 0;

    // when both axes request, keep the axis that is already green, else NS
    wire ev_pick = ev_ew & (~ev_ns | cur_axis);   // 1 = EW, 0 = NS

    wire walk_window = (t < (GREEN_T - PED_CLR_T));
    wire ped2_g = (st == NS_G) && ped2_act && walk_window;
    wire ped1_g = (st == EW_G) && ped1_act && walk_window;
    wire ped_walking = ped1_g | ped2_g;

    wire enter_ns = (st == NS_G) && (st_prev != NS_G);
    wire enter_ew = (st == EW_G) && (st_prev != EW_G);
    wire cur_req  = cur_axis ? ev_ew : ev_ns;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st <= NS_G; st_prev <= NS_G; t <= 0; cur_axis <= 0;
            ped1_req <= 0; ped2_req <= 0; ped1_act <= 0; ped2_act <= 0;
        end else begin
            st_prev <= st;

            if (!p1_s[1]) ped1_req <= 1'b1;
            if (!p2_s[1]) ped2_req <= 1'b1;
            if (enter_ns) begin ped2_act <= ped2_req; ped2_req <= 1'b0; end
            if (enter_ew) begin ped1_act <= ped1_req; ped1_req <= 1'b0; end

            if (tick && t != 6'd63) t <= t + 1;   // transitions below override this

            case (st)
                NS_G: begin
                    if (ev_any) begin
                        if (!ev_pick)         begin st <= EV_G;      t <= 0; end  // NS EV, already green
                        else if (ped_walking) begin st <= EV_PEDCLR; t <= 0; end  // clear peds first
                        else                  begin st <= EV_Y;      t <= 0; end
                    end else if (tick && t >= GREEN_T-1) begin st <= NS_Y; t <= 0; end
                end
                NS_Y: if (tick && t >= YELLOW_T-1) begin st <= AR_A; t <= 0; end
                AR_A: if (tick && t >= ALLRED_T-1) begin
                    t <= 0;
                    if (ev_any) begin st <= EV_G; cur_axis <= ev_pick; end
                    else        begin st <= EW_G; cur_axis <= 1'b1; end
                end

                EW_G: begin
                    if (ev_any) begin
                        if (ev_pick)          begin st <= EV_G;      t <= 0; end  // EW EV, already green
                        else if (ped_walking) begin st <= EV_PEDCLR; t <= 0; end
                        else                  begin st <= EV_Y;      t <= 0; end
                    end else if (tick && t >= GREEN_T-1) begin st <= EW_Y; t <= 0; end
                end
                EW_Y: if (tick && t >= YELLOW_T-1) begin st <= AR_B; t <= 0; end
                AR_B: if (tick && t >= ALLRED_T-1) begin
                    t <= 0;
                    if (ev_any) begin st <= EV_G; cur_axis <= ev_pick; end
                    else        begin st <= NS_G; cur_axis <= 1'b0; end
                end

                EV_PEDCLR: if (tick && t >= PED_CLR_T-1) begin st <= EV_Y; t <= 0; end
                EV_Y:      if (tick && t >= YELLOW_T-1)  begin st <= EV_AR; t <= 0; end
                EV_AR: if (tick && t >= ALLRED_T-1) begin
                    t <= 0;
                    if (ev_any) begin st <= EV_G; cur_axis <= ev_pick; end
                    else if (cur_axis) begin st <= NS_G; cur_axis <= 1'b0; end
                    else               begin st <= EW_G; cur_axis <= 1'b1; end
                end
                EV_G: if (!cur_req && t >= EV_MIN_T) begin st <= EV_Y; t <= 0; end

                default: begin st <= NS_G; t <= 0; cur_axis <= 0; end
            endcase
        end
    end

    // ---------------- light decode ----------------
    localparam L_R = 3'b001, L_Y = 3'b010, L_G = 3'b100;   // {G,Y,R}
    reg [2:0] ns_l, ew_l;
    always @* begin
        ns_l = L_R; ew_l = L_R;
        case (st)
            NS_G: ns_l = L_G;
            NS_Y: ns_l = L_Y;
            EW_G: ew_l = L_G;
            EW_Y: ew_l = L_Y;
            EV_PEDCLR, EV_G: if (cur_axis) ew_l = L_G; else ns_l = L_G;
            EV_Y:            if (cur_axis) ew_l = L_Y; else ns_l = L_Y;
            default: ;
        endcase
    end

    wire [15:0] lights_next = { ped2_g, ~ped2_g, ped1_g, ~ped1_g,   // P2_G P2_R P1_G P1_R
                                ew_l, ns_l, ew_l, ns_l };           // W S E N
    reg [15:0] lights_r = 16'h5249;                                  // all red
    always @(posedge clk) lights_r <= lights_next;

    // ---------------- fault injection + conflict monitor ----------------
    // SW9 forces N green and E green on at the same time (after the FSM)
    wire [15:0] lights_inj = sw_f_s2 ? ((lights_r & ~16'h0009) | 16'h0024) : lights_r;

    wire ns_go = lights_inj[1] | lights_inj[2] | lights_inj[7]  | lights_inj[8];   // N/S Y or G
    wire ew_go = lights_inj[4] | lights_inj[5] | lights_inj[10] | lights_inj[11];  // E/W Y or G
    wire p1_gn = lights_inj[13];
    wire p2_gn = lights_inj[15];
    wire conflict = (ns_go & ew_go) | (p1_gn & ns_go) | (p2_gn & ew_go);

    reg [15:0] cf_cnt = 0;
    reg        fault  = 0;                  // latched until KEY0
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin cf_cnt <= 0; fault <= 0; end
        else begin
            if (conflict) begin if (cf_cnt != 16'hFFFF) cf_cnt <= cf_cnt + 1; end
            else cf_cnt <= 0;
            if (cf_cnt >= 16'd1000) fault <= 1'b1;     // ~20 us filter
        end
    end

    reg flash = 0;
    always @(posedge clk) if (tick) flash <= ~flash;

    // fault = flashing all-red, peds steady red
    wire [15:0] out_lights = fault ? (flash ? 16'h5249 : 16'h5000) : lights_inj;

    wire ev_active = (st == EV_PEDCLR) | (st == EV_Y) | (st == EV_AR) | (st == EV_G);

    // ---------------- outputs ----------------
    assign GPIO[15:0] = out_lights;
    assign GPIO[16]   = 1'bz;       // ped button 1
    assign GPIO[17]   = 1'bz;       // ped button 2
    assign GPIO[18]   = 1'bz;       // UART RX
    assign GPIO[19]   = ev_active;

    assign LEDR = {fault, ev_active, rx_byte};

endmodule
