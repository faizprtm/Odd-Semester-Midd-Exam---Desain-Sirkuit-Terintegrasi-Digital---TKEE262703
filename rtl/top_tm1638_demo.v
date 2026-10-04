module top_tm1638_demo(
    input clk,
    output reg tm_cs,
    output tm_clk,
    inout  tm_dio
);

    localparam HIGH = 1'b1, LOW = 1'b0;

    // Pola Lampu 7-Segment
    localparam [6:0]
        S_0 = 7'b0111111, S_1 = 7'b0000110, S_2 = 7'b1011011,
        S_3 = 7'b1001111, S_4 = 7'b1100110, S_5 = 7'b1101101,
        S_6 = 7'b1111101, S_7 = 7'b0000111, S_8 = 7'b1111111,
        S_9 = 7'b1101111, S_MINUS = 7'b1000000, S_BLK = 7'b0000000;

    // Command TM1638
    localparam [7:0]
        C_READ  = 8'b01000010,
        C_WRITE = 8'b01000000,
        C_DISP  = 8'b10001111,
        C_ADDR  = 8'b11000000;

    // --- Persiapan Pin Bidirectional (I/O) TM1638 ---
    reg rst = HIGH;
    reg tm_rw, tm_latch;
    wire dio_in, dio_out, busy;
    wire [7:0] tm_data, tm_in;
    reg [7:0] tm_out;
    
    // Variabel Animasi LED Atas 
    reg [2:0] led_pos = 0;   // Nilai 0 sampai 7 (mewakili LED 1 sampai 8)
    reg led_dir = 0;         // 0: Geser ke kanan, 1: Geser ke kiri

    assign tm_in = tm_data;
    assign tm_data = tm_rw ? tm_out : 8'hZZ;

    SB_IO #(
        .PIN_TYPE(6'b101001),
        .PULLUP(1'b1)
    ) tm_dio_io (
        .PACKAGE_PIN(tm_dio),
        .OUTPUT_ENABLE(tm_rw),
        .D_IN_0(dio_in),
        .D_OUT_0(dio_out)
    );

    tm1638 u_tm1638 (
        .clk(clk), .rst(rst), .data_latch(tm_latch),
        .data(tm_data), .rw(tm_rw), .busy(busy),
        .sclk(tm_clk), .dio_in(dio_in), .dio_out(dio_out)
    );

    // --- Pembuatan Pita Data NIM (Seamless Loop) ---
    // Total 25 karakter = 15 (NIM) + 3 (Spasi) + 7 (Jiplakan awal untuk padding)
    wire [6:0] msg [0:24];

    // Data NIM Asli (Indeks 0 - 14)
    assign msg[0]=S_2;   assign msg[1]=S_2;   assign msg[2]=S_MINUS; assign msg[3]=S_5;
    assign msg[4]=S_0;   assign msg[5]=S_0;   assign msg[6]=S_3;     assign msg[7]=S_5;
    assign msg[8]=S_5;   assign msg[9]=S_MINUS; assign msg[10]=S_5;  assign msg[11]=S_4;
    assign msg[12]=S_8;  assign msg[13]=S_4;  assign msg[14]=S_5;
    
    // Spasi Pemisah Antar Putaran (Indeks 15 - 17)
    assign msg[15]=S_BLK; assign msg[16]=S_BLK; assign msg[17]=S_BLK;
    
    // Padding untuk Looping Seamless (Indeks 18 - 24)
    assign msg[18]=S_2;   assign msg[19]=S_2;   assign msg[20]=S_MINUS; assign msg[21]=S_5;
    assign msg[22]=S_0;   assign msg[23]=S_0;   assign msg[24]=S_3;

    // --- Variabel Logika Animasi ---
    reg [23:0] timer = 0;
    reg [23:0] led_timer = 0; // Timer LED
    reg [4:0] offset = 0;
    reg dir_right = 0;
    reg [1:0] mode = 2'b00; 

    reg [2:0] led_pos = 0; 
    reg led_dir = 0;
    
    // Variabel Komunikasi
    reg [7:0] keys;
    reg [5:0] step = 0;
    reg [4:0] counter = 0;

    always @(posedge clk) begin
        if (rst) begin
            rst <= LOW;
            tm_cs <= HIGH;
            tm_rw <= HIGH;
            step <= 0;
            keys <= 0;
            timer <= 0;
            offset <= 0;
            led_pos <= 0;
            led_dir <= 0;
        end else begin
            // 1. Logika Pembacaan Tombol S1 - S3 (Memori / Latch Mode)
            if (keys[7]) mode <= 2'b01;      // S1 Ditekan -> Geser Kiri
            else if (keys[6]) mode <= 2'b10; // S2 Ditekan -> Geser Kanan
            else if (keys[5]) mode <= 2'b00; // S3 Ditekan -> Ping-pong

           // 2. Timer Animasi
            if (timer >= 12000000) begin
                timer <= 0;

                // A. Pergerakan Teks NIM 
                if (mode == 2'b01) begin
                    if (offset < 17) offset <= offset + 1;
                    else offset <= 0; 
                end else if (mode == 2'b10) begin
                    if (offset > 0) offset <= offset - 1;
                    else offset <= 17; 
                end else begin
                    if (dir_right) begin
                        if (offset > 0) offset <= offset - 1;
                        else begin dir_right <= 0; offset <= offset + 1; end
                    end else begin
                        if (offset < 17) offset <= offset + 1;
                        else begin dir_right <= 1; offset <= offset - 1; end
                    end
                end
            end else begin
                timer <= timer + 1;
            end

            // B. Timer Khusus LED 
            if (led_timer >= 1200000) begin 
                led_timer <= 0;

                // Pergerakan Ping-pong Tanpa Jeda di Ujung
                if (led_dir == 0) begin
                    if (led_pos < 3'd7) begin
                        led_pos <= led_pos + 1;
                    end else begin
                        led_pos <= led_pos - 1; // Langsung mundur ke 6
                        led_dir <= 1;           // Ubah arah ke kiri seketika
                    end
                end else begin
                    if (led_pos > 3'd0) begin
                        led_pos <= led_pos - 1;
                    end else begin
                        led_pos <= led_pos + 1; // Langsung maju ke 1
                        led_dir <= 0;           // Ubah arah ke kanan seketika
                    end
                end
            end else begin
                led_timer <= led_timer + 1;
            end

            // 3. State Machine untuk Komunikasi dengan TM1638
            if (counter[0] && ~busy) begin
                case (step)
                    // --- MINTA DATA TOMBOL (READ KEYS) ---
                    1:  {tm_cs, tm_rw}     <= {LOW, HIGH};
                    2:  {tm_latch, tm_out} <= {HIGH, C_READ};
                    3:  {tm_latch, tm_rw}  <= {HIGH, LOW};
                    4:  {keys[7], keys[3]} <= {tm_in[0], tm_in[4]};
                    5:  {tm_latch}         <= {HIGH};
                    6:  {keys[6], keys[2]} <= {tm_in[0], tm_in[4]};
                    7:  {tm_latch}         <= {HIGH};
                    8:  {keys[5], keys[1]} <= {tm_in[0], tm_in[4]};
                    9:  {tm_latch}         <= {HIGH};
                    10: {keys[4], keys[0]} <= {tm_in[0], tm_in[4]};
                    11: {tm_cs}            <= {HIGH};

                    // --- TULIS NIM & LED KE LAYAR (WRITE DISPLAY) ---
                    12: {tm_cs, tm_rw}     <= {LOW, HIGH};
                    13: {tm_latch, tm_out} <= {HIGH, C_WRITE};
                    14: {tm_cs}            <= {HIGH};
                    
                    15: {tm_cs, tm_rw}     <= {LOW, HIGH};
                    16: {tm_latch, tm_out} <= {HIGH, C_ADDR}; // Alamat awal layar

                    17: {tm_latch, tm_out} <= {HIGH, {1'b0, msg[offset+0]}};                    // Digit 1
                    18: {tm_latch, tm_out} <= {HIGH, {7'b0, (led_pos == 3'd0) ? 1'b1 : 1'b0}}; // LED 1
                    19: {tm_latch, tm_out} <= {HIGH, {1'b0, msg[offset+1]}};                    // Digit 2
                    20: {tm_latch, tm_out} <= {HIGH, {7'b0, (led_pos == 3'd1) ? 1'b1 : 1'b0}}; // LED 2
                    21: {tm_latch, tm_out} <= {HIGH, {1'b0, msg[offset+2]}};                    // Digit 3
                    22: {tm_latch, tm_out} <= {HIGH, {7'b0, (led_pos == 3'd2) ? 1'b1 : 1'b0}}; // LED 3
                    23: {tm_latch, tm_out} <= {HIGH, {1'b0, msg[offset+3]}};                    // Digit 4
                    24: {tm_latch, tm_out} <= {HIGH, {7'b0, (led_pos == 3'd3) ? 1'b1 : 1'b0}}; // LED 4
                    25: {tm_latch, tm_out} <= {HIGH, {1'b0, msg[offset+4]}};                    // Digit 5
                    26: {tm_latch, tm_out} <= {HIGH, {7'b0, (led_pos == 3'd4) ? 1'b1 : 1'b0}}; // LED 5
                    27: {tm_latch, tm_out} <= {HIGH, {1'b0, msg[offset+5]}};                    // Digit 6
                    28: {tm_latch, tm_out} <= {HIGH, {7'b0, (led_pos == 3'd5) ? 1'b1 : 1'b0}}; // LED 6
                    29: {tm_latch, tm_out} <= {HIGH, {1'b0, msg[offset+6]}};                    // Digit 7
                    30: {tm_latch, tm_out} <= {HIGH, {7'b0, (led_pos == 3'd6) ? 1'b1 : 1'b0}}; // LED 7
                    31: {tm_latch, tm_out} <= {HIGH, {1'b0, msg[offset+7]}};                    // Digit 8
                    32: {tm_latch, tm_out} <= {HIGH, {7'b0, (led_pos == 3'd7) ? 1'b1 : 1'b0}}; // LED 8

                    33: {tm_cs}            <= {HIGH};
                    34: {tm_cs, tm_rw}     <= {LOW, HIGH};
                    35: {tm_latch, tm_out} <= {HIGH, C_DISP}; // Nyalakan kecerahan maksimal
                    36: begin tm_cs <= HIGH; step <= 0; end   // Selesai, Reset siklus
                endcase
                
                if (step != 36) step <= step + 1;
            end else if (busy) begin
                tm_latch <= LOW;
            end
            counter <= counter + 1;
        end
    end
endmodule
