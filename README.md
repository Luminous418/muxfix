# MuxFix — keep "Switchable Graphics = Discrete" on macOS

A tiny kext for **Gigabyte** laptops with a display MUX switch that, under macOS, lose the
**`Switchable Graphics device = Discrete`** setting on every restart.

It restores it automatically. No BIOS trips, no Windows app.

> ⚠️ **Experimental.** It writes a CMOS register. Tested on a **Gigabyte GAMING A16 (GA6H)**
> with an i7-13620H + RTX 5050. The register may differ on other models.
> **Back up your EFI and use at your own risk.**

---

## The problem

On these laptops the firmware keeps the MUX mode in **extended CMOS**:

| Port | Purpose |
|---|---|
| `0x72` | index |
| `0x73` | data |

The setting lives at **index `0xD0`**:

| Value | Mode |
|---|---|
| `0x00` | MSHybrid (panel on the iGPU → macOS without acceleration) |
| `0x01` | Discrete (panel on the dGPU → native Metal) |

Gigabyte Control Center writes it over **WMI**: method **`SetPEG2orSG2`** (`WmiMethodId 0xE6`)
on the ACPI device **`AMW0`** (PNP0C14), which in the DSDT ends up as:

```
WMBD (0, 0xE6, value)  ->  WXCM (0xD0, value)   // SystemIO 0x72/0x73
WMBC (0, 0xE6, 0)      ->  RXCM (0xD0) & 0x7F   // read back
```

The important part: **the value is consumed at POST**. One write = one Discrete boot.
That is why neither a one-off write nor an ACPI SSDT is enough: it has to be written
**during every macOS session**, and the next POST applies it.

macOS never writes it, so after a restart the panel falls back to the iGPU.

## How it works

`MuxFix.kext` writes `0xD0 = 0x01` from its module start routine. A `LaunchDaemon` loads the
kext on every boot, so the next boot comes up in Discrete.

- No IOKit dependency: no classes, no matching. Only `IOLog`.
- Builds with the **Command Line Tools** alone (`src/build.sh`).
- Writes nothing if the value is already `1`.

## Install

```sh
git clone <this repo> && cd muxfix
bash src/build.sh          # builds src/MuxFix.kext
sudo bash install.sh       # copies the kext, installs the daemon, loads it
```

If macOS asks in **System Settings → Privacy & Security**, approve the extension and restart.

The first boot after installing still starts in MSHybrid; the one after that is Discrete.

## Uninstall

```sh
sudo bash uninstall.sh
```

## How it was found

1. Gigabyte's app is .NET (`GiMATE` + `Gbt.GpuPowerGear.Hardware.dll`). Disassembling the IL
   shows the mode is sent as a `PowerGearComboBoxSettingItem` (`Id = 36`, `BiosMode = 1`) and
   that the actual value goes through `GB_WMIACPI_Set.SetPEG2orSG2`, parameter `Data`
   (enum `BiosDisplayMode`: 0 Dynamic, 1 Discrete, 2 MsHybrid).
2. That WMI method's `WmiMethodId` qualifier is **`0xE6`**, which in the DSDT is the
   `WMBD`/`WMBC` case that talks to ports `0x72/0x73`.
3. Reading it from Linux with `acpi_call`: MSHybrid returns `0x0`, Discrete `0x1`.
4. Writing `WMBD (0, 0xE6, 1)` from Linux made the next boot come up in Discrete — mechanism
   confirmed.
5. An ACPI-only attempt (SSDT calling the same method from `_INI`/`_STA`) has no effect under
   macOS. A kext writing the ports directly does.

## Known limitations

- Gigabyte-specific (probably the A16 / AORUS family with a manual MUX).
- The setting is one boot deep: the kext must run in every session (the daemon handles it).
- If you change the mode by hand in the BIOS or with the Windows app, MuxFix will put it back
  to Discrete on the next boot. That is the point.
- It does not replace the NVIDIA driver: you still need NullMoth (or similar) to accelerate
  the panel.

## License

MIT. No Apple, NVIDIA or Gigabyte code: only reverse engineering of the public ACPI/WMI
interface and access to the ports documented above.
