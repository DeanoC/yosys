module named_pattern_typed_cast(output logic [2:0] result);
    typedef struct packed {
        logic x;
        logic [1:0] y;
    } s_t;

    assign result = s_t'('{x: 1'b1, y: 2'b01});

    always_comb assert(result == 3'b101);
endmodule
