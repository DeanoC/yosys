module array_pattern_default(output logic [7:0] result);
    logic [3:0] a [1:0];

    initial a = '{default: 4'h0};
    assign result = {a[1], a[0]};

    always_comb assert(result == 8'h00);
endmodule
