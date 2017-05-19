// Author(s):
// - Huailu Ren, hlren.pub@gmail.com
//

// Revision 1.1  16:56 2011-4-28  hlren
// created
//

// synopsys translate_off
`include "timescale.v"
// synopsys translate_on

module sram_wrapper (
    wb_clk_i,
    wb_rst_i,

    wb_dat_i,
    wb_dat_o,
    wb_adr_i,
    wb_sel_i,
    wb_we_i,
    wb_cyc_i,
    wb_stb_i,
    wb_ack_o,
    wb_err_o,

    SRAM_DQ,
    SRAM_ADDR,
    SRAM_LB_N,
    SRAM_UB_N,
    SRAM_CE_N,
    SRAM_OE_N,
    SRAM_WE_N
);

//
// clock and reset signals
//
  input         wb_clk_i;
  input         wb_rst_i;
//
// WB slave i/f
//
  input  [31:0] wb_dat_i;
  output [31:0] wb_dat_o;
  input  [31:0] wb_adr_i;
  input  [ 3:0] wb_sel_i;
  input         wb_we_i;
  input         wb_cyc_i;
  input         wb_stb_i;
  output        wb_ack_o;
  output        wb_err_o;
//
// SRAM port
//
  inout  [15:0]   SRAM_DQ;    // SRAM Data bus 16 Bits
  output [17:0] SRAM_ADDR;    // SRAM Address bus 18 Bits
  output        SRAM_LB_N;    // SRAM Low-byte Data Mask
  output        SRAM_UB_N;    // SRAM High-byte Data Mask
  output        SRAM_CE_N;    // SRAM Chip chipselect
  output        SRAM_OE_N;    // SRAM Output chipselect
  output        SRAM_WE_N;    // SRAM Write chipselect

  reg    [17:0] SRAM_ADDR;
  reg           SRAM_LB_N;
  reg           SRAM_UB_N;
  reg           SRAM_CE_N;
  reg           SRAM_OE_N;
  reg           SRAM_WE_N;
 
  reg [3:0] state, state_r;
  reg [15:0] wb_data_o_l, wb_data_o_u;
 
  reg [16:0] wb_addr_i_reg;
  reg [31:0] wb_data_i_reg;
  //reg [31:0] wb_data_o_reg;
  reg [ 3:0] wb_sel_i_reg;
 
  reg ack_we, ack_re;
// *****************************************************************************
//  FSM
// *****************************************************************************
  localparam IDLE = 0;
  localparam WE0  = 1;
  localparam WE1  = 2;
  localparam WE2  = 3;
  localparam WE3  = 4;
  localparam RD0  = 5;
  localparam RD1  = 6;
  localparam RD2  = 7;
  localparam RD3  = 8;
  localparam ACK  = 9;
 
  assign SRAM_DQ =  ( (state_r == WE0 || state_r == WE1) ? wb_data_i_reg[15: 0]
                    : (state_r == WE2 || state_r == WE3) ? wb_data_i_reg[31:16]
                    : 16'hzzzz);
  assign wb_dat_o = {wb_data_o_u,wb_data_o_l};
 
  assign wb_ack_o = (state == ACK);
  assign wb_err_o = wb_cyc_i & wb_stb_i & (| wb_adr_i[23:19]);
 
  always @ (posedge wb_clk_i or posedge wb_rst_i) begin
    if(wb_rst_i)
      state <= IDLE;
    else begin
      case (state)
        IDLE : begin
          if (wb_cyc_i & wb_stb_i & wb_we_i & ~ack_we)
            state <= WE0;
          else if (wb_cyc_i & wb_stb_i & ~wb_err_o & ~wb_we_i & ~ack_re)
            state <= RD0;
        end
        WE0 : state <= WE1;
        WE1 : state <= WE2;
        WE2 : state <= WE3;
        WE3 : state <= ACK;
        RD0 : state <= RD1;
        RD1 : state <= RD2;
        RD2 : state <= RD3;
        RD3 : state <= ACK;
        ACK : state <= IDLE;
        default : state <= IDLE;
      endcase
    end
  end
 
  always @ (posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i)
      state_r <= IDLE;
    else
      state_r <= state;
  end
//
// Write acknowledge
//
  always @ (posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i)
      ack_we <= 1'b0;
    else
    if (wb_cyc_i & wb_stb_i & wb_we_i & ~ack_we)
      ack_we <= #1 1'b1;
    else
      ack_we <= #1 1'b0;
  end
 
//
// Read acknowledge
//
  always @ (posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i)
      ack_re <= 1'b0;
    else
    if (wb_cyc_i & wb_stb_i & ~wb_err_o & ~wb_we_i & ~ack_re)
      ack_re <= #1 1'b1;
    else
      ack_re <= #1 1'b0;
  end
 
  always @ (posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
      wb_addr_i_reg <= 32'b0;
      wb_data_i_reg <= 32'b0;
      wb_sel_i_reg  <= 4'b0;
    end
    else
    if (wb_cyc_i & wb_stb_i & ~ack_re & ~ack_we)
    begin
      wb_addr_i_reg <= wb_adr_i[18:2];
      wb_data_i_reg <= wb_dat_i[31:0];
      wb_sel_i_reg  <= wb_sel_i[3:0];
    end
  end
 
  always @ (posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
      SRAM_ADDR <= 18'b0;
    end
    else
      case (state)
        WE0, WE1, RD0, RD1 :
          SRAM_ADDR <= {wb_addr_i_reg[16:0], 1'b0};
        WE2, WE3, RD2, RD3 :
          SRAM_ADDR <= {wb_addr_i_reg[16:0], 1'b1};
        default : SRAM_ADDR <= 18'hz;
      endcase
  end
 
  always @ (posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
      SRAM_LB_N <= 1'b1;
    end
    else
      case (state)
        WE0, WE1, RD0, RD1 :
          SRAM_LB_N <= ~wb_sel_i[0];
        WE2, WE3, RD2, RD3 :
          SRAM_LB_N <= ~wb_sel_i[2];
        default :
          SRAM_LB_N <= 1'b1;
      endcase
  end
 
  always @ (posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
      SRAM_UB_N <= 1'b1;
    end
    else
      case (state)
        WE0, WE1, RD0, RD1 :
          SRAM_UB_N <= ~wb_sel_i[1];
        WE2, WE3, RD2, RD3 :
          SRAM_UB_N <= ~wb_sel_i[3];
        default :
          SRAM_UB_N <= 1'b1;
      endcase
  end
 
  always @ (posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
      SRAM_CE_N <= 1'b1;
    end
    else
      case (state)
        WE0, WE1, RD0, RD1 :
          SRAM_CE_N <= 1'b0;
        WE2, WE3, RD2, RD3 :
          SRAM_CE_N <= 1'b0;
        default :
          SRAM_CE_N <= 1'b1;
      endcase
  end
 
  always @ (posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
      SRAM_OE_N <= 1'b1;
    end
    else
      case (state)
        RD0, RD1, RD2, RD3 :
          SRAM_OE_N <= 1'b0;
        default :
          SRAM_OE_N <= 1'b1;
      endcase
  end
 
  always @ (posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
      SRAM_WE_N <= 1'b1;
    end
    else
      case (state)
        WE0, WE1, WE2, WE3 :
          SRAM_WE_N <= 1'b0;
        default :
          SRAM_WE_N <= 1'b1;
      endcase
  end
  //
  // assemble ouput data
  //
  always @ (posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
      wb_data_o_l <= 16'b0;
      wb_data_o_u <= 16'b0;
    end
    else
      case (state_r)
        RD0, RD1 :
          wb_data_o_l <= SRAM_DQ;
        RD2, RD3 :
          wb_data_o_u <= SRAM_DQ;
      endcase
  end
endmodule
