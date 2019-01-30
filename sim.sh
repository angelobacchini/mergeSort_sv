
#!/bin/sh

# lots of issue in xsim system verilog dynamic types support...
# if [ "$1" == "xsim" ]; then 
#     xvlog -sv ./src/*.sv
#     xelab tb -s tb -debug all -timescale 1ns/1ns
#     xsim tb -R
# else
    vlog +acc=npr ./src/*.sv
    vsim work.tb -c -do "run -all"
# fi
