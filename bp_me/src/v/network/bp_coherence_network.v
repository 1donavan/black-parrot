/**
 * bp_coherence_network
 *
 * Input and output signals should be concatinated together at instantiation
 * Example input and output assignment ,.lce_cmd_x({lce_cmd_x_2, lce_cmd_x_1, lce_cmd_x_0})
 *
 * Network is demanding as a producer and helpful as a consumer
 * producer (outputs): ready_i, v_o (ready->valid)
 * consumer (inputs): ready_o, v_i (valid->ready)
 *
 */

`include "bsg_defines.v"
`include "bp_common_me_if.vh"

module bp_coherence_network
  #(parameter num_lce_p="inv"
  ,parameter num_cce_p="inv"
  ,parameter addr_width_p="inv"
  ,parameter lce_assoc_p="inv"
  ,parameter block_size_in_bytes_p="inv"

  ,parameter lg_num_lce_lp=`BSG_SAFE_CLOG2(num_lce_p)
  ,parameter lg_num_cce_lp=`BSG_SAFE_CLOG2(num_cce_p)

  ,parameter block_size_in_bits_lp=block_size_in_bytes_p*8
  ,parameter mesh_width_lp=`BSG_MAX(num_lce_p, num_cce_p)
  ,parameter lg_mesh_width_lp=`BSG_SAFE_CLOG2(mesh_width_lp)
  ,parameter lg_lce_lce_width_lp=`BSG_SAFE_CLOG2(num_lce_p) //For lce->lce since this could be diff than mesh width

  ,parameter bp_lce_cce_req_width_lp=`bp_lce_cce_req_width(num_cce_p, num_lce_p, addr_width_p, lce_assoc_p)
  ,parameter bp_lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_p, num_lce_p, addr_width_p)
  ,parameter bp_lce_cce_data_resp_width_lp=`bp_lce_cce_data_resp_width(num_cce_p, num_lce_p, addr_width_p, block_size_in_bits_lp)
  ,parameter bp_cce_lce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p, num_lce_p, addr_width_p, lce_assoc_p)
  ,parameter bp_cce_lce_data_cmd_width_lp=`bp_cce_lce_data_cmd_width(num_cce_p, num_lce_p, addr_width_p, block_size_in_bits_lp, lce_assoc_p)
  ,parameter bp_lce_lce_tr_resp_width_lp=`bp_lce_lce_tr_resp_width(num_lce_p, addr_width_p, block_size_in_bits_lp, lce_assoc_p)

  ,parameter debug_p=0
  )
  (
  input clk_i
  ,input reset_i

  // CCE Command Network - (CCE->trans_net->LCE)
  // (LCE side)
  ,output [num_lce_p-1:0][bp_cce_lce_cmd_width_lp-1:0] lce_cmd_o
  ,output [num_lce_p-1:0] lce_cmd_v_o
  ,input  [num_lce_p-1:0] lce_cmd_ready_i
  // (CCE side)
  ,input  [num_cce_p-1:0][bp_cce_lce_cmd_width_lp-1:0] lce_cmd_i
  ,input  [num_cce_p-1:0] lce_cmd_v_i
  ,output [num_cce_p-1:0] lce_cmd_ready_o

  // CCE Data Command Network - (CCE->trans_net->LCE)
  // (LCE side)
  ,output [num_lce_p-1:0][bp_cce_lce_data_cmd_width_lp-1:0] lce_data_cmd_o
  ,output [num_lce_p-1:0] lce_data_cmd_v_o
  ,input  [num_lce_p-1:0] lce_data_cmd_ready_i
  // (CCE side)
  ,input  [num_cce_p-1:0][bp_cce_lce_data_cmd_width_lp-1:0] lce_data_cmd_i
  ,input  [num_cce_p-1:0] lce_data_cmd_v_i
  ,output [num_cce_p-1:0] lce_data_cmd_ready_o

  // LCE Request Network - (LCE->trans_net->CCE)
  // (LCE side)
  ,input  [num_lce_p-1:0][bp_lce_cce_req_width_lp-1:0] lce_req_i
  ,input  [num_lce_p-1:0] lce_req_v_i
  ,output [num_lce_p-1:0] lce_req_ready_o
  // (CCE side)
  ,output [num_cce_p-1:0][bp_lce_cce_req_width_lp-1:0] lce_req_o
  ,output [num_cce_p-1:0] lce_req_v_o
  ,input  [num_cce_p-1:0] lce_req_ready_i

  // LCE Response Network - (LCE->trans_net->CCE)
  // (LCE side)
  ,input  [num_lce_p-1:0][bp_lce_cce_resp_width_lp-1:0] lce_resp_i
  ,input  [num_lce_p-1:0] lce_resp_v_i
  ,output [num_lce_p-1:0] lce_resp_ready_o
  // (CCE side)
  ,output [num_cce_p-1:0][bp_lce_cce_resp_width_lp-1:0] lce_resp_o
  ,output [num_cce_p-1:0] lce_resp_v_o
  ,input  [num_cce_p-1:0] lce_resp_ready_i

  // LCE Data Response Network - (LCE->trans_net->CCE)
  // (LCE side)
  ,input  [num_lce_p-1:0][bp_lce_cce_data_resp_width_lp-1:0] lce_data_resp_i
  ,input  [num_lce_p-1:0] lce_data_resp_v_i
  ,output [num_lce_p-1:0] lce_data_resp_ready_o
  // (CCE side)
  ,output [num_cce_p-1:0][bp_lce_cce_data_resp_width_lp-1:0] lce_data_resp_o
  ,output [num_cce_p-1:0] lce_data_resp_v_o
  ,input  [num_cce_p-1:0] lce_data_resp_ready_i

  // LCE-LCE Transfer Network - (LCE(s)->trans_net->LCE(d))
  // (LCE source side)
  ,input  [num_lce_p-1:0][bp_lce_lce_tr_resp_width_lp-1:0] lce_tr_resp_i
  ,input  [num_lce_p-1:0] lce_tr_resp_v_i
  ,output [num_lce_p-1:0] lce_tr_resp_ready_o
  // (LCE dest side)
  ,output [num_lce_p-1:0][bp_lce_lce_tr_resp_width_lp-1:0] lce_tr_resp_o
  ,output [num_lce_p-1:0] lce_tr_resp_v_o
  ,input  [num_lce_p-1:0] lce_tr_resp_ready_i
  );

  // CCE Command Network - (CCE->trans_net->LCE)
  bp_coherence_network_channel #(
    .packet_width_p(bp_cce_lce_cmd_width_lp)
    ,.num_src_p(num_cce_p)
    ,.num_dst_p(num_lce_p)
    ,.debug_p(debug_p)
    ,.repeater_output_p(5'b00000)
  ) cce_lce_cmd_network (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    // South Port (src)
    ,.src_data_i(lce_cmd_i)
    ,.src_v_i(lce_cmd_v_i)
    ,.src_ready_o(lce_cmd_ready_o)
    // Proc Port (dst)
    ,.dst_data_o(lce_cmd_o)
    ,.dst_v_o(lce_cmd_v_o)
    ,.dst_ready_i(lce_cmd_ready_i)
  );

  // CCE Data Command Network - (CCE->trans_net->LCE)
  bp_coherence_network_channel #(
    .packet_width_p(bp_cce_lce_data_cmd_width_lp)
    ,.num_src_p(num_cce_p)
    ,.num_dst_p(num_lce_p)
    ,.debug_p(debug_p)
    ,.repeater_output_p(5'b00000)
  ) cce_lce_data_cmd_network (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    // South Port (src)
    ,.src_data_i(lce_data_cmd_i)
    ,.src_v_i(lce_data_cmd_v_i)
    ,.src_ready_o(lce_data_cmd_ready_o)
    // Proc Port (dst)
    ,.dst_data_o(lce_data_cmd_o)
    ,.dst_v_o(lce_data_cmd_v_o)
    ,.dst_ready_i(lce_data_cmd_ready_i)
  );

  // LCE Request Network - (LCE->trans_net->CCE)
  bp_coherence_network_channel #(
    .packet_width_p(bp_lce_cce_req_width_lp)
    ,.num_src_p(num_lce_p)
    ,.num_dst_p(num_cce_p)
    ,.debug_p(debug_p)
    ,.repeater_output_p(5'b00000)
  ) lce_cce_req_network (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    // South Port (src)
    ,.src_data_i(lce_req_i)
    ,.src_v_i(lce_req_v_i)
    ,.src_ready_o(lce_req_ready_o)
    // Proc Port (dst)
    ,.dst_data_o(lce_req_o)
    ,.dst_v_o(lce_req_v_o)
    ,.dst_ready_i(lce_req_ready_i)
  );

  // LCE Response Network - (LCE->trans_net->CCE)
  bp_coherence_network_channel #(
    .packet_width_p(bp_lce_cce_resp_width_lp)
    ,.num_src_p(num_lce_p)
    ,.num_dst_p(num_cce_p)
    ,.debug_p(debug_p)
    ,.repeater_output_p(5'b00000)
  ) lce_cce_resp_network (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    // South Port (src)
    ,.src_data_i(lce_resp_i)
    ,.src_v_i(lce_resp_v_i)
    ,.src_ready_o(lce_resp_ready_o)
    // Proc Port (dst)
    ,.dst_data_o(lce_resp_o)
    ,.dst_v_o(lce_resp_v_o)
    ,.dst_ready_i(lce_resp_ready_i)
  );

  // LCE Data Response Network - (LCE->trans_net->CCE)
  bp_coherence_network_channel #(
    .packet_width_p(bp_lce_cce_data_resp_width_lp)
    ,.num_src_p(num_lce_p)
    ,.num_dst_p(num_cce_p)
    ,.debug_p(debug_p)
    ,.repeater_output_p(5'b00000)
  ) lce_cce_data_resp_network (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    // South Port (src)
    ,.src_data_i(lce_data_resp_i)
    ,.src_v_i(lce_data_resp_v_i)
    ,.src_ready_o(lce_data_resp_ready_o)
    // Proc Port (dst)
    ,.dst_data_o(lce_data_resp_o)
    ,.dst_v_o(lce_data_resp_v_o)
    ,.dst_ready_i(lce_data_resp_ready_i)
  );

  // LCE-LCE Transfer Network - (LCE->trans_net->LCE)
  bp_coherence_network_channel #(
    .packet_width_p(bp_lce_lce_tr_resp_width_lp)
    ,.num_src_p(num_lce_p)
    ,.num_dst_p(num_lce_p)
    ,.debug_p(debug_p)
    ,.repeater_output_p(5'b00000)
  ) lce_lce_tr_resp_network (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    // South Port (src)
    ,.src_data_i(lce_tr_resp_i)
    ,.src_v_i(lce_tr_resp_v_i)
    ,.src_ready_o(lce_tr_resp_ready_o)
    // Proc Port (dst)
    ,.dst_data_o(lce_tr_resp_o)
    ,.dst_v_o(lce_tr_resp_v_o)
    ,.dst_ready_i(lce_tr_resp_ready_i)
  );

endmodule
