//`include "crc.sv"; 

module canxmit(cantintf.xmit can);

typedef enum [2:0] {idle, XMITdataframe,XMITremoteframe,XMITerrorframe,
    XMIToverloadframe } new_state;

new_state current, next_state;
logic data_out,remote_out,err_out,over_out;
logic data_busy,remote_busy,err_busy,over_busy;
logic data_ddrive,remote_ddrive,err_ddrive,over_ddrive;
logic data_flag,remote_flag,err_flag,over_flag;
logic last_bit,wait_data,xtra;
logic ddrive,dout_d,busy_d;

logic [7:0] wait_counter, wait_counter_d,data_count,remote_count;


	always@(*) begin
		//bit_stuff_count_d = bit_stuff_count;
		//wait_counter_d = wait_counter;
		next_state = current;
		can.ddrive = ddrive;
		can.dout = dout_d;
		can.busy = busy_d;
		case(current)
		idle : begin
			can.ddrive = 1;
			can.dout = 1;
			if(can.startXmit==1) begin
			case(can.frameType)
			2'b00 : begin next_state = XMITdataframe; end
			2'b01 : begin next_state = XMITremoteframe; end
			2'b10 : begin next_state = XMITerrorframe; end
			2'b11 : begin next_state = XMIToverloadframe; end
			default : begin next_state = idle; end
			endcase
			can.busy = 1;
			end
			else begin
				next_state = idle;
				can.busy = 0;
			end
		end
		XMITdataframe : begin
			can.ddrive = data_ddrive;
			can.busy = data_busy;
			can.dout = data_out;
			//case(data_flag)
			//1'b0 : begin
				
				
			//	next_state = idle;
			//end
			//1'b1 : begin
               		  	
                    	//	can.busy = data_busy;
		     
				if(data_count==0) begin
					next_state = idle;
				end
				else begin
					next_state = XMITdataframe;
				end
			//end
			//endcase
		end
		XMITremoteframe : begin
			can.dout = remote_out;
			can.busy = remote_busy;
			can.ddrive = remote_ddrive;
			if(remote_count==0) begin
				next_state = idle;
			end
			else begin
				next_state = XMITremoteframe;
			end
			
		end
		XMITerrorframe : begin
			case(err_flag)
			1'b1 : begin
				can.dout = 1;
				next_state = idle;
			end
			1'b0 : begin
				can.dout = err_out;
				next_state = XMITerrorframe;
			end
			endcase
		end
		XMIToverloadframe : begin
			case(over_flag)
			1'b1 : begin
				can.dout = 1;
				next_state = idle;
			end
			1'b0 : begin
				can.dout = over_out;
				next_state = XMIToverloadframe;
			end
			endcase
		end
		endcase
	end

	always@(posedge can.clk) begin
		if(can.rst) begin
			current <= #1 idle;
			ddrive <= #1 0;
			dout_d <= #1 0;
			busy_d <= #1 0;
		end
		else begin
			ddrive <= #1 can.ddrive;
			dout_d <= #1 can.dout;
			busy_d <= #1 can.busy;
			current <= #1 next_state;
			//bit_stuff_count <= bit_stuff_count_d;
		end
	end


dataframe  data(
	.clk(can.clk), .reset(can.rst), 
	.din(can.din), 
	.startXmit(can.startXmit),
	.quantaDiv(can.quantaDiv), 
	.propQuanta(can.propQuanta),
    	.seg1Quanta(can.seg1Quanta),
	.xmitdata(can.xmitdata),
    	.datalen(can.datalen), 		// Number of bytes
	.id(can.id), 		//Arbitration field
	.format(can.format), 
	.frameType(can.frameType),
    	.dout(data_out), 
	.busy(data_busy),
	.ddrive(data_ddrive),
	.data_flag(data_flag),
	.count_d(data_count),
	.last_bit(last_bit)
	
);


remoteframe remote(
	.clk(can.clk), .reset(can.rst), 
	.din(can.din), .startXmit(can.startXmit),
	.quantaDiv(can.quantaDiv), 
	.propQuanta(can.propQuanta),
    	.seg1Quanta(can.seg1Quanta),
	.datalen(can.datalen),
	.id(can.id), 		//Arbitration field
	.format(can.format), 
	.frameType(can.frameType),
    	.dout(remote_out), 
	.busy(remote_busy),
	.count_d(remote_count),
	.top_state(current),
	.ddrive(remote_ddrive),
	.remote_flag(remote_flag)
);

errframe error(
	.clk(can.clk), 
	.reset(can.rst), 
	.din(can.din), 
	.startXmit(can.startXmit),
	.quantaDiv(can.quantaDiv), 
	.propQuanta(can.propQuanta),
    	.seg1Quanta(can.seg1Quanta), 
	.frameType(can.frameType),
    	.dout(err_out), 
	.busy(err_busy),
	.ddrive(err_ddrive),
	.err_out_flag(err_flag)
);

overload overloadframe(
	.clk(can.clk), 
	.reset(can.rst), 
	.din(can.din), 
	.startXmit(can.startXmit),
	.quantaDiv(can.quantaDiv), 
	.propQuanta(can.propQuanta),
    	.seg1Quanta(can.seg1Quanta), 
	.frameType(can.frameType),
    	.dout(over_out), 
	.busy(over_busy),
	.ddrive(over_ddrive),
	.over_flag_out(over_flag)
);
endmodule

////////////////////////////////////////// Data Frame State Machine. ////////////////////////////////////////

module dataframe(
	input clk, input reset, 
	input din, input startXmit,
	input [7:0] quantaDiv, 
	input [5:0] propQuanta,
    	input [5:0] seg1Quanta,
	input [63:0] xmitdata,
    	input [3:0] datalen, 		// Number of bytes
	input [28:0] id, 		//Arbitration field
	input format, 
	input [1:0] frameType,
    	output logic dout, 
	output logic busy,
	output logic ddrive,
	output logic [7:0] count_d,
	output logic data_flag,last_bit
);
	logic [138:0] tranx_d,tranx,crcx,crcx_d;
	logic wait_flag_d,ddrive_d;
	logic d_d,d;
	logic crc_flag_d,crc_flag,xmit_flag_d,xmit_flag,data_flag_d,wait_flag;
	logic [14:0] crc_d,crc;
	logic [101:0] crc_in,crc_in_d;
	logic rtr,ide,srr,r1,r0; 
	logic crc_delimiter,ack_slot,ack_delimiter; 
	logic [7:0] count,crc_count,crc_count_d;
	logic [7:0] wait_count_d,wait_count,bit_wait_count,bit_wait_count_d;
	logic [63:0] databyte;
	typedef enum [2:0] {s0,s1,s2,s3,s4,s5,s6,s7} new_state;
	new_state state,next_state;
	logic [2:0] bit_stuff_count_d,bit_stuff_count;
	logic [18:0] part_crc_in;

	assign rtr = 1'b0;
	//assign ide = format ? 1'b1 : 1'b0;
	assign ide = 1'b0;	
	assign srr = 1'b1;
	assign r1 = 1'b0;
	assign r0 = 1'b0;
	assign last_bit = tranx[138];
	assign crc_delimiter = 1'b1;
	assign ack_delimiter = 1'b1;
	assign ack_slot = 1'b1;
	assign part_crc_in = {1'b0,id[28:18],rtr,ide,r0,datalen};
//	assign databyte = datalen*8;

//	assign crc = 15'h4210;

	crc c1(.d(d), .clk(clk), .reset(reset), .crc_flag(crc_flag), .crc_rg(crc_d));

	always@(*) begin
		tranx_d = tranx;
		wait_flag_d = wait_flag;
		wait_count_d = wait_count;
		crc_flag_d = crc_flag;
		crc_in = crc_in_d;
		count_d = count;
		xmit_flag_d = xmit_flag;
		next_state = state;
		crc = crc_d;
		d_d = d;
		crc_count_d = crc_count;
		crcx_d = crcx;
		busy = 0;
		ddrive = ddrive_d;
		data_flag_d = data_flag;
		bit_stuff_count_d = bit_stuff_count;
		bit_wait_count_d = bit_wait_count;
		case(state)
			s0 : begin
				ddrive = 1;
				if(startXmit==1) begin
				case(frameType)
				2'b00 : begin next_state = s1; end  // Dataframe
				2'b01 : begin next_state = s0; end
				2'b10 : begin next_state = s0; end
				2'b11 : begin next_state = s0; end
				default : begin next_state = s0; end
				endcase
				busy = 1;
				end
				else begin
					next_state = s0;
					busy = 1;
				end
			end
//////////////////////////////// Accepting data for standard and extended frames and updating coutn value /////////////////////////////////////////
			s1 : begin
				ddrive = 1;
				xmit_flag_d = 0;
				crc = crc_d;
				if(format==0) begin
					case(datalen)
					4'd0 : begin    tranx_d[138:120] = {1'b0,id[28:18],rtr,ide,r0,datalen};
							crcx_d[138:120] = {1'b0,id[28:18],rtr,ide,r0,datalen};
							count_d = 19+0;
							crc_count_d = 19;
							//crc_in[101:83] = {tranx_d[138:120]};
							crc_flag_d = 0; 
							next_state = s2; end
					4'd1 : begin    tranx_d[138:112] = {1'b0,id[28:18],rtr,ide,r0,datalen,xmitdata[63:56]};
							crcx_d[138:112] = {1'b0,id[28:18],rtr,ide,r0,datalen,xmitdata[63:56]};
							count_d = 19+8;
							crc_count_d = 19+8;
							//crc_in[101:75] = {tranx_d[138:112]};
							crc_flag_d = 0; 
							next_state = s2; end
					4'd2 : begin    tranx_d[138:104] = {1'b0,id[28:18],rtr,ide,r0,datalen,xmitdata[63:48]};
							crcx_d[138:104] = {1'b0,id[28:18],rtr,ide,r0,datalen,xmitdata[63:48]};
							count_d = 19+16;
							crc_count_d = 19+16;
							//crc_in[101:67] = {tranx_d[138:104]};
							crc_flag_d = 0;  
							next_state = s2; end
					4'd3 : begin    tranx_d[138:96] = {1'b0,id[28:18],rtr,ide,r0,datalen,xmitdata[63:40]};
							crcx_d[138:96] = {1'b0,id[28:18],rtr,ide,r0,datalen,xmitdata[63:40]};
							count_d = 19+24;
							crc_count_d = 19+24;
							//crc_in[101:59] = {tranx_d[138:96]};
							crc_flag_d = 0; 
							next_state = s2; end
					4'd4 : begin    tranx_d[138:88] = {1'b0,id[28:18],rtr,ide,r0,datalen,xmitdata[63:32]};
							crcx_d[138:88] = {1'b0,id[28:18],rtr,ide,r0,datalen,xmitdata[63:32]};
							count_d = 19+32;
							crc_count_d = 19+32;
							//crc_in[101:51] = {tranx_d[138:88]};
							crc_flag_d = 0;  
							next_state = s2; end
					4'd5 : begin    tranx_d[138:80] = {1'b0,id[28:18],rtr,ide,r0,datalen,xmitdata[63:24]};
							crcx_d[138:80] = {1'b0,id[28:18],rtr,ide,r0,datalen,xmitdata[63:24]};
							count_d = 19+40;
							crc_count_d = 19+40;
							//crc_in[101:43] = {tranx_d[138:80]};
							crc_flag_d = 0; 
							next_state = s2; end
					4'd6 : begin    tranx_d[138:72] = {1'b0,id[28:18],rtr,ide,r0,datalen,xmitdata[63:16]};
							crcx_d[138:72] = {1'b0,id[28:18],rtr,ide,r0,datalen,xmitdata[63:16]};
							count_d = 19+48;
							crc_count_d = 19+48;
							//crc_in[101:35] = {tranx_d[138:72]};
							crc_flag_d = 0;  
							next_state = s2; end
					4'd7 : begin    tranx_d[138:64] = {1'b0,id[28:18],rtr,ide,r0,datalen,xmitdata[63:8]};
							crcx_d[138:64] = {1'b0,id[28:18],rtr,ide,r0,datalen,xmitdata[63:8]};
							count_d = 19+56;
							crc_count_d = 19+56;
							//crc_in[101:27] = {tranx_d[138:64]};
							crc_flag_d = 0;  
							next_state = s2; end
					4'd8 : begin    tranx_d[138:56] = {1'b0,id[28:18],rtr,ide,r0,datalen,xmitdata};
							crcx_d[138:56] = {1'b0,id[28:18],rtr,ide,r0,datalen,xmitdata};
							count_d = 19+64;
							crc_count_d = 19+64;
							//crc_in[101:19] = {tranx_d[138:56]};
							crc_flag_d = 0;  
							next_state = s2; end
					default : begin    tranx_d = 0;
							count_d = 0;
							crc_in = 0;
							crc_flag_d = 0;
							crcx_d = 0;
							next_state = s0; end
					endcase
				end
				else begin
				    case(datalen)
					4'd0 : begin  
					tranx_d[138:100] = {1'b0,id[28:18],srr,ide,id[17:0],rtr,r1,r0,datalen};		
					crcx_d[138:100] = {1'b0,id[28:18],srr,ide,id[17:0],rtr,r1,r0,datalen};				
					count_d = 39+0;
					crc_count_d = 39;
					//crc_in[101:63] = {tranx_d[138:100]};
					crc_flag_d = 0; 
					next_state = s2; end
					4'd1 : begin  
					tranx_d[138:92] = {1'b0,id[28:18],srr,ide,id[17:0],rtr,r1,r0,datalen,xmitdata[63:56]};					
					crcx_d[138:92] = {1'b0,id[28:18],srr,ide,id[17:0],rtr,r1,r0,datalen,xmitdata[63:56]};					
					count_d = 39+8;
					crc_count_d = 39+8;
					//crc_in[101:55] = {tranx_d[138:92]};
					crc_flag_d = 0; 
					next_state = s2; end
					4'd2 : begin  
					tranx_d[138:84] = {1'b0,id[28:18],srr,ide,id[17:0],rtr,r1,r0,datalen,xmitdata[63:48]};				
					crcx_d[138:84] = {1'b0,id[28:18],srr,ide,id[17:0],rtr,r1,r0,datalen,xmitdata[63:48]};	
					count_d = 39+16;
					crc_count_d = 39+16;
					//crc_in[101:47] = {tranx_d[138:84]};
					crc_flag_d = 0; 
					next_state = s2; end
					4'd3 : begin  
					tranx_d[138:76] = {1'b0,id[28:18],srr,ide,id[17:0],rtr,r1,r0,datalen,xmitdata[63:40]};					
					crcx_d[138:76] = {1'b0,id[28:18],srr,ide,id[17:0],rtr,r1,r0,datalen,xmitdata[63:40]};					
					count_d = 39+24;
					crc_count_d = 39+24;
					//crc_in[101:39] = {tranx_d[138:76]};
					crc_flag_d = 0; 
					next_state = s2; end
					4'd4 : begin  
					tranx_d[138:68] = {1'b0,id[28:18],srr,ide,id[17:0],rtr,r1,r0,datalen,xmitdata[63:32]};
					crcx_d[138:68] = {1'b0,id[28:18],srr,ide,id[17:0],rtr,r1,r0,datalen,xmitdata[63:32]};					
					count_d = 39+32;
					crc_count_d = 39+32;
					//crc_in[101:31] = {tranx_d[138:68]};
					crc_flag_d = 0; 
					next_state = s2; end
					4'd5 : begin  
					tranx_d[138:60] = {1'b0,id[28:18],srr,ide,id[17:0],rtr,r1,r0,datalen,xmitdata[63:24]};	
					crcx_d[138:60] = {1'b0,id[28:18],srr,ide,id[17:0],rtr,r1,r0,datalen,xmitdata[63:24]};				
					count_d = 39+40;
					crc_count_d = 39+40;
					//crc_in[101:23] = {tranx_d[138:60]};
					crc_flag_d = 0; 
					next_state = s2; end
					4'd6 : begin  
					tranx_d[138:52] = {1'b0,id[28:18],srr,ide,id[17:0],rtr,r1,r0,datalen,xmitdata[63:16]};
					crcx_d[138:52] = {1'b0,id[28:18],srr,ide,id[17:0],rtr,r1,r0,datalen,xmitdata[63:16]};					
					count_d = 39+48;
					crc_count_d = 39+48;
					//crc_in[101:15] = {tranx_d[138:52]};
					crc_flag_d = 0; 
					next_state = s2; end
					4'd7 : begin  
					tranx_d[138:44] = {1'b0,id[28:18],srr,ide,id[17:0],rtr,r1,r0,datalen,xmitdata[63:8]};
					crcx_d[138:44] = {1'b0,id[28:18],srr,ide,id[17:0],rtr,r1,r0,datalen,xmitdata[63:8]};					
					count_d = 39+56;
					crc_count_d = 39+56;
					//crc_in[101:7] = {tranx_d[138:44]};
					crc_flag_d = 0; 
					next_state = s2; end
					4'd8 : begin  
					tranx_d[138:36] = {1'b0,id[28:18],srr,ide,id[17:0],rtr,r1,r0,datalen,xmitdata};
					crcx_d[138:36] = {1'b0,id[28:18],srr,ide,id[17:0],rtr,r1,r0,datalen,xmitdata};					
					count_d = 39+64;
					crc_count_d = 39+64;
					//crc_in = {tranx_d[138:36]};
					crc_flag_d = 0; 
					next_state = s2; end
					default : begin  
					tranx_d = 0;					
					count_d = 0;
					crcx_d = 0;
					crc_in = 0;
					crc_flag_d = 0; 
					next_state = s0; end
				    endcase
				end
				xmit_flag_d = 0;
				busy = 1;
//				next_state = s2;
			end

			s2 : begin
				busy = 1;
				if(crc_count==0) begin
					crc_flag_d = 0;	
					d_d = d;
					crc_count_d = crc_count;
					crcx_d = crcx;	
					tranx_d = tranx;			
					next_state = s3;
					busy = 1;
				end
				else begin
					crc_count_d = crc_count - 1;
					busy = 1;
					crc_flag_d = 1;
					d_d = crcx[138];
					tranx_d = tranx;
					crcx_d = crcx << 1; 
					next_state = s2;
				end
			end
///////////////////////////////////////////// Calculating crc and updating counter value //////////////////////////////////////////////////
			s3 : begin
				crc_flag_d = 0;
				xmit_flag_d = 0;
				crc = crc_d;
				if(format==0) begin
					case(datalen)
					4'd0 : begin    tranx_d[138:84] = {tranx[138:120],crc,crc_delimiter,ack_slot,ack_delimiter,{7{1'b1}},{11{1'b1}}};
							count_d = count+36;
							next_state = s4; end
					4'd1 : begin    tranx_d[138:76] = {tranx[138:112],crc,crc_delimiter,ack_slot,ack_delimiter,{7{1'b1}},{11{1'b1}}};
							count_d = count+36;
							next_state = s4; end
					4'd2 : begin    tranx_d[138:68] = {tranx[138:104],crc,crc_delimiter,ack_slot,ack_delimiter,{7{1'b1}},{11{1'b1}}};
							count_d = count+36;
							next_state = s4; end
					4'd3 : begin    tranx_d[138:60] = {tranx[138:96],crc,crc_delimiter,ack_slot,ack_delimiter,{7{1'b1}},{11{1'b1}}};
							count_d = count+36;
							next_state = s4; end
					4'd4 : begin    tranx_d[138:52] = {tranx[138:88],crc,crc_delimiter,ack_slot,ack_delimiter,{7{1'b1}},{11{1'b1}}};
							count_d = count+36;
							next_state = s4; end
					4'd5 : begin    tranx_d[138:44] = {tranx[138:80],crc,crc_delimiter,ack_slot,ack_delimiter,{7{1'b1}},{11{1'b1}}};
							count_d = count+36;
							next_state = s4; end
					4'd6 : begin    tranx_d[138:36] = {tranx[138:72],crc,crc_delimiter,ack_slot,ack_delimiter,{7{1'b1}},{11{1'b1}}};
							count_d = count+36;
							next_state = s4; end
					4'd7 : begin    tranx_d[138:28] = {tranx[138:64],crc,crc_delimiter,ack_slot,ack_delimiter,{7{1'b1}},{11{1'b1}}};
							count_d = count+36;
							next_state = s4; end
					4'd8 : begin    tranx_d[138:20] = {tranx[138:56],crc,crc_delimiter,ack_slot,ack_delimiter,{7{1'b1}},{11{1'b1}}};
							count_d = count+36;
							next_state = s4; end
					default : begin    tranx_d = 0;
							count_d = 0;
							crc_in = 0;
							crc_flag_d = 0;
							next_state = s0; end
					endcase	
				   /* tranx_d = {tranx,crc,crc_delimiter,ack_slot,ack_delimiter,{7{1'b1}}};
				    count_d = count+25;*/
				end
				else begin
				    case(datalen)
					4'd0 : begin  
					tranx_d[138:64] = {tranx[138:100],crc,crc_delimiter,ack_slot,ack_delimiter,{7{1'b1}},{11{1'b1}}};					
					count_d = count+36;
					next_state = s4; end
					4'd1 : begin  
					tranx_d[138:56] = {tranx[138:92],crc,crc_delimiter,ack_slot,ack_delimiter,{7{1'b1}},{11{1'b1}}};					
					count_d = count+36;
					next_state = s4; end
					4'd2 : begin  
					tranx_d[138:48] = {tranx[138:84],crc,crc_delimiter,ack_slot,ack_delimiter,{7{1'b1}},{11{1'b1}}};					
					count_d = count+36;
					next_state = s4; end
					4'd3 : begin  
					tranx_d[138:40] = {tranx[138:76],crc,crc_delimiter,ack_slot,ack_delimiter,{7{1'b1}},{11{1'b1}}};					
					count_d = count+36;
					next_state = s4; end
					4'd4 : begin  
					tranx_d[138:32] = {tranx[138:68],crc,crc_delimiter,ack_slot,ack_delimiter,{7{1'b1}},{11{1'b1}}};					
					count_d = count+36;
					next_state = s4; end
					4'd5 : begin  
					tranx_d[138:24] = {tranx[138:60],crc,crc_delimiter,ack_slot,ack_delimiter,{7{1'b1}},{11{1'b1}}};					
					count_d = count+36;
					next_state = s4; end
					4'd6 : begin  
					tranx_d[138:16] = {tranx[138:52],crc,crc_delimiter,ack_slot,ack_delimiter,{7{1'b1}},{11{1'b1}}};					
					count_d = count+36;
					next_state = s4; end
					4'd7 : begin  
					tranx_d[138:8] = {tranx[138:44],crc,crc_delimiter,ack_slot,ack_delimiter,{7{1'b1}},{11{1'b1}}};					
					count_d = count+36;
					next_state = s4; end
					4'd8 : begin  
					tranx_d = {tranx[138:36],crc,crc_delimiter,ack_slot,ack_delimiter,{7{1'b1}},{11{1'b1}}};					
					count_d = count+36;
					next_state = s4; end
					default : begin  
					tranx_d = 0;					
					count_d = 0;
					crc_in = 0;
					crc_flag_d = 0; 
					next_state = s0; end
				    endcase
				   /* tranx_d = {tranx,crc,crc_delimiter,ack_slot,ack_delimiter,{7{1'b1}}};
				    count_d = count+25;*/
				end
				busy = 1;
				ddrive = 1;
			end
			s4 : begin
				
				crc = crc_d;
				tranx_d = tranx;
				ddrive = 1;
			/*	if(count==0) begin
					xmit_flag_d = 0;
					next_state = s0;
				end
				else begin
					xmit_flag_d = 1;
					next_state = s2;
				end*/
				//if(din==1) begin
				xmit_flag_d = 1;
				busy = 1;
				next_state = s5; 
				/*else begin
				xmit_flag_d = 0;
				busy = 1;
				next_state = s4;
				end*/
				crc_flag_d = 0;
				wait_flag_d = 1;
				bit_stuff_count_d = 6;
			end
			s5 : begin
				if(count==0) begin
					xmit_flag_d = 0;
					data_flag_d = 0;
					tranx_d = 0;
					busy = 0;
					next_state = s0;
				end
				else if(count>20) begin
					data_flag_d = 1;
					tranx_d = tranx;
					count_d = count;
					busy = 1;
					if(wait_flag==0) begin
						wait_count_d = (quantaDiv)*(1+propQuanta+seg1Quanta+seg1Quanta);	//wait_condition
						bit_wait_count_d = (quantaDiv)*(1+propQuanta+seg1Quanta+seg1Quanta);	//wait_condition						
					end
					else begin
						wait_count_d = ((quantaDiv)*(1+propQuanta+seg1Quanta+seg1Quanta))-1;
						bit_wait_count_d = ((quantaDiv)*(1+propQuanta+seg1Quanta+seg1Quanta));	//wait_condition		
					end
					if(dout==tranx[138]) begin
						bit_stuff_count_d = bit_stuff_count-1; 
						next_state = s6;
						xmit_flag_d = 0;
					end
					else begin
						bit_stuff_count_d = 6;
						xmit_flag_d = 0;
						next_state = s6;
					end
					//next_state = s6;
					xmit_flag_d = 0;
				end
				else begin
					data_flag_d = 1;
					tranx_d = tranx;
					count_d = count;
					busy = 1;
					if(wait_flag==0) begin
						wait_count_d = (quantaDiv)*(1+propQuanta+seg1Quanta+seg1Quanta);	//wait_condition
						xmit_flag_d = 0;
					end
					else begin
						wait_count_d = ((quantaDiv)*(1+propQuanta+seg1Quanta+seg1Quanta))-1;
						xmit_flag_d = 0;
					end
					bit_wait_count = bit_wait_count_d;	
					next_state = s6;
					bit_stuff_count_d = bit_stuff_count;
				end
			end
			s6 : begin
				busy = 1;
				if(wait_count==1) begin
					wait_flag_d = 1;
					if(bit_stuff_count==1) begin
						wait_count_d = wait_count;
						if(bit_wait_count==0) begin
							next_state = s5;
							bit_stuff_count_d = 6;
							xmit_flag_d = 1;
						end
						else begin
							xmit_flag_d = 0;
							bit_stuff_count_d = bit_stuff_count;
							next_state = s6;
						end
					end
					else begin
						bit_stuff_count_d = bit_stuff_count;
						next_state = s5;
						xmit_flag_d = 1;
						wait_count_d = wait_count;	//wait_condition;
					end
				end
				else begin
					xmit_flag_d = 0;
					wait_flag_d = 0;
					bit_stuff_count_d = bit_stuff_count;
					next_state = s6;
				end
			end
			/*s7 : begin
				busy = 1;
				if(wait_count==1) begin
					wait_flag_d = 1;
					xmit_flag_d = 1;
					bit_stuff_count_d = 6;
					next_state = s5;
					wait_count_d = (quantaDiv)*(1+propQuanta+seg1Quanta+seg1Quanta);	//wait_condition;
				end
				else begin
					wait_flag_d = 0;
					xmit_flag_d = 0;
					bit_stuff_count_d = bit_stuff_count;
					wait_count_d = wait_count;
					next_state = s7;
				end
			end*/
		endcase
	end

	always@(posedge clk) begin
		if(reset) begin
			tranx <= #1 0;
			crc_flag <= #1 0;
			count <= 0;
			xmit_flag <= #1 0;
			data_flag <= #1 0;
			state <= #1 s0;	
			dout <= #1 1'b1;
			wait_flag <= #1 0;
			wait_count <= #1 0;
			bit_stuff_count <= #1 0;
			bit_wait_count <= #1 0;
			ddrive_d <= #1 0;
			crcx <= #1 0;
			d <= #1 0;
			crc_count <= #1 0;
			crc_in_d <= #1 0;
		end
		else begin
			ddrive_d <= #1 ddrive;
			bit_stuff_count <= #1 bit_stuff_count_d;
			state <= #1 next_state;
			crc_flag <= #1 crc_flag_d;
			d <= #1 d_d;
			crc_count <= #1 crc_count_d;
			crcx <= #1 crcx_d;
			data_flag <= #1 data_flag_d;
			wait_flag <= #1 wait_flag_d;
			crc_in_d <= #1 crc_in;
			if(xmit_flag_d==0) begin
				count <= #1 count_d;
				tranx <= #1 tranx_d;
				
				if((state==s6)) begin
					if(bit_stuff_count==1 && wait_count==1) begin
						wait_count <= #1 wait_count_d;
						bit_wait_count <= #1 bit_wait_count_d-1;
						if(last_bit==1) begin
							dout <= #1 1'b0;
						end
						else begin
							dout <= #1 1'b1;
						end
					end
					else begin
						wait_count <= #1 wait_count_d-1;
						bit_wait_count <= #1 bit_wait_count_d;
						dout <= #1 dout;
					end

				end
				else begin
				//	wait_count <= wait_count_d;
				/*	if(state==s7 || wait_count==63)
						begin
						dout <= #1 ~dout;
						end
					else begin
						dout <= #1 dout;
					end*/
					dout <= #1 dout;
					wait_count <= #1 wait_count_d;
					bit_wait_count <= bit_wait_count_d;
				end
			end
			else begin
				dout <= #1 tranx_d[138];
				tranx <= #1 {tranx_d[137:0],1'b0};
				wait_count <= #1 wait_count_d-1;
				count <= #1 count_d-1;
			end
			/*if(state==s6)begin
				wait_count <= #1 wait_count_d-1;
			end
			else begin
				wait_count <= #1 wait_count_d;
			end*/
			/*if(state==s7 || wait_count==63)
				begin
					dout <= #1 ~dout;
				end
			else begin
				dout <= #1 dout;
			end*/
			xmit_flag <= #1 xmit_flag_d;
		end
	end

endmodule
/////////////////////////////////////////////////Data Frame CRC ////////////////////////////////////////////////
module crc (
	input wire clk,reset,crc_flag,d,
	output reg [14:0] crc_rg
);
	logic [14:0] crc_rg_d;
	logic [14:0] poly;

	assign poly = 15'h4599;

	always@(*) begin
		crc_rg_d = crc_rg;
		if(crc_flag) begin
			crc_rg_d = ((crc_rg[14])^(d)) ? ((crc_rg<<1)^poly) : (crc_rg<<1);
		end
		else begin
			crc_rg_d = crc_rg;
		end
	end
	always@(posedge clk) begin
		if(reset) begin
			crc_rg <= #1 0;		
		end
		else begin
			if(crc_flag) begin
			crc_rg <= #1 crc_rg_d;
			end
			else begin
			crc_rg <= #1 0;
			end
		end
	end
endmodule

///////////////////////////////////////////////// CRC Module for data frame ////////////////////////////////////
/*
module crc(
	//input wire [18:0] d
	input wire [101:0] d,
	input wire [3:0] datalen,
//	input wire [7:0] count,
	input wire clk,reset,crc_flag,format,
	output reg [14:0] crc_rg_d
);
	logic [1:0] next_state;
	logic [1:0] state;
	logic [14:0] poly;
	logic [14:0] crc_rg,crc_rg_dd;
	logic crcnxt;	
	parameter s0 = 2'b01;
	parameter s1 = 2'b10;
	integer i;
	logic [101:0] crc_input,crc_input_d;
	logic [7:0] count_d,count;

	always@(*) begin
		next_state = state;
		crc_rg_d = crc_rg;
		count_d = count;
		crc_input= crc_input_d;
		case(state)
			s0 : begin
				if(crc_flag) begin
					crc_input = d;
					crc_rg_d = 0;
					poly = 15'h4599;
					if(format==0) begin
						case(datalen)
						4'd0 : begin count_d = 19; end
						4'd1 : begin count_d = 27; end
						4'd2 : begin count_d = 35; end
						4'd3 : begin count_d = 43; end
						4'd4 : begin count_d = 51; end
						4'd5 : begin count_d = 59; end
						4'd6 : begin count_d = 67; end
						4'd7 : begin count_d = 75; end
						4'd8 : begin count_d = 83; end
						default : begin count_d = 0; end					
						endcase
					end
					else begin
						case(datalen)
						4'd0 : begin count_d = 39; end
						4'd1 : begin count_d = 47; end
						4'd2 : begin count_d = 55; end
						4'd3 : begin count_d = 63; end
						4'd4 : begin count_d = 71; end
						4'd5 : begin count_d = 79; end
						4'd6 : begin count_d = 87; end
						4'd7 : begin count_d = 95; end
						4'd8 : begin count_d = 103; end
						default : begin count_d = 0; end
						endcase
					end
					next_state = s1;
				end
				else begin
					crc_input = 0;
					crc_rg_d = crc_rg;
					poly = 15'h4599;
					next_state = s0;
					count_d = 0;
				end
				//$display ("$$$$$$$$$$$$$$$$$ %d ", $time);
			end
			s1 : begin
				crc_rg_d = 0;
				for(i=0;i<count_d;i=i+1) begin
					crcnxt = crc_input[101-i]^crc_rg_d[14];
				//	$display("%d", crcnxt);
					crc_rg_d[14:1] = {crc_rg_d[13:0]};
					crc_rg_d[0] = 1'b0;
				//	$display ("$$$$$$$$$$$ %0d %b", crc_rg_d,crc_input);
					if(crcnxt) begin
						crc_rg_d = crc_rg_d ^ poly;	
					end
					else begin
						crc_rg_d = crc_rg_d;
					end
					crc_rg_d = ((crc_rg_d[14])^(crc_input[101-i])) ? ((crc_rg_d<<1)^poly) : (crc_rg_d<<1);
				//	$display ("$$$$$$$$$$$ %0d", crc_rg_d);
				//	crc_rg_d = ((crc_rg_d^d[102-i])<<1)^((crc_rg_d[14])?poly:0);
					
				end
				next_state = s0;
			//	$display ("######### %d ", $time);
			end
		endcase
	end
	
	always@(posedge clk) begin
		if(reset) begin
			crc_rg <= #1 0;	
			state <= #1 s0;
			count <= #1 0;
			crc_input_d <= #1 0;
		end
		else begin
			count <= #1 count_d;
			crc_input_d <= #1 crc_input;
			crc_rg <= #1 crc_rg_d;
		//	$display ("_--------- %0d",crc_rg);
			state <= #1 next_state;
		end
	end
	
endmodule*/ 
/////////////////////////////////////////////////CRC NEW FOR data frame/////////////////////////////////////////
/*module crc(
	//input wire [18:0] d
	input wire [101:0] d,
	input wire [3:0] datalen,
//	input wire [7:0] count,
	input wire clk,reset,crc_flag,format,
	output reg [14:0] crc_rg
);
	logic [1:0] next_state;
	logic [1:0] state;
	logic [14:0] poly;
	logic [14:0] crc_rg_d;
	logic crcnxt;	
	parameter s0 = 2'b01;
	parameter s1 = 2'b10;
	integer i;
	logic [101:0] crc_input,crc_input_d;
	logic [7:0] count_d,count;

	assign poly = 15'h4599;
	always@(*) begin
		next_state = state;
		crc_rg_d = crc_rg;
		count_d = count;
		crc_input= crc_input_d;
		case(state)
			s0 : begin
				if(crc_flag) begin
					crc_input = d;
					crc_rg_d = 0;
					//poly = 15'h4599;
					if(format==0) begin
						case(datalen)
						4'd0 : begin count_d = 19; end
						4'd1 : begin count_d = 27; end
						4'd2 : begin count_d = 35; end
						4'd3 : begin count_d = 43; end
						4'd4 : begin count_d = 51; end
						4'd5 : begin count_d = 59; end
						4'd6 : begin count_d = 67; end
						4'd7 : begin count_d = 75; end
						4'd8 : begin count_d = 83; end
						default : begin count_d = 0; end					
						endcase
					end
					else begin
						case(datalen)
						4'd0 : begin count_d = 39; end
						4'd1 : begin count_d = 47; end
						4'd2 : begin count_d = 55; end
						4'd3 : begin count_d = 63; end
						4'd4 : begin count_d = 71; end
						4'd5 : begin count_d = 79; end
						4'd6 : begin count_d = 87; end
						4'd7 : begin count_d = 95; end
						4'd8 : begin count_d = 103; end
						default : begin count_d = 0; end
						endcase
					end
					next_state = s1;
				end
				else begin
					crc_input = 0;
					crc_rg_d = crc_rg;
					//poly = 15'h4599;
					next_state = s0;
					count_d = 0;
				end
				//$display ("$$$$$$$$$$$$$$$$$ %d ", $time);
			end
			s1 : begin
				crc_rg_d = 0;

				if(format==0) begin
					case(datalen)
					4'd0 : begin 
						for(i=0;i<19;i=i+1) begin
							crc_rg_d = ((crc_rg_d[14])^(crc_input[101-i])) ? ((crc_rg_d<<1)^poly) : (crc_rg_d<<1);
						end
					end
					4'd1 : begin 
						for(i=0;i<27;i=i+1) begin
							crc_rg_d = ((crc_rg_d[14])^(crc_input[101-i])) ? ((crc_rg_d<<1)^poly) : (crc_rg_d<<1);
						end
					end
					4'd2 : begin 
						for(i=0;i<35;i=i+1) begin
							crc_rg_d = ((crc_rg_d[14])^(crc_input[101-i])) ? ((crc_rg_d<<1)^poly) : (crc_rg_d<<1);
						end
					end
					4'd3 : begin 
						for(i=0;i<43;i=i+1) begin
							crc_rg_d = ((crc_rg_d[14])^(crc_input[101-i])) ? ((crc_rg_d<<1)^poly) : (crc_rg_d<<1);
						end
					end
					4'd4 : begin 
						for(i=0;i<51;i=i+1) begin
							crc_rg_d = ((crc_rg_d[14])^(crc_input[101-i])) ? ((crc_rg_d<<1)^poly) : (crc_rg_d<<1);
						end
					end
					4'd5 : begin 
						for(i=0;i<59;i=i+1) begin
							crc_rg_d = ((crc_rg_d[14])^(crc_input[101-i])) ? ((crc_rg_d<<1)^poly) : (crc_rg_d<<1);
						end
					end
					4'd6 : begin 
						for(i=0;i<67;i=i+1) begin
							crc_rg_d = ((crc_rg_d[14])^(crc_input[101-i])) ? ((crc_rg_d<<1)^poly) : (crc_rg_d<<1);
						end
					end
					4'd7 : begin 
						for(i=0;i<75;i=i+1) begin
							crc_rg_d = ((crc_rg_d[14])^(crc_input[101-i])) ? ((crc_rg_d<<1)^poly) : (crc_rg_d<<1);
						end
					end
					4'd8 : begin 
						for(i=0;i<83;i=i+1) begin
							crc_rg_d = ((crc_rg_d[14])^(crc_input[101-i])) ? ((crc_rg_d<<1)^poly) : (crc_rg_d<<1);
						end
					end
					default : begin
						crc_rg_d = crc_rg;
					end
					endcase
				end
				else begin
					
					case(datalen)
					4'd0 : begin 
						for(i=0;i<39;i=i+1) begin
							crc_rg_d = ((crc_rg_d[14])^(crc_input[101-i])) ? ((crc_rg_d<<1)^poly) : (crc_rg_d<<1);
						end
					end
					4'd1 : begin 
						for(i=0;i<47;i=i+1) begin
							crc_rg_d = ((crc_rg_d[14])^(crc_input[101-i])) ? ((crc_rg_d<<1)^poly) : (crc_rg_d<<1);
						end
					end
					4'd2 : begin 
						for(i=0;i<55;i=i+1) begin
							crc_rg_d = ((crc_rg_d[14])^(crc_input[101-i])) ? ((crc_rg_d<<1)^poly) : (crc_rg_d<<1);
						end
					end
					4'd3 : begin 
						for(i=0;i<63;i=i+1) begin
							crc_rg_d = ((crc_rg_d[14])^(crc_input[101-i])) ? ((crc_rg_d<<1)^poly) : (crc_rg_d<<1);
						end
					end
					4'd4 : begin 
						for(i=0;i<71;i=i+1) begin
							crc_rg_d = ((crc_rg_d[14])^(crc_input[101-i])) ? ((crc_rg_d<<1)^poly) : (crc_rg_d<<1);
						end
					end
					4'd5 : begin 
						for(i=0;i<79;i=i+1) begin
							crc_rg_d = ((crc_rg_d[14])^(crc_input[101-i])) ? ((crc_rg_d<<1)^poly) : (crc_rg_d<<1);
						end
					end
					4'd6 : begin 
						for(i=0;i<87;i=i+1) begin
							crc_rg_d = ((crc_rg_d[14])^(crc_input[101-i])) ? ((crc_rg_d<<1)^poly) : (crc_rg_d<<1);
						end
					end
					4'd7 : begin 
						for(i=0;i<95;i=i+1) begin
							crc_rg_d = ((crc_rg_d[14])^(crc_input[101-i])) ? ((crc_rg_d<<1)^poly) : (crc_rg_d<<1);
						end
					end
					4'd8 : begin 
						for(i=0;i<103;i=i+1) begin
							crc_rg_d = ((crc_rg_d[14])^(crc_input[101-i])) ? ((crc_rg_d<<1)^poly) : (crc_rg_d<<1);
						end
					end
					default : begin
						crc_rg_d = crc_rg;
					end
					endcase
				end
				next_state = s0;
			//	$display ("######### %d ", $time);
			end
		endcase
	end
	
	always@(posedge clk) begin
		if(reset) begin
			crc_rg <= #1 0;	
			state <= #1 s0;
			count <= #1 0;
			crc_input_d <= #1 0;
		end
		else begin
			count <= #1 count_d;
			crc_input_d <= #1 crc_input;
			crc_rg <= #1 crc_rg_d;
		//	$display ("_--------- %0d",crc_rg);
			state <= #1 next_state;
		end
	end
	
endmodule */
/////////////////////////////////////////////////CRC for Remote Frame///////////////////////////////////////////
module remote_crc(
	//input wire [18:0] d
	input wire [38:0] d,
//	input wire [7:0] count,
	input wire clk,reset,crc_flag,format,
	output reg [14:0] crc_rg_d
);
	logic [1:0] next_state;
	logic [1:0] state;
	logic [14:0] poly;
	logic [14:0] crc_rg,crc_rg_dd;
	logic crcnxt;	
	parameter s0 = 2'b01;
	parameter s1 = 2'b10;
	integer i;
	logic [38:0] crc_input,crc_input_d;
	logic [7:0] count_d,count;

	assign poly = 15'h4599;
	always@(*) begin
		next_state = state;
		crc_rg_d = crc_rg;
		count_d = count;
		crc_input = crc_input_d;
		case(state)
			s0 : begin
				if(crc_flag) begin
					crc_input = d;
					crc_rg_d = 0;
					//poly = 15'h4599;
					if(format==0) begin
						count_d = 19;
					end
					else begin
						count_d = 39;						
					end
					next_state = s1;
				end
				else begin
					//crc_input = 0;
					crc_rg_d = crc_rg;
					//poly = 15'h4599;
					next_state = s0;
				//	count_d = 0;
				end
				//$display ("$$$$$$$$$$$$$$$$$ %d ", $time);
			end
			s1 : begin
				crc_rg_d = 0;
			//	for(i=0;i<count_d;i=i+1) begin
				/*	crcnxt = crc_input[101-i]^crc_rg_d[14];
				//	$display("%d", crcnxt);
					crc_rg_d[14:1] = {crc_rg_d[13:0]};
					crc_rg_d[0] = 1'b0;
				//	$display ("$$$$$$$$$$$ %0d %b", crc_rg_d,crc_input);
					if(crcnxt) begin
						crc_rg_d = crc_rg_d ^ poly;	
					end
					else begin
						crc_rg_d = crc_rg_d;
					end*/
			//		crc_rg_d = ((crc_rg_d[14])^(crc_input[38-i])) ? ((crc_rg_d<<1)^poly) : (crc_rg_d<<1);
			//		$display ("$$$$$$$$$$$ %0d", crc_rg_d);
				//	crc_rg_d = ((crc_rg_d^d[102-i])<<1)^((crc_rg_d[14])?poly:0);
					
			//	end
				if(format==0) begin
					for(i=0;i<19;i=i+1) begin
						crc_rg_d = ((crc_rg_d[14])^(crc_input[38-i])) ? ((crc_rg_d<<1)^poly) : (crc_rg_d<<1);
						$display ("$$$$$$$$$$$ %0d", crc_rg_d);
					end
				end
				else begin
					for(i=0;i<39;i=i+1) begin
						crc_rg_d = ((crc_rg_d[14])^(crc_input[38-i])) ? ((crc_rg_d<<1)^poly) : (crc_rg_d<<1);
						$display ("$$$$$$$$$$$ %0d", crc_rg_d);
					end
				end
				next_state = s0;
			//	$display ("######### %d ", $time);
			end
		endcase
	end
	
	always@(posedge clk) begin
		if(reset) begin
			crc_rg <= #1 0;	
			count <= 0;
			state <= #1 s0;
			crc_input_d <= #1 0;
		end
		else begin
			count <= #1 count_d;			
			crc_rg <= #1 crc_rg_d;
			crc_input_d <= #1 crc_input;
		//	$display ("_--------- %0d",crc_rg);
			state <= #1 next_state;
		end
	end
	
endmodule


/////////////////////////////////////////////////Remote Frame state Machine. ///////////////////////////////////
module remoteframe(
	input clk, input reset, 
	input din, input startXmit,
	input [7:0] quantaDiv, 
	input [5:0] propQuanta,
    	input [5:0] seg1Quanta,
	//input [63:0] xmitdata,
	input [3:0] datalen,
	input [28:0] id, 		//Arbitration field
	input format, 
	input [2:0] top_state,
	input [1:0] frameType,
    	output logic dout, 
	output logic busy,
	output logic ddrive,
	output logic [7:0] count_d,
	output logic remote_flag
);
	logic busy_d;
	logic rtr,ide,r1,r0,srr,crc_flag_d,crc_flag;
	logic xmit_flag_d,xmit_flag,remote_flag_d;
	logic [38:0] crc_in,crc_in_d; 
	logic [74:0] tranx_d,tranx;
	logic [7:0] count;
	logic [14:0] crc,crc_d;
	logic crc_delimiter,ack_slot,ack_delimiter,wait_flag_d,wait_flag,last_bit; 
	typedef enum [2:0] {s0,s1,s2,s3,s4,s5} new_state;
	new_state state,next_state;
	logic [7:0] wait_count_d,wait_count,bit_wait_count_d,bit_wait_count;
	logic [2:0] bit_stuff_count_d,bit_stuff_count;
	assign rtr = 1'b1;
	assign srr = 1'b1;
	assign r1 = 0, r0 = 0;
	assign ide = 1'b0;
	assign crc_delimiter = 1;
	assign ack_slot = 1;
	assign ack_delimiter = 1;

	assign last_bit = tranx_d[74];
	remote_crc rcrc(.d(crc_in), .clk(clk), .reset(reset), .crc_flag(crc_flag_d), .format(format), .crc_rg_d(crc_d));

	always@(*) begin
		tranx_d = tranx;
		wait_flag_d = wait_flag;
		wait_count_d = wait_count;
		crc_flag_d = crc_flag;
		crc_in = crc_in_d;
		count_d = count;
		xmit_flag_d = xmit_flag;
		next_state = state;
		crc = crc_d;
		busy = busy_d;
		remote_flag_d = remote_flag;
		bit_stuff_count_d = bit_stuff_count;
		bit_wait_count_d = bit_wait_count;
		
		//crc_in = 0;
		case(state)
		s0 : begin
			if(startXmit==1) begin
			case(top_state)
			3'b000 : begin 
				case(frameType) 
				2'b00 : begin next_state = s0; end
				2'b01 : begin next_state = s1; end
				default : begin next_state = s0; end
				endcase
				busy = 1;
				end
			default : begin
				next_state = s0;
				busy = 0;
			end
			endcase
			end
			else begin
				next_state = s0;
				busy = 0;
			end
			xmit_flag_d = 0;			
			count_d = 0;
			crc_in = 0;
			crc_flag_d = 0;
			//busy = 0;
		end
		s1 : begin
			case(format)
				1'b0 : begin
					tranx_d[74:56] = {1'b0,id[28:18],rtr,ide,r0,datalen};
					count_d = 19;	
					crc_in[38:0] = {tranx_d[74:56],{20{1'b0}}};
					crc_flag_d = 1;
				end
				1'b1 : begin
					tranx_d[74:36] = {1'b0,id[28:18],srr,ide,id[17:0],rtr,r1,r0,datalen};
					count_d = 39;
					crc_in = tranx_d[74:36];
					crc_flag_d = 1;
				end
			endcase
			xmit_flag_d = 0;
			crc = crc_d;
			busy = 1;
			next_state = s2;
		end
		s2 : begin
			case(format)
				1'b0 : begin
					tranx_d[74:20] = {tranx[74:56],crc,crc_delimiter,ack_slot,ack_delimiter,{7{1'b1}},{11{1'b1}}};
					count_d = count+36;
				end
				1'b1 : begin
					tranx_d = {tranx[74:36],crc,crc_delimiter,ack_slot,ack_delimiter,{7{1'b1}},{11{1'b1}}};
					count_d = count+36;
				end
			endcase
			xmit_flag_d = 0;
			crc_flag_d = 0;
			busy = 1;
			crc = crc_d;
			next_state = s3;
		end
		s3 : begin
			xmit_flag_d = 1;
			busy = 1;
			crc_flag_d = 0;
			wait_flag_d = 0;
			next_state = s4;
		end
		/*s4 : begin
			busy = 1;
				if(count==0) begin
					xmit_flag_d = 0;
					remote_flag_d = 0;
					next_state = s0;
				end
				else if (count>10)begin
					if((dout == tranx[61]) || (dout != tranx[61])) begin
						remote_flag_d = 1;
						//wait_condition
						xmit_flag_d = 0;
					end
					else begin
						remote_flag_d = 1;
						xmit_flag_d = 1;
					end
					next_state = s4;
				end		
				else begin
					remote_flag_d = 0;
					xmit_flag_d = 1;
					next_state = s4;
				end
		end*/
		s4 : begin
			busy = 1;
				if(count==0) begin
					xmit_flag_d = 0;
					remote_flag_d = 0;
					tranx_d = 0;
					busy = 0;
					next_state = s0;
				end
				else if(count>20) begin
					remote_flag_d = 1;
					tranx_d = tranx;
					count_d = count;
					busy = 1;
					if(wait_flag==0) begin
						wait_count_d = (quantaDiv)*(1+propQuanta+seg1Quanta+seg1Quanta);	//wait_condition
						bit_wait_count_d = (quantaDiv)*(1+propQuanta+seg1Quanta+seg1Quanta);	//wait_condition						
					end
					else begin
						wait_count_d = ((quantaDiv)*(1+propQuanta+seg1Quanta+seg1Quanta))-1;
						bit_wait_count_d = ((quantaDiv)*(1+propQuanta+seg1Quanta+seg1Quanta));	//wait_condition		
					end
					if(dout==tranx[74]) begin
						bit_stuff_count_d = bit_stuff_count-1; 
						next_state = s5;
						xmit_flag_d = 0;
					end
					else begin
						bit_stuff_count_d = 6;
						xmit_flag_d = 0;
						next_state = s5;
					end
					//next_state = s6;
					xmit_flag_d = 0;
				end
				else begin
					remote_flag_d = 1;
					tranx_d = tranx;
					count_d = count;
					busy = 1;
					if(wait_flag==0) begin
						wait_count_d = (quantaDiv)*(1+propQuanta+seg1Quanta+seg1Quanta);	//wait_condition
						xmit_flag_d = 0;
					end
					else begin
						wait_count_d = ((quantaDiv)*(1+propQuanta+seg1Quanta+seg1Quanta))-1;
						xmit_flag_d = 0;
					end
					bit_wait_count_d = bit_wait_count;	
					next_state = s5;
					bit_stuff_count_d = bit_stuff_count;
				end
			end
			s5 : begin
				busy = 1;
				if(wait_count==1) begin
					wait_flag_d = 1;
					if(bit_stuff_count==1) begin
						wait_count_d = wait_count;
						if(bit_wait_count==0) begin
							next_state = s4;
							bit_stuff_count_d = 6;
							xmit_flag_d = 1;
						end
						else begin
							xmit_flag_d = 0;
							bit_stuff_count_d = bit_stuff_count;
							next_state = s5;
						end
					end
					else begin
						bit_stuff_count_d = bit_stuff_count;
						next_state = s4;
						xmit_flag_d = 1;
						wait_count_d = wait_count;	//wait_condition;
					end
				end
				else begin
					xmit_flag_d = 0;
					wait_flag_d = 0;
					bit_stuff_count_d = bit_stuff_count;
					next_state = s5;
				end
			end
		endcase
	end	

	always@(posedge clk) begin
		if(reset) begin
			tranx <= 0;
			crc_flag <= 0;
			count <= 0;
			xmit_flag <= 0;
			state <= s0;	
			dout <= 1'b1;
			remote_flag <= 1'b0;
			bit_stuff_count <= #1 0;
			bit_wait_count <= #1 0;
			busy_d <= #1 0;
			crc_in_d <= #1 0;
		end
		else begin
			state <= next_state;
			busy_d <= #1 busy;
			crc_in_d <= #1 crc_in;
			crc_flag <= crc_flag_d;
			bit_stuff_count <= #1 bit_stuff_count_d;
			remote_flag <= remote_flag_d;
			if(xmit_flag_d==0) begin
				count <= #1 count_d;
				tranx <= #1 tranx_d;
				
				if((state==s5)) begin
					if(bit_stuff_count==1 && wait_count==1) begin
						wait_count <= #1 wait_count_d;
						bit_wait_count <= #1 bit_wait_count_d-1;
						if(last_bit==1) begin
							dout <= #1 1'b0;
						end
						else begin
							dout <= #1 1'b1;
						end
					end
					else begin
						wait_count <= #1 wait_count_d-1;
						bit_wait_count <= #1 bit_wait_count_d;
						dout <= #1 dout;
					end

				end
				else begin
				//	wait_count <= wait_count_d;
				/*	if(state==s7 || wait_count==63)
						begin
						dout <= #1 ~dout;
						end
					else begin
						dout <= #1 dout;
					end*/
					dout <= #1 dout;
					wait_count <= #1 wait_count_d;
					bit_wait_count <= #1 bit_wait_count_d;
				end
			end
			else begin
				dout <= #1 tranx_d[74];
				tranx <= #1 {tranx_d[73:0],1'b0};
				wait_count <= #1 wait_count_d-1;
				count <= #1 count_d-1;
			end
			xmit_flag <= #1 xmit_flag_d;
		end
	end

endmodule

//////////////////////////////////////// Error Frame State Machine. //////////////////////////////////////

module errframe(
	input clk, input reset, 
	input din, input startXmit,
	input [7:0] quantaDiv, 
	input [5:0] propQuanta,
    	input [5:0] seg1Quanta, 
	input [1:0] frameType,
    	output logic dout, 
	output logic busy,
	output logic ddrive,
	output logic err_out_flag
);

	logic [13:0] tranx_d,tranx;
	logic err_flag_d,err_flag;
	logic err_out_flag_d;
	logic [3:0] count,count_d;
	typedef enum {s0,s1,s2,s3,s4,s5} new_state;
	new_state state,next_state;

	always@(*) begin
		tranx_d = tranx;
		err_out_flag_d = err_out_flag;
		count_d = count;
		err_flag_d = err_flag;
		case(state)
		s0 : begin
			case(frameType)
				2'b00 : begin next_state = s0; end  // Dataframe
				2'b01 : begin next_state = s0; end
				2'b10 : begin next_state = s1; end
				2'b11 : begin next_state = s0; end
				default : begin next_state = s0; end	
			endcase
		end
		s1 : begin
			tranx_d = {{6{1'b0}},{8{1'b1}}};
			err_flag_d = 1;
			count_d = 14;
			next_state = s2; 
		end
		s2 : begin
			if(count==0) begin
				err_flag_d = 0;
				err_out_flag_d = 0;
				count_d = 0;
				next_state = s0;
			end
			else begin
				err_flag_d = 1;
				err_out_flag_d = 1;
				count_d = count;
				next_state = s2;
			end
		end
		endcase
	end

	always@(posedge clk) begin
		if(reset) begin
			tranx <= 0;
			err_flag <= 0;
			count <= 0;
			err_out_flag <= 0;
			state <= s0;
		end
		else begin
			err_flag <= err_flag_d;
			if(err_flag) begin
				dout <= tranx[13];
				err_out_flag <= err_out_flag_d;
				tranx <= {tranx[12:0],1'b0};
				count <= count_d-1;
			end
			else begin
				dout <= 1'b1;
				err_out_flag <= err_out_flag_d;
				tranx <= tranx_d;
				count <= count_d;
			end
		end
	end
endmodule	

///////////////////////////////////////// Overload Frame State Machine //////////////////////////////////////


module overload(
	input clk, input reset, 
	input din, input startXmit,
	input [7:0] quantaDiv, 
	input [5:0] propQuanta,
    	input [5:0] seg1Quanta, 
	input [1:0] frameType,
    	output logic dout, 
	output logic busy,
	output logic ddrive,
	output logic over_flag_out
);
	logic over_flag_out_d;
	logic [13:0] tranx_d,tranx;
	logic [3:0] count,count_d;
	logic over_flag_d, over_flag;
	typedef enum {s0,s1,s2,s3,s4,s5} new_state;
	new_state state,next_state;

	always@(*) begin
		tranx_d = tranx;
		count_d = count;
		over_flag_d = over_flag;
		over_flag_out_d = over_flag_out;
		case(state)
		s0 : begin
			case(frameType)
				2'b00 : begin next_state = s0; end  // Dataframe
				2'b01 : begin next_state = s0; end
				2'b10 : begin next_state = s0; end
				2'b11 : begin next_state = s1; end
				default : begin next_state = s0; end	
			endcase
		end
		s1 : begin
			tranx_d = {{6{1'b0}},{8{1'b1}}};
			over_flag_d = 1;
			count_d = 14;
			next_state = s2; 
		end
		s2 : begin
			if(count==0) begin
				over_flag_out_d = 0;
				over_flag_d = 0;
				count_d = 0;
				next_state = s0;
			end
			else begin
				over_flag_out_d = 1;
				over_flag_d = 1;
				count_d = count;
				next_state = s2;
			end
		end
		endcase
	end

	always@(posedge clk) begin
		if(reset) begin
			tranx <= 0;
			over_flag <= 0;
			count <= 0;
			state <= s0;
			over_flag_out <= 0;
		end
		else begin
			over_flag <= over_flag_d;
			over_flag_out <= over_flag_out_d;
			if(over_flag) begin
				dout <= tranx[13];
				tranx <= {tranx[12:0],1'b0};
				count <= count_d-1;
			end
			else begin
				dout <= 1'b1;
				tranx <= tranx_d;
				count <= count_d;
			end
		end
	end
endmodule	


