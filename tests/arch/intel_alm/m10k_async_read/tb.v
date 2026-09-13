// Cycle-driven fixture for the Yosys RTL simulator. The read data remains a
// top-level port so the regression can inspect its VCD.
module tb(clk, rd_addr, rd_data);
    input clk;
    output reg [8:0] rd_addr = 9'd0;
    output wire [19:0] rd_data;

    reg [8:0] wr_addr = 9'd0;
    reg [19:0] wr_data = 20'd0;
    reg wr_en = 1'b0;
    reg [2:0] cycle = 3'd0;

    MISTRAL_M10K #(
        .CFG_ABITS(9),
        .CFG_DBITS(20),
        .CFG_ASYNC_READ(1),
        .INIT(10240'hA6)
    ) dut (
        .CLK1(clk),
        .A1ADDR(wr_addr),
        .A1DATA(wr_data),
        // The 20-bit primitive has the established active-low A1EN contract.
        .A1EN(~wr_en),
        .A1BE(2'b11),
        .B1ADDR(rd_addr),
        .B1DATA(rd_data),
        .B1EN(1'b1),
        .CLK2(1'b0),
        .ACLR0(1'b0),
        .ACLR1(1'b0)
    );

    always @(posedge clk) begin
        case (cycle)
            3'd0: begin
                // Read an initialized location.
                rd_addr <= 9'd0;
                wr_en <= 1'b0;
            end
            3'd1: begin
                // Write address 3 on CLK1 while reading that address.
                wr_addr <= 9'd3;
                wr_data <= 20'h54321;
                wr_en <= 1'b1;
                rd_addr <= 9'd3;
            end
            3'd2: begin
                // The write from the preceding edge is now visible without a
                // read clock edge.
                wr_en <= 1'b0;
                rd_addr <= 9'd3;
            end
            default: begin
                // Move to an untouched neighbour after observing the write.
                wr_en <= 1'b0;
                rd_addr <= 9'd4;
            end
        endcase
        cycle <= cycle + 1'b1;
    end
endmodule
