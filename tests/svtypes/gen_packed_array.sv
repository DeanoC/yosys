module top (
    input  logic [15:0] x,
    input  logic [1:0]  s,
    output logic [1:0]  y,
    output logic [1:0]  y_if,
    output logic        y_case
);
    for (genvar k = 0; k < 2; k++) begin : g
        logic [3:0][3:0] el;
        assign el = x;
        assign y[k] = el[s][k];
    end

    if (1) begin : gi
        logic [3:0][3:0] el;
        assign el = x;
        assign y_if[0] = el[s][0];
        assign y_if[1] = el[s][1];
    end

    case (1)
        1: begin : gc
            logic [3:0][3:0] el;
            assign el = x;
            assign y_case = el[s][0];
        end
    endcase

    always_comb assert(y == {x[s * 4 + 1], x[s * 4]});
    always_comb assert(y_if == y);
    always_comb assert(y_case == y[0]);
endmodule
