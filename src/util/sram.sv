// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: Florian Zaruba    <zarubaf@iis.ee.ethz.ch>, ETH Zurich
//         Michael Schaffner <schaffner@iis.ee.ethz.ch>, ETH Zurich
// Date: 15.08.2018
// Description: SRAM wrapper for FPGA (requires the fpga-support submodule)
//
// Note: the wrapped module contains two different implementations for
// ALTERA and XILINX tools, since these follow different coding styles for
// inferrable RAMS with byte enable. define `FPGA_TARGET_XILINX or
// `FPGA_TARGET_ALTERA in your build environment (default is ALTERA)

module sram #(
    parameter DATA_WIDTH = 64,
    parameter NUM_WORDS  = 1024,
    parameter OUT_REGS   = 0    // enables output registers in FPGA macro (read lat = 2)
)(
   input  logic                          clk_i,
   input  logic                          rst_ni,
   input  logic                          req_i,
   input  logic                          we_i,
   input  logic [$clog2(NUM_WORDS)-1:0]  addr_i,
   input  logic [DATA_WIDTH-1:0]         wdata_i,
   input  logic [(DATA_WIDTH+7)/8-1:0]   be_i,
   output logic [DATA_WIDTH-1:0]         rdata_o
);

localparam DATA_WIDTH_ALIGNED = ((DATA_WIDTH+63)/64)*64;
localparam BE_WIDTH_ALIGNED   = (((DATA_WIDTH+7)/8+7)/8)*8;

// Red1
logic [DATA_WIDTH_ALIGNED-1:0]  wdata_aligned;
logic [BE_WIDTH_ALIGNED-1:0]    be_aligned;
logic [DATA_WIDTH_ALIGNED-1:0]  rdata_aligned;

// Red2
logic [DATA_WIDTH_ALIGNED-1:0]  wdata_aligned2;
logic [BE_WIDTH_ALIGNED-1:0]    be_aligned2;
logic [DATA_WIDTH_ALIGNED-1:0]  rdata_aligned2;

// Red3
logic [DATA_WIDTH_ALIGNED-1:0]  wdata_aligned3;
logic [BE_WIDTH_ALIGNED-1:0]    be_aligned3;
logic [DATA_WIDTH_ALIGNED-1:0]  rdata_aligned3;

logic compare_1_2;
logic compare_2_3;
logic compare_1_3;


// align to 64 bits for inferrable macro below
always_comb begin : p_align
    // Red1
    wdata_aligned                     ='0;
    be_aligned                        ='0;
    wdata_aligned[DATA_WIDTH-1:0]     = wdata_i;
    be_aligned[BE_WIDTH_ALIGNED-1:0]  = be_i;

    assign compare_1_2 = (rdata_aligned[DATA_WIDTH-1:0] == rdata_aligned2[DATA_WIDTH-1:0]);
    assign compare_2_3 = (rdata_aligned2[DATA_WIDTH-1:0] == rdata_aligned3[DATA_WIDTH-1:0]);
    assign compare_1_3 = (rdata_aligned[DATA_WIDTH-1:0] == rdata_aligned3[DATA_WIDTH-1:0]);

    if (compare_1_2 == 1'b1 && 
        compare_2_3 == 1'b1 &&
        compare_1_3 == 1'b1) 
        begin
            rdata_o = rdata_aligned[DATA_WIDTH-1:0];
        end
    else 
        begin

            // If comparison of 1 and 2 is 1, then sram 3 is faulty.
            if (compare_1_2 == 1'b1)
                begin
                    rdata_o = rdata_aligned[DATA_WIDTH-1:0];
                end
            else 
                begin
                    // If comparison of 2 and 3 is 1, then sram 1 is faulty.
                    if (compare_2_3 == 1'b1)
                        begin
                            rdata_o = rdata_aligned2[DATA_WIDTH-1:0];
                        end
                    else
                        begin
                            // If comparison of 1 and 3 is 1, then sram 2 is faulty.
                            if (compare_1_3 == 1'b1)
                            begin
                                        rdata_o = rdata_aligned[DATA_WIDTH-1:0];
                            end
                        end
                end

        end



    // Red2
    wdata_aligned2                    ='0;
    be_aligned2                       ='0;
    wdata_aligned2[DATA_WIDTH-1:0]    = wdata_i;
    be_aligned2[BE_WIDTH_ALIGNED-1:0] = be_i;

    // Red3
    wdata_aligned3                    ='0;
    be_aligned3                       ='0;
    wdata_aligned3[DATA_WIDTH-1:0]    = wdata_i;
    be_aligned3[BE_WIDTH_ALIGNED-1:0] = be_i;
end

genvar k;
generate
    for (k = 0; k<(DATA_WIDTH+63)/64; k++) begin
        // unused byte-enable segments (8bits) are culled by the tool
        SyncSpRamBeNx64 #(
          .ADDR_WIDTH($clog2(NUM_WORDS)),
          .DATA_DEPTH(NUM_WORDS),
          .OUT_REGS (0),
          // this initializes the memory with 0es. adjust to taste...
          // 0: no init, 1: zero init, 2: random init, 3: deadbeef init
          .SIM_INIT (1)
        ) i_ram (
           .Clk_CI    ( clk_i                     ),
           .Rst_RBI   ( rst_ni                    ),
           .CSel_SI   ( req_i                     ),
           .WrEn_SI   ( we_i                      ),
           .BEn_SI    ( be_aligned[k*8 +: 8]      ),
           .WrData_DI ( wdata_aligned[k*64 +: 64] ),
           .Addr_DI   ( addr_i                    ),
           .RdData_DO ( rdata_aligned[k*64 +: 64] )
        );
    end
endgenerate

genvar kk;
generate
    for (kk = 0; kk<(DATA_WIDTH+63)/64; kk++) begin
        // unused byte-enable segments (8bits) are culled by the tool
        SyncSpRamBeNx64 #(
          .ADDR_WIDTH($clog2(NUM_WORDS)),
          .DATA_DEPTH(NUM_WORDS),
          .OUT_REGS (0),
          // this initializes the memory with 0es. adjust to taste...
          // 0: no init, 1: zero init, 2: random init, 3: deadbeef init
          .SIM_INIT (1)
        ) i_ram (
           .Clk_CI    ( clk_i                      ),
           .Rst_RBI   ( rst_ni                     ),
           .CSel_SI   ( req_i                      ),
           .WrEn_SI   ( we_i                       ),
           .BEn_SI    ( be_aligned2[kk*8 +: 8]      ),
           .WrData_DI ( wdata_aligned2[kk*64 +: 64] ),
           .Addr_DI   ( addr_i                     ),
           .RdData_DO ( rdata_aligned2[kk*64 +: 64] )
        );
    end
endgenerate

genvar kkk;
generate
    for (kkk = 0; kkk<(DATA_WIDTH+63)/64; kkk++) begin
        // unused byte-enable segments (8bits) are culled by the tool
        SyncSpRamBeNx64 #(
          .ADDR_WIDTH($clog2(NUM_WORDS)),
          .DATA_DEPTH(NUM_WORDS),
          .OUT_REGS (0),
          // this initializes the memory with 0es. adjust to taste...
          // 0: no init, 1: zero init, 2: random init, 3: deadbeef init
          .SIM_INIT (1)
        ) i_ram (
           .Clk_CI    ( clk_i                      ),
           .Rst_RBI   ( rst_ni                     ),
           .CSel_SI   ( req_i                      ),
           .WrEn_SI   ( we_i                       ),
           .BEn_SI    ( be_aligned3[kkk*8 +: 8]      ),
           .WrData_DI ( wdata_aligned3[kkk*64 +: 64] ),
           .Addr_DI   ( addr_i                     ),
           .RdData_DO ( rdata_aligned3[kkk*64 +: 64] )
        );
    end
endgenerate

endmodule : sram
