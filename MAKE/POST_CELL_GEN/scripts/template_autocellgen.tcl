set_vdd -type primary VDD $VDD
set_gnd -type primary VSS 0
set_gnd -no_model GND 0

set_var slew_lower_rise 0.2
set_var slew_lower_fall 0.2
set_var slew_upper_rise 0.5
set_var slew_upper_fall 0.5

set_var measure_slew_lower_rise 0.2
set_var measure_slew_lower_fall 0.2
set_var measure_slew_upper_rise 0.5
set_var measure_slew_upper_fall 0.5

set_var delay_inp_rise 0.35
set_var delay_inp_fall 0.35
set_var delay_out_rise 0.35
set_var delay_out_fall 0.35

set_var def_arc_msg_level 0
set_var process_match_pins_to_ports 1
set_var min_transition $MIN_TRAN
set_var max_transition $MAX_TRAN
set_var min_output_cap $MIN_OUT_CAP

set inv_x1_pin_cap $INV_X1_PIN_CAP
if {[info exists env(AUTOCHAR_SMOKE)] && $env(AUTOCHAR_SMOKE) eq "1"} {
  set cap_idx_coef_list [list 2.0 8.0]
  set max_tran_list [list 0.010 0.080]
} else {
  set cap_idx_coef_list [list 2.0 4.0 8.0 16.0 24.0 32.0 45.0]
  set max_tran_list [list 0.005 0.010 0.020 0.040 0.080 0.160 0.320]
}

set cap_idx_list [list]
foreach c $cap_idx_coef_list {
  lappend cap_idx_list [format %.9f [expr $inv_x1_pin_cap * $c]]
}

define_template -type delay -index_2 $cap_idx_list -index_1 $max_tran_list delay_template
define_template -type power -index_2 $cap_idx_list -index_1 $max_tran_list power_template
define_template -type constraint -index_2 $cap_idx_list -index_1 $max_tran_list const_template

source ${RUN_DIR}/libchar/cells.tcl

set_pin_vdd -supply_name VDD $cells {*}
set_pin_gnd -supply_name VSS $cells {*}

foreach cell $cells {
  if {![ALAPI_active_cell $cell]} {
    continue
  }

  set info_file "${RUN_DIR}/cell_info/${cell}.info"
  if {![file exists $info_file]} {
    puts "WARNING: No info file found for ${cell}; skipping define_cell"
    continue
  }

  set info_in [open ${info_file} "r"]
  set info_lines [split [read $info_in] "\n"]
  close $info_in

  set input_line [string trim [lindex $info_lines 1]]
  set output_line [string trim [lindex $info_lines 2]]
  set input_pins [expr {$input_line eq "" ? {} : [split $input_line " "]}]
  set output_pins [expr {$output_line eq "" ? {} : [split $output_line " "]}]
  set pinlist [concat $input_pins $output_pins]

  if {[llength $input_pins] == 0 || [llength $output_pins] == 0} {
    puts "WARNING: Incomplete pin info for ${cell}; skipping define_cell"
    continue
  }

  puts "INFO: Auto define_cell for ${cell} with inputs {$input_pins} and outputs {$output_pins}"
  define_cell \
   -input $input_pins \
   -output $output_pins \
   -pinlist $pinlist \
   -delay delay_template \
   -power power_template \
   $cell
}
