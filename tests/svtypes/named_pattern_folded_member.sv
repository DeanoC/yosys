module named_pattern_folded_member(output logic [1:0] result);
    typedef struct packed {
        logic x;
        logic y;
    } s_t;

    s_t value;
    assign value = '{x: (1'b0 | 1'b1), y: 1'b0};
    assign result = value;

    always_comb assert(result == 2'b10);
endmodule
