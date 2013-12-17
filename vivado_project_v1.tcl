
# Project Batch-Mode Build Script

# Get Environment Variables
set XDC_FILES        $::env(XDC_FILES)
set RTL_FILES        $::env(RTL_FILES)
set SIM_FILES        $::env(SIM_FILES)
set CORE_FILES       $::env(CORE_FILES)
set PRJ_PART         $::env(PRJ_PART)
set PROJECT          $::env(PROJECT)
set OUT_DIR          $::env(OUT_DIR)
set VIVADO_DIR       $::env(VIVADO_DIR)
set VIVADO_PROJECT   $::env(VIVADO_PROJECT)
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)

# Load Custom Procedures
source -quiet ${VIVADO_BUILD_DIR}/vivado_proc_v1.tcl

# Create a Project
create_project ${VIVADO_PROJECT} -force ${OUT_DIR} -part ${PRJ_PART}

# Add RTL Source Files
add_files -fileset sources_1 ${RTL_FILES}

# Add Simulation Source Files
add_files -fileset sim_1 ${SIM_FILES}

# Add Core Files
if { ${CORE_FILES} != "" } {

   # add the IP Cores
   add_files -fileset sources_1 ${CORE_FILES}

   # Force Absolute Path (not relative to project)
   set_property PATH_MODE AbsoluteOnly [get_files ${CORE_FILES}]
   
}

# Add XDC FILES
add_files -fileset constrs_1 ${XDC_FILES}
set_property PATH_MODE AbsoluteOnly [get_files ${XDC_FILES}]

# Set the Top Level 
set_property top ${PROJECT} [current_fileset]

# Set VHDL as preferred language
set_property target_language VHDL [current_project]

# Disable Xilinx's WebTalk
config_webtalk -user off

# Message Filtering Script
source -quiet ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl

# Enable implementation steps by default
set_property STEPS.POWER_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.POST_PLACE_POWER_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1] 

# Setup pre and post scripts for synthesis
set_property STEPS.SYNTH_DESIGN.TCL.PRE  ${VIVADO_BUILD_DIR}/vivado_pre_synthesis_v1.tcl [get_runs synth_1]

# Setup pre and post scripts for implementation
set_property STEPS.OPT_DESIGN.TCL.PRE                  ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl [get_runs impl_1]
set_property STEPS.POWER_OPT_DESIGN.TCL.PRE            ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl [get_runs impl_1]
set_property STEPS.PLACE_DESIGN.TCL.PRE                ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl [get_runs impl_1]
set_property STEPS.POST_PLACE_POWER_OPT_DESIGN.TCL.PRE ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.TCL.PRE             ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl [get_runs impl_1]
set_property STEPS.ROUTE_DESIGN.TCL.PRE                ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl [get_runs impl_1]
set_property STEPS.WRITE_BITSTREAM.TCL.PRE             ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl [get_runs impl_1]

# Close/Open the project required for setting NEEDS_REFRESH=0 for ${corePntr}_synth_1
close_project
open_project -quiet ${VIVADO_PROJECT}

# Generate all IP cores' output files
generate_target -force all [get_ips]
if { [get_ips] != "" } {
   foreach corePntr [get_ips] {
   
      # Build the IP Core
      create_ip_run [get_ips ${corePntr}]
      puts "\nBuilding ${corePntr}.xci IP Core ..."
      launch_runs -quiet [get_runs ${corePntr}_synth_1]
      wait_on_run -quiet ${corePntr}_synth_1
      puts "... Build Complete!\n"
      
      # Disable the IP Core's XDC (so it doesn't get implemented at the project level)
      set xdcPntr [get_files -of_objects [get_files ${corePntr}.xci] -filter {FILE_TYPE == XDC}]
      set_property is_enabled false [get_files ${xdcPntr}]
      
      # IP Core thinks it needs refreshing because PATH_MODE changed from RelativeOnly to AbsoluteOnly
      set_property NEEDS_REFRESH false [get_runs ${corePntr}_synth_1]
      
   }
}

# Target specific project setup script
source ${VIVADO_DIR}/project_setup.tcl

# Close the project
close_project