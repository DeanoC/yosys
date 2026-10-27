module top;
    localparam logic [32:0] IDX = 33'h100000000;
    logic [7:0] values [0:1];

    initial values = '{IDX: 8'h11, default: 8'h22};
endmodule
