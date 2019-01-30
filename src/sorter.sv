`include "global.svh"

// true dual-port ram with registered outputs
module tdpRam 
import TYPES::*;
(
  input clka,
  input clkb,
  input wea,
  input web,
  input [CONST::MEM_ADDR_WIDTH-1:0] addra,
  input [CONST::MEM_ADDR_WIDTH-1:0] addrb,
  input sample_t dia,
  input sample_t dib,
  output sample_t doa,
  output sample_t dob
);


logic [CONST::DATA_WIDTH-1:0] ram [2**CONST::MEM_ADDR_WIDTH-1:0];
sample_t outa, outb;

always_ff @(posedge clka) begin 
  if (wea)
    ram[addra] <= dia;
  outa <= ram[addra];
  doa <= outa;
end
always_ff @(posedge clkb) begin 
  if (web)
    ram[addrb] <= dib;
  outb <= ram[addrb];
  dob <= outb;
end

endmodule


// top level module
module sorter 
import TYPES::*;
(
  input logic clk,
  samples_if.sink inputSamples,
  samples_if.source outputSamples
);


// ping-pong buffer (true dual port memory - 2 instances)
// sample_t buff [2**CONST::MEM_ADDR_WIDTH-1:0][0:1];
logic we_A [0:1] = '{'0, '0};
logic we_B [0:1] = '{'0, '0};
logic unsigned [CONST::MEM_ADDR_WIDTH:0] addr_A [0:1] = '{'0, '0};
logic unsigned [CONST::MEM_ADDR_WIDTH:0] addr_B [0:1] = '{'0, '0};
sample_t dataIn_A [0:1] = '{'0, '0};
sample_t dataIn_B [0:1] = '{'0, '0};
sample_t dataOut_A [0:1];// = '{'0, '0};
sample_t dataOut_B [0:1];// = '{'0, '0};
genvar g;
generate
for (g = 0; g < 2; g++) begin : buffInst
  (* keep_hierarchy = "yes" *)
  tdpRam buff_0(
    .clka(clk),
    .clkb(clk),
    .wea(we_A[g]),
    .web(we_B[g]),
    .addra(addr_A[g][CONST::MEM_ADDR_WIDTH-1:0]),
    .addrb(addr_B[g][CONST::MEM_ADDR_WIDTH-1:0]),
    .dia(dataIn_A[g]),
    .dib(dataIn_B[g]),
    .doa(dataOut_A[g]),
    .dob(dataOut_B[g])
  );
end
endgenerate


////////////////////////////////////////////////////////////////////
//  
//  eg. s = 4, i = 1 (group of 4)
//  l m r h 
//  G H E F C D A B O P M N K L I J
//
//  eg. s = 4, i = 1 (group of 4)
//          l m r h 
//  E F G H C D A B O P M N K L I J
//
//  eg. s = 4, i = 1 (group of 4)
//                  l m r h 
//  G H E F A B C D B O P M N K L I J
//
//  eg. s = 4, i = 1 (group of 4)
//                          l m r h 
//  E F G H A B C D M N O P K L I J
//
//  eg. s = 8, i = 0 (next level - group of 8)
//  l     m r     h
//  E F G H A B C D M N O P I J K L
//
//  eg. s = 8, i = 8
//                  l     m r     h
//  A B C D E F G H M N O P I J K L
//
// def mySort(arr):
//
//     pong = arr
//     n = 0
// 
//     N = len(arr)
//    
//     s = 2
//     while s/2 <= N:
//         ping = pong
//         pong = []
//         i = 0
//         j = 0
//         while j < N:
//             l = i
//             r = i + s//2
//             m = r - 1
//             h = i + s - 1
//             if h > N-1:
//                 h = N-1
//             while j <= h:
//                 if r > h:
//                     pong.append(ping[l])
//                     l += 1
//                 elif l > m:
//                     pong.append(ping[r])
//                     r += 1
//                 elif ping[r] < ping[l]:
//                     pong.append(ping[r])
//                     r += 1
//                 else:
//                     pong.append(ping[l])
//                     l += 1
//                 j += 1
//             i += s
//         s *= 2
//     return pong
// 
////////////////////////////////////////////////////////////////////
always_ff @(posedge clk) begin : mainFsm

  static logic unsigned [CONST::MEM_ADDR_WIDTH:0] s = 0;
  static logic unsigned p = 0; // ping pong index
  static logic unsigned [CONST::MEM_ADDR_WIDTH:0] i = '0, j = '0;
  static logic unsigned [CONST::MEM_ADDR_WIDTH:0] m = '0, h = '0;
  static logic unsigned [2:0] step = '0;
  static logic unsigned [CONST::MEM_ADDR_WIDTH:0] samplesCount;
  static logic unsigned [CONST::MEM_ADDR_WIDTH:0] numSamples;
  static sample_t previousSample;
  typedef enum {IDLE, READ, NODE, LEVEL, LAST} fsm_t;
  static fsm_t currentState = IDLE;

  case (currentState)

    IDLE: begin
      inputSamples.ready <= 0;
      outputSamples.valid <= 0;
      outputSamples.first <= 0;
      outputSamples.last <= 0;
      outputSamples.data <= '0;
      if (inputSamples.first && inputSamples.valid == 1) begin
        inputSamples.ready <= 1;
        samplesCount <= '0;
        step <= 0;
        currentState <= READ;
      end
    end

    // Store samples from the input IF on a ping pong buffer
    // Sort groups of 2 samples (e.g BADC => ABCD) before storing them (first mergesort level with group size s = 2)
    READ: begin
      if (inputSamples.valid == 1) begin
        samplesCount <= samplesCount + 1;
        dataIn_A[p] <= inputSamples.data;
        dataIn_B[p] <= dataIn_A[p];
        if (inputSamples.last == 1'b1 && samplesCount[0] == 1'b1) begin // last sample received and number of samples is even
          if (inputSamples.data >= dataIn_A[p]) begin // sort the two samples by switching the addresses
            addr_A[p] <= samplesCount;
            addr_B[p] <= samplesCount - 1;
          end else begin
            addr_A[p] <= samplesCount - 1;
            addr_B[p] <= samplesCount;
          end
          we_A[p] <= 1;
          we_B[p] <= 1;
        end else if (inputSamples.last == 1'b1 && samplesCount[0] == 1'b0) begin // last sample received and number of samples is odd
          addr_A[p] <= samplesCount;
          we_A[p] <= 1;
          we_B[p] <= 0;
        end else if (inputSamples.last == 1'b0 && samplesCount[0] == 1'b1) begin // even number of samples received
          if (inputSamples.data >= dataIn_A[p]) begin // sort the two samples by switching the addresses
            addr_A[p] <= samplesCount;
            addr_B[p] <= samplesCount - 1;
          end else begin
            addr_A[p] <= samplesCount - 1;
            addr_B[p] <= samplesCount;
          end
          we_A[p] <= 1;
          we_B[p] <= 1;
        end else if (inputSamples.last == 1'b0 && samplesCount[0] == 1'b0) begin // odd number of samples received
          we_A[p] <= 0;
          we_B[p] <= 0;
        end
        if (inputSamples.last == 1) begin // last sample received
          inputSamples.ready <= 0;
          numSamples <= samplesCount + 1;
          if (CFG::DBG_PRINT)
            $display("numSamples: %0d", samplesCount + 1);
          s <= 4;
          currentState <= NODE;
        end
      end
    end

    NODE: begin
      we_A[p] <= 0; // deassert 'we' from previous state
      we_B[p] <= 0;
      p <= ~p; // swap ping pomng buffers
      j <= 0;
      i <= 0;
      addr_A[p] <= 0; // l = i
      addr_B[p] <= 0 + (s >> 1); // r = i + s//2
      m <= 0 + (s >> 1) - 1; // m = r - 1
      if (s >= numSamples) begin // jump to last level if number of samples <= 4
        h <= numSamples - 1; // h = numSamples
        step <= 0;
        currentState <= LAST;
      end else begin
        if ((0 + s - 1) > numSamples - 1) // h = less(i + s - 1, numSamples-1)
          h <= numSamples - 1;
        else
          h <= 0 + s - 1;
        step <= 0;
        currentState <= LEVEL;
      end
    end

    LEVEL: begin
      if (step == 0) begin // BRAM latency
        step <= 1;
      end else if (step == 1) begin // BRAM latency
        step <= 2;
      end else if (step == 2) begin
        if (addr_B[~p] > h) begin
          dataIn_A[p] <= dataOut_A[~p];
          addr_A[~p] <= addr_A[~p] + 1;
        end else if (addr_A[~p] > m) begin
          dataIn_A[p] <= dataOut_B[~p];
          addr_B[~p] <= addr_B[~p] + 1;
        end else if (dataOut_B[~p] < dataOut_A[~p]) begin
          dataIn_A[p] <= dataOut_B[~p];
          addr_B[~p] <= addr_B[~p] + 1;
        end else begin
          dataIn_A[p] <= dataOut_A[~p];
          addr_A[~p] <= addr_A[~p] + 1;
        end
        addr_A[p] <= j;
        we_A[p] <= 1;
        j <= j + 1;
        step <= 3;
        if (CFG::DBG_PRINT)
          $display("s:%0d i:%0d j:%0d | l:%0d r:%0d m:%0d h:%0d", s, i, j, addr_A[~p], addr_B[~p], m, h);
      end else if (step == 3) begin
        we_A[p] <= 0;
        if (j > h) begin // group is sorted
          if (j >= numSamples) begin // move to next mergesort level
            s <= s << 1;
            currentState <= NODE;
          end else begin // move to the next group in the same level
            i <= i + s;
            addr_A[~p] <= i + s; // l = i
            addr_B[~p] <= i + s + (s >> 1); // r = i + s//2
            m <= i + s + (s >> 1) - 1; // m = r - 1
            if ((i + s + s - 1) > numSamples - 1) // h = less(i + s - 1, numSamples-1)
              h <= numSamples - 1;
            else
              h <= i + s + s - 1;
            step <= 0;
          end
        end else begin
          step <= 0;
        end
      end
    end

    // last level is similar to the intermediate ones (LEVEL state) but samples are 
    // sent to the output IF instead of being written to the ping pong buffer
    LAST: begin
      if (step == 0) begin// BRAM latency
        step <= 1;
      end else if (step == 1) begin // BRAM latency
        step <= 2;
      end else if (step == 2) begin
        if (j == 0)
          outputSamples.first <= 1;
        if (j == h)
          outputSamples.last <= 1;
        outputSamples.valid <= 1;
        if (addr_B[~p] > h) begin
          outputSamples.data <= dataOut_A[~p];
          addr_A[~p] <= addr_A[~p] + 1;
        end else if (addr_A[~p] > m) begin
          outputSamples.data <= dataOut_B[~p];
          addr_B[~p] <= addr_B[~p] + 1;
        end else if (dataOut_B[~p] < dataOut_A[~p]) begin
          outputSamples.data <= dataOut_B[~p];
          addr_B[~p] <= addr_B[~p] + 1;
        end else begin
          outputSamples.data <= dataOut_A[~p];
          addr_A[~p] <= addr_A[~p] + 1;
        end
        j <= j + 1;
        step <= 3;
        if (CFG::DBG_PRINT)
          $display("s:%0d i:%0d j:%0d | l:%0d r:%0d m:%0d h:%0d", s, i, j, addr_A[~p], addr_B[~p], m, h);
      end else if (step == 3) begin
        if (outputSamples.ready == 1) begin
          if (CFG::DBG_PRINT)
            $display("sample out transmitted: %0d", outputSamples.data);
          outputSamples.valid <= 0;
          outputSamples.first <= 0;
          outputSamples.last <= 0;
          if (j > h) begin
            currentState <= IDLE; // deassert 'valid' and 'last' first thing in the next state
            step <= 0;
          end else begin
            step <= 0;
          end
        end
      end
    end

    default: begin
      currentState <= IDLE;
    end
  endcase
end : mainFsm

endmodule
