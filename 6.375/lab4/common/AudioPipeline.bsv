
import ClientServer::*;
import GetPut::*;

import AudioProcessorTypes::*;
import Chunker::*;
import FFT::*;
import OverSampler::*;
import ToMP::*;
import PitchAdjust::*;
import FromMP::*;
import Overlayer::*;
import FilterCoefficients::*;
import FIRFilter::*;
import Splitter::*;
import FixedPoint::*;
import Vector::*;

module mkAudioPipeline(AudioProcessor);

    AudioProcessor fir <- mkFIRFilter(c);  //"c" defined in FilterCoefficients.bsv
    Chunker#(STRIDE, Sample) chunker <- mkChunker();
	OverSampler#(STRIDE, FFT_POINTS, Sample) over_sampler <- mkOverSampler(replicate(0));
    FFT#(FFT_POINTS, FixedPoint#(16, 16)) fft <- mkFFT();
	ToMP#(FFT_POINTS, 16, 16, 16) to_mp <- mkToMP();
	SettablePitchAdjust#(FFT_POINTS, 16, 16, 16) pitch <- mkPitchAdjust(2);
	FromMP#(FFT_POINTS, 16, 16, 16) from_mp <- mkFromMP();
    FFT#(FFT_POINTS, FixedPoint#(16, 16)) ifft <- mkIFFT();
	Overlayer#(FFT_POINTS,STRIDE,Sample) over_layer <- mkOverlayer(replicate(0));
    Splitter#(STRIDE, Sample) splitter <- mkSplitter();

    rule fir_to_chunker (True);
        let x <- fir.getSampleOutput();
        chunker.request.put(x);
    endrule

    rule chunker_to_oversampler (True);
        let x <- chunker.response.get();
        over_sampler.request.put(x);
    endrule

	rule oversampler_to_fft (True);
		Vector#(FFT_POINTS, Sample) x <- over_sampler.response.get();
		Vector#(FFT_POINTS, ComplexSample) y;
		for (Integer i=0; i<valueOf(FFT_POINTS); i=i+1) begin
			y[i] = tocmplx(x[i]);
		end
		fft.request.put(y);
	endrule

    rule fft_to_tomp (True);
        let x <- fft.response.get();
        to_mp.request.put(x);
    endrule

	rule tomp_to_adjust (True);
		let x <- to_mp.response.get();
		pitch.adjust.request.put(x);
	endrule

	rule adjust_to_frmp (True);
		let x <- pitch.adjust.response.get();
		from_mp.request.put(x);
	endrule

	rule frmp_to_ifft (True);
		let x <- from_mp.response.get();
		ifft.request.put(x);
	endrule

    rule ifft_to_overlayer (True);
		Vector#(FFT_POINTS, ComplexSample) x <- ifft.response.get();
		Vector#(FFT_POINTS, Sample) y;
		for (Integer i=0; i<valueOf(FFT_POINTS); i=i+1) begin
			y[i] = frcmplx(x[i]);
		end
		over_layer.request.put(y);
    endrule

	rule overlayer_to_splitter (True);
		let x <- over_layer.response.get();
		splitter.request.put(x);
	endrule
    
    method Action putSampleInput(Sample x);
//		$display("Put Sample Input");
        fir.putSampleInput(x);
    endmethod

    method ActionValue#(Sample) getSampleOutput();
        let x <- splitter.response.get();
        return x;
    endmethod

	method Action putFactor(FixedPoint#(16, 16) x);
		pitch.setFactor.put(x);
	endmethod

endmodule

