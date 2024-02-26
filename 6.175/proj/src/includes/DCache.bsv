import CacheTypes::*;
import Vector::*;
import Fifo::*;
import Types::*;
import RefTypes::*;
import MemTypes::*;

typedef enum {
    Ready,
    StartMiss,
    SendFillReq,
    WaitFillResp
} CacheStatus deriving ( Bits, Eq );

module mkDCache#(CoreID id)(MessageGet fromMem, MessagePut toMem, RefDMem refDMem, DCache ifc);

    Vector#(CacheRows, Reg#(CacheLine)) dataArray <- replicateM(mkRegU);
    Vector#(CacheRows, Reg#(CacheTag)) tagArray <- replicateM(mkRegU);
    Vector#(CacheRows, Reg#(MSI)) stateArray <- replicateM(mkReg(I));

    Fifo#(2, MemResp) hitQ <- mkBypassFifo;
    Reg#(MemReq) missReq <- mkRegU;
    Reg#(CacheStatus) mshr <- mkReg(Ready);

    // Fifo#(2, MemReq) memReqQ <- mkCFFifo;
    // Fifo#(2, MemResp) memRespQ <- mkCFFifo;

    // log2(16*32/8) = 6
    function CacheIndex getIndex(Addr addr) = truncate(addr >> 6);
    // log2(32/8) = 2
    function CacheWordSelect getOffset(Addr addr) = truncate(addr >> 2);
    function CacheTag getTag(Addr addr) = truncateLSB(addr);

    rule startMiss(mshr == StartMiss);
		$display("begin StartMiss Rule");
        let idx = getIndex(missReq.addr);
        let tag = tagArray[idx];
		let wOffset = getOffset(missReq.addr);
		let state = stateArray[idx];
		Addr wb_addr = {tag, idx, wOffset, 0};

		let wb_data = (state == M)? tagged Valid dataArray[idx] : tagged Invalid;
		toMem.enq_resp(CacheMemResp{child: id, addr: wb_addr, state: I, data: wb_data});

		stateArray[idx] <= I;
        mshr <= SendFillReq;
    endrule

	rule sendFillReq(mshr == SendFillReq);
		$display("begin sendFillReq Rule");

		toMem.enq_req(CacheMemReq{child: id, addr: missReq.addr, state: missReq.op == St ? M : S});

        mshr <= WaitFillResp;
    endrule

    rule waitFillResp ((mshr == WaitFillResp) && (fromMem.hasResp));
		$display("begin waitFillResp Rule");  
        let idx = getIndex(missReq.addr);
        let tag = getTag(missReq.addr);
        let wOffset = getOffset(missReq.addr);
		CacheMemResp resp = fromMem.first.Resp;
		fromMem.deq;

		CacheLine data = isValid(resp.data)? fromMaybe(?, resp.data) : dataArray[idx];

        if(missReq.op == Ld) begin
        	hitQ.enq(data[wOffset]);
        end else if(missReq.op == St) begin
        	data[wOffset] = missReq.data;
        end

        tagArray[idx] <= tag;
        dataArray[idx] <= data;
		stateArray[idx] <= resp.state;
        mshr <= Ready;
    endrule

	rule downgrade (fromMem.hasReq);
		CacheMemReq req = fromMem.first.Req;
		fromMem.deq;

		let idx = getIndex(req.addr);	
		let state = stateArray[idx];

		if(state > req.state) begin
			$display("downgrade successfully");
			let data = (state == M)? tagged Valid dataArray[idx] : tagged Invalid;
			toMem.enq_resp(CacheMemResp{child: id, addr: req.addr, state: req.state, data: data});
			stateArray[idx] <= req.state;
		end
		else begin
			$display("refuse downgrade ========", fshow(stateArray[idx]), fshow(req));
		end
	endrule

    method Action req(MemReq r) if (mshr == Ready);
        let idx = getIndex(r.addr);
        let tag = getTag(r.addr);
        let wOffset = getOffset(r.addr);
        let currTag = tagArray[idx];
		let state = stateArray[idx];
    	let hit = (currTag == tag)? True : False;
		missReq <= r;

        if (hit) begin
        	let cacheLine = dataArray[idx];
        	if ( r.op == Ld ) begin
				if((state == S) || (state == M)) begin	
					hitQ.enq(cacheLine[wOffset]);
				end
				else begin
					mshr <= SendFillReq;
				end
			end
        	else if(r.op == St) begin
				if(state == M) begin
					cacheLine[wOffset] = r.data;
					dataArray[idx] <= cacheLine;
				end
				else begin
					mshr <= SendFillReq;
				end
        	end
        end else begin
			if(state == I) begin
				mshr <= SendFillReq;
			end
			else begin
				mshr <= StartMiss;
			end
        end
    endmethod

    method ActionValue#(MemResp) resp;
        hitQ.deq;
        return hitQ.first;
    endmethod

endmodule
