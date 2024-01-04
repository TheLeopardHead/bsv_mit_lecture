import Complex::*;
import FixedPoint::*;
import Real::*;
import Vector::*;

import ClientServer::*;
import FIFO::*;
import GetPut::*;

import ComplexMP::*;
import Cordic::*;

typedef Server#(
	Vector#(nbins, Complex#(FixedPoint#(isize, fsize))),
	Vector#(nbins, ComplexMP#(isize, fsize, psize))
) ToMP#(numeric type nbins, numeric type isize, numeric type fsize, numeric type psize);

module mkToMP(ToMP#(nbins, isize, fsize, psize));
	ToMagnitudePhase#(isize, fsize, psize) tomp <- mkCordicToMagnitudePhase();

	FIFO#(Vector#(nbins, Complex#(FixedPoint#(isize, fsize)))) infifo <- mkFIFO();
	FIFO#(Vector#(nbins, ComplexMP#(isize, fsize, psize))) outfifo <- mkFIFO();

	Reg#(Vector#(nbins, ComplexMP#(isize, fsize, psize))) data_out <- mkRegU();
	Reg#(Bit#(TLog#(nbins))) cnt_read <- mkReg(0);
	Reg#(Bit#(TLog#(nbins))) cnt_write <- mkReg(0);

	rule data_read;
		tomp.request.put(infifo.first[cnt_read]);
		if(cnt_read == fromInteger(valueOf(nbins)-1)) begin
			cnt_read <= 0;
			infifo.deq();
		end
		else begin
			cnt_read <= cnt_read + 1;
		end
	endrule

	rule data_write;
		let x <- tomp.response.get();
		data_out[cnt_write] <= x;
		if(cnt_write == fromInteger(valueOf(nbins)-1)) begin
			cnt_write <= 0;
			Vector#(nbins, ComplexMP#(isize, fsize, psize)) tmp = data_out;
			tmp[cnt_write] = x;
			outfifo.enq(tmp);
		end
		else begin
			cnt_write <= cnt_write + 1;
		end
	endrule

	interface Put request = toPut(infifo);
	interface Get response = toGet(outfifo);

endmodule
