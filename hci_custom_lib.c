#include <string.h>
#include <stdint.h>
#include <byteswap.h>

#define HCI_VENDOR_PKT		0xff
#define HCI_FLT_TYPE_BITS	31
#define HCI_FLT_EVENT_BITS	63

struct hci_filter {
	uint32_t type_mask;
	uint32_t event_mask[2];
	uint16_t opcode;
};

void hci_set_bit(int nr, void *addr)
{
	*((uint32_t *) addr + (nr >> 5)) |= (1 << (nr & 31));
}

void hci_filter_clear(struct hci_filter *f)
{
	memset(f, 0, sizeof(*f));
}
void hci_filter_set_ptype(int t, struct hci_filter *f)
{
	hci_set_bit((t == HCI_VENDOR_PKT) ? 0 : (t & HCI_FLT_TYPE_BITS), &f->type_mask);
}

void hci_filter_set_event(int e, struct hci_filter *f)
{
	hci_set_bit((e & HCI_FLT_EVENT_BITS), &f->event_mask);
}

uint16_t htobs(uint16_t x) {
    return bswap_16(x);
}
