set _part xcku3p-ffva676-2-e
set _top sorter

read_verilog -sv ./src/interfaces.sv
read_verilog -sv ./src/sorter.sv

synth_design -part $_part -top $_top

create_clock -name clk -period 2.0 [get_ports clk]

write_verilog postSynth.v -force

opt_design -verbose
place_design -verbose

report_qor_suggestion -output_dir suggestions

phys_opt_design -verbose
route_design -verbose