
import FIFO::*;
import FixedPoint::*;
import Vector::*;
import Multiplier::*;

import AudioProcessorTypes::*;
import FilterCoefficients::*;


module mkFIRFilter (AudioProcessor);

    FIFO#(Sample) infifo <- mkFIFO();
    FIFO#(Sample) outfifo <- mkFIFO();

    Vector#(8, Reg#(Sample)) r <- replicateM(mkReg(0));
    Vector#(9, Multiplier) mul <- replicateM(mkMultiplier());
//	Reg#(Bit#(4)) count <- mkReg(0);
//	rule process;
//		Sample sample = infifo.first();
//		infifo.deq();
//
//		r[0] <= sample;
//
//		for(Integer i = 0; i < 7; i = i + 1) begin
//			r[i+1] <= r[i];
//		end
//	
//		FixedPoint#(16, 16) accumulate = c[0] * fromInt(sample);
//
//		for(Integer i = 0; i < 8; i = i + 1) begin
//			accumulate = accumulate + c[i+1] * fromInt(r[i]);
//		end
//
//		outfifo.enq(fxptGetInt(accumulate));
//	endrule

//	rule enqueue (count == 0);
//		Sample sample = infifo.first();
//		infifo.deq();
//		r[0] <= sample;
//
//		for(integer i = 0; i < 7; i = i + 1) begin
//			r[i+1] <= r[i];
//		end
//
//		mul[0].putoperands(c[0], sample);
//	endrule
//
//	rule roll_count;
//		if(count == 9) count <= 0;
//		else count <= count + 1;
//	endrule
//
//	rule multiply ((count > 0) && (count < 9));
//		mul[count].putOperands(c[count], r[count-1]);
//	endrule

	rule input_multiply;
		Sample sample = infifo.first();
		infifo.deq();
   		r[0] <= sample;

		for(Integer i = 0; i < 7; i = i + 1) begin
			r[i+1] <= r[i];
		end

		mul[0].putOperands(c[0], sample);
		for(Integer i = 0; i < 8; i = i + 1) begin
			mul[i+1].putOperands(c[i+1], r[i]);
		end
	endrule

	rule output_sum;
		FixedPoint#(16,16) accumulate = 0;
        for (Integer i=0; i<9; i=i+1) begin
            let t <- mul[i].getResult;
            accumulate = accumulate + t;
        end

        outfifo.enq(fxptGetInt(accumulate));
	endrule

        method Action putSampleInput(Sample in);
        infifo.enq(in);
    endmethod

    method ActionValue#(Sample) getSampleOutput();
        outfifo.deq();
        return outfifo.first();
    endmethod

endmodule

