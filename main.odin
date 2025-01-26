package main

import "core:c"
import "core:fmt"
import "core:strings"
import net "core:net"

// https://android.googlesource.com/platform/external/bluetooth/bluez/+/froyo/lib/hci.c

BD_addr :: struct {
    b: [6]u8
}

Inquiry_info :: struct {
    bdaddr: BD_addr,
    pscan_rep_mode: u8,
    pscan_period_mode: u8,
    pscan_mode: u8,
    dev_class: [3]u8,
    clock_offset: u16,
}

Hci_Filter :: struct {
    type_mask: u32,
    event_mask: [2]u32,
    opcode: u16
}

Hci_State :: struct {
    device_id: i32,
    device_handle: i32,
    original_filter: Hci_Filter,
    state: Hci_Scanning_State,
    has_error: bool,
    error_message: [1024]u8
}

Hci_Scanning_State :: enum {
    SCANNING,
    FILTERING,
    HCI_STATE_OPEN
}

HCI_EVENT_PKT := 0x04
EVT_LE_META_EVENT := 0x3E

// https://github.com/pauloborges/bluez/blob/master/lib/hci_lib.h
// https://people.csail.mit.edu/albert/bluez-intro/c404.html#simplescan.c

/*
int hci_le_set_scan_enable(int dev_id, uint8_t enable, uint8_t filter_dup, int to);
int hci_le_set_scan_parameters(int dev_id, uint8_t type, uint16_t interval,
					uint16_t window, uint8_t own_type,
					uint8_t filter, int to);
*/

foreign import hci_lib "system:bluetooth"
foreign hci_lib {
    hci_open_dev :: proc(dev_id: int) -> c.int ---
    hci_close_dev :: proc(dd: int) -> c.int ---
    hci_get_route :: proc(addr: ^int) -> c.int ---
    hci_read_remote_name :: proc(socket: int, addr: ^BD_addr, len: int, name: [^]u8, to: int) -> c.int ---
    hci_inquiry :: proc(dev_id: int, len: int, num_rsp: int, lap: ^int, inquiry_info: ^[dynamic]Inquiry_info, flags: int) -> c.int ---
    hci_le_set_scan_enable :: proc(dev_id: int, enable: u8, filter_dup: u8, to: int) -> c.int ---
    hci_le_set_scan_parameters :: proc(dev_id: int, type: u8, interval: u16, window: u16, own_type: u8, filter: u8, to: int) -> c.int ---
}

foreign import bluetooth "system:bluetooth"
foreign bluetooth {
    // https://android.googlesource.com/platform/external/bluetooth/bluez/+/froyo/lib/bluetooth.c
    ba2str :: proc (ba: ^BD_addr , str: [^]u8) -> c.int ---
}

foreign import libc "system:c"
foreign libc {
    setsockopt :: proc(
        socket:       int,
        level:        int,
        option_name:  int,
        option_value: rawptr,
        option_len:   int,
    ) -> c.int ---
    getsockopt :: proc(
        socket:       int,
        level:        int,
        option_name:  int,
        option_value: rawptr,
        option_len:   int,
    ) -> c.int ---
}

foreign import hci_custom_lib "hci_custom_lib.a"
foreign hci_custom_lib {
    hci_filter_set_ptype :: proc(t: int, hci_filter: ^Hci_Filter) ---
    hci_filter_set_event :: proc(e: int, hci_filter: ^Hci_Filter) ---
    htobs :: proc(x: u16) -> c.uint16_t ---
}

bswap_16 :: proc(value: int) -> int {
    return (value >> 8) | (value << 8)
}

main :: proc() {
    state := open_dev()
    start_le_scan(state)
}

open_dev :: proc() -> ^Hci_State {
    current_hci_state := new(Hci_State)
    current_hci_state.device_id = hci_get_route(nil)

    open_dev := hci_open_dev(int(current_hci_state.device_id))
    if open_dev < 0 {
        current_hci_state.has_error = true
        fmt.println("Could not open hci dev")
        return current_hci_state;
    }

    current_hci_state.device_handle = open_dev

    /*err := net.set_blocking(net.TCP_Socket(current_hci_state.device_handle), false)
    if err != nil {
        current_hci_state.has_error = true
        fmt.println("could not set socker nonblocking")
        return current_hci_state
    }*/

    current_hci_state.state = .HCI_STATE_OPEN
    return current_hci_state

}

//https://github.com/carsonmcdonald/bluez-experiments/blob/master/experiments/scantest.c
start_le_scan :: proc(hci_state: ^Hci_State) {
    new_filter: Hci_Filter
    hci_filter_set_ptype(HCI_EVENT_PKT, &new_filter)
    hci_filter_set_event(EVT_LE_META_EVENT, &new_filter)

    res2 := setsockopt(int(hci_state.device_handle), 0, 2, &new_filter, size_of(new_filter))
    if res2 < 0  {
        hci_state.has_error = true
        fmt.println("setsockopt failed")
        return
    }

    hci_le_set_scan_enable(int(hci_state.device_handle), 0x00, 0, 1000);

    hci_scan_params := hci_le_set_scan_parameters(
        int(hci_state.device_handle),
        0x01,
        htobs(0x0010),
        htobs(0x0010),
        0x00,
        0,
        1000
    )
    fmt.println("here: ", hci_scan_params)

    if hci_scan_params < 0 {
        hci_state.has_error = true
        fmt.println("Failed to set hci_scan_params")
        return;
    }

    hci_le_scan_enabled := hci_le_set_scan_enable(int(hci_state.device_handle), 0x01, 1, 1000)
    if hci_le_scan_enabled < 0 {
        hci_state.has_error = true
        fmt.println("Faild to enable hci_le_scan")
        return;
    }

    hci_state.state = .SCANNING


    res := getsockopt(int(hci_state.device_handle), 0, 2, &hci_state.original_filter, size_of(hci_state.original_filter))
    if res < 0 {
        hci_state.has_error = true
        fmt.println("getsockopt failed")
        return
    }

    hci_state.state = .FILTERING
}


simple_scan_test :: proc() {
    ii := make([dynamic]Inquiry_info, 5)

    dev_id := hci_get_route(nil)
    socket := hci_open_dev(int(dev_id))

    if dev_id < 0 || socket < 0 {
        fmt.println("failed to open socket")
        return
    }

    flags := 0x0001 // IREQ_CACHE_FLUSH
    num_rsp := hci_inquiry(int(dev_id), 8, 255, nil, &ii, flags)
    fmt.println(num_rsp)

    for i in 0..<num_rsp {
        addr_str := make([^]u8, 19)
        defer free(addr_str)

        ba2str(&ii[i].bdaddr, addr_str)
        fmt.println(strings.string_from_ptr(addr_str, 19))

        name := make([^]u8, 248)
        defer free(name)

        hci_read_remote_name(int(socket), &ii[i].bdaddr, 248, name, 0)
        fmt.println(strings.string_from_ptr(name, 248))

    }


    hci_close_dev(int(socket))
    delete(ii)
}


