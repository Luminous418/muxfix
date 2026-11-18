/*
 * SSDT-MUX v5: escribe Discrete SIN comprobar el valor previo.
 * Objetivo: distinguir "no escribe porque la lectura no da 0" de
 * "escribe pero no cuaja".  Si tras un arranque completo el siguiente
 * sigue en MSHybrid y el CMOS vuelve a 0, la escritura no llega en macOS
 * y habría que hacerla desde un kext (puertos 0x72/0x73 directamente).
 */
DefinitionBlock ("", "SSDT", 2, "ZPSS", "MUXFIX", 0x00000005)
{
    External (_SB_.PC00.AMW0, DeviceObj)
    External (_SB_.PC00.AMW0.WMBD, MethodObj)

    Scope (\_SB.PC00.AMW0)
    {
        Method (_INI, 0, NotSerialized)  // _INI: Initialize
        {
            WMBD (Zero, 0xE6, One)
        }
    }

    Device (MUXF)
    {
        Name (_HID, "MUX0001")  // _HID: Hardware ID
        Name (_UID, One)        // _UID: Unique ID

        Method (_STA, 0, NotSerialized)  // _STA: Status
        {
            \_SB.PC00.AMW0.WMBD (Zero, 0xE6, One)
            Return (0x0F)
        }

        Method (_INI, 0, NotSerialized)  // _INI: Initialize
        {
            \_SB.PC00.AMW0.WMBD (Zero, 0xE6, One)
        }
    }
}
