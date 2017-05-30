// These are the definitions for classes in the can transmitter test bench
//
    import cantidef::*;

class Si extends uvm_sequence_item;
`uvm_object_utils(Si)
reg do_reset;
rand reg [7:0] quantaDiv;
rand reg [5:0] propQuanta,seg1Quanta;
rand reg [63:0] xmitdata; // data in. Assume big endian byte order
rand reg [3:0] datalen; // 0-8 are valid
rand reg [28:0] id; // use the upper 11 bits in 11 bit mode
rand reg format; // 0=11 bit 1=29 bit
rand cantidef::xmitFrameType frameType;
  
  function new(string name="cant");
    super.new(name);
  endfunction : new
endclass : Si

class DBIT extends uvm_sequence_item;
`uvm_object_utils(DBIT)

  reg dout;
  reg ddrive;
  reg din;

  function new(string name = "DBIT");
    super.new(name);
  endfunction : new

endclass : DBIT

typedef enum logic [1:0] { D0,D1,DA,DX } Ebit;

class EXPframe;
    Ebit fdata[404];    // biggest frameType
    string dname[404]; // string names for each bit
    int flen;
    
    function new();
      flen=0;
    endfunction : new

endclass : EXPframe

class Ri;
    reg [1:0] addr;
    reg [31:0] value;
    reg write;
endclass : Ri


