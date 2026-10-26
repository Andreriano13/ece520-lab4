// part6_fifo_test.c - ECE 520 Lab 4, Part 6: drive the sc_fifo_axi IP from the ARM.
// Pushes words through WR_DATA, pops them with RD_REQ + RD_VALID polling, and checks
// STATUS, DATA_COUNT, CONFIG and THRESHOLD against the register map (PDF p. 58-62).
// Drafted with Claude (Anthropic); see README "AI assistance".
#include <stdint.h>
#include "platform.h"
#include "xil_printf.h"
#include "xil_io.h"

#define FIFO_BASE_ADDR   (0x43C10000)            // from the Address Editor (check yours)
#define FPGA_REV_REG     (FIFO_BASE_ADDR + 0x00) // RO
#define FIFO_RST_REG     (FIFO_BASE_ADDR + 0x04) // WO: write 1 = reset
#define WR_DATA_REG      (FIFO_BASE_ADDR + 0x08) // WO: write = push
#define RD_REQ_REG       (FIFO_BASE_ADDR + 0x0C) // WO: write 1 = pop
#define RD_DATA_REG      (FIFO_BASE_ADDR + 0x10) // RO: last popped word
#define STATUS_REG       (FIFO_BASE_ADDR + 0x14) // RO: [4]RD_VALID [3]AF [2]AE [1]FULL [0]EMPTY
#define DATA_COUNT_REG   (FIFO_BASE_ADDR + 0x18) // RO
#define CONFIG_REG       (FIFO_BASE_ADDR + 0x1C) // RO
#define THRESHOLD_REG    (FIFO_BASE_ADDR + 0x20) // RO

#define RD_VALID_BIT     (1u << 4)
#define NUM_WORDS        5

static int errors = 0;

static void check(const char *what, uint32_t got, uint32_t want)
{
    xil_printf("%s: 0x%08x %s\n", what, got, (got == want) ? "OK" : "<-- WRONG");
    if (got != want) errors++;
}

static uint32_t fifo_pop(void)
{
    Xil_Out32(RD_REQ_REG, 1);                          // step 1: ask for a word
    while ((Xil_In32(STATUS_REG) & RD_VALID_BIT) == 0) // step 2: wait for RD_VALID
        ;
    return Xil_In32(RD_DATA_REG);                      // step 3: read it
}

int main()
{
    init_platform();
    xil_printf("\nECE 520/L - Custom AXI-Lite FIFO IP - Andres Riano\n");

    Xil_Out32(FIFO_RST_REG, 1);                        // start from empty
    check("FPGA_REV  ", Xil_In32(FPGA_REV_REG), 0x52000004);
    check("CONFIG    ", Xil_In32(CONFIG_REG),   0x01002010);
    check("THRESHOLD ", Xil_In32(THRESHOLD_REG),0x001F0001);
    check("STATUS    ", Xil_In32(STATUS_REG),   0x00000005);

    xil_printf("\nPushing %d words:\n", NUM_WORDS);
    for (uint32_t k = 0; k < NUM_WORDS; k++) {
        uint32_t w = 0x1111 * (k + 1);
        Xil_Out32(WR_DATA_REG, w);
        xil_printf("  push 0x%04x  (count now %d)\n", w, Xil_In32(DATA_COUNT_REG));
    }
    check("DATA_COUNT", Xil_In32(DATA_COUNT_REG), NUM_WORDS);

    xil_printf("\nPopping them back:\n");
    for (uint32_t k = 0; k < NUM_WORDS; k++) {
        uint32_t w = fifo_pop();
        xil_printf("  pop  0x%04x  %s\n", w, (w == 0x1111 * (k + 1)) ? "OK" : "<-- WRONG");
        if (w != 0x1111 * (k + 1)) errors++;
    }
    check("STATUS    ", Xil_In32(STATUS_REG), 0x00000015);  // RD_VALID + almost_empty + empty

    Xil_Out32(FIFO_RST_REG, 1);                        // also clears RD_VALID
    xil_printf("\nFilling to 32, then one extra write:\n");
    for (uint32_t k = 0; k < 33; k++) Xil_Out32(WR_DATA_REG, k);
    check("DATA_COUNT", Xil_In32(DATA_COUNT_REG), 32);
    check("STATUS    ", Xil_In32(STATUS_REG), 0x0000000A);  // full + almost_full

    Xil_Out32(FIFO_RST_REG, 1);
    check("after RST ", Xil_In32(DATA_COUNT_REG), 0);

    xil_printf("\n%s (%d errors)\nEnd of FIFO Test\n", errors ? "FAILED" : "ALL PASS", errors);
    cleanup_platform();
    return 0;
}
