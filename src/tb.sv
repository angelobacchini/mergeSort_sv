`include "global.svh"

class readFile;

  int fd;
  string line = "";
  int val = 0;

  function automatic new(string _fileName);
    fd = $fopen(_fileName, "r");
    line = "";
    if (fd == 0) begin
      $display("not found");
      $finish;
    end
  endfunction

  function automatic int restart();
    int err = $fseek(fd, 0, 0);
    return err;
  endfunction

  function automatic string getLine();
    if (!$feof(fd)) begin
      int err = $fscanf(fd, "%s\n", line);
    end
    return line;
  endfunction

  function automatic int getInt();
    if (!$feof(fd)) begin
      int err = $fscanf(fd, "%d\n", val);
    end
    return val;
  endfunction 

endclass


module tb;
timeunit 1ns;
timeprecision 1ns;
import TYPES::*;

  function automatic int checkSort(ref samplesQueue_t _samples, sample_t _inputArray[]);
    automatic sample_t previous = 0;
    automatic sample_t next = 0;
    automatic sample_t expected = 0;
    automatic int i = 0;
    automatic int sorted = 1;

    _inputArray.sort();
    while (_samples.size() > 0) begin
      next = _samples.pop_back();
      expected = _inputArray[i++];
      if (CFG::DBG_PRINT)
        $display("got: %0d expected: %0d", next, _inputArray[i]);
      if (next < previous)
        sorted = 2;
      if (next !== expected) begin
        sorted = 3;
      end
      previous = next;
    end
    return sorted;
  endfunction

  function automatic void printArray(sample_t _inputArray[]);
    string str;
    for (int i = 0; i < _inputArray.size(); i++) begin
      str = {str, $sformatf("%0d ", _inputArray[i])};
    end
    $display(str);
  endfunction

  logic clk;
  logic start;
  sample_t inputArray[];
  int unsigned numSamples;
  samplesQueue_t outFifo;
  readFile myFile;
  event sortComplete;

  samples_if # (
    .DATA_WIDTH(CONST::DATA_WIDTH)
  ) inputSamples (
  );

  samples_if # (
    .DATA_WIDTH(CONST::DATA_WIDTH)
  ) outputSamples (
  );

  sorter mySorter(
    .clk(clk),
    .inputSamples(inputSamples),
    .outputSamples(outputSamples)
  );


  //
  initial begin : p_clk
    clk = 0;
    forever #(CONST::PERIOD/2) clk = ~clk;
  end : p_clk


  // 
  always_ff @(posedge clk) begin : p_inputSamples
    static int i = 0;
    typedef enum {IDLE, RUN} fsm_t;
    static fsm_t currentState = IDLE;

    case (currentState)
      IDLE: begin
        if (start) begin
          inputSamples.valid <= 1;
          inputSamples.data = inputArray[0];
          inputSamples.first <= 1;
          if (i == numSamples - 1)
            inputSamples.last <= 1;
          i <= i + 1;
          currentState <= RUN;
        end else begin
          inputSamples.valid <= 0;
          inputSamples.first <= 0;
          inputSamples.last <= 0;
          i <= 0;
        end
      end
      RUN: begin
        if (inputSamples.ready) begin
          inputSamples.first <= 0;
          inputSamples.data <= inputArray[i]; // pitch next sample if sink acknowledged
          if (i == numSamples - 1) begin
            i <= i + 1;
            inputSamples.last <= 1;
          end else if (i == numSamples) begin
            i <= 0;
            inputSamples.valid <= 0;
            inputSamples.last <= 0;
            currentState <= IDLE; // set 'valid' and 'last' to 0 first thing in the next state
          end else begin
            i <= i + 1;
          end
        end
      end
    endcase
  end : p_inputSamples


  // 
  always_ff @(posedge clk) begin : p_outputSamplesCheck
    outputSamples.ready <= 1;
    if (outputSamples.valid) begin
      if (CFG::DBG_PRINT)
        $display("sample out: %0d", outputSamples.data);
      outFifo.push_front(outputSamples.data);
      if (outputSamples.last) begin
        -> sortComplete;
      end
    end
  end : p_outputSamplesCheck


  //
  initial begin : p_main
    automatic int errors = 0;
    automatic time startTime;
    automatic int sorted = 0;
    myFile = new("myFile.txt");
    start = 0;
    numSamples = 0;
    #100;
    for (int i = 0; i < CFG::NUM_RUNS; i++) begin
      numSamples = $urandom_range(CONST::MIN_NUM_SAMPLES, CONST::MAX_NUM_SAMPLES);
      inputArray = new[numSamples];
      for (int j = 0; j < numSamples; j++) begin
        if (CFG::FROM_FILE)
          inputArray[j] = myFile.getInt();
        else
          inputArray[j] = $urandom_range(0, 2**CONST::DATA_WIDTH-1);
      end
      if (CFG::DBG_PRINT)
        printArray(inputArray);
      if (myFile.restart())
        $display("File error when resetting pointer");
      startTime = $time;
      @(posedge clk) start = 1;
      @(posedge clk) start = 0;
      @sortComplete;
      sorted = checkSort(outFifo, inputArray);
      if (sorted != 1) begin
        errors++;
        $display("ERROR: output is not sorted!");
        $stop;
      end else begin
        automatic int clockCycles = $floor(($time - startTime)/CONST::PERIOD);
        $display ("Sorted %0d samples in %0t ns (%0d clock cycles). clockCycles/Nlog2(N) = %.3f", numSamples, $time - startTime, clockCycles, clockCycles/(numSamples*($ln(numSamples)/$ln(2))));
      end
      inputArray.delete;
      $display("-----------");
    end
    $display("%0d runs completed. %0d errors.", CFG::NUM_RUNS, errors );
    $stop;
  end : p_main

endmodule