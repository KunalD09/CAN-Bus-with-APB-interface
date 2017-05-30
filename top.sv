// A very simple top level for the can transmitter
//
`timescale 1ns/10ps

`include "cant_idef.svh"

import cantidef::*;

`include "cant_intf.svh"
`include "apb_intf.svh"

`include "tapb.svhp"

`include "canxmit.sv"

`include "apb.sv"


module top();

import uvm_pkg::*;
import cant::*;


cantintf ci();
apbintf ai();

initial begin
  ci.clk=0;
  ai.PCLK=0;
  repeat(200000) begin
    #5 ci.clk=~ci.clk;
    ai.PCLK=~ai.PCLK;
  end
  $display("Used up the clocks");
  $finish;
end

initial begin
  ci.rst=0;
  ai.PRESET=0;
end

initial begin
    #0;
    uvm_config_db #(virtual cantintf)::set(null, "*", "cantintf" , ci);
    uvm_config_db #(virtual apbintf)::set(null,"*", "apbintf",ai);
    run_test("t1");
    $display("Test came back to me");
    #100;
    $finish;


end

initial begin
  $dumpfile("apb.vpd");
  $dumpvars(9,top);
end


canxmit c(ci.xmit);
apb a(ai.slv,ci.tox);





endmodule : top
