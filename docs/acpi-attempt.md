# The ACPI attempt (did not work)

Before writing a kext we tried to do the same thing from ACPI, which would have been
cleaner: an SSDT that calls the firmware's own WMI method during namespace init.

```asl
Scope (\_SB.PC00.AMW0)
{
    Method (_INI, 0, NotSerialized)
    {
        WMBD (Zero, 0xE6, One)
    }
}
```

`SSDT-MUX-attempt.dsl` is the final version we tested. It loads (visible in the kernel log as
`SSDT ... ZPSS MUXFIX`) and the extra device appears in `ioreg -p IOACPIPlane`, but the write
never takes effect: after a macOS session the CMOS value was still `0`.

We also tried a device with its own `_INI` and `_STA` doing the write unconditionally, with the
same result. Whatever blocks it (Apple's ACPI implementation, or the timing during namespace
init), doing the write from a kext at runtime does work.

Kept here for reference.
