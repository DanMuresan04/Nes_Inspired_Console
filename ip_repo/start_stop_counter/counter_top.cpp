#include <ap_int.h>

// 1. Use a Class to define a reusable hardware Component
class Debouncer {
private:
    // Class members act exactly like 'static' variables but are unique to each instance
    ap_uint<20> counter;
    bool clean_state;

public:
    // Constructor (Initializes the registers on reset)
    Debouncer() {
        counter = 0;
        clean_state = false;
    }

    // The 'process' equivalent
    bool run(bool button_in) {
        if (button_in != clean_state) {
            counter++;
            if (counter == 1000000) {
                clean_state = button_in;
                counter = 0;
            }
        } else {
            counter = 0;
        }
        return clean_state;
    }
};

// 2. Helper Class for Edge Detection
class EdgeDetector {
private:
    bool prev_state;
public:
    EdgeDetector() { prev_state = false; }
    
    bool is_rising_edge(bool current_state) {
        bool rising = (current_state == true && prev_state == false);
        prev_state = current_state; // Latch for next clock cycle
        return rising;
    }
};



// Top-Level Module
void counter_module(
    bool start_stop, 
    bool init, 
    ap_uint<16> init_value, 
    ap_uint<16> &count_out
) {
    #pragma HLS PIPELINE II=1
    // 3. Instantiate our components (static so they persist across clock cycles)
    static Debouncer db_start_stop_inst;
    static Debouncer db_init_inst;
    static EdgeDetector edge_start_stop_inst;

    // Registers for the counter module
    static ap_uint<16> internal_count = 0;
    static ap_uint<27> fast_count = 100000000;
    static bool is_running = false;
    
    // Wire up the debouncers
    bool db_start_stop = db_start_stop_inst.run(start_stop);
    bool db_init       = db_init_inst.run(init);
    
    // Wire up the edge detector to the debounced start/stop signal
    bool start_stop_pulse = edge_start_stop_inst.is_rising_edge(db_start_stop);

    // 4. Main State Logic
    if (db_init == true) { // Init is usually level-sensitive override
        internal_count = init_value;
        is_running = false;
    } 
    else {
        // Toggle run state ONLY on the rising edge of the button press
        if (start_stop_pulse) {
            is_running = !is_running; 
        }

        // Counter Logic
        if (is_running) {
            if (fast_count == 0 && internal_count > 0) {
                internal_count--;       // Decrement the visible counter
                fast_count = 99999999;  // Reload the 1-second delay
            } else {
                fast_count--;           // Otherwise, just tick down the fast clock
            }
        }
    }

    // Drive the output port
    count_out = internal_count;
}