
################################################################
# This is a generated script based on design: nes_SoC
#
# Though there are limitations about the generated script,
# the main purpose of this utility is to make learning
# IP Integrator Tcl commands easier.
################################################################

namespace eval _tcl {
proc get_script_folder {} {
   set script_path [file normalize [info script]]
   set script_folder [file dirname $script_path]
   return $script_folder
}
}
variable script_folder
set script_folder [_tcl::get_script_folder]

################################################################
# Check if script is running in correct Vivado version.
################################################################
set scripts_vivado_version 2025.2
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
   puts ""
   if { [string compare $scripts_vivado_version $current_vivado_version] > 0 } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2042 -severity "ERROR" " This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Sourcing the script failed since it was created with a future version of Vivado."}

   } else {
     catch {common::send_gid_msg -ssname BD::TCL -id 2041 -severity "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_bd_tcl to create an updated script."}

   }

   return 1
}

################################################################
# START
################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source nes_SoC_script.tcl

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xc7a100tcsg324-1
   set_property BOARD_PART digilentinc.com:nexys-a7-100t:part0:1.3 [current_project]
}


# CHANGE DESIGN NAME HERE
variable design_name
set design_name nes_SoC

# If you do not already have an existing IP Integrator design open,
# you can create a design using the following command:
#    create_bd_design $design_name

# Creating design if needed
set errMsg ""
set nRet 0

set cur_design [current_bd_design -quiet]
set list_cells [get_bd_cells -quiet]

if { ${design_name} eq "" } {
   # USE CASES:
   #    1) Design_name not set

   set errMsg "Please set the variable <design_name> to a non-empty value."
   set nRet 1

} elseif { ${cur_design} ne "" && ${list_cells} eq "" } {
   # USE CASES:
   #    2): Current design opened AND is empty AND names same.
   #    3): Current design opened AND is empty AND names diff; design_name NOT in project.
   #    4): Current design opened AND is empty AND names diff; design_name exists in project.

   if { $cur_design ne $design_name } {
      common::send_gid_msg -ssname BD::TCL -id 2001 -severity "INFO" "Changing value of <design_name> from <$design_name> to <$cur_design> since current design is empty."
      set design_name [get_property NAME $cur_design]
   }
   common::send_gid_msg -ssname BD::TCL -id 2002 -severity "INFO" "Constructing design in IPI design <$cur_design>..."

} elseif { ${cur_design} ne "" && $list_cells ne "" && $cur_design eq $design_name } {
   # USE CASES:
   #    5) Current design opened AND has components AND same names.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 1
} elseif { [get_files -quiet ${design_name}.bd] ne "" } {
   # USE CASES: 
   #    6) Current opened design, has components, but diff names, design_name exists in project.
   #    7) No opened design, design_name exists in project.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 2

} else {
   # USE CASES:
   #    8) No opened design, design_name not in project.
   #    9) Current opened design, has components, but diff names, design_name not in project.

   common::send_gid_msg -ssname BD::TCL -id 2003 -severity "INFO" "Currently there is no design <$design_name> in project, so creating one..."

   create_bd_design $design_name

   common::send_gid_msg -ssname BD::TCL -id 2004 -severity "INFO" "Making design <$design_name> as current_bd_design."
   current_bd_design $design_name

}

common::send_gid_msg -ssname BD::TCL -id 2005 -severity "INFO" "Currently the variable <design_name> is equal to \"$design_name\"."

if { $nRet != 0 } {
   catch {common::send_gid_msg -ssname BD::TCL -id 2006 -severity "ERROR" $errMsg}
   return $nRet
}

set bCheckIPsPassed 1
##################################################################
# CHECK IPs
##################################################################
set bCheckIPs 1
if { $bCheckIPs == 1 } {
   set list_check_ips "\ 
user.org:user:key_mapper:1.0\
user.org:user:axi_lite_slave:1.0\
xilinx.com:ip:clk_wiz:6.0\
xilinx.com:ip:blk_mem_gen:8.4\
xilinx.com:ip:proc_sys_reset:5.0\
xilinx.com:ip:microblaze:11.0\
xilinx.com:ip:smartconnect:1.0\
xilinx.com:ip:axi_intc:4.1\
xilinx.com:ip:mdm:3.2\
user.org:user:sprite_renderer:1.0\
xilinx.com:ip:xlconstant:1.1\
xilinx.com:ip:axi_timer:2.0\
xilinx.com:ip:xlconcat:2.1\
user.org:user:apu_engine:1.0\
xilinx.com:ip:mig_7series:4.2\
xilinx.com:ip:axi_dma:7.1\
xilinx.com:ip:axi_uartlite:2.0\
xilinx.com:ip:axi_quad_spi:3.2\
user.org:user:memory_arbiter:1.0\
xilinx.com:ip:system_ila:1.1\
xilinx.com:ip:axis_data_fifo:2.0\
xilinx.com:ip:axis_dwidth_converter:1.1\
user.org:user:udp_ip:1.0\
user.org:user:gatekeeper:1.0\
xilinx.com:ip:lmb_v10:3.0\
xilinx.com:ip:lmb_bram_if_cntlr:4.0\
"

   set list_ips_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2011 -severity "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

   foreach ip_vlnv $list_check_ips {
      set ip_obj [get_ipdefs -all $ip_vlnv]
      if { $ip_obj eq "" } {
         lappend list_ips_missing $ip_vlnv
      }
   }

   if { $list_ips_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2012 -severity "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
      set bCheckIPsPassed 0
   }

}

if { $bCheckIPsPassed != 1 } {
  common::send_gid_msg -ssname BD::TCL -id 2023 -severity "WARNING" "Will not continue with creation of design due to the error(s) above."
  return 3
}


##################################################################
# MIG PRJ FILE TCL PROCs
##################################################################

proc write_mig_file_nes_SoC_mig_7series_0_2 { str_mig_prj_filepath } {

   file mkdir [ file dirname "$str_mig_prj_filepath" ]
   set mig_prj_file [open $str_mig_prj_filepath  w+]

   puts $mig_prj_file {﻿<?xml version="1.0" encoding="UTF-8" standalone="no" ?>}
   puts $mig_prj_file {<Project NoOfControllers="1">}
   puts $mig_prj_file {  }
   puts $mig_prj_file {<!-- IMPORTANT: This is an internal file that has been generated by the MIG software. Any direct editing or changes made to this file may result in unpredictable behavior or data corruption. It is strongly advised that users do not edit the contents of this file. Re-run the MIG GUI with the required settings if any of the options provided below need to be altered. -->}
   puts $mig_prj_file {  <ModuleName>nes_SoC_mig_7series_0_2</ModuleName>}
   puts $mig_prj_file {  <dci_inouts_inputs>1</dci_inouts_inputs>}
   puts $mig_prj_file {  <dci_inputs>1</dci_inputs>}
   puts $mig_prj_file {  <Debug_En>OFF</Debug_En>}
   puts $mig_prj_file {  <DataDepth_En>1024</DataDepth_En>}
   puts $mig_prj_file {  <LowPower_En>ON</LowPower_En>}
   puts $mig_prj_file {  <XADC_En>Enabled</XADC_En>}
   puts $mig_prj_file {  <TargetFPGA>xc7a100t-csg324/-1</TargetFPGA>}
   puts $mig_prj_file {  <Version>4.2</Version>}
   puts $mig_prj_file {  <SystemClock>No Buffer</SystemClock>}
   puts $mig_prj_file {  <ReferenceClock>No Buffer</ReferenceClock>}
   puts $mig_prj_file {  <SysResetPolarity>ACTIVE LOW</SysResetPolarity>}
   puts $mig_prj_file {  <BankSelectionFlag>FALSE</BankSelectionFlag>}
   puts $mig_prj_file {  <InternalVref>1</InternalVref>}
   puts $mig_prj_file {  <dci_hr_inouts_inputs>50 Ohms</dci_hr_inouts_inputs>}
   puts $mig_prj_file {  <dci_cascade>0</dci_cascade>}
   puts $mig_prj_file {  <FPGADevice>}
   puts $mig_prj_file {    <selected>7a/xc7a50t-csg324</selected>}
   puts $mig_prj_file {  </FPGADevice>}
   puts $mig_prj_file {  <Controller number="0">}
   puts $mig_prj_file {    <MemoryDevice>DDR2_SDRAM/Components/MT47H64M16HR-25E</MemoryDevice>}
   puts $mig_prj_file {    <TimePeriod>3077</TimePeriod>}
   puts $mig_prj_file {    <VccAuxIO>1.8V</VccAuxIO>}
   puts $mig_prj_file {    <PHYRatio>4:1</PHYRatio>}
   puts $mig_prj_file {    <InputClkFreq>99.997</InputClkFreq>}
   puts $mig_prj_file {    <UIExtraClocks>1</UIExtraClocks>}
   puts $mig_prj_file {    <MMCM_VCO>1200</MMCM_VCO>}
   puts $mig_prj_file {    <MMCMClkOut0> 6.000</MMCMClkOut0>}
   puts $mig_prj_file {    <MMCMClkOut1>1</MMCMClkOut1>}
   puts $mig_prj_file {    <MMCMClkOut2>1</MMCMClkOut2>}
   puts $mig_prj_file {    <MMCMClkOut3>1</MMCMClkOut3>}
   puts $mig_prj_file {    <MMCMClkOut4>1</MMCMClkOut4>}
   puts $mig_prj_file {    <DataWidth>16</DataWidth>}
   puts $mig_prj_file {    <DeepMemory>1</DeepMemory>}
   puts $mig_prj_file {    <DataMask>1</DataMask>}
   puts $mig_prj_file {    <ECC>Disabled</ECC>}
   puts $mig_prj_file {    <Ordering>Strict</Ordering>}
   puts $mig_prj_file {    <BankMachineCnt>4</BankMachineCnt>}
   puts $mig_prj_file {    <CustomPart>FALSE</CustomPart>}
   puts $mig_prj_file {    <NewPartName/>}
   puts $mig_prj_file {    <RowAddress>13</RowAddress>}
   puts $mig_prj_file {    <ColAddress>10</ColAddress>}
   puts $mig_prj_file {    <BankAddress>3</BankAddress>}
   puts $mig_prj_file {    <C0_MEM_SIZE>134217728</C0_MEM_SIZE>}
   puts $mig_prj_file {    <UserMemoryAddressMap>BANK_ROW_COLUMN</UserMemoryAddressMap>}
   puts $mig_prj_file {    <PinSelection>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="M4" SLEW="" VCCAUX_IO="" name="ddr2_addr[0]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="R2" SLEW="" VCCAUX_IO="" name="ddr2_addr[10]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="K5" SLEW="" VCCAUX_IO="" name="ddr2_addr[11]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="N6" SLEW="" VCCAUX_IO="" name="ddr2_addr[12]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="P4" SLEW="" VCCAUX_IO="" name="ddr2_addr[1]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="M6" SLEW="" VCCAUX_IO="" name="ddr2_addr[2]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="T1" SLEW="" VCCAUX_IO="" name="ddr2_addr[3]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="L3" SLEW="" VCCAUX_IO="" name="ddr2_addr[4]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="P5" SLEW="" VCCAUX_IO="" name="ddr2_addr[5]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="M2" SLEW="" VCCAUX_IO="" name="ddr2_addr[6]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="N1" SLEW="" VCCAUX_IO="" name="ddr2_addr[7]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="L4" SLEW="" VCCAUX_IO="" name="ddr2_addr[8]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="N5" SLEW="" VCCAUX_IO="" name="ddr2_addr[9]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="P2" SLEW="" VCCAUX_IO="" name="ddr2_ba[0]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="P3" SLEW="" VCCAUX_IO="" name="ddr2_ba[1]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="R1" SLEW="" VCCAUX_IO="" name="ddr2_ba[2]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="L1" SLEW="" VCCAUX_IO="" name="ddr2_cas_n"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="DIFF_SSTL18_II" PADName="L5" SLEW="" VCCAUX_IO="" name="ddr2_ck_n[0]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="DIFF_SSTL18_II" PADName="L6" SLEW="" VCCAUX_IO="" name="ddr2_ck_p[0]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="M1" SLEW="" VCCAUX_IO="" name="ddr2_cke[0]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="K6" SLEW="" VCCAUX_IO="" name="ddr2_cs_n[0]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="T6" SLEW="" VCCAUX_IO="" name="ddr2_dm[0]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="U1" SLEW="" VCCAUX_IO="" name="ddr2_dm[1]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="R7" SLEW="" VCCAUX_IO="" name="ddr2_dq[0]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="V5" SLEW="" VCCAUX_IO="" name="ddr2_dq[10]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="U4" SLEW="" VCCAUX_IO="" name="ddr2_dq[11]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="V4" SLEW="" VCCAUX_IO="" name="ddr2_dq[12]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="T4" SLEW="" VCCAUX_IO="" name="ddr2_dq[13]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="V1" SLEW="" VCCAUX_IO="" name="ddr2_dq[14]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="T3" SLEW="" VCCAUX_IO="" name="ddr2_dq[15]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="V6" SLEW="" VCCAUX_IO="" name="ddr2_dq[1]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="R8" SLEW="" VCCAUX_IO="" name="ddr2_dq[2]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="U7" SLEW="" VCCAUX_IO="" name="ddr2_dq[3]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="V7" SLEW="" VCCAUX_IO="" name="ddr2_dq[4]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="R6" SLEW="" VCCAUX_IO="" name="ddr2_dq[5]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="U6" SLEW="" VCCAUX_IO="" name="ddr2_dq[6]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="R5" SLEW="" VCCAUX_IO="" name="ddr2_dq[7]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="T5" SLEW="" VCCAUX_IO="" name="ddr2_dq[8]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="U3" SLEW="" VCCAUX_IO="" name="ddr2_dq[9]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="DIFF_SSTL18_II" PADName="V9" SLEW="" VCCAUX_IO="" name="ddr2_dqs_n[0]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="DIFF_SSTL18_II" PADName="V2" SLEW="" VCCAUX_IO="" name="ddr2_dqs_n[1]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="DIFF_SSTL18_II" PADName="U9" SLEW="" VCCAUX_IO="" name="ddr2_dqs_p[0]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="DIFF_SSTL18_II" PADName="U2" SLEW="" VCCAUX_IO="" name="ddr2_dqs_p[1]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="M3" SLEW="" VCCAUX_IO="" name="ddr2_odt[0]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="N4" SLEW="" VCCAUX_IO="" name="ddr2_ras_n"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL18_II" PADName="N2" SLEW="" VCCAUX_IO="" name="ddr2_we_n"/>}
   puts $mig_prj_file {    </PinSelection>}
   puts $mig_prj_file {    <System_Control>}
   puts $mig_prj_file {      <Pin Bank="Select Bank" PADName="No connect" name="sys_rst"/>}
   puts $mig_prj_file {      <Pin Bank="Select Bank" PADName="No connect" name="init_calib_complete"/>}
   puts $mig_prj_file {      <Pin Bank="Select Bank" PADName="No connect" name="tg_compare_error"/>}
   puts $mig_prj_file {    </System_Control>}
   puts $mig_prj_file {    <TimingParameters>}
   puts $mig_prj_file {      <Parameters tfaw="45" tras="40" trcd="15" trefi="7.8" trfc="127.5" trp="12.5" trrd="10" trtp="7.5" twtr="7.5"/>}
   puts $mig_prj_file {    </TimingParameters>}
   puts $mig_prj_file {    <mrBurstLength name="Burst Length">8</mrBurstLength>}
   puts $mig_prj_file {    <mrBurstType name="Burst Type">Sequential</mrBurstType>}
   puts $mig_prj_file {    <mrCasLatency name="CAS Latency">5</mrCasLatency>}
   puts $mig_prj_file {    <mrMode name="Mode">Normal</mrMode>}
   puts $mig_prj_file {    <mrDllReset name="DLL Reset">No</mrDllReset>}
   puts $mig_prj_file {    <mrPdMode name="PD Mode">Fast exit</mrPdMode>}
   puts $mig_prj_file {    <mrWriteRecovery name="Write Recovery">5</mrWriteRecovery>}
   puts $mig_prj_file {    <emrDllEnable name="DLL Enable">Enable-Normal</emrDllEnable>}
   puts $mig_prj_file {    <emrOutputDriveStrength name="Output Drive Strength">Fullstrength</emrOutputDriveStrength>}
   puts $mig_prj_file {    <emrCSSelection name="Controller Chip Select Pin">Enable</emrCSSelection>}
   puts $mig_prj_file {    <emrCKSelection name="Memory Clock Selection">1</emrCKSelection>}
   puts $mig_prj_file {    <emrRTT name="RTT (nominal) - ODT">50ohms</emrRTT>}
   puts $mig_prj_file {    <emrPosted name="Additive Latency (AL)">0</emrPosted>}
   puts $mig_prj_file {    <emrOCD name="OCD Operation">OCD Exit</emrOCD>}
   puts $mig_prj_file {    <emrDQS name="DQS# Enable">Enable</emrDQS>}
   puts $mig_prj_file {    <emrRDQS name="RDQS Enable">Disable</emrRDQS>}
   puts $mig_prj_file {    <emrOutputs name="Outputs">Enable</emrOutputs>}
   puts $mig_prj_file {    <PortInterface>AXI</PortInterface>}
   puts $mig_prj_file {    <AXIParameters>}
   puts $mig_prj_file {      <C0_C_RD_WR_ARB_ALGORITHM>RD_PRI_REG</C0_C_RD_WR_ARB_ALGORITHM>}
   puts $mig_prj_file {      <C0_S_AXI_ADDR_WIDTH>27</C0_S_AXI_ADDR_WIDTH>}
   puts $mig_prj_file {      <C0_S_AXI_DATA_WIDTH>128</C0_S_AXI_DATA_WIDTH>}
   puts $mig_prj_file {      <C0_S_AXI_ID_WIDTH>4</C0_S_AXI_ID_WIDTH>}
   puts $mig_prj_file {      <C0_S_AXI_SUPPORTS_NARROW_BURST>0</C0_S_AXI_SUPPORTS_NARROW_BURST>}
   puts $mig_prj_file {    </AXIParameters>}
   puts $mig_prj_file {  </Controller>}
   puts $mig_prj_file {</Project>}

   close $mig_prj_file
}
# End of write_mig_file_nes_SoC_mig_7series_0_2()



##################################################################
# DESIGN PROCs
##################################################################


# Hierarchical cell: microblaze_0_local_memory
proc create_hier_cell_microblaze_0_local_memory { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_microblaze_0_local_memory() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode MirroredMaster -vlnv xilinx.com:interface:lmb_rtl:1.0 DLMB

  create_bd_intf_pin -mode MirroredMaster -vlnv xilinx.com:interface:lmb_rtl:1.0 ILMB


  # Create pins
  create_bd_pin -dir I -type clk LMB_Clk
  create_bd_pin -dir I -type rst SYS_Rst

  # Create instance: dlmb_v10, and set properties
  set dlmb_v10 [ create_bd_cell -type ip -vlnv xilinx.com:ip:lmb_v10:3.0 dlmb_v10 ]

  # Create instance: ilmb_v10, and set properties
  set ilmb_v10 [ create_bd_cell -type ip -vlnv xilinx.com:ip:lmb_v10:3.0 ilmb_v10 ]

  # Create instance: dlmb_bram_if_cntlr, and set properties
  set dlmb_bram_if_cntlr [ create_bd_cell -type ip -vlnv xilinx.com:ip:lmb_bram_if_cntlr:4.0 dlmb_bram_if_cntlr ]
  set_property CONFIG.C_ECC {0} $dlmb_bram_if_cntlr


  # Create instance: ilmb_bram_if_cntlr, and set properties
  set ilmb_bram_if_cntlr [ create_bd_cell -type ip -vlnv xilinx.com:ip:lmb_bram_if_cntlr:4.0 ilmb_bram_if_cntlr ]
  set_property CONFIG.C_ECC {0} $ilmb_bram_if_cntlr


  # Create instance: lmb_bram, and set properties
  set lmb_bram [ create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 lmb_bram ]
  set_property -dict [list \
    CONFIG.Memory_Type {True_Dual_Port_RAM} \
    CONFIG.use_bram_block {BRAM_Controller} \
  ] $lmb_bram


  # Create interface connections
  connect_bd_intf_net -intf_net microblaze_0_dlmb [get_bd_intf_pins dlmb_v10/LMB_M] [get_bd_intf_pins DLMB]
  connect_bd_intf_net -intf_net microblaze_0_dlmb_bus [get_bd_intf_pins dlmb_v10/LMB_Sl_0] [get_bd_intf_pins dlmb_bram_if_cntlr/SLMB]
  connect_bd_intf_net -intf_net microblaze_0_dlmb_cntlr [get_bd_intf_pins dlmb_bram_if_cntlr/BRAM_PORT] [get_bd_intf_pins lmb_bram/BRAM_PORTA]
  connect_bd_intf_net -intf_net microblaze_0_ilmb [get_bd_intf_pins ilmb_v10/LMB_M] [get_bd_intf_pins ILMB]
  connect_bd_intf_net -intf_net microblaze_0_ilmb_bus [get_bd_intf_pins ilmb_v10/LMB_Sl_0] [get_bd_intf_pins ilmb_bram_if_cntlr/SLMB]
  connect_bd_intf_net -intf_net microblaze_0_ilmb_cntlr [get_bd_intf_pins ilmb_bram_if_cntlr/BRAM_PORT] [get_bd_intf_pins lmb_bram/BRAM_PORTB]

  # Create port connections
  connect_bd_net -net SYS_Rst_1  [get_bd_pins SYS_Rst] \
  [get_bd_pins dlmb_v10/SYS_Rst] \
  [get_bd_pins dlmb_bram_if_cntlr/LMB_Rst] \
  [get_bd_pins ilmb_v10/SYS_Rst] \
  [get_bd_pins ilmb_bram_if_cntlr/LMB_Rst]
  connect_bd_net -net microblaze_0_Clk  [get_bd_pins LMB_Clk] \
  [get_bd_pins dlmb_v10/LMB_Clk] \
  [get_bd_pins dlmb_bram_if_cntlr/LMB_Clk] \
  [get_bd_pins ilmb_v10/LMB_Clk] \
  [get_bd_pins ilmb_bram_if_cntlr/LMB_Clk]

  # Restore current instance
  current_bd_instance $oldCurInst
}


# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell } {

  variable script_folder
  variable design_name

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj


  # Create interface ports
  set ddr2_sdram_0 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddrx_rtl:1.0 ddr2_sdram_0 ]

  set usb_uart [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:uart_rtl:1.0 usb_uart ]

  set spi_rtl [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:spi_rtl:1.0 spi_rtl ]

  set qspi_flash [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:spi_rtl:1.0 qspi_flash ]


  # Create ports
  set clk_100MHz [ create_bd_port -dir I -type clk -freq_hz 100000000 clk_100MHz ]
  set CPU_RESETN [ create_bd_port -dir I -type rst CPU_RESETN ]
  set_property -dict [ list \
   CONFIG.POLARITY {ACTIVE_LOW} \
 ] $CPU_RESETN
  set PS2_CLK [ create_bd_port -dir I PS2_CLK ]
  set PS2_DATA [ create_bd_port -dir I PS2_DATA ]
  set VGA_B [ create_bd_port -dir O -from 3 -to 0 VGA_B ]
  set VGA_R [ create_bd_port -dir O -from 3 -to 0 VGA_R ]
  set VGA_VS [ create_bd_port -dir O VGA_VS ]
  set VGA_G [ create_bd_port -dir O -from 3 -to 0 VGA_G ]
  set VGA_HS [ create_bd_port -dir O VGA_HS ]
  set AUD_PWM [ create_bd_port -dir O AUD_PWM ]
  set AUD_SD [ create_bd_port -dir O AUD_SD ]
  set DDR2_calib_complete [ create_bd_port -dir O DDR2_calib_complete ]
  set SD_RESET [ create_bd_port -dir O -from 0 -to 0 -type rst SD_RESET ]
  set ETH_REFCLK [ create_bd_port -dir O ETH_REFCLK ]
  set ETH_RSTN [ create_bd_port -dir O -type rst ETH_RSTN ]
  set ETH_TXEN [ create_bd_port -dir O ETH_TXEN ]
  set ETH_TXD [ create_bd_port -dir O -from 1 -to 0 ETH_TXD ]
  set ETH_CRSDV [ create_bd_port -dir I ETH_CRSDV ]
  set ETH_RXERR [ create_bd_port -dir I ETH_RXERR ]
  set ETH_RXD [ create_bd_port -dir I -from 1 -to 0 ETH_RXD ]

  # Create instance: key_mapper_0, and set properties
  set key_mapper_0 [ create_bd_cell -type ip -vlnv user.org:user:key_mapper:1.0 key_mapper_0 ]

  # Create instance: axi_lite_slave_0, and set properties
  set axi_lite_slave_0 [ create_bd_cell -type ip -vlnv user.org:user:axi_lite_slave:1.0 axi_lite_slave_0 ]

  # Create instance: clk_wiz_0, and set properties
  set clk_wiz_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0 ]
  set_property -dict [list \
    CONFIG.CLKOUT1_DRIVES {BUFG} \
    CONFIG.CLKOUT1_JITTER {130.958} \
    CONFIG.CLKOUT1_PHASE_ERROR {98.575} \
    CONFIG.CLKOUT2_DRIVES {BUFG} \
    CONFIG.CLKOUT2_JITTER {175.402} \
    CONFIG.CLKOUT2_PHASE_ERROR {98.575} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {25} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT3_DRIVES {BUFG} \
    CONFIG.CLKOUT3_JITTER {114.829} \
    CONFIG.CLKOUT3_PHASE_ERROR {98.575} \
    CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {200} \
    CONFIG.CLKOUT3_USED {true} \
    CONFIG.CLKOUT4_DRIVES {BUFG} \
    CONFIG.CLKOUT4_JITTER {151.636} \
    CONFIG.CLKOUT4_PHASE_ERROR {98.575} \
    CONFIG.CLKOUT4_REQUESTED_OUT_FREQ {50} \
    CONFIG.CLKOUT4_USED {true} \
    CONFIG.CLKOUT5_DRIVES {BUFG} \
    CONFIG.CLKOUT5_JITTER {151.636} \
    CONFIG.CLKOUT5_PHASE_ERROR {98.575} \
    CONFIG.CLKOUT5_REQUESTED_OUT_FREQ {50} \
    CONFIG.CLKOUT5_REQUESTED_PHASE {45} \
    CONFIG.CLKOUT5_USED {true} \
    CONFIG.CLKOUT6_DRIVES {BUFG} \
    CONFIG.CLKOUT7_DRIVES {BUFG} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {10.000} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {10.000} \
    CONFIG.MMCM_CLKOUT1_DIVIDE {40} \
    CONFIG.MMCM_CLKOUT2_DIVIDE {5} \
    CONFIG.MMCM_CLKOUT3_DIVIDE {20} \
    CONFIG.MMCM_CLKOUT4_DIVIDE {20} \
    CONFIG.MMCM_CLKOUT4_PHASE {45.000} \
    CONFIG.NUM_OUT_CLKS {5} \
    CONFIG.RESET_BOARD_INTERFACE {reset} \
    CONFIG.RESET_PORT {resetn} \
    CONFIG.RESET_TYPE {ACTIVE_LOW} \
    CONFIG.SECONDARY_SOURCE {Single_ended_clock_capable_pin} \
    CONFIG.USE_BOARD_FLOW {true} \
    CONFIG.USE_PHASE_ALIGNMENT {true} \
  ] $clk_wiz_0


  # Create instance: sprite_memory, and set properties
  set sprite_memory [ create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 sprite_memory ]
  set_property -dict [list \
    CONFIG.Assume_Synchronous_Clk {false} \
    CONFIG.Load_Init_File {false} \
    CONFIG.Memory_Type {True_Dual_Port_RAM} \
    CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
    CONFIG.Register_PortB_Output_of_Memory_Primitives {false} \
    CONFIG.Write_Depth_A {65536} \
    CONFIG.Write_Width_A {8} \
    CONFIG.use_bram_block {Stand_Alone} \
  ] $sprite_memory


  # Create instance: rst_clk_wiz_0_100M, and set properties
  set rst_clk_wiz_0_100M [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_clk_wiz_0_100M ]
  set_property -dict [list \
    CONFIG.RESET_BOARD_INTERFACE {reset} \
    CONFIG.USE_BOARD_FLOW {true} \
  ] $rst_clk_wiz_0_100M


  # Create instance: microblaze_0, and set properties
  set microblaze_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:microblaze:11.0 microblaze_0 ]
  set_property -dict [list \
    CONFIG.C_AREA_OPTIMIZED {0} \
    CONFIG.C_CACHE_BYTE_SIZE {8192} \
    CONFIG.C_DCACHE_BASEADDR {0x0000000088000000} \
    CONFIG.C_DCACHE_BYTE_SIZE {8192} \
    CONFIG.C_DCACHE_FORCE_TAG_LUTRAM {1} \
    CONFIG.C_DCACHE_HIGHADDR {0x000000008FFFFFFF} \
    CONFIG.C_DEBUG_ENABLED {1} \
    CONFIG.C_D_AXI {1} \
    CONFIG.C_D_LMB {1} \
    CONFIG.C_ENABLE_CONVERSION {0} \
    CONFIG.C_ICACHE_BASEADDR {0x0000000088000000} \
    CONFIG.C_ICACHE_FORCE_TAG_LUTRAM {1} \
    CONFIG.C_ICACHE_HIGHADDR {0x000000008FFFFFFF} \
    CONFIG.C_I_LMB {1} \
    CONFIG.C_USE_BARREL {1} \
    CONFIG.C_USE_DCACHE {1} \
    CONFIG.C_USE_ICACHE {1} \
    CONFIG.G_TEMPLATE_LIST {8} \
  ] $microblaze_0


  # Create instance: microblaze_0_local_memory
  create_hier_cell_microblaze_0_local_memory [current_bd_instance .] microblaze_0_local_memory

  # Create instance: microblaze_0_axi_periph, and set properties
  set microblaze_0_axi_periph [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 microblaze_0_axi_periph ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {2} \
    CONFIG.NUM_MI {8} \
    CONFIG.NUM_SI {5} \
  ] $microblaze_0_axi_periph


  # Create instance: microblaze_0_axi_intc, and set properties
  set microblaze_0_axi_intc [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_intc:4.1 microblaze_0_axi_intc ]
  set_property CONFIG.C_HAS_FAST {1} $microblaze_0_axi_intc


  # Create instance: mdm_1, and set properties
  set mdm_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:mdm:3.2 mdm_1 ]

  # Create instance: sprite_renderer_0, and set properties
  set sprite_renderer_0 [ create_bd_cell -type ip -vlnv user.org:user:sprite_renderer:1.0 sprite_renderer_0 ]

  # Create instance: xlconstant_0, and set properties
  set xlconstant_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0 ]
  set_property CONFIG.CONST_VAL {0} $xlconstant_0


  # Create instance: axi_timer_0, and set properties
  set axi_timer_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_timer:2.0 axi_timer_0 ]

  # Create instance: xlconcat_0, and set properties
  set xlconcat_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0 ]
  set_property CONFIG.NUM_PORTS {4} $xlconcat_0


  # Create instance: apu_engine_0, and set properties
  set apu_engine_0 [ create_bd_cell -type ip -vlnv user.org:user:apu_engine:1.0 apu_engine_0 ]

  # Create instance: mig_sys_reset, and set properties
  set mig_sys_reset [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 mig_sys_reset ]
  set_property -dict [list \
    CONFIG.RESET_BOARD_INTERFACE {Custom} \
    CONFIG.USE_BOARD_FLOW {true} \
  ] $mig_sys_reset


  # Create instance: mig_7series_0, and set properties
  set mig_7series_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:mig_7series:4.2 mig_7series_0 ]

  # Generate the PRJ File for MIG
  set str_mig_folder [get_property IP_DIR [ get_ips [ get_property CONFIG.Component_Name $mig_7series_0 ] ] ]
  set str_mig_file_name mig_b.prj
  set str_mig_file_path ${str_mig_folder}/${str_mig_file_name}
  write_mig_file_nes_SoC_mig_7series_0_2 $str_mig_file_path

  set_property -dict [list \
    CONFIG.BOARD_MIG_PARAM {ddr2_sdram} \
    CONFIG.MIG_DONT_TOUCH_PARAM {Custom} \
    CONFIG.RESET_BOARD_INTERFACE {Custom} \
    CONFIG.XML_INPUT_FILE {mig_b.prj} \
  ] $mig_7series_0


  # Create instance: font_memory, and set properties
  set font_memory [ create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 font_memory ]
  set_property -dict [list \
    CONFIG.Coe_File "${script_folder}/assets/font_rom.coe" \
    CONFIG.Load_Init_File {true} \
    CONFIG.Memory_Type {True_Dual_Port_RAM} \
    CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
    CONFIG.Register_PortB_Output_of_Memory_Primitives {false} \
    CONFIG.Write_Depth_A {512} \
    CONFIG.Write_Width_A {8} \
    CONFIG.use_bram_block {Stand_Alone} \
  ] $font_memory


  # Create instance: axi_dma_0, and set properties
  set axi_dma_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0 ]
  set_property -dict [list \
    CONFIG.c_include_mm2s {1} \
    CONFIG.c_include_s2mm {1} \
    CONFIG.c_include_sg {0} \
    CONFIG.c_m_axi_s2mm_data_width {32} \
    CONFIG.c_s_axis_s2mm_tdata_width {32} \
    CONFIG.c_sg_length_width {26} \
  ] $axi_dma_0


  # Create instance: axi_uartlite_0, and set properties
  set axi_uartlite_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uartlite:2.0 axi_uartlite_0 ]
  set_property -dict [list \
    CONFIG.C_BAUDRATE {115200} \
    CONFIG.UARTLITE_BOARD_INTERFACE {usb_uart} \
    CONFIG.USE_BOARD_FLOW {true} \
  ] $axi_uartlite_0


  # Create instance: axi_quad_spi_0, and set properties
  set axi_quad_spi_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_quad_spi:3.2 axi_quad_spi_0 ]
  set_property -dict [list \
    CONFIG.C_SCK_RATIO {4} \
    CONFIG.C_USE_STARTUP {0} \
    CONFIG.Master_mode {1} \
    CONFIG.QSPI_BOARD_INTERFACE {Custom} \
    CONFIG.USE_BOARD_FLOW {true} \
  ] $axi_quad_spi_0


  # Create instance: memory_arbiter_0, and set properties
  set memory_arbiter_0 [ create_bd_cell -type ip -vlnv user.org:user:memory_arbiter:1.0 memory_arbiter_0 ]

  # Create instance: axi_quad_spi_1, and set properties
  set axi_quad_spi_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_quad_spi:3.2 axi_quad_spi_1 ]
  set_property -dict [list \
    CONFIG.QSPI_BOARD_INTERFACE {qspi_flash} \
    CONFIG.USE_BOARD_FLOW {true} \
  ] $axi_quad_spi_1


  # Create instance: proc_sys_reset_0, and set properties
  set proc_sys_reset_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0 ]
  set_property -dict [list \
    CONFIG.RESET_BOARD_INTERFACE {Custom} \
    CONFIG.USE_BOARD_FLOW {true} \
  ] $proc_sys_reset_0


  # Create instance: system_ila_0, and set properties
  set system_ila_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:system_ila:1.1 system_ila_0 ]
  set_property -dict [list \
    CONFIG.C_MON_TYPE {MIX} \
    CONFIG.C_NUM_MONITOR_SLOTS {1} \
    CONFIG.C_NUM_OF_PROBES {5} \
    CONFIG.C_PROBE0_WIDTH {2} \
    CONFIG.C_PROBE_WIDTH_PROPAGATION {MANUAL} \
    CONFIG.C_SLOT {0} \
    CONFIG.C_SLOT_0_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_1_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_2_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
  ] $system_ila_0


  # Create instance: axis_data_fifo_0, and set properties
  set axis_data_fifo_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 axis_data_fifo_0 ]
  set_property -dict [list \
    CONFIG.FIFO_DEPTH {32768} \
    CONFIG.FIFO_MEMORY_TYPE {block} \
    CONFIG.FIFO_MODE {2} \
    CONFIG.IS_ACLK_ASYNC {1} \
    CONFIG.TDATA_NUM_BYTES {1} \
  ] $axis_data_fifo_0


  # Create instance: axis_dwidth_converter_0, and set properties
  set axis_dwidth_converter_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_dwidth_converter:1.1 axis_dwidth_converter_0 ]
  set_property -dict [list \
    CONFIG.HAS_TLAST {1} \
    CONFIG.M_TDATA_NUM_BYTES {4} \
  ] $axis_dwidth_converter_0


  # Create instance: udp_ip_0, and set properties
  set udp_ip_0 [ create_bd_cell -type ip -vlnv user.org:user:udp_ip:1.0 udp_ip_0 ]

  # Create instance: axis_data_fifo_1, and set properties
  set axis_data_fifo_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 axis_data_fifo_1 ]
  set_property -dict [list \
    CONFIG.FIFO_DEPTH {128} \
    CONFIG.IS_ACLK_ASYNC {1} \
  ] $axis_data_fifo_1


  # Create instance: gatekeeper_0, and set properties
  set gatekeeper_0 [ create_bd_cell -type ip -vlnv user.org:user:gatekeeper:1.0 gatekeeper_0 ]

  # Create interface connections
  connect_bd_intf_net -intf_net axi_dma_0_M_AXI_MM2S [get_bd_intf_pins axi_dma_0/M_AXI_MM2S] [get_bd_intf_pins microblaze_0_axi_periph/S01_AXI]
  connect_bd_intf_net -intf_net axi_dma_0_M_AXI_S2MM [get_bd_intf_pins axi_dma_0/M_AXI_S2MM] [get_bd_intf_pins microblaze_0_axi_periph/S04_AXI]
  connect_bd_intf_net -intf_net axi_quad_spi_0_SPI_0 [get_bd_intf_ports spi_rtl] [get_bd_intf_pins axi_quad_spi_0/SPI_0]
  connect_bd_intf_net -intf_net axi_quad_spi_1_SPI_0 [get_bd_intf_ports qspi_flash] [get_bd_intf_pins axi_quad_spi_1/SPI_0]
  connect_bd_intf_net -intf_net axi_uartlite_0_UART [get_bd_intf_ports usb_uart] [get_bd_intf_pins axi_uartlite_0/UART]
  connect_bd_intf_net -intf_net axis_data_fifo_0_M_AXIS [get_bd_intf_pins axis_data_fifo_0/M_AXIS] [get_bd_intf_pins gatekeeper_0/s_axis]
  connect_bd_intf_net -intf_net axis_data_fifo_1_M_AXIS [get_bd_intf_pins axis_data_fifo_1/M_AXIS] [get_bd_intf_pins gatekeeper_0/s_meta]
  connect_bd_intf_net -intf_net axis_dwidth_converter_0_M_AXIS [get_bd_intf_pins axis_dwidth_converter_0/M_AXIS] [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM]
  connect_bd_intf_net -intf_net gatekeeper_0_m_axis [get_bd_intf_pins gatekeeper_0/m_axis] [get_bd_intf_pins axis_dwidth_converter_0/S_AXIS]
  connect_bd_intf_net -intf_net microblaze_0_M_AXI_DC [get_bd_intf_pins microblaze_0/M_AXI_DC] [get_bd_intf_pins microblaze_0_axi_periph/S02_AXI]
  connect_bd_intf_net -intf_net microblaze_0_M_AXI_IC [get_bd_intf_pins microblaze_0/M_AXI_IC] [get_bd_intf_pins microblaze_0_axi_periph/S03_AXI]
  connect_bd_intf_net -intf_net microblaze_0_axi_dp [get_bd_intf_pins microblaze_0_axi_periph/S00_AXI] [get_bd_intf_pins microblaze_0/M_AXI_DP]
  connect_bd_intf_net -intf_net microblaze_0_axi_periph_M01_AXI [get_bd_intf_pins microblaze_0_axi_periph/M01_AXI] [get_bd_intf_pins axi_lite_slave_0/s_axi]
  connect_bd_intf_net -intf_net microblaze_0_axi_periph_M02_AXI [get_bd_intf_pins microblaze_0_axi_periph/M02_AXI] [get_bd_intf_pins mig_7series_0/S_AXI]
  connect_bd_intf_net -intf_net microblaze_0_axi_periph_M03_AXI [get_bd_intf_pins microblaze_0_axi_periph/M03_AXI] [get_bd_intf_pins axi_timer_0/S_AXI]
  connect_bd_intf_net -intf_net microblaze_0_axi_periph_M04_AXI [get_bd_intf_pins microblaze_0_axi_periph/M04_AXI] [get_bd_intf_pins axi_dma_0/S_AXI_LITE]
  connect_bd_intf_net -intf_net microblaze_0_axi_periph_M05_AXI [get_bd_intf_pins microblaze_0_axi_periph/M05_AXI] [get_bd_intf_pins axi_uartlite_0/S_AXI]
  connect_bd_intf_net -intf_net microblaze_0_axi_periph_M06_AXI [get_bd_intf_pins microblaze_0_axi_periph/M06_AXI] [get_bd_intf_pins axi_quad_spi_0/AXI_LITE]
  connect_bd_intf_net -intf_net microblaze_0_axi_periph_M07_AXI [get_bd_intf_pins microblaze_0_axi_periph/M07_AXI] [get_bd_intf_pins axi_quad_spi_1/AXI_LITE]
  connect_bd_intf_net -intf_net microblaze_0_debug [get_bd_intf_pins mdm_1/MBDEBUG_0] [get_bd_intf_pins microblaze_0/DEBUG]
  connect_bd_intf_net -intf_net microblaze_0_dlmb_1 [get_bd_intf_pins microblaze_0/DLMB] [get_bd_intf_pins microblaze_0_local_memory/DLMB]
  connect_bd_intf_net -intf_net microblaze_0_ilmb_1 [get_bd_intf_pins microblaze_0/ILMB] [get_bd_intf_pins microblaze_0_local_memory/ILMB]
  connect_bd_intf_net -intf_net microblaze_0_intc_axi [get_bd_intf_pins microblaze_0_axi_periph/M00_AXI] [get_bd_intf_pins microblaze_0_axi_intc/s_axi]
  connect_bd_intf_net -intf_net microblaze_0_interrupt [get_bd_intf_pins microblaze_0_axi_intc/interrupt] [get_bd_intf_pins microblaze_0/INTERRUPT]
  connect_bd_intf_net -intf_net mig_7series_0_DDR2 [get_bd_intf_ports ddr2_sdram_0] [get_bd_intf_pins mig_7series_0/DDR2]

  # Create port connections
  connect_bd_net -net ETH_CRSDV_0_1  [get_bd_ports ETH_CRSDV] \
  [get_bd_pins system_ila_0/probe2] \
  [get_bd_pins udp_ip_0/ETH_CRSDV]
  connect_bd_net -net ETH_RXD_0_1  [get_bd_ports ETH_RXD] \
  [get_bd_pins system_ila_0/probe0] \
  [get_bd_pins udp_ip_0/ETH_RXD]
  connect_bd_net -net ETH_RXERR_0_1  [get_bd_ports ETH_RXERR] \
  [get_bd_pins system_ila_0/probe1] \
  [get_bd_pins udp_ip_0/ETH_RXERR]
  connect_bd_net -net PS2_CLK_0_1  [get_bd_ports PS2_CLK] \
  [get_bd_pins key_mapper_0/PS2_CLK]
  connect_bd_net -net PS2_DATA_0_1  [get_bd_ports PS2_DATA] \
  [get_bd_pins key_mapper_0/PS2_DATA]
  connect_bd_net -net apu_engine_0_AUD_PWM  [get_bd_pins apu_engine_0/AUD_PWM] \
  [get_bd_ports AUD_PWM]
  connect_bd_net -net apu_engine_0_AUD_SD  [get_bd_pins apu_engine_0/AUD_SD] \
  [get_bd_ports AUD_SD]
  connect_bd_net -net apu_engine_0_s_axis_apu_ready  [get_bd_pins apu_engine_0/s_axis_apu_ready] \
  [get_bd_pins axi_dma_0/m_axis_mm2s_tready]
  connect_bd_net -net axi_dma_0_m_axis_mm2s_tdata  [get_bd_pins axi_dma_0/m_axis_mm2s_tdata] \
  [get_bd_pins apu_engine_0/s_axis_apu_data]
  connect_bd_net -net axi_dma_0_m_axis_mm2s_tvalid  [get_bd_pins axi_dma_0/m_axis_mm2s_tvalid] \
  [get_bd_pins apu_engine_0/s_axis_apu_valid]
  connect_bd_net -net axi_dma_0_mm2s_introut  [get_bd_pins axi_dma_0/mm2s_introut] \
  [get_bd_pins xlconcat_0/In2]
  connect_bd_net -net axi_dma_0_mm2s_prmry_reset_out_n  [get_bd_pins axi_dma_0/mm2s_prmry_reset_out_n] \
  [get_bd_pins apu_engine_0/reset_n]
  connect_bd_net -net axi_dma_0_s2mm_introut  [get_bd_pins axi_dma_0/s2mm_introut] \
  [get_bd_pins xlconcat_0/In3] \
  [get_bd_pins system_ila_0/probe3]
  connect_bd_net -net axi_dma_0_s_axis_s2mm_tready  [get_bd_pins axis_data_fifo_0/s_axis_tready] \
  [get_bd_pins system_ila_0/SLOT_0_AXIS_tready]
  connect_bd_net -net axi_lite_slave_0_cpu_selector_o  [get_bd_pins axi_lite_slave_0/cpu_selector_o] \
  [get_bd_pins memory_arbiter_0/selector]
  connect_bd_net -net axi_lite_slave_0_hud_char_addr_o  [get_bd_pins axi_lite_slave_0/hud_char_addr_o] \
  [get_bd_pins sprite_renderer_0/hud_addr_a]
  connect_bd_net -net axi_lite_slave_0_hud_char_din_o  [get_bd_pins axi_lite_slave_0/hud_char_din_o] \
  [get_bd_pins sprite_renderer_0/hud_din_a]
  connect_bd_net -net axi_lite_slave_0_hud_char_we_o  [get_bd_pins axi_lite_slave_0/hud_char_we_o] \
  [get_bd_pins sprite_renderer_0/hud_we_a]
  connect_bd_net -net axi_lite_slave_0_oam_addr_o  [get_bd_pins axi_lite_slave_0/oam_addr_o] \
  [get_bd_pins sprite_renderer_0/oam_addr]
  connect_bd_net -net axi_lite_slave_0_oam_din_o  [get_bd_pins axi_lite_slave_0/oam_din_o] \
  [get_bd_pins sprite_renderer_0/oam_din]
  connect_bd_net -net axi_lite_slave_0_oam_we_o  [get_bd_pins axi_lite_slave_0/oam_we_o] \
  [get_bd_pins sprite_renderer_0/oam_we]
  connect_bd_net -net axi_lite_slave_0_ppu_irq  [get_bd_pins axi_lite_slave_0/ppu_irq] \
  [get_bd_pins xlconcat_0/In1]
  connect_bd_net -net axi_lite_slave_0_scroll_x_o  [get_bd_pins axi_lite_slave_0/scroll_x_o] \
  [get_bd_pins sprite_renderer_0/scroll_x]
  connect_bd_net -net axi_lite_slave_0_scroll_y_o  [get_bd_pins axi_lite_slave_0/scroll_y_o] \
  [get_bd_pins sprite_renderer_0/scroll_y]
  connect_bd_net -net axi_lite_slave_0_slv_reg5_data_o  [get_bd_pins axi_lite_slave_0/slv_reg5_data_o] \
  [get_bd_pins memory_arbiter_0/axi_wdata]
  connect_bd_net -net axi_lite_slave_0_slv_reg5_we_o  [get_bd_pins axi_lite_slave_0/slv_reg5_we_o] \
  [get_bd_pins memory_arbiter_0/axi_we]
  connect_bd_net -net axi_lite_slave_0_vram_addr_a_o  [get_bd_pins axi_lite_slave_0/vram_addr_a_o] \
  [get_bd_pins sprite_renderer_0/vram_addr_a]
  connect_bd_net -net axi_lite_slave_0_vram_din_a_o  [get_bd_pins axi_lite_slave_0/vram_din_a_o] \
  [get_bd_pins sprite_renderer_0/vram_din_a]
  connect_bd_net -net axi_lite_slave_0_vram_we_a_o  [get_bd_pins axi_lite_slave_0/vram_we_a_o] \
  [get_bd_pins sprite_renderer_0/vram_we_a]
  connect_bd_net -net axi_timer_0_interrupt  [get_bd_pins axi_timer_0/interrupt] \
  [get_bd_pins xlconcat_0/In0]
  connect_bd_net -net clk_100MHz_1  [get_bd_ports clk_100MHz] \
  [get_bd_pins clk_wiz_0/clk_in1]
  connect_bd_net -net clk_wiz_0_clk_out2  [get_bd_pins clk_wiz_0/clk_out2] \
  [get_bd_pins sprite_renderer_0/vga_read_clk]
  connect_bd_net -net clk_wiz_0_clk_out3  [get_bd_pins clk_wiz_0/clk_out3] \
  [get_bd_pins mig_7series_0/clk_ref_i]
  connect_bd_net -net clk_wiz_0_clk_out4  [get_bd_pins clk_wiz_0/clk_out4] \
  [get_bd_pins udp_ip_0/clk_ref_internal]
  connect_bd_net -net clk_wiz_0_clk_out5  [get_bd_pins clk_wiz_0/clk_out5] \
  [get_bd_pins proc_sys_reset_0/slowest_sync_clk] \
  [get_bd_pins axis_data_fifo_0/s_axis_aclk] \
  [get_bd_pins udp_ip_0/clk_skew_internal] \
  [get_bd_pins axis_data_fifo_1/s_axis_aclk]
  connect_bd_net -net clk_wiz_0_locked  [get_bd_pins clk_wiz_0/locked] \
  [get_bd_pins rst_clk_wiz_0_100M/dcm_locked] \
  [get_bd_pins proc_sys_reset_0/dcm_locked] \
  [get_bd_pins udp_ip_0/locked]
  connect_bd_net -net font_memory_douta  [get_bd_pins font_memory/douta] \
  [get_bd_pins sprite_renderer_0/font_ram_data]
  connect_bd_net -net key_mapper_0_FLAG_REG  [get_bd_pins key_mapper_0/FLAG_REG] \
  [get_bd_pins axi_lite_slave_0/key_flags_in]
  connect_bd_net -net mdm_1_debug_sys_rst  [get_bd_pins mdm_1/Debug_SYS_Rst] \
  [get_bd_pins rst_clk_wiz_0_100M/mb_debug_sys_rst]
  connect_bd_net -net memory_arbiter_0_bram_addr_a  [get_bd_pins memory_arbiter_0/bram_addr_a] \
  [get_bd_pins sprite_memory/addra]
  connect_bd_net -net memory_arbiter_0_bram_en_a  [get_bd_pins memory_arbiter_0/bram_en_a] \
  [get_bd_pins sprite_memory/ena]
  connect_bd_net -net memory_arbiter_0_bram_wdata_a  [get_bd_pins memory_arbiter_0/bram_wdata_a] \
  [get_bd_pins sprite_memory/dina]
  connect_bd_net -net memory_arbiter_0_bram_we_a  [get_bd_pins memory_arbiter_0/bram_we_a] \
  [get_bd_pins sprite_memory/wea]
  connect_bd_net -net memory_arbiter_0_ppu_bram_rdata  [get_bd_pins memory_arbiter_0/ppu_bram_rdata] \
  [get_bd_pins sprite_renderer_0/bram_data_a]
  connect_bd_net -net microblaze_0_Clk  [get_bd_pins clk_wiz_0/clk_out1] \
  [get_bd_pins key_mapper_0/CLK100MHZ] \
  [get_bd_pins microblaze_0/Clk] \
  [get_bd_pins microblaze_0_axi_periph/aclk] \
  [get_bd_pins microblaze_0_axi_intc/s_axi_aclk] \
  [get_bd_pins microblaze_0_axi_intc/processor_clk] \
  [get_bd_pins microblaze_0_local_memory/LMB_Clk] \
  [get_bd_pins rst_clk_wiz_0_100M/slowest_sync_clk] \
  [get_bd_pins axi_timer_0/s_axi_aclk] \
  [get_bd_pins mig_7series_0/sys_clk_i] \
  [get_bd_pins axi_dma_0/m_axi_mm2s_aclk] \
  [get_bd_pins axi_dma_0/s_axi_lite_aclk] \
  [get_bd_pins axi_uartlite_0/s_axi_aclk] \
  [get_bd_pins axi_quad_spi_0/s_axi_aclk] \
  [get_bd_pins axi_quad_spi_0/ext_spi_clk] \
  [get_bd_pins axi_lite_slave_0/s_axi_aclk] \
  [get_bd_pins memory_arbiter_0/clk100mhz] \
  [get_bd_pins sprite_renderer_0/mem_write_clk] \
  [get_bd_pins axi_quad_spi_1/s_axi_aclk] \
  [get_bd_pins axi_quad_spi_1/ext_spi_clk] \
  [get_bd_pins apu_engine_0/clk100Mhz] \
  [get_bd_pins axi_dma_0/m_axi_s2mm_aclk] \
  [get_bd_pins system_ila_0/clk] \
  [get_bd_pins axis_data_fifo_0/m_axis_aclk] \
  [get_bd_pins axis_dwidth_converter_0/aclk] \
  [get_bd_pins axis_data_fifo_1/m_axis_aclk] \
  [get_bd_pins gatekeeper_0/clk]
  connect_bd_net -net mig_7series_0_init_calib_complete  [get_bd_pins mig_7series_0/init_calib_complete] \
  [get_bd_ports DDR2_calib_complete]
  connect_bd_net -net mig_7series_0_mmcm_locked  [get_bd_pins mig_7series_0/mmcm_locked] \
  [get_bd_pins mig_sys_reset/dcm_locked]
  connect_bd_net -net mig_7series_0_ui_clk  [get_bd_pins mig_7series_0/ui_clk] \
  [get_bd_pins microblaze_0_axi_periph/aclk1] \
  [get_bd_pins mig_sys_reset/slowest_sync_clk]
  connect_bd_net -net mig_7series_0_ui_clk_sync_rst  [get_bd_pins mig_7series_0/ui_clk_sync_rst] \
  [get_bd_pins mig_sys_reset/ext_reset_in]
  connect_bd_net -net mig_sys_reset_peripheral_aresetn  [get_bd_pins mig_sys_reset/peripheral_aresetn] \
  [get_bd_pins mig_7series_0/aresetn]
  connect_bd_net -net proc_sys_reset_0_peripheral_aresetn  [get_bd_pins proc_sys_reset_0/peripheral_aresetn] \
  [get_bd_pins axis_data_fifo_0/s_axis_aresetn] \
  [get_bd_pins udp_ip_0/resetn] \
  [get_bd_pins axis_data_fifo_1/s_axis_aresetn]
  connect_bd_net -net reset_rtl_0_1  [get_bd_ports CPU_RESETN] \
  [get_bd_pins rst_clk_wiz_0_100M/ext_reset_in] \
  [get_bd_pins clk_wiz_0/resetn] \
  [get_bd_pins mig_7series_0/sys_rst] \
  [get_bd_pins proc_sys_reset_0/ext_reset_in]
  connect_bd_net -net rst_clk_wiz_0_100M_bus_struct_reset  [get_bd_pins rst_clk_wiz_0_100M/bus_struct_reset] \
  [get_bd_pins microblaze_0_local_memory/SYS_Rst]
  connect_bd_net -net rst_clk_wiz_0_100M_mb_reset  [get_bd_pins rst_clk_wiz_0_100M/mb_reset] \
  [get_bd_pins microblaze_0/Reset] \
  [get_bd_pins microblaze_0_axi_intc/processor_rst]
  connect_bd_net -net rst_clk_wiz_0_100M_peripheral_aresetn  [get_bd_pins rst_clk_wiz_0_100M/peripheral_aresetn] \
  [get_bd_pins microblaze_0_axi_periph/aresetn] \
  [get_bd_pins microblaze_0_axi_intc/s_axi_aresetn] \
  [get_bd_pins axi_timer_0/s_axi_aresetn] \
  [get_bd_pins axi_dma_0/axi_resetn] \
  [get_bd_pins axi_uartlite_0/s_axi_aresetn] \
  [get_bd_pins axi_quad_spi_0/s_axi_aresetn] \
  [get_bd_pins axi_lite_slave_0/s_axi_aresetn] \
  [get_bd_pins memory_arbiter_0/aresetn] \
  [get_bd_pins axi_quad_spi_1/s_axi_aresetn] \
  [get_bd_pins system_ila_0/resetn] \
  [get_bd_pins axis_dwidth_converter_0/aresetn] \
  [get_bd_pins gatekeeper_0/resetn]
  connect_bd_net -net rst_clk_wiz_0_100M_peripheral_reset  [get_bd_pins rst_clk_wiz_0_100M/peripheral_reset] \
  [get_bd_pins sprite_renderer_0/reset]
  connect_bd_net -net sprite_memory_douta  [get_bd_pins sprite_memory/douta] \
  [get_bd_pins memory_arbiter_0/bram_rdata_a]
  connect_bd_net -net sprite_memory_doutb  [get_bd_pins sprite_memory/doutb] \
  [get_bd_pins sprite_renderer_0/bram_data_b]
  connect_bd_net -net sprite_renderer_0_VGA_B  [get_bd_pins sprite_renderer_0/VGA_B] \
  [get_bd_ports VGA_B]
  connect_bd_net -net sprite_renderer_0_VGA_G  [get_bd_pins sprite_renderer_0/VGA_G] \
  [get_bd_ports VGA_G]
  connect_bd_net -net sprite_renderer_0_VGA_HS  [get_bd_pins sprite_renderer_0/VGA_HS] \
  [get_bd_ports VGA_HS]
  connect_bd_net -net sprite_renderer_0_VGA_R  [get_bd_pins sprite_renderer_0/VGA_R] \
  [get_bd_ports VGA_R]
  connect_bd_net -net sprite_renderer_0_VGA_VS  [get_bd_pins sprite_renderer_0/VGA_VS] \
  [get_bd_ports VGA_VS] \
  [get_bd_pins axi_lite_slave_0/vga_vsync_in]
  connect_bd_net -net sprite_renderer_0_bram_addr_a  [get_bd_pins sprite_renderer_0/bram_addr_a] \
  [get_bd_pins memory_arbiter_0/ppu_bram_addr_a]
  connect_bd_net -net sprite_renderer_0_bram_addr_b  [get_bd_pins sprite_renderer_0/bram_addr_b] \
  [get_bd_pins sprite_memory/addrb]
  connect_bd_net -net sprite_renderer_0_bram_clk_a  [get_bd_pins sprite_renderer_0/bram_clk_a] \
  [get_bd_pins sprite_memory/clka]
  connect_bd_net -net sprite_renderer_0_bram_clk_b  [get_bd_pins sprite_renderer_0/bram_clk_b] \
  [get_bd_pins sprite_memory/clkb]
  connect_bd_net -net sprite_renderer_0_bram_en_b  [get_bd_pins sprite_renderer_0/bram_en_b] \
  [get_bd_pins sprite_memory/enb]
  connect_bd_net -net sprite_renderer_0_collision_hi  [get_bd_pins sprite_renderer_0/collision_hi] \
  [get_bd_pins axi_lite_slave_0/collision_flags_hi]
  connect_bd_net -net sprite_renderer_0_collision_lo  [get_bd_pins sprite_renderer_0/collision_lo] \
  [get_bd_pins axi_lite_slave_0/collision_flags_lo]
  connect_bd_net -net sprite_renderer_0_font_ram_addr  [get_bd_pins sprite_renderer_0/font_ram_addr] \
  [get_bd_pins font_memory/addra]
  connect_bd_net -net sprite_renderer_0_font_ram_clk  [get_bd_pins sprite_renderer_0/font_ram_clk] \
  [get_bd_pins font_memory/clka]
  connect_bd_net -net sprite_renderer_0_font_ram_en  [get_bd_pins sprite_renderer_0/font_ram_en] \
  [get_bd_pins font_memory/ena]
  connect_bd_net -net udp_ip_0_ETH_REFCLK  [get_bd_pins udp_ip_0/ETH_REFCLK] \
  [get_bd_ports ETH_REFCLK]
  connect_bd_net -net udp_ip_0_ETH_RSTN  [get_bd_pins udp_ip_0/ETH_RSTN] \
  [get_bd_ports ETH_RSTN]
  connect_bd_net -net udp_ip_0_ETH_TXD  [get_bd_pins udp_ip_0/ETH_TXD] \
  [get_bd_ports ETH_TXD]
  connect_bd_net -net udp_ip_0_ETH_TXEN  [get_bd_pins udp_ip_0/ETH_TXEN] \
  [get_bd_ports ETH_TXEN] \
  [get_bd_pins system_ila_0/probe4]
  connect_bd_net -net udp_ip_0_m_axis_tdata  [get_bd_pins udp_ip_0/m_axis_rx_tdata] \
  [get_bd_pins system_ila_0/SLOT_0_AXIS_tdata] \
  [get_bd_pins axis_data_fifo_0/s_axis_tdata]
  connect_bd_net -net udp_ip_0_m_axis_tlast  [get_bd_pins udp_ip_0/m_axis_rx_tlast] \
  [get_bd_pins system_ila_0/SLOT_0_AXIS_tlast] \
  [get_bd_pins axis_data_fifo_0/s_axis_tlast]
  connect_bd_net -net udp_ip_0_m_axis_tvalid  [get_bd_pins udp_ip_0/m_axis_rx_tvalid] \
  [get_bd_pins system_ila_0/SLOT_0_AXIS_tvalid] \
  [get_bd_pins axis_data_fifo_0/s_axis_tvalid]
  connect_bd_net -net udp_ip_0_meta_rx_data  [get_bd_pins udp_ip_0/meta_rx_data] \
  [get_bd_pins axis_data_fifo_1/s_axis_tdata]
  connect_bd_net -net udp_ip_0_meta_rx_wen  [get_bd_pins udp_ip_0/meta_rx_wen] \
  [get_bd_pins axis_data_fifo_1/s_axis_tvalid]
  connect_bd_net -net xlconcat_0_dout  [get_bd_pins xlconcat_0/dout] \
  [get_bd_pins microblaze_0_axi_intc/intr]
  connect_bd_net -net xlconstant_0_dout  [get_bd_pins xlconstant_0/dout] \
  [get_bd_pins sprite_memory/web] \
  [get_bd_pins font_memory/web] \
  [get_bd_pins font_memory/wea] \
  [get_bd_ports SD_RESET]

  # Create address segments
  assign_bd_address -offset 0x41E00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces microblaze_0/Data] [get_bd_addr_segs axi_dma_0/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x80000000 -range 0x00001000 -target_address_space [get_bd_addr_spaces microblaze_0/Data] [get_bd_addr_segs axi_lite_slave_0/s_axi/reg0] -force
  assign_bd_address -offset 0x44A00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces microblaze_0/Data] [get_bd_addr_segs axi_quad_spi_0/AXI_LITE/Reg] -force
  assign_bd_address -offset 0x44A10000 -range 0x00010000 -target_address_space [get_bd_addr_spaces microblaze_0/Data] [get_bd_addr_segs axi_quad_spi_1/AXI_LITE/Reg] -force
  assign_bd_address -offset 0x41C00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces microblaze_0/Data] [get_bd_addr_segs axi_timer_0/S_AXI/Reg] -force
  assign_bd_address -offset 0x40600000 -range 0x00010000 -target_address_space [get_bd_addr_spaces microblaze_0/Data] [get_bd_addr_segs axi_uartlite_0/S_AXI/Reg] -force
  assign_bd_address -offset 0x00000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces microblaze_0/Data] [get_bd_addr_segs microblaze_0_local_memory/dlmb_bram_if_cntlr/SLMB/Mem] -force
  assign_bd_address -offset 0x41200000 -range 0x00010000 -target_address_space [get_bd_addr_spaces microblaze_0/Data] [get_bd_addr_segs microblaze_0_axi_intc/S_AXI/Reg] -force
  assign_bd_address -offset 0x88000000 -range 0x08000000 -target_address_space [get_bd_addr_spaces microblaze_0/Data] [get_bd_addr_segs mig_7series_0/memmap/memaddr] -force
  assign_bd_address -offset 0x41E00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces microblaze_0/Instruction] [get_bd_addr_segs axi_dma_0/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x80000000 -range 0x00001000 -target_address_space [get_bd_addr_spaces microblaze_0/Instruction] [get_bd_addr_segs axi_lite_slave_0/s_axi/reg0] -force
  assign_bd_address -offset 0x44A00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces microblaze_0/Instruction] [get_bd_addr_segs axi_quad_spi_0/AXI_LITE/Reg] -force
  assign_bd_address -offset 0x44A10000 -range 0x00010000 -target_address_space [get_bd_addr_spaces microblaze_0/Instruction] [get_bd_addr_segs axi_quad_spi_1/AXI_LITE/Reg] -force
  assign_bd_address -offset 0x41C00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces microblaze_0/Instruction] [get_bd_addr_segs axi_timer_0/S_AXI/Reg] -force
  assign_bd_address -offset 0x40600000 -range 0x00010000 -target_address_space [get_bd_addr_spaces microblaze_0/Instruction] [get_bd_addr_segs axi_uartlite_0/S_AXI/Reg] -force
  assign_bd_address -offset 0x00000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces microblaze_0/Instruction] [get_bd_addr_segs microblaze_0_local_memory/ilmb_bram_if_cntlr/SLMB/Mem] -force
  assign_bd_address -offset 0x41200000 -range 0x00010000 -target_address_space [get_bd_addr_spaces microblaze_0/Instruction] [get_bd_addr_segs microblaze_0_axi_intc/S_AXI/Reg] -force
  assign_bd_address -offset 0x88000000 -range 0x08000000 -target_address_space [get_bd_addr_spaces microblaze_0/Instruction] [get_bd_addr_segs mig_7series_0/memmap/memaddr] -force
  assign_bd_address -offset 0x41E00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces axi_dma_0/Data_MM2S] [get_bd_addr_segs axi_dma_0/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x80000000 -range 0x00001000 -target_address_space [get_bd_addr_spaces axi_dma_0/Data_MM2S] [get_bd_addr_segs axi_lite_slave_0/s_axi/reg0] -force
  assign_bd_address -offset 0x44A00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces axi_dma_0/Data_MM2S] [get_bd_addr_segs axi_quad_spi_0/AXI_LITE/Reg] -force
  assign_bd_address -offset 0x41C00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces axi_dma_0/Data_MM2S] [get_bd_addr_segs axi_timer_0/S_AXI/Reg] -force
  assign_bd_address -offset 0x40600000 -range 0x00010000 -target_address_space [get_bd_addr_spaces axi_dma_0/Data_MM2S] [get_bd_addr_segs axi_uartlite_0/S_AXI/Reg] -force
  assign_bd_address -offset 0x41200000 -range 0x00010000 -target_address_space [get_bd_addr_spaces axi_dma_0/Data_MM2S] [get_bd_addr_segs microblaze_0_axi_intc/S_AXI/Reg] -force
  assign_bd_address -offset 0x88000000 -range 0x08000000 -target_address_space [get_bd_addr_spaces axi_dma_0/Data_MM2S] [get_bd_addr_segs mig_7series_0/memmap/memaddr] -force
  assign_bd_address -offset 0x88000000 -range 0x08000000 -target_address_space [get_bd_addr_spaces axi_dma_0/Data_S2MM] [get_bd_addr_segs mig_7series_0/memmap/memaddr] -force

  # Exclude Address Segments
  exclude_bd_addr_seg -offset 0x44A10000 -range 0x00010000 -target_address_space [get_bd_addr_spaces axi_dma_0/Data_MM2S] [get_bd_addr_segs axi_quad_spi_1/AXI_LITE/Reg]
  exclude_bd_addr_seg -offset 0x41E00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces axi_dma_0/Data_S2MM] [get_bd_addr_segs axi_dma_0/S_AXI_LITE/Reg]
  exclude_bd_addr_seg -offset 0x00000000 -range 0x40000000 -target_address_space [get_bd_addr_spaces axi_dma_0/Data_S2MM] [get_bd_addr_segs axi_lite_slave_0/s_axi/reg0]
  exclude_bd_addr_seg -offset 0x44A00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces axi_dma_0/Data_S2MM] [get_bd_addr_segs axi_quad_spi_0/AXI_LITE/Reg]
  exclude_bd_addr_seg -offset 0x44A10000 -range 0x00010000 -target_address_space [get_bd_addr_spaces axi_dma_0/Data_S2MM] [get_bd_addr_segs axi_quad_spi_1/AXI_LITE/Reg]
  exclude_bd_addr_seg -offset 0x41C00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces axi_dma_0/Data_S2MM] [get_bd_addr_segs axi_timer_0/S_AXI/Reg]
  exclude_bd_addr_seg -offset 0x40600000 -range 0x00010000 -target_address_space [get_bd_addr_spaces axi_dma_0/Data_S2MM] [get_bd_addr_segs axi_uartlite_0/S_AXI/Reg]
  exclude_bd_addr_seg -offset 0x41200000 -range 0x00010000 -target_address_space [get_bd_addr_spaces axi_dma_0/Data_S2MM] [get_bd_addr_segs microblaze_0_axi_intc/S_AXI/Reg]


  # Restore current instance
  current_bd_instance $oldCurInst

  validate_bd_design
  save_bd_design
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################

create_root_design ""


