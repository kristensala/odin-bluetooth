package main

import "core:c"
import "core:fmt"
import "core:strings"

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

// https://github.com/pauloborges/bluez/blob/master/lib/hci_lib.h
// https://people.csail.mit.edu/albert/bluez-intro/c404.html#simplescan.c
foreign import hci_lib "system:bluetooth"

foreign hci_lib {
    hci_open_dev :: proc(dev_id: int) -> c.int ---
    hci_close_dev :: proc(dd: int) -> c.int ---
    hci_get_route :: proc(addr: ^int) -> c.int ---
    hci_read_remote_name :: proc(socket: int, addr: ^BD_addr, len: int, name: [^]u8, to: int) -> c.int ---
    hci_inquiry :: proc(dev_id: int, len: int, num_rsp: int, lap: ^int, inquiry_info: ^[dynamic]Inquiry_info, flags: int) -> c.int ---
}

foreign import bluetooth "system:bluetooth"
foreign bluetooth {
    // https://android.googlesource.com/platform/external/bluetooth/bluez/+/froyo/lib/bluetooth.c
    ba2str :: proc (ba: ^BD_addr , str: [^]u8) -> c.int ---
}

main :: proc() {
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
