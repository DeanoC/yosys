// 128-bit Avalon port 0 (command 0, data 0 and 1) and 64-bit port 1
// (command 1, data 2) in the MiSTer sysmem layout.
module top (
    input  wire         clk,
    input  wire         read,
    input  wire         write,
    input  wire [27:0]  address,
    input  wire [127:0] writedata,
    output wire         ready0,
    output wire         ready1,
    output wire [127:0] readdata0,
    output wire         valid0,
    output wire [63:0]  readdata1,
    output wire         valid1
);
    wire [79:0] rd_data_0, rd_data_1, rd_data_2;
    assign readdata0 = {rd_data_1[63:0], rd_data_0[63:0]};
    assign readdata1 = rd_data_2[63:0];
    cyclonev_hps_interface_fpga2sdram f2sdram (
        .cfg_axi_mm_select(6'h00), .cfg_cport_rfifo_map(18'h000d0),
        .cfg_cport_type(12'h03f), .cfg_cport_wfifo_map(18'h000d0),
        .cfg_port_width(12'h016), .cfg_rfifo_cport_map(16'h2100),
        .cfg_wfifo_cport_map(16'h2100),
        .cmd_port_clk_0(clk), .cmd_port_clk_1(clk),
        .cmd_valid_0(read | write), .cmd_valid_1(read | write),
        .cmd_data_0({18'd0, 8'd1, 4'd0, address, write, read}),
        .cmd_data_1({18'd0, 8'd1, 3'd0, address, 1'b0, write, read}),
        .cmd_ready_0(ready0), .cmd_ready_1(ready1),
        .wr_clk_0(clk), .wr_clk_1(clk), .wr_clk_2(clk),
        .wr_data_0({2'b00, 8'hff, 16'd0, writedata[63:0]}),
        .wr_data_1({2'b00, 8'hff, 16'd0, writedata[127:64]}),
        .wr_data_2({2'b00, 8'hff, 16'd0, writedata[63:0]}),
        .rd_clk_0(clk), .rd_clk_1(clk), .rd_clk_2(clk),
        .rd_ready_0(1'b1), .rd_ready_1(1'b1), .rd_ready_2(1'b1),
        .rd_data_0(rd_data_0), .rd_data_1(rd_data_1), .rd_data_2(rd_data_2),
        .rd_valid_1(valid0), .rd_valid_2(valid1),
        .wrack_ready_0(1'b1), .wrack_ready_1(1'b1)
    );
endmodule
