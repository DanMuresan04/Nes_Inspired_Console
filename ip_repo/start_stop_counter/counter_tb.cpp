#include <iostream>
#include <ap_int.h>

// Declare the hardware module so the testbench knows it exists
// (In a real project, this goes in a header file like "counter.h")
void counter_module(
    bool start_stop, 
    bool init, 
    ap_uint<16> init_value, 
    ap_uint<16> &count_out
);

int main() {
    // 1. Declare testbench signals (Wires to connect to our module)
    bool tb_start_stop = false;
    bool tb_init = false;
    ap_uint<16> tb_init_value = 10; // We want to count down from 10
    ap_uint<16> tb_count_out;

    std::cout << "Starting HLS C Simulation..." << std::endl;
    std::cout << "CLK | INIT | START/STOP | COUNT_OUT" << std::endl;
    std::cout << "-----------------------------------" << std::endl;

    // 2. The Clock Generator Loop
    // We will simulate 30 clock cycles.
    for (int clk = 0; clk < 30; clk++) {
        
        // 3. Apply Stimuli (Like concurrent assignments in VHDL)
        
        // Cycle 2: Press the Init button
        if (clk == 2) tb_init = true;
        // Cycle 5: Release the Init button
        if (clk == 5) tb_init = false;

        // Cycle 8: Press the Start/Stop button
        if (clk == 8) tb_start_stop = true;
        // Cycle 11: Release the Start/Stop button
        if (clk == 11) tb_start_stop = false;

        // Cycle 20: Press the Start/Stop button again (to pause)
        if (clk == 14) tb_start_stop = true;
        // Cycle 23: Release the Start/Stop button
        if (clk == 17) tb_start_stop = false;

        // 4. Instantiate/Call the Hardware Module
        // This executes exactly ONE clock cycle of logic.
        counter_module(tb_start_stop, tb_init, tb_init_value, tb_count_out);

        // 5. Print the Waveform to the Console
        std::cout << " " << clk << "  |  " 
                  << tb_init << "   |     " 
                  << tb_start_stop << "      |    " 
                  << tb_count_out << std::endl;
    }

    // 6. The Golden Rule of HLS Testbenches
    // Returning 0 tells the Vitis HLS tool: "The simulation passed!"
    // If you return anything else, Vitis HLS will flag the test as FAILED.
    return 0; 
}