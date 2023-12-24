import Multiplexer::*;

// Full adder functions

function Bit#(2) fa( Bit#(1) a, Bit#(1) b, Bit#(1) c_in );
	Bit#(1) sum = a ^ b ^ c_in;
	Bit#(1) c_out = (a & b) | ((a ^ b) & c_in);
    return {c_out, sum};
endfunction

function Bit#(1) fa_c( Bit#(1) a, Bit#(1) b, Bit#(1) c_in );
	Bit#(1) c_out = (a & b) | ((a ^ b) & c_in);
    return c_out;
endfunction

function Bit#(1) fa_sum( Bit#(1) a, Bit#(1) b, Bit#(1) c_in );
	Bit#(1) sum = a ^ b ^ c_in;
    return sum;
endfunction

// 4 Bit full adder

function Bit#(5) add4( Bit#(4) a, Bit#(4) b, Bit#(1) c_in );
    Bit#(4) sum = 0;
    Bit#(5) c = {4'b0, c_in};
    for (Integer i = 0; i < 4; i = i + 1) begin
       // {c[i+1] , sum[i]} = fa(a[i], b[i], c[i]);
		c[i+1] = fa_c(a[i], b[i], c[i]);
		sum[i] = fa_sum(a[i], b[i], c[i]);
    end
    return {c[4], sum};
endfunction

// Adder interface

interface Adder8;
    method ActionValue#( Bit#(9) ) sum( Bit#(8) a, Bit#(8) b, Bit#(1) c_in );
endinterface

// Adder modules

// RC = Ripple Carry
module mkRCAdder( Adder8 );
    method ActionValue#( Bit#(9) ) sum( Bit#(8) a, Bit#(8) b, Bit#(1) c_in );
        Bit#(5) result_l = add4( a[3:0], b[3:0], c_in );
        Bit#(5) result_h = add4( a[7:4], b[7:4], result_l[4] );
        return { result_h , result_l[3:0] };
    endmethod
endmodule

// CS = Carry Select
module mkCSAdder( Adder8 );
    method ActionValue#( Bit#(9) ) sum( Bit#(8) a, Bit#(8) b, Bit#(1) c_in );
		Bit#(5) result_l_0 = add4( a[3:0], b[3:0], 0 );
		Bit#(5) result_l_1 = add4( a[3:0], b[3:0], 1 );
        Bit#(5) result_h_0 = add4( a[7:4], b[7:4], 0 );
		Bit#(5) result_h_1 = add4( a[7:4], b[7:4], 1 );
		Bit#(5) result_l = multiplexer5(c_in, result_l_0, result_l_1);
		Bit#(5) result_h = multiplexer5(result_l[4], result_h_0, result_h_1);

       	return {result_h, result_l[3 : 0]};
    endmethod
endmodule
