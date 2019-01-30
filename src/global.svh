`ifndef CONST
`define CONST
package CONST;
  parameter int DATA_WIDTH = 32;
  parameter int MIN_NUM_SAMPLES = 1;
  parameter int MAX_NUM_SAMPLES = 2**16;
  parameter int MEM_ADDR_WIDTH = $clog2(MAX_NUM_SAMPLES);
  parameter int PERIOD = 10;
endpackage
`endif

`ifndef TYPES
`define TYPES
package TYPES;
  typedef logic unsigned [CONST::DATA_WIDTH-1:0] sample_t;
  typedef sample_t samplesQueue_t[$];
endpackage
`endif

`ifndef CFG
`define CFG
package CFG;
  parameter int FROM_FILE = 0;
  parameter int NUM_RUNS = 1000;
  parameter bit DBG_PRINT = 0;
endpackage
`endif