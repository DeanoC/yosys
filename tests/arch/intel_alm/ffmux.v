// Full-flow golden RTL. Every input is left arbitrary in ffmux.ys, including
// enable, so a held value must agree after any previous data/select sequence.
module ffmux_zero(input clk, en, a, b, s, output reg q = 1'b0);
    always @(posedge clk)
        if (en) q <= s ? b : a;
endmodule

// Logical init=1 must use the existing legalizer. MISTRAL_FF itself has no
// INIT parameter and its actual simulation model always starts at zero.
module ffmux_one(input clk, en, a, b, s, output reg q = 1'b1);
    always @(posedge clk)
        if (en) q <= s ? b : a;
endmodule

module ffmux_inverted_select(input clk, en, a, b, s, output reg q = 1'b0);
    always @(posedge clk)
        if (en) q <= !s ? b : a;
endmodule

module ffmux_falling(input clk, en, a, b, s, output reg q = 1'b0);
    always @(negedge clk)
        if (en) q <= s ? b : a;
endmodule

module ffmux_shared(input clk, en0, en1, a, b, s,
                    output reg q0 = 1'b0, output reg q1 = 1'b0, output comb);
    wire selected = s ? b : a;
    assign comb = selected;
    always @(posedge clk) begin
        if (en0) q0 <= selected;
        if (en1) q1 <= selected;
    end
endmodule

// These reset-enabled cases must remain unabsorbed in the initial scope.
// The golden RTL exercises reset together with enable and arbitrary data.
module ffmux_sync_clear(input clk, en, reset, a, b, s,
                        output reg q = 1'b0);
    always @(posedge clk)
        if (en) begin
            if (reset) q <= 1'b0;
            else q <= s ? b : a;
        end
endmodule

module ffmux_async_clear(input clk, en, reset_n, a, b, s,
                         output reg q = 1'b0);
    always @(posedge clk or negedge reset_n)
        if (!reset_n) q <= 1'b0;
        else if (en) q <= s ? b : a;
endmodule

// Direct native fixtures are read with -icells and the real dff_sim.v loaded
// as a library. No replacement FF model or invented native INIT is used.
// Aliases and unrelated attributes must survive the three-port rewrite.
module ffmux_native(input clk, en, a, b, s, output q);
    wire mux_y;
    (* fixture_alias = 27 *) wire mux_alias;
    (* init = 1'b0, fixture_state = 31 *) wire q_alias;
    assign mux_alias = mux_y;
    assign q = q_alias;
    (* fixture_mux = 11 *) \$_MUX_ mux(.A(a), .B(b), .S(s), .Y(mux_y));
    (* fixture_ff = 19 *) MISTRAL_FF ff(
        .DATAIN(mux_alias), .CLK(clk), .ACLR(1'b1), .ENA(en),
        .SCLR(1'b0), .SLOAD(1'b0), .SDATA(1'b0), .Q(q_alias));
endmodule

module ffmux_native_shared(input clk, en0, en1, a, b, s,
                           output q0, q1, comb);
    wire mux_y, mux_alias;
    assign mux_alias = mux_y;
    assign comb = mux_alias;
    \$_MUX_ mux(.A(a), .B(b), .S(s), .Y(mux_y));
    MISTRAL_FF ff0(.DATAIN(mux_y), .CLK(clk), .ACLR(1'b1), .ENA(en0),
        .SCLR(1'b0), .SLOAD(1'b0), .SDATA(1'b0), .Q(q0));
    MISTRAL_FF ff1(.DATAIN(mux_alias), .CLK(clk), .ACLR(1'b1), .ENA(en1),
        .SCLR(1'b0), .SLOAD(1'b0), .SDATA(1'b0), .Q(q1));
endmodule

// Each independent mux has an otherwise eligible FF. The single changed
// control below is the reason for rejecting that consumer, not an unknown
// clock or a missing data driver. None of these cells may be rewritten.
module ffmux_native_controls(input clk, en, a, b, s, reset_n, reset, load, data,
                             output [5:0] q);
    wire [5:0] selected;
    \$_MUX_ mux0(.A(a), .B(b), .S(s), .Y(selected[0]));
    \$_MUX_ mux1(.A(a), .B(b), .S(s), .Y(selected[1]));
    \$_MUX_ mux2(.A(a), .B(b), .S(s), .Y(selected[2]));
    \$_MUX_ mux3(.A(a), .B(b), .S(s), .Y(selected[3]));
    \$_MUX_ mux4(.A(a), .B(b), .S(s), .Y(selected[4]));
    \$_MUX_ mux5(.A(a), .B(b), .S(s), .Y(selected[5]));
    MISTRAL_FF async_ff(.DATAIN(selected[0]), .CLK(clk), .ACLR(reset_n),
        .ENA(en), .SCLR(1'b0), .SLOAD(1'b0), .SDATA(1'b0), .Q(q[0]));
    MISTRAL_FF sync_ff(.DATAIN(selected[1]), .CLK(clk), .ACLR(1'b1),
        .ENA(en), .SCLR(reset), .SLOAD(1'b0), .SDATA(1'b0), .Q(q[1]));
    MISTRAL_FF load_ff(.DATAIN(selected[2]), .CLK(clk), .ACLR(1'b1),
        .ENA(en), .SCLR(1'b0), .SLOAD(load), .SDATA(data), .Q(q[2]));
    MISTRAL_FF data_ff(.DATAIN(selected[3]), .CLK(clk), .ACLR(1'b1),
        .ENA(en), .SCLR(1'b0), .SLOAD(1'b0), .SDATA(data), .Q(q[3]));
    MISTRAL_FF always_load_ff(.DATAIN(selected[4]), .CLK(clk), .ACLR(1'b1),
        .ENA(en), .SCLR(1'b0), .SLOAD(1'b1), .SDATA(1'b0), .Q(q[4]));
    MISTRAL_FF clear_ff(.DATAIN(selected[5]), .CLK(clk), .ACLR(1'b0),
        .ENA(en), .SCLR(1'b0), .SLOAD(1'b0), .SDATA(1'b0), .Q(q[5]));
endmodule

// Malformed/ambiguous fixtures intentionally bypass hierarchy -check and
// equivalence. They test fail-closed admission with exact port assertions.
module ffmux_missing(input clk, en, a, b, s, output q);
    wire selected;
    \$_MUX_ mux(.A(a), .B(b), .S(s), .Y(selected));
    MISTRAL_FF ff(.DATAIN(selected), .CLK(clk), .ACLR(1'b1), .ENA(en),
        .SCLR(1'b0), .SLOAD(1'b0), .Q(q));
endmodule

module ffmux_undriven(input clk, en, b, s, output q);
    wire a, selected;
    \$_MUX_ mux(.A(a), .B(b), .S(s), .Y(selected));
    MISTRAL_FF ff(.DATAIN(selected), .CLK(clk), .ACLR(1'b1), .ENA(en),
        .SCLR(1'b0), .SLOAD(1'b0), .SDATA(1'b0), .Q(q));
endmodule

module ffmux_multiple(input clk, en, a, b, s, output q);
    wire collided, selected;
    \$_NOT_ driver0(.A(a), .Y(collided));
    \$_NOT_ driver1(.A(b), .Y(collided));
    \$_MUX_ mux(.A(collided), .B(b), .S(s), .Y(selected));
    MISTRAL_FF ff(.DATAIN(selected), .CLK(clk), .ACLR(1'b1), .ENA(en),
        .SCLR(1'b0), .SLOAD(1'b0), .SDATA(1'b0), .Q(q));
endmodule

module ffmux_unknown(input clk, en, a, b, s, output q);
    wire unknown, selected;
    FFMUX_UNKNOWN driver(.A(a), .Y(unknown));
    \$_MUX_ mux(.A(unknown), .B(b), .S(s), .Y(selected));
    MISTRAL_FF ff(.DATAIN(selected), .CLK(clk), .ACLR(1'b1), .ENA(en),
        .SCLR(1'b0), .SLOAD(1'b0), .SDATA(1'b0), .Q(q));
endmodule

// These protected aliases are canonical S0, but their raw connections must
// still be honored. The unrelated literal-zero FF must remain eligible: a
// protected alias must not protect every use of the shared constant value.
module ffmux_protected_zero(input clk, en, a, b, s, output [2:0] q);
    (* keep = 1 *) wire protected_load_zero;
    (* dont_touch = 1 *) wire protected_data_zero;
    wire selected_load, selected_data, selected_plain;
    assign protected_load_zero = 1'b0;
    assign protected_data_zero = 1'b0;
    \$_MUX_ mux_load(.A(a), .B(b), .S(s), .Y(selected_load));
    \$_MUX_ mux_data(.A(a), .B(b), .S(s), .Y(selected_data));
    \$_MUX_ mux_plain(.A(a), .B(b), .S(s), .Y(selected_plain));
    MISTRAL_FF guarded_load(.DATAIN(selected_load), .CLK(clk), .ACLR(1'b1), .ENA(en),
        .SCLR(1'b0), .SLOAD(protected_load_zero), .SDATA(1'b0), .Q(q[0]));
    MISTRAL_FF guarded_data(.DATAIN(selected_data), .CLK(clk), .ACLR(1'b1), .ENA(en),
        .SCLR(1'b0), .SLOAD(1'b0), .SDATA(protected_data_zero), .Q(q[1]));
    MISTRAL_FF plain(.DATAIN(selected_plain), .CLK(clk), .ACLR(1'b1), .ENA(en),
        .SCLR(1'b0), .SLOAD(1'b0), .SDATA(1'b0), .Q(q[2]));
endmodule
