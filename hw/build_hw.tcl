#*****************************************************************************************
# Vivado (TM) v2025.2 (64-bit)
# build_hw.tcl: Tcl script for re-creating project 'nes_SoC'
# (Cleaned and made Portable for Git Version Control)
#*****************************************************************************************

# Check file required for this script exists
proc checkRequiredFiles { origin_dir} {
  set status true
  set files [list \
 "[file normalize "$origin_dir/src/mig/board.prj"]"\
 "[file normalize "$origin_dir/src/mig/mig_a.prj"]"\
 "[file normalize "$origin_dir/src/ip/memory_arbiter_0.xci"]"\
 "[file normalize "$origin_dir/../sw/bootloader/console_bootloader.elf"]"\
 "[file normalize "$origin_dir/src/mig/mig_b.prj"]"\
 "[file normalize "$origin_dir/src/bd/nes_SoC.bd"]"\
 "[file normalize "$origin_dir/src/nes_SoC_wrapper.dcp"]"\
  ]
  foreach ifile $files {
    if { ![file isfile $ifile] } {
      puts " Could not find local file $ifile "
      set status false
    }
  }

  set files [list \
 "[file normalize "$origin_dir/assets/mario_demo_rom.coe"]"\
 "[file normalize "$origin_dir/assets/mario_palette_rom.coe"]"\
 "[file normalize "$origin_dir/assets/font_rom.coe"]"\
 "[file normalize "$origin_dir/constraints/Nexys-A7-100T-Master.xdc"]"\
  ]
  foreach ifile $files {
    if { ![file isfile $ifile] } {
      puts " Could not find remote file $ifile "
      set status false
    }
  }

  set paths [list \
 "[file normalize "$origin_dir/../ip_repo"]"\
  ]
  foreach ipath $paths {
    if { ![file isdirectory $ipath] } {
      puts " Could not access $ipath "
      set status false
    }
  }

  return $status
}
# Set the reference directory for source file relative paths (by default the value is script directory path)
set origin_dir "."

# Use origin directory path location variable, if specified in the tcl shell
if { [info exists ::origin_dir_loc] } {
  set origin_dir $::origin_dir_loc
}

# Set the project name
set _xil_proj_name_ "nes_SoC"

# Use project name variable, if specified in the tcl shell
if { [info exists ::user_project_name] } {
  set _xil_proj_name_ $::user_project_name
}

variable script_file
set script_file "build_hw.tcl"

# Create project
create_project -force ${_xil_proj_name_} ./${_xil_proj_name_} -part xc7a100tcsg324-1

# Set the directory path for the new project
set proj_dir [get_property directory [current_project]]

# Set project properties
set obj [current_project]
set_property -name "board_part" -value "digilentinc.com:nexys-a7-100t:part0:1.3" -objects $obj
set_property -name "default_lib" -value "xil_defaultlib" -objects $obj
set_property -name "enable_resource_estimation" -value "0" -objects $obj
set_property -name "enable_vhdl_2008" -value "1" -objects $obj
set_property -name "ip_cache_permissions" -value "read write" -objects $obj
set_property -name "ip_output_repo" -value "$proj_dir/${_xil_proj_name_}.cache/ip" -objects $obj
set_property -name "mem.enable_memory_map_generation" -value "1" -objects $obj
set_property -name "platform.board_id" -value "nexys-a7-100t" -objects $obj
set_property -name "revised_directory_structure" -value "1" -objects $obj
set_property -name "sim.central_dir" -value "$proj_dir/${_xil_proj_name_}.ip_user_files" -objects $obj
set_property -name "sim.ip.auto_export_scripts" -value "1" -objects $obj
set_property -name "simulator_language" -value "Mixed" -objects $obj
set_property -name "sim_compile_state" -value "1" -objects $obj
set_property -name "target_language" -value "VHDL" -objects $obj
set_property -name "use_inline_hdl_ip" -value "1" -objects $obj
set_property -name "xpm_libraries" -value "XPM_CDC XPM_FIFO XPM_MEMORY" -objects $obj

# Create 'sources_1' fileset (if not found)
if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}

# Set IP repository paths (Points to new ip_repo folder)
set obj [get_filesets sources_1]
if { $obj != {} } {
   set_property "ip_repo_paths" "[file normalize "$origin_dir/../ip_repo"]" $obj
   update_ip_catalog -rebuild
}

# Add Remote/Asset Files
set obj [get_filesets sources_1]
set files [list \
 [file normalize "${origin_dir}/assets/mario_demo_rom.coe"] \
 [file normalize "${origin_dir}/assets/mario_palette_rom.coe"] \
 [file normalize "${origin_dir}/assets/font_rom.coe"] \
]
add_files -norecurse -fileset $obj $files

# Add Local Source Files (Exclude the .bd file)
set files [list \
 [file normalize "${origin_dir}/src/mig/board.prj" ]\
 [file normalize "${origin_dir}/src/mig/mig_a.prj" ]\
 [file normalize "${origin_dir}/src/ip/memory_arbiter_0.xci" ]\
 [file normalize "${origin_dir}/../sw/bootloader/console_bootloader.elf" ]\
 [file normalize "${origin_dir}/src/mig/mig_b.prj" ]\
]
set added_files [add_files -fileset sources_1 $files]

# Recreate the Block Design from script
source ${origin_dir}/bd_recreate.tcl

# Auto-generate wrapper file for the newly created BD
set wrapper_path [make_wrapper -fileset sources_1 -files [ get_files -norecurse nes_SoC.bd] -top]
add_files -norecurse -fileset sources_1 $wrapper_path

# Set scoped properties for MIG and ELF files
set file "mig/board.prj"
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
set_property -name "scoped_to_cells" -value "nes_SoC_mig_7series_0_0" -objects $file_obj

set file "mig/board.prj"
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
set_property -name "scoped_to_cells" -value "nes_SoC_mig_7series_0_2" -objects $file_obj

set file "mig/mig_a.prj"
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
set_property -name "scoped_to_cells" -value "nes_SoC_mig_7series_0_2" -objects $file_obj

set file "memory_arbiter_0.xci"
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
set_property -name "generate_files_for_reference" -value "0" -objects $file_obj
set_property -name "registered_with_manager" -value "1" -objects $file_obj
if { ![get_property "is_locked" $file_obj] } {
  set_property -name "synth_checkpoint_mode" -value "Singular" -objects $file_obj
}

set file "console_bootloader.elf"
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
set_property -name "used_in" -value "implementation" -objects $file_obj
set_property -name "used_in_simulation" -value "0" -objects $file_obj

set file "mig/mig_b.prj"
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
set_property -name "scoped_to_cells" -value "nes_SoC_mig_7series_0_2" -objects $file_obj

set file "nes_SoC.bd"
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
set_property -name "registered_with_manager" -value "1" -objects $file_obj

# Set Top Module
set obj [get_filesets sources_1]
set_property -name "top" -value "nes_SoC_wrapper" -objects $obj

# Add Constraints
if {[string equal [get_filesets -quiet constrs_1] ""]} {
  create_fileset -constrset constrs_1
}
set obj [get_filesets constrs_1]
set file "[file normalize "$origin_dir/constraints/Nexys-A7-100T-Master.xdc"]"
set file_added [add_files -norecurse -fileset $obj [list $file]]
set file_obj [get_files -of_objects [get_filesets constrs_1] [list "*Nexys-A7-100T-Master.xdc"]]
set_property -name "file_type" -value "XDC" -objects $file_obj

# Add Utility / Incremental Checkpoints
set obj [get_filesets utils_1]
set files [list \
 [file normalize "${origin_dir}/src/nes_SoC_wrapper.dcp" ]\
]
set added_files [add_files -fileset utils_1 $files]
set file "nes_SoC_wrapper.dcp"
set file_obj [get_files -of_objects [get_filesets utils_1] [list "*$file"]]
set_property -name "netlist_only" -value "0" -objects $file_obj

# Setup Synth Run
if {[string equal [get_runs -quiet synth_1] ""]} {
    create_run -name synth_1 -part xc7a100tcsg324-1 -flow {Vivado Synthesis 2025} -strategy "Vivado Synthesis Defaults" -report_strategy {No Reports} -constrset constrs_1
} else {
  set_property strategy "Vivado Synthesis Defaults" [get_runs synth_1]
  set_property flow "Vivado Synthesis 2025" [get_runs synth_1]
}
set obj [get_runs synth_1]
set_property -name "incremental_checkpoint" -value "[file normalize "$origin_dir/src/nes_SoC_wrapper.dcp"]" -objects $obj
set_property -name "auto_incremental_checkpoint" -value "1" -objects $obj
current_run -synthesis [get_runs synth_1]

# Setup Impl Run
if {[string equal [get_runs -quiet impl_1] ""]} {
    create_run -name impl_1 -part xc7a100tcsg324-1 -flow {Vivado Implementation 2025} -strategy "Vivado Implementation Defaults" -report_strategy {No Reports} -constrset constrs_1 -parent_run synth_1
} else {
  set_property strategy "Vivado Implementation Defaults" [get_runs impl_1]
  set_property flow "Vivado Implementation 2025" [get_runs impl_1]
}
current_run -implementation [get_runs impl_1]

puts "INFO: Project created:${_xil_proj_name_}"
