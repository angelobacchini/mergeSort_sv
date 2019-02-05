# mergeSort_sv

synthesizable System Verilog implementation of bottom-up merge sort.

https://www.youtube.com/watch?v=lOUe8Q9jQow

## interface

Top level module "sorter" provides 2 handshake based streaming interfaces for input samples (module act as a slave) and sorted output samples (module acts as a master). Handshake rules mimic the AXI4 stream specs:
* a transfer occurs when both VALID (master driven) and READY (slave driven) are asserted
* master does not have to wait until READY is asserted before asserting VALID, but once VALID is raised it must remain up until READY is asserted by the slave
* FIRST and LAST are strobed by the master to signal the first and last sample in the packet. They are valid only if VALID is asserted at the same time.

## architecture

The implementation replicates the following code:
```python
def mySort(arr):

    pong = arr
    n = 0
    
    N = len(arr)
    
    s = 2
    while s/2 <= N:
        ping = pong
        pong = []
        i = 0
        j = 0
        while j < N:
            l = i
            r = i + s//2
            m = r - 1
            h = i + s - 1
            if h > N-1:
                h = N-1
            while j <= h:
                if r > h:
                    pong.append(ping[l])
                    l += 1
                elif l > m:
                    pong.append(ping[r])
                    r += 1
                elif ping[r] < ping[l]:
                    pong.append(ping[r])
                    r += 1
                else:
                    pong.append(ping[l])
                    l += 1
                j += 1
            i += s
        s *= 2
    return pong
```

* The ping-pong buffers are implemented in block memories
* The first level of sorting (sorting groups of two) is performed while reading samples from the input interface: every two read samples, the pair is written to the block memory in a sorted order
* Samples are provided to the output interface in last level of sorting (no writing on the block memory occurs)
* Implementation supports a variable lenght of input samples (from 1 to MAX_NUM_SAMPLES defined in global.svh). The core can automatically detect the number of samples to sort from the FIRST and LAST signal on the input interface.

## testbench

A self-checking tb is included in tb.sv:
* NUM_RUNS (defined in global.svh) packets are generated and transmitted to the core. Each packet has a random length from 1 to MAX_NUM_SAMPLES
* The tb will check if the output packets sent by the core are sorted (output is compared with output from System Verilog array.sort() method)
