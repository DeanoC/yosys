module named_pattern_positional_nested(output logic [2:0] result);
    typedef struct packed {
        logic x;
        logic y;
    } inner_t;
    typedef struct packed {
        inner_t inner;
        logic flag;
    } outer_t;

    outer_t o;
    assign o = '{inner: '{1'b1, 1'b0}, flag: 1'b0};
    assign result = o;

    always_comb assert(result == 3'b100);
endmodule
