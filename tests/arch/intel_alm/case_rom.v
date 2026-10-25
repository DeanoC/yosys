// Case-table ROMs. A 128-entry table is large enough for memory_bram to
// infer one M10K. The read is registered, so the block has a read clock
// and no write clock. nextpnr-mistral requires CLK1 to be that clock.
module rom_repro (
    input clk,
    output reg led
);
    reg [7:0] a = 8'h1;
    reg [3:0] y, q;
    always @* begin
        case (a)
            8'd0: y = 4'd3;
            8'd1: y = 4'd10;
            8'd2: y = 4'd1;
            8'd3: y = 4'd8;
            8'd4: y = 4'd15;
            8'd5: y = 4'd6;
            8'd6: y = 4'd13;
            8'd7: y = 4'd4;
            8'd8: y = 4'd11;
            8'd9: y = 4'd2;
            8'd10: y = 4'd9;
            8'd11: y = 4'd0;
            8'd12: y = 4'd7;
            8'd13: y = 4'd14;
            8'd14: y = 4'd5;
            8'd15: y = 4'd12;
            8'd16: y = 4'd3;
            8'd17: y = 4'd10;
            8'd18: y = 4'd1;
            8'd19: y = 4'd8;
            8'd20: y = 4'd15;
            8'd21: y = 4'd6;
            8'd22: y = 4'd13;
            8'd23: y = 4'd4;
            8'd24: y = 4'd11;
            8'd25: y = 4'd2;
            8'd26: y = 4'd9;
            8'd27: y = 4'd0;
            8'd28: y = 4'd7;
            8'd29: y = 4'd14;
            8'd30: y = 4'd5;
            8'd31: y = 4'd12;
            8'd32: y = 4'd3;
            8'd33: y = 4'd10;
            8'd34: y = 4'd1;
            8'd35: y = 4'd8;
            8'd36: y = 4'd15;
            8'd37: y = 4'd6;
            8'd38: y = 4'd13;
            8'd39: y = 4'd4;
            8'd40: y = 4'd11;
            8'd41: y = 4'd2;
            8'd42: y = 4'd9;
            8'd43: y = 4'd0;
            8'd44: y = 4'd7;
            8'd45: y = 4'd14;
            8'd46: y = 4'd5;
            8'd47: y = 4'd12;
            8'd48: y = 4'd3;
            8'd49: y = 4'd10;
            8'd50: y = 4'd1;
            8'd51: y = 4'd8;
            8'd52: y = 4'd15;
            8'd53: y = 4'd6;
            8'd54: y = 4'd13;
            8'd55: y = 4'd4;
            8'd56: y = 4'd11;
            8'd57: y = 4'd2;
            8'd58: y = 4'd9;
            8'd59: y = 4'd0;
            8'd60: y = 4'd7;
            8'd61: y = 4'd14;
            8'd62: y = 4'd5;
            8'd63: y = 4'd12;
            8'd64: y = 4'd3;
            8'd65: y = 4'd10;
            8'd66: y = 4'd1;
            8'd67: y = 4'd8;
            8'd68: y = 4'd15;
            8'd69: y = 4'd6;
            8'd70: y = 4'd13;
            8'd71: y = 4'd4;
            8'd72: y = 4'd11;
            8'd73: y = 4'd2;
            8'd74: y = 4'd9;
            8'd75: y = 4'd0;
            8'd76: y = 4'd7;
            8'd77: y = 4'd14;
            8'd78: y = 4'd5;
            8'd79: y = 4'd12;
            8'd80: y = 4'd3;
            8'd81: y = 4'd10;
            8'd82: y = 4'd1;
            8'd83: y = 4'd8;
            8'd84: y = 4'd15;
            8'd85: y = 4'd6;
            8'd86: y = 4'd13;
            8'd87: y = 4'd4;
            8'd88: y = 4'd11;
            8'd89: y = 4'd2;
            8'd90: y = 4'd9;
            8'd91: y = 4'd0;
            8'd92: y = 4'd7;
            8'd93: y = 4'd14;
            8'd94: y = 4'd5;
            8'd95: y = 4'd12;
            8'd96: y = 4'd3;
            8'd97: y = 4'd10;
            8'd98: y = 4'd1;
            8'd99: y = 4'd8;
            8'd100: y = 4'd15;
            8'd101: y = 4'd6;
            8'd102: y = 4'd13;
            8'd103: y = 4'd4;
            8'd104: y = 4'd11;
            8'd105: y = 4'd2;
            8'd106: y = 4'd9;
            8'd107: y = 4'd0;
            8'd108: y = 4'd7;
            8'd109: y = 4'd14;
            8'd110: y = 4'd5;
            8'd111: y = 4'd12;
            8'd112: y = 4'd3;
            8'd113: y = 4'd10;
            8'd114: y = 4'd1;
            8'd115: y = 4'd8;
            8'd116: y = 4'd15;
            8'd117: y = 4'd6;
            8'd118: y = 4'd13;
            8'd119: y = 4'd4;
            8'd120: y = 4'd11;
            8'd121: y = 4'd2;
            8'd122: y = 4'd9;
            8'd123: y = 4'd0;
            8'd124: y = 4'd7;
            8'd125: y = 4'd14;
            8'd126: y = 4'd5;
            8'd127: y = 4'd12;
            default: y = 4'd0;
        endcase
    end
    always @(posedge clk) begin
        a <= {a[6:0], a[7] ^ a[5] ^ a[4] ^ a[3]};
        q <= y;
        led <= ^q;
    end
endmodule

// 64 entries stay below the M10K efficiency floor and must remain logic.
module narrow_rom (
    input clk,
    input [5:0] a,
    output reg [3:0] q
);
    reg [3:0] y;
    always @* begin
        case (a)
            6'd0: y = 4'd1;
            6'd1: y = 4'd6;
            6'd2: y = 4'd11;
            6'd3: y = 4'd0;
            6'd4: y = 4'd5;
            6'd5: y = 4'd10;
            6'd6: y = 4'd15;
            6'd7: y = 4'd4;
            6'd8: y = 4'd9;
            6'd9: y = 4'd14;
            6'd10: y = 4'd3;
            6'd11: y = 4'd8;
            6'd12: y = 4'd13;
            6'd13: y = 4'd2;
            6'd14: y = 4'd7;
            6'd15: y = 4'd12;
            6'd16: y = 4'd1;
            6'd17: y = 4'd6;
            6'd18: y = 4'd11;
            6'd19: y = 4'd0;
            6'd20: y = 4'd5;
            6'd21: y = 4'd10;
            6'd22: y = 4'd15;
            6'd23: y = 4'd4;
            6'd24: y = 4'd9;
            6'd25: y = 4'd14;
            6'd26: y = 4'd3;
            6'd27: y = 4'd8;
            6'd28: y = 4'd13;
            6'd29: y = 4'd2;
            6'd30: y = 4'd7;
            6'd31: y = 4'd12;
            6'd32: y = 4'd1;
            6'd33: y = 4'd6;
            6'd34: y = 4'd11;
            6'd35: y = 4'd0;
            6'd36: y = 4'd5;
            6'd37: y = 4'd10;
            6'd38: y = 4'd15;
            6'd39: y = 4'd4;
            6'd40: y = 4'd9;
            6'd41: y = 4'd14;
            6'd42: y = 4'd3;
            6'd43: y = 4'd8;
            6'd44: y = 4'd13;
            6'd45: y = 4'd2;
            6'd46: y = 4'd7;
            6'd47: y = 4'd12;
            6'd48: y = 4'd1;
            6'd49: y = 4'd6;
            6'd50: y = 4'd11;
            6'd51: y = 4'd0;
            6'd52: y = 4'd5;
            6'd53: y = 4'd10;
            6'd54: y = 4'd15;
            6'd55: y = 4'd4;
            6'd56: y = 4'd9;
            6'd57: y = 4'd14;
            6'd58: y = 4'd3;
            6'd59: y = 4'd8;
            6'd60: y = 4'd13;
            6'd61: y = 4'd2;
            6'd62: y = 4'd7;
            6'd63: y = 4'd12;
        endcase
    end
    always @(posedge clk)
        q <= y;
endmodule

// No clocked read: this must not become an M10K. Cyclone V M10K has no
// asynchronous read, and nextpnr-mistral rejects that configuration.
module async_rom (
    input [6:0] a,
    output reg [3:0] y
);
    always @* begin
        case (a)
            7'd0: y = 4'd3;
            7'd1: y = 4'd10;
            7'd2: y = 4'd1;
            7'd3: y = 4'd8;
            7'd4: y = 4'd15;
            7'd5: y = 4'd6;
            7'd6: y = 4'd13;
            7'd7: y = 4'd4;
            7'd8: y = 4'd11;
            7'd9: y = 4'd2;
            7'd10: y = 4'd9;
            7'd11: y = 4'd0;
            7'd12: y = 4'd7;
            7'd13: y = 4'd14;
            7'd14: y = 4'd5;
            7'd15: y = 4'd12;
            7'd16: y = 4'd3;
            7'd17: y = 4'd10;
            7'd18: y = 4'd1;
            7'd19: y = 4'd8;
            7'd20: y = 4'd15;
            7'd21: y = 4'd6;
            7'd22: y = 4'd13;
            7'd23: y = 4'd4;
            7'd24: y = 4'd11;
            7'd25: y = 4'd2;
            7'd26: y = 4'd9;
            7'd27: y = 4'd0;
            7'd28: y = 4'd7;
            7'd29: y = 4'd14;
            7'd30: y = 4'd5;
            7'd31: y = 4'd12;
            7'd32: y = 4'd3;
            7'd33: y = 4'd10;
            7'd34: y = 4'd1;
            7'd35: y = 4'd8;
            7'd36: y = 4'd15;
            7'd37: y = 4'd6;
            7'd38: y = 4'd13;
            7'd39: y = 4'd4;
            7'd40: y = 4'd11;
            7'd41: y = 4'd2;
            7'd42: y = 4'd9;
            7'd43: y = 4'd0;
            7'd44: y = 4'd7;
            7'd45: y = 4'd14;
            7'd46: y = 4'd5;
            7'd47: y = 4'd12;
            7'd48: y = 4'd3;
            7'd49: y = 4'd10;
            7'd50: y = 4'd1;
            7'd51: y = 4'd8;
            7'd52: y = 4'd15;
            7'd53: y = 4'd6;
            7'd54: y = 4'd13;
            7'd55: y = 4'd4;
            7'd56: y = 4'd11;
            7'd57: y = 4'd2;
            7'd58: y = 4'd9;
            7'd59: y = 4'd0;
            7'd60: y = 4'd7;
            7'd61: y = 4'd14;
            7'd62: y = 4'd5;
            7'd63: y = 4'd12;
            7'd64: y = 4'd3;
            7'd65: y = 4'd10;
            7'd66: y = 4'd1;
            7'd67: y = 4'd8;
            7'd68: y = 4'd15;
            7'd69: y = 4'd6;
            7'd70: y = 4'd13;
            7'd71: y = 4'd4;
            7'd72: y = 4'd11;
            7'd73: y = 4'd2;
            7'd74: y = 4'd9;
            7'd75: y = 4'd0;
            7'd76: y = 4'd7;
            7'd77: y = 4'd14;
            7'd78: y = 4'd5;
            7'd79: y = 4'd12;
            7'd80: y = 4'd3;
            7'd81: y = 4'd10;
            7'd82: y = 4'd1;
            7'd83: y = 4'd8;
            7'd84: y = 4'd15;
            7'd85: y = 4'd6;
            7'd86: y = 4'd13;
            7'd87: y = 4'd4;
            7'd88: y = 4'd11;
            7'd89: y = 4'd2;
            7'd90: y = 4'd9;
            7'd91: y = 4'd0;
            7'd92: y = 4'd7;
            7'd93: y = 4'd14;
            7'd94: y = 4'd5;
            7'd95: y = 4'd12;
            7'd96: y = 4'd3;
            7'd97: y = 4'd10;
            7'd98: y = 4'd1;
            7'd99: y = 4'd8;
            7'd100: y = 4'd15;
            7'd101: y = 4'd6;
            7'd102: y = 4'd13;
            7'd103: y = 4'd4;
            7'd104: y = 4'd11;
            7'd105: y = 4'd2;
            7'd106: y = 4'd9;
            7'd107: y = 4'd0;
            7'd108: y = 4'd7;
            7'd109: y = 4'd14;
            7'd110: y = 4'd5;
            7'd111: y = 4'd12;
            7'd112: y = 4'd3;
            7'd113: y = 4'd10;
            7'd114: y = 4'd1;
            7'd115: y = 4'd8;
            7'd116: y = 4'd15;
            7'd117: y = 4'd6;
            7'd118: y = 4'd13;
            7'd119: y = 4'd4;
            7'd120: y = 4'd11;
            7'd121: y = 4'd2;
            7'd122: y = 4'd9;
            7'd123: y = 4'd0;
            7'd124: y = 4'd7;
            7'd125: y = 4'd14;
            7'd126: y = 4'd5;
            7'd127: y = 4'd12;
        endcase
    end
endmodule

// A real simple-dual RAM keeps its write clock on CLK1.
module sdp_ram (
    input clk_w, clk_r, we,
    input [9:0] wa, ra,
    input [9:0] wd,
    output reg [9:0] rd
);
    reg [9:0] mem [0:1023];
    always @(posedge clk_w)
        if (we)
            mem[wa] <= wd;
    always @(posedge clk_r)
        rd <= mem[ra];
endmodule
