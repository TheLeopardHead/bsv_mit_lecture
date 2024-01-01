
import ClientServer::*;
import FIFO::*;
import GetPut::*;

import FixedPoint::*;
import Vector::*;

import ComplexMP::*;


typedef Server#(
    Vector#(nbins, ComplexMP#(isize, fsize, psize)),
    Vector#(nbins, ComplexMP#(isize, fsize, psize))
) PitchAdjust#(numeric type nbins, numeric type isize, numeric type fsize, numeric type psize);


// s - the amount each window is shifted from the previous window.
//
// factor - the amount to adjust the pitch.
//  1.0 makes no change. 2.0 goes up an octave, 0.5 goes down an octave, etc...
module mkPitchAdjust(Integer s, FixedPoint#(isize, fsize) factor, PitchAdjust#(nbins, isize, fsize, psize) ifc) provisos (Add#(psize, a__, isize), Add#(b__, psize, TAdd#(isize, isize)));
// TODO: implement this module 
	FIFO#(Vector#(nbins, ComplexMP#(isize, fsize, psize))) inFIFO <- mkFIFO();
	FIFO#(Vector#(nbins, ComplexMP#(isize, fsize, psize))) outFIFO <- mkFIFO();

	Vector#(nbins, Reg#(Phase#(psize))) inphases <- replicateM(mkReg(0));
	Vector#(nbins, Reg#(Phase#(psize))) outphases <- replicateM(mkReg(0));

	rule process;
		Vector#(nbins, ComplexMP#(isize, fsize, psize)) data_in = inFIFO.first();
		inFIFO.deq();
		FixedPoint#(isize, fsize) mag_0 = fromInteger(0);
		Phase#(psize) phs_0 = fromInteger(0);
		Vector#(nbins, ComplexMP#(isize, fsize, psize)) data_out = replicate(cmplxmp(mag_0, phs_0));

		for(Integer i = 0; i < valueOf(nbins); i = i + 1) begin
			Phase#(psize) phs = data_in[i].phase;
			FixedPoint#(isize, fsize) mag = data_in[i].magnitude;

			Phase#(psize) dphs = phs - inphases[i];
			FixedPoint#(isize, fsize) fp_dphs = fromInt(dphs);
			inphases[i] <= phs;

			FixedPoint#(isize, fsize) fp_i = fromInteger(i);
			FixedPoint#(isize, fsize) fp_iplus1 = fromInteger(i + 1);
			let bin = fxptGetInt(fp_i * factor);
			let nbin = fxptGetInt(fp_iplus1 * factor);

			if(nbin != bin && bin >= 0 && bin < fromInteger(valueOf(nbins))) begin
				Phase#(psize) shifted_phs = truncate(fxptGetInt(fxptMult(fp_dphs, factor)));
				outphases[bin] <= outphases[bin] + shifted_phs;
				data_out[bin] = cmplxmp(mag, outphases[bin] + shifted_phs);
			end
		end
		outFIFO.enq(data_out);
	endrule

	interface Put request = toPut(inFIFO);
	interface Get response = toGet(outFIFO);

endmodule

