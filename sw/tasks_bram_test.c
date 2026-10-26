#include <stdint.h>
#include "platform.h"
#include "xil_printf.h"
#include "xil_io.h"

#define MULT_BASE_ADDR  (0x43C00000)
#define A_REG_ADDR      (MULT_BASE_ADDR + 0x00)
#define B_REG_ADDR      (MULT_BASE_ADDR + 0x04)
#define P_REG_ADDR      (MULT_BASE_ADDR + 0x08)
#define BRAM_BASE_ADDR  (0x40000000)              // from your Address Editor
#define NUM_ENTRIES     32

int main()
{
    init_platform();
    xil_printf("ECE 520/L - Custom AXI IP Lab - Andres Riano\n");
    xil_printf("Start of Multiplier + BRAM Test\n");

    for (uint32_t k = 0; k < NUM_ENTRIES; k++) {
        uint32_t n = k + 1;                           // 1 .. 32
        Xil_Out32(A_REG_ADDR, n);
        Xil_Out32(B_REG_ADDR, n);
        uint32_t p = Xil_In32(P_REG_ADDR);                         // read the product
        Xil_Out32(BRAM_BASE_ADDR + (k * 4), p);                       // BRAM address of entry k
        xil_printf("Stored: %d x %d = %d at BRAM[%d]\n", n, n, p, k);
    }

    xil_printf("\nBRAM Contents:\n");
    for (uint32_t k = 0; k < NUM_ENTRIES; k++) {
        uint32_t v = Xil_In32(BRAM_BASE_ADDR + (k * 4));                         // read entry k back
        xil_printf("BRAM[%d] = %d\n", k, v);
    }

    xil_printf("End of Multiplier + BRAM Test\n");
    cleanup_platform();
    return 0;
}