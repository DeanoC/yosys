module named_array_pattern_index(output logic [7:0] result);
    localparam int IDX = 1;
    logic [3:0] a [0:1];
    logic [3:0] b [0:1];

    initial a = '{IDX: 4'hA, default: 4'h0};
    initial b = '{IDX + 0: 4'h5, default: 4'h1};
    assign result = {a[1], a[0]};

    always_comb assert(result == 8'hA0 && b[1] == 4'h5 && b[0] == 4'h1);
endmodule
