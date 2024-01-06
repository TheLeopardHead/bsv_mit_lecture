
import ClientServer::*;
import GetPut::*;
import Vector::*;
import PitchAdjust::*;
import FixedPoint::*;
import FShow::*;
import ComplexMP::*;

// Unit test for PitchAdjust
(* synthesize *)
module mkPitchAdjustTest (Empty);

    // For nbins = 8, S = 2, pitch factor = 2.0
    SettablePitchAdjust#(8, 16, 16, 16) pitch <- mkPitchAdjust(2);

    Reg#(Bool) passed <- mkReg(True);
    Reg#(Bit#(32)) feed <- mkReg(0);
    Reg#(Bit#(32)) check <- mkReg(0);

    function Action dofeed(Vector#(8, ComplexMP#(16, 16, 16)) x);
        action
            pitch.adjust.request.put(x);
            feed <= feed+1;
        endaction
    endfunction

    function Action docheck(Vector#(8, ComplexMP#(16, 16, 16)) wnt);
        action
            let x <- pitch.adjust.response.get();
            if (x != wnt) begin
                $display("wnt: ", fshow(wnt));
                $display("got: ", fshow(x));
                passed <= False;
            end
            check <= check+1;
        endaction
    endfunction
   
	function Action start();
		action
			pitch.setFactor.put(2);
			feed <= feed + 1;
			check <= check + 1;
			$display("set factor: 2");
		endaction
	endfunction

    Vector#(8, ComplexMP#(16, 16, 16)) ti1 = newVector;
    ti1[0] = cmplxmp(1.000000, tophase(3.141593));
    ti1[1] = cmplxmp(1.000000, tophase(-1.570796));
    ti1[2] = cmplxmp(1.000000, tophase(0.000000));
    ti1[3] = cmplxmp(1.000000, tophase(1.570796));
    ti1[4] = cmplxmp(1.000000, tophase(3.141593));
    ti1[5] = cmplxmp(1.000000, tophase(-1.570796));
    ti1[6] = cmplxmp(1.000000, tophase(0.000000));
    ti1[7] = cmplxmp(1.000000, tophase(1.570796));

    Vector#(8, ComplexMP#(16, 16, 16)) to1 = newVector;
    to1[0] = cmplxmp(1.000000, tophase(-0.000000));
    to1[1] = cmplxmp(0.000000, tophase(0.000000));
    to1[2] = cmplxmp(1.000000, tophase(-3.141593));
    to1[3] = cmplxmp(0.000000, tophase(0.000000));
    to1[4] = cmplxmp(1.000000, tophase(0.000000));
    to1[5] = cmplxmp(0.000000, tophase(0.000000));
    to1[6] = cmplxmp(1.000000, tophase(3.141593));
    to1[7] = cmplxmp(0.000000, tophase(0.000000));

    Vector#(8, ComplexMP#(16, 16, 16)) ti2 = newVector;
    ti2[0] = cmplxmp(1.000000, tophase(3.141593));
    ti2[1] = cmplxmp(1.000000, tophase(0.000000));
    ti2[2] = cmplxmp(1.000000, tophase(3.141593));
    ti2[3] = cmplxmp(1.000000, tophase(0.000000));
    ti2[4] = cmplxmp(1.000000, tophase(3.141593));
    ti2[5] = cmplxmp(1.000000, tophase(0.000000));
    ti2[6] = cmplxmp(1.000000, tophase(3.141593));
    ti2[7] = cmplxmp(1.000000, tophase(0.000000));

    Vector#(8, ComplexMP#(16, 16, 16)) to2 = newVector;
    to2[0] = cmplxmp(1.000000, tophase(-0.000000));
    to2[1] = cmplxmp(0.000000, tophase(0.000000));
    to2[2] = cmplxmp(1.000000, tophase(0.000000));
    to2[3] = cmplxmp(0.000000, tophase(0.000000));
    to2[4] = cmplxmp(1.000000, tophase(-0.000000));
    to2[5] = cmplxmp(0.000000, tophase(0.000000));
    to2[6] = cmplxmp(1.000000, tophase(0.000000));
    to2[7] = cmplxmp(0.000000, tophase(0.000000));

    Vector#(8, ComplexMP#(16, 16, 16)) ti3 = newVector;
    ti3[0] = cmplxmp(0.000000, tophase(0.000000));
    ti3[1] = cmplxmp(6.395666, tophase(2.455808));
    ti3[2] = cmplxmp(9.899495, tophase(-2.356194));
    ti3[3] = cmplxmp(14.801873, tophase(-1.229828));
    ti3[4] = cmplxmp(14.000000, tophase(0.000000));
    ti3[5] = cmplxmp(14.801873, tophase(1.229828));
    ti3[6] = cmplxmp(9.899495, tophase(2.356194));
    ti3[7] = cmplxmp(6.395666, tophase(-2.455808));

    Vector#(8, ComplexMP#(16, 16, 16)) to3 = newVector;
    to3[0] = cmplxmp(0.000000, tophase(0.000000));
    to3[1] = cmplxmp(0.000000, tophase(0.000000));
    to3[2] = cmplxmp(6.395666, tophase(-1.371570));
    to3[3] = cmplxmp(0.000000, tophase(0.000000));
    to3[4] = cmplxmp(9.899495, tophase(1.570796));
    to3[5] = cmplxmp(0.000000, tophase(0.000000));
    to3[6] = cmplxmp(14.801873, tophase(-2.4597));
    to3[7] = cmplxmp(0.000000, tophase(0.000000));

	Vector#(8, ComplexMP#(16, 16, 16)) ti4 = newVector;
    ti4[0] = cmplxmp(974.000000, tophase(3.141593));
    ti4[1] = cmplxmp(149.368098, tophase(-1.140977));
    ti4[2] = cmplxmp(77.794601, tophase(-0.767218));
    ti4[3] = cmplxmp(57.281508, tophase(-0.352604));
    ti4[4] = cmplxmp(54.000000, tophase(0.000000));
    ti4[5] = cmplxmp(57.281508, tophase(0.352604));
    ti4[6] = cmplxmp(77.794601, tophase(0.767218));
    ti4[7] = cmplxmp(149.368098, tophase(1.140977));

    Vector#(8, ComplexMP#(16, 16, 16)) to4 = newVector;
    to4[0] = cmplxmp(974.000000, tophase(-0.000000));
    to4[1] = cmplxmp(0.000000, tophase(0.000000));
    to4[2] = cmplxmp(149.368098, tophase(-2.281954));
    to4[3] = cmplxmp(0.000000, tophase(0.000000));
    to4[4] = cmplxmp(77.794601, tophase(-1.534437));
    to4[5] = cmplxmp(0.000000, tophase(0.000000));
    to4[6] = cmplxmp(57.281508, tophase(-0.705208));
    to4[7] = cmplxmp(0.000000, tophase(0.000000));

	Vector#(8, ComplexMP#(16, 16, 16)) ti5 = newVector;
    ti5[0] = cmplxmp(332.000000, tophase(3.141593));
    ti5[1] = cmplxmp(125.501074, tophase(-1.293612));
    ti5[2] = cmplxmp(65.115282, tophase(-0.828849));
    ti5[3] = cmplxmp(50.134624, tophase(-0.425857));
    ti5[4] = cmplxmp(44.000000, tophase(0.000000));
    ti5[5] = cmplxmp(50.134624, tophase(0.425857));
    ti5[6] = cmplxmp(65.115282, tophase(0.828849));
    ti5[7] = cmplxmp(125.501074, tophase(1.293612));

    Vector#(8, ComplexMP#(16, 16, 16)) to5 = newVector;
    to5[0] = cmplxmp(332.000000, tophase(-0.000000));
    to5[1] = cmplxmp(0.000000, tophase(0.000000));
    to5[2] = cmplxmp(125.501074, tophase(-2.587225));
    to5[3] = cmplxmp(0.000000, tophase(0.000000));
    to5[4] = cmplxmp(65.115282, tophase(-1.657698));
    to5[5] = cmplxmp(0.000000, tophase(0.000000));
    to5[6] = cmplxmp(50.134624, tophase(-0.851714));
    to5[7] = cmplxmp(0.000000, tophase(0.000000));

	rule init (feed == 0); start(); endrule
    rule f0 (feed == 1); dofeed(ti1); endrule
    rule f1 (feed == 2); dofeed(ti2); endrule
    rule f2 (feed == 3); dofeed(ti3); endrule
//    rule f3 (feed == 3); dofeed(ti4); endrule
//	rule f4 (feed == 4); dofeed(ti5); endrule

    rule c0 (check == 1); docheck(to1); endrule
    rule c1 (check == 2); docheck(to2); endrule
    rule c2 (check == 3); docheck(to3); endrule
//    rule c3 (check == 3); docheck(to4); endrule
//    rule c4 (check == 4); docheck(to5); endrule

    rule finish (feed == 4 && check == 4);
        if (passed) begin
            $display("PASSED");
        end else begin
            $display("FAILED");
        end
        $finish();
    endrule

endmodule


