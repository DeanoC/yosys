`default_nettype none

module top(output logic result);
    typedef struct packed { logic field; } s_t;
    s_t value;

    assign value = '{field: 1'b1};
    assign result = value.field;

    always_comb assert(result);
endmodule
