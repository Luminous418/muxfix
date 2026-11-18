/*
 * MuxFix - keep "Switchable Graphics device = Discrete" on Gigabyte laptops
 * running macOS.
 *
 * The setting lives in extended CMOS, index 0xD0 (ports 0x72/0x73):
 *     0x00 = MSHybrid      0x01 = Discrete
 *
 * Gigabyte Control Center writes it over WMI (WmiMethodId 0xE6) on the ACPI
 * device AMW0, which in the DSDT ends up as:
 *     WMBD (0, 0xE6, value)  ->  WXCM (0xD0, value)   (SystemIO 0x72/0x73)
 *
 * This kext does the same directly from its module start routine, without
 * IOKit (no class, no provider, no matching).
 *
 * Note: the firmware consumes the value at POST, so it has to be written in
 * every session. The LaunchDaemon loads this kext on each boot.
 */

#include <mach/kmod.h>
#include <sys/types.h>

#define MUX_IDX_PORT   0x72
#define MUX_DATA_PORT  0x73
#define MUX_REG        0xD0
#define MUX_MASK       0x7F
#define MUX_DISCRETE   0x01

extern "C" void IOLog(const char *format, ...);

static inline void muxWriteReg(unsigned char idx, unsigned char val)
{
    __asm__ volatile ("outb %0, %1" :: "a" (idx), "Nd" ((unsigned short) MUX_IDX_PORT));
    __asm__ volatile ("outb %0, %1" :: "a" (val), "Nd" ((unsigned short) MUX_DATA_PORT));
}

static inline unsigned char muxReadReg(unsigned char idx)
{
    unsigned char v;
    __asm__ volatile ("outb %0, %1" :: "a" (idx), "Nd" ((unsigned short) MUX_IDX_PORT));
    __asm__ volatile ("inb %1, %0" : "=a" (v) : "Nd" ((unsigned short) MUX_DATA_PORT));
    return v;
}

extern "C" kern_return_t MuxFix_start(kmod_info_t *ki, void *data)
{
    unsigned char before = muxReadReg(MUX_REG) & MUX_MASK;

    if (before != MUX_DISCRETE) {
        muxWriteReg(MUX_REG, MUX_DISCRETE);
        unsigned char after = muxReadReg(MUX_REG) & MUX_MASK;
        IOLog("MuxFix: mode %u -> %u (wrote %u)\n", before, after, MUX_DISCRETE);
    } else {
        IOLog("MuxFix: already Discrete (%u)\n", before);
    }

    return KERN_SUCCESS;
}

extern "C" kern_return_t MuxFix_stop(kmod_info_t *ki, void *data)
{
    return KERN_SUCCESS;
}

/*
 * kmod_info is declared by hand: the Command Line Tools' ld no longer
 * synthesises it, so we point the kernel at our own start/stop routines.
 */
extern "C" kmod_info_t kmod_info =
{
    0,                          /* next */
    KMOD_INFO_VERSION,          /* info_version */
    (uint32_t) -1,              /* id */
    "com.lumi.MuxFix",          /* name */
    "1.0.0",                    /* version */
    -1,                         /* reference_count */
    0, 0, 0, 0,                 /* reference_list, address, size, hdr_size */
    MuxFix_start,
    MuxFix_stop
};
