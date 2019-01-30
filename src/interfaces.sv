`include "global.svh"

interface samples_if # (
  parameter DATA_WIDTH = 32
);

  logic valid = 0, ready = 0, first = 0, last = 0;
  logic [DATA_WIDTH-1:0] data = 0;

  modport sink (
    input data,
    input valid,
    input first,
    input last,
    output ready
  );

  modport source (
    output data,
    output valid,
    output first,
    output last,
    input ready
  );

endinterface
