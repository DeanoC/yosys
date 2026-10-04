module top (
    input  wire clk, shiftnld, user_tdo,
    input  wire altera_reserved_tms, altera_reserved_tck, altera_reserved_tdi,
    output wire altera_reserved_tdo,
    output wire id, crc, crc_error, crc_end, opreg, tck, tdi, shift
);
    cyclonev_chipidblock chipid (.clk(clk), .shiftnld(shiftnld), .regout(id));
    cyclonev_crcblock #(.oscillator_divider(2)) crcblock (.clk(clk), .shiftnld(shiftnld), .regout(crc),
        .crcerror(crc_error), .endofedfullchip(crc_end));
    cyclonev_opregblock opregblock (.clk(clk), .shiftnld(shiftnld), .regout(opreg));
    cyclonev_jtag jtag (.tms(altera_reserved_tms), .tck(altera_reserved_tck), .tdi(altera_reserved_tdi),
        .tdo(altera_reserved_tdo), .tdouser(user_tdo), .tckutap(tck), .tdiutap(tdi), .shiftuser(shift));
endmodule
