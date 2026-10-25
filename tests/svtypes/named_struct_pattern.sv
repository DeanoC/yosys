module top(
    input logic a,
    output logic [2:0] y,
    output logic [2:0] y_rev,
    output logic [2:0] y_def,
    output logic [2:0] y_anon,
    output logic [2:0] y_nest,
    output logic [2:0] y_fn
);
    typedef struct packed { logic x; logic [1:0] z; } s_t;
    s_t s, s_rev, s_def;
    assign s = '{x: a, z: 2'b10};
    assign s_rev = '{z: 2'b01, x: a};
    assign s_def = '{default: 2'b11, x: a};
    assign y = s;
    assign y_rev = s_rev;
    assign y_def = s_def;

    struct packed { logic x; logic [1:0] z; } anon;
    assign anon = '{z: 2'b10, x: a};
    assign y_anon = anon;

    typedef struct packed {
        logic x;
        struct packed { logic [1:0] z; } inner;
    } n_t;
    n_t n;
    assign n = '{inner: '{z: 2'b10}, x: a};
    assign y_nest = n;

    function automatic s_t pack(input logic v);
        pack = '{x: v, z: 2'b10};
    endfunction
    assign y_fn = pack(a);

    always_comb assert(y == {a, 2'b10});
    always_comb assert(y_rev == {a, 2'b01});
    always_comb assert(y_def == {a, 2'b11});
    always_comb assert(y_anon == {a, 2'b10});
    always_comb assert(y_nest == {a, 2'b10});
    always_comb assert(y_fn == {a, 2'b10});
endmodule
