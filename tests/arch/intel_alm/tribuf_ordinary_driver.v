(* blackbox *)
module ordinary_driver(input a, output y);
endmodule

module tribuf_ordinary_driver #(
    parameter WIDTH = 1, POSITION = 1, SOURCE = 0, SHARED = 1, ENABLE = 0
) (
    input wire [WIDTH-1:0] d,
    input wire d2, en, clk,
    output wire [WIDTH-1:0] pad, other_pad, readback
);
    wire [WIDTH-1:0] t, branch, next_branch;
    wire ordinary;
    wire driver_en, zero_alias, opaque;
    assign zero_alias = 1'b0;
    generate
        if (ENABLE == 0) assign driver_en = en;
        if (ENABLE == 1) assign driver_en = 1'b0;
        if (ENABLE == 2) assign driver_en = zero_alias;
        if (ENABLE == 3) assign driver_en = en & 1'b0;
        if (ENABLE == 4) assign driver_en = ~(en | 1'b1);
        if (ENABLE == 5) assign driver_en = en ? 1'b0 : 1'b0;
        if (ENABLE == 6) assign driver_en = {zero_alias, zero_alias} + 2'b00;
        if (ENABLE == 7) assign driver_en = 1'b1;
        if (ENABLE == 8) assign driver_en = ~(en === 1'bx);
        if (ENABLE == 9) assign driver_en = 1'bx;
        if (ENABLE == 10) begin
            ordinary_driver unknown_enable(.a(en), .y(opaque));
            assign driver_en = opaque & 1'b0;
        end
    endgenerate
    assign t = driver_en ? d : {WIDTH{1'bz}};
    assign branch = t;
    assign next_branch = branch;
    assign pad = next_branch;
    assign other_pad = SHARED ? t : d;
    assign readback = pad;
    generate
        if (SOURCE == 0) assign ordinary = d2;
        if (SOURCE == 1) assign ordinary = 1'b0;
        if (SOURCE == 2) assign ordinary = 1'b1;
        if (SOURCE == 3) assign ordinary = ~d2;
        if (SOURCE == 4) begin
            reg q;
            always @(posedge clk) q <= d2;
            assign ordinary = q;
        end
        if (SOURCE == 5) ordinary_driver driver(.a(d2), .y(ordinary));
        if (SOURCE == 6) assign ordinary = 1'bz;
        if (SOURCE == 7) assign ordinary = 1'bx;
        if (SOURCE == 8) assign ordinary = other_pad[0];

        if (POSITION == 0) assign t[0] = ordinary;
        if (POSITION == 1) assign branch[0] = ordinary;
        if (POSITION == 2) assign next_branch[0] = ordinary;
        if (POSITION == 3) assign pad[0] = ordinary;
    endgenerate
endmodule
