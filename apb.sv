module apb(apbintf.slv apb,cantintf.tox can);

	logic [1:0] wr_en;
	logic [31:0] xmit_high,xmit_high_d,xmit_low,xmit_low_d,command_d,command,id_d,id,st_busy_d,st_busy;

	assign wr_en = {apb.PWRITE,apb.PENABLE};

	always@(*) begin
		case(wr_en)	
			2'b11 : begin
				case(apb.PADDR)
					32'hf000_ff00 : begin
						xmit_high_d = apb.PWDATA;
						xmit_low_d=xmit_low;
						command_d = command;
						id_d = id;
						can.startXmit = 0;
						apb.PREADY = 1;
					end
					32'hf000_ff04 : begin
						xmit_high_d = xmit_high;
						xmit_low_d= apb.PWDATA;
						command_d = command;
						id_d = id;
						can.startXmit = 0;
						apb.PREADY = 1;
					end
					32'hf000_ff08 : begin
						xmit_high_d = xmit_high;
						xmit_low_d= xmit_low;
						command_d = apb.PWDATA;
						id_d = id;
						can.startXmit = 0;
						apb.PREADY = 1;
				
					end
					32'hf000_ff0c : begin
						xmit_high_d = xmit_high;
						xmit_low_d= xmit_low;
						command_d = command;
						id_d = apb.PWDATA;
						can.startXmit = 0;
						apb.PREADY = 1;
						st_busy_d = {{31{1'b0}},can.busy};
					end
					32'hf000_ff10 : begin
						xmit_high_d = xmit_high;
						xmit_low_d= xmit_low;
						command_d = command;
						id_d = id;
						can.startXmit = 1;
						apb.PREADY = 1;
						can.quantaDiv = command_d[31:24];
						can.propQuanta = command_d[23:18];
						can.seg1Quanta = command_d[17:12];
    						can.xmitdata = {xmit_high_d,xmit_low_d};
						can.datalen = command_d[11:8];
						can.id = id_d[31:3];
						can.format = command_d[7];
						can.frameType = command_d[6:5];
						st_busy_d = {{31{1'b0}},can.busy};
						//can.startXmit = 1;
					end
				endcase
				end
			2'b01 : begin
				case(apb.PADDR)
				32'hf000_ff00 : begin
					xmit_high_d = xmit_high;
					xmit_low_d=xmit_low;
					command_d = command;
					id_d = id;
					apb.PRDATA = xmit_high_d;
					can.startXmit = 0;
					apb.PREADY = 1;
				end
				32'hf000_ff04 : begin
					xmit_high_d = xmit_high;
					xmit_low_d= xmit_low;
					command_d = command;
					id_d = id;
					apb.PRDATA = xmit_low_d;
					can.startXmit = 0;
					apb.PREADY = 1;
				end
				32'hf000_ff08 : begin
					xmit_high_d = xmit_high;
					xmit_low_d= xmit_low;
					command_d = command;
					id_d = id;
					apb.PRDATA = command_d;
					can.startXmit = 0;
					apb.PREADY = 1;
				end
				32'hf000_ff0c : begin
					xmit_high_d = xmit_high;
					xmit_low_d= xmit_low;
					command_d = command;
					id_d = id;
					apb.PRDATA = id_d;
					can.startXmit = 0;
					apb.PREADY = 1;
				end
				32'hf000_ff10 : begin
					xmit_high_d = xmit_high;
					xmit_low_d= xmit_low;
					command_d = command;
					id_d = id;
					can.startXmit = 0;
					apb.PREADY = 1;
					apb.PRDATA = {{31{1'b0}},can.busy};
						//can.startXmit = 1;
				end
				endcase
			end
			default : begin
				xmit_high_d = xmit_high;
				xmit_low_d= xmit_low;
				command_d = command;
				id_d = id;
				apb.PREADY = 1;
				can.startXmit = 0;
				end
		
		endcase
	end

	/////////////////// Posedge block ///////////////////////
	always@(posedge apb.PCLK) begin
		if(apb.PRESET) begin
			xmit_high <= 0;
			xmit_low <= 0;
			command <= 0;
			id <= 0;
			st_busy <= 0;
		end
		else begin
			xmit_high <= xmit_high_d;
			xmit_low <= xmit_low_d;
			command <= command_d;
			id <= id_d;
			st_busy <= st_busy_d;
		end
	end

	
endmodule
