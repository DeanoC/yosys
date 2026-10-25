module named_pattern_member_select(output logic [2:0] result);
    typedef struct packed {
        logic x;
        logic [1:0] y;
    } inner_t;
    typedef struct packed {
        inner_t inner;
        logic flag;
    } outer_t;

    outer_t s;
    assign s.inner = '{x: 1'b1, y: 2'b10};
    assign result = s.inner;

    always_comb assert(result == 3'b110);
endmodule
