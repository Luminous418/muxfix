# MuxFix — keep "Switchable Graphics = Discrete" on Gigabyte laptops (macOS)

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

Two details matter:

1. **The value is consumed at POST.** One write = one Discrete boot. It has to be written
   during *every* macOS session; the next POST applies it.
2. macOS never writes it, so after a restart the panel falls back to the iGPU.

## How it works

```
OpenCore injects MuxFix.kext into the boot kernel collection
        ↓
com.lumi.muxfix (LaunchDaemon) asks the kernel to start it
        ↓
MuxFix_start() writes 0xD0 = 0x01
        ↓
next POST → panel on the dGPU
```

The kext has no IOKit dependency (no classes, no matching), only `IOLog`.

### Why the LaunchDaemon is needed (and why the kext also goes in `/Library/Extensions`)

macOS 26 ships with `spctl kext-consent` **disabled**, so a kext in `/Library/Extensions` is
only accepted if it is signed with a **Developer ID Team ID**. An ad-hoc signature is blocked:

```
Kernel extension not signed with valid team ID
Kernel Extension BLOCKED
```

But a kext injected by OpenCore lands in the **boot kernel collection** without any approval.
The catch: the kernel does not start it on its own, so something has to ask for it. And here
is the quirk that makes the whole thing work:

- `kmutil load -b com.lumi.MuxFix` → goes through the approval path → blocked.
- `kmutil load -p /Library/Extensions/MuxFix.kext` → resolves to the copy **already in the
  kernel collection** → starts it, no approval.

So the `/Library/Extensions` copy is only there to give `kmutil` a path. The binary that runs
is the one OpenCore injected.

## Install

1. **Build** (Command Line Tools are enough):

   ```sh
   bash src/build.sh          # -> src/MuxFix.kext
   ```

2. **Put the kext in your EFI**: copy `src/MuxFix.kext` to `EFI/OC/Kexts/MuxFix.kext` and add
   an entry to `Kernel → Add`:

   ```
   Arch           x86_64
   BundlePath     MuxFix.kext
   Comment        MuxFix: keep Switchable Graphics = Discrete
   Enabled        true
   ExecutablePath Contents/MacOS/MuxFix
   MaxKernel      (empty)
   MinKernel      (empty)
   PlistPath      Contents/Info.plist
   ```

3. **Install the daemon and the path copy**:

   ```sh
   sudo bash install.sh
   ```

4. Restart. The first boot after installing may still come up in MSHybrid; the next one is
   Discrete and it stays that way.

## Uninstall

```sh
sudo bash uninstall.sh      # removes the daemon and the /Library/Extensions copy
```

Then remove `MuxFix.kext` from `EFI/OC/Kexts` and from `Kernel → Add`.

## How it was found

1. Gigabyte's app is .NET (`GiMATE` + `Gbt.GpuPowerGear.Hardware.dll`). Disassembling the IL
   shows the mode is sent as a `PowerGearComboBoxSettingItem` (`Id = 36`, `BiosMode = 1`) and
   that the actual value goes through `GB_WMIACPI_Set.SetPEG2orSG2`, parameter `Data`
   (enum `BiosDisplayMode`: 0 Dynamic, 1 Discrete, 2 MsHybrid).
2. That WMI method's `WmiMethodId` qualifier is **`0xE6`**, which in the DSDT is the
   `WMBD`/`WMBC` case that talks to ports `0x72/0x73`.
3. Reading it from Linux with `acpi_call`: MSHybrid returns `0x0`, Discrete `0x1`.
4. Writing `WMBD (0, 0xE6, 1)` from Linux made the next boot come up in Discrete —
   mechanism confirmed.
5. An ACPI-only attempt (SSDT calling the same method from `_INI`/`_STA`) has no effect under
   macOS; see `docs/`. A kext writing the ports directly does.

## Known limitations

- Gigabyte-specific (probably the A16 / AORUS family with a manual MUX).
- One boot deep: the kext must run in every session (the daemon handles it).
- If you change the mode by hand in the BIOS or with the Windows app, MuxFix puts it back to
  Discrete on the next boot. That is the point.
- It does not replace the NVIDIA driver: you still need NullMoth (or similar) to accelerate
  the panel.
- After a macOS update the kext keeps working as long as the EFI entry survives; if a tool
  rewrites your EFI, re-add the kext.

## License

MIT. No Apple, NVIDIA or Gigabyte code: only reverse engineering of the public ACPI/WMI
interface and access to the ports documented above.
