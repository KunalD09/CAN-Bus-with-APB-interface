//
// This is an interface for the apb bus
//
interface apbintf();
logic PCLK,PRESET;
logic [31:0] PADDR;
logic PSEL;
logic PENABLE;
logic PWRITE;
logic [31:0] PWDATA,PRDATA;
logic PREADY;
logic PSLVERR;

modport slv(input PCLK,input PRESET,input PSEL,input PENABLE,input PADDR,
    input PWRITE, input PWDATA, output PRDATA, output PREADY,
    output PSLVERR);



endinterface : apbintf
