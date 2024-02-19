import Types::*;
import Vector::*;
import CacheTypes::*;

module mkMessageRouter(
	Vector#(CoreNum, MessageGet) c2r, Vector#(CoreNum, MessagePut) r2c, 
	MessageGet m2r, MessagePut r2m,
	Empty ifc 
);

rule doRoute;
	Bool resp_c2r = False;
	Bool req_c2r = False;
	let resp_m2r = m2r.hasResp;
	let req_m2r = m2r.hasReq;
	
	Bit#(TLog#(CoreNum)) resp_core_idx = 0;
	Bit#(TLog#(CoreNum)) req_core_idx = 0;

	for(Integer i = 0; i < valueOf(CoreNum); i = i + 1) begin
		resp_c2r = resp_c2r || c2r[i].hasResp;
		req_c2r = req_c2r || c2r[i].hasReq;

		if(c2r[i].hasResp) begin
			resp_core_idx = fromInteger(i);
		end
		if(c2r[i].hasReq) begin
			req_core_idx = fromInteger(i);
		end
	end

	if(resp_c2r) begin
		r2m.enq_resp(c2r[resp_core_idx].first.Resp);
		c2r[resp_core_idx].deq();
	end
	else if(resp_m2r) begin
		let resp = m2r.first.Resp;
		m2r.deq();
		r2c[resp.child].enq_resp(resp);
	end
	else if(req_m2r) begin
		let req = m2r.first.Req;
		m2r.deq();
		r2c[req.child].enq_req(req);
	end
	else if(req_c2r) begin
		r2m.enq_req(c2r[req_core_idx].first.Req);
		c2r[req_core_idx].deq();
	end

endrule

endmodule
