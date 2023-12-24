function Bit#(1) multiplexer1(Bit#(1) sel, Bit#(1) a, Bit#(1) b);
	Bit#(1) result = (sel == 0)? a : b;
    return result;
endfunction


function Bit#(5) multiplexer5(Bit#(1) sel, Bit#(5) a, Bit#(5) b);
	Bit#(5) result = 0;

//	for(Integer i = 0; i < 5; i = i + 1)begin
//		result[i] = (sel == 0)? a[i] : b[i];
//	end

// use function multiplexer_n
	result = multiplexer_n(sel, a, b);
    return result;
endfunction

function Bit#(n) multiplexer_n(Bit#(1) sel, Bit#(n) a, Bit#(n) b);
    Bit#(n) result  = 0;
    for (Integer i = 0; i < valueOf(n); i = i + 1) begin
        	result[i] = (sel == 0)? a[i] : b[i];
    end
    return result;
endfunction
