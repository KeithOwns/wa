# Naming Convention for wa.ps1 Steps & Atomic Scripts

## Context

`wa.ps1`'s dashboard currently labels every step with a `Met` ID like `SET_ARSOOptOut` or
`RUN_OptimizeDisks`. These IDs (and the matching standalone files under `AtomicScripts/`)
only encode *what* the step does, not *where* in Windows the corresponding control lives.
A user looking at `SET_PSModuleLogging` next to `SET_Telemetry` has no way to tell that one
has a real Settings-app toggle and the other is registry/Group-Policy-only with no UI at
all. The goal is a naming convention where the identifier itself tells the user which app
to open and roughly where to look — without needing to read the function body.

Verified before designing this:
- The `Met` field is a pure display string (`Write-ColItem`/`Write-MaintItem` print it,
  nothing else reads it as a key) — confirmed via repo-wide grep. Renaming it is
  cosmetic-only, zero functional risk.
- `AtomicScripts/*.ps1` filenames already mirror the `Met` IDs 1:1 (e.g. `SET_ARSOOptOut.ps1`),
  per [CLAUDE.md](CLAUDE.md) — they're independent standalone copies, not invoked by `wa.ps1`,
  so renaming them is also isolated/low-risk.
- Decided with user: use a **2-letter surface-code prefix** (fits the dashboard's existing
  ~27-char Met column with no layout changes), and **leave the internal `Invoke-WA_Set*`/
  `Invoke-WA_Run*` function names unchanged** (lower risk; they're invisible to the end user).

## Naming Convention

**Format:** `<Surface>_<Verb><SettingName>` — e.g. `WS_SetRealTimeProt`, `ST_SetTelemetry`,
`FE_SetShowHidden`, `NX_SetLLMNR`, `ST_RunUpdateSuite`.

- `<Surface>` — 2-letter code for the Windows UI surface where the control physically lives
  (see dictionary below). This is the new part.
- `<Verb>` — unchanged from today: `Set` (a configurable toggle/setting) or `Run` (a
  maintenance action with no persistent on/off state).
- `<SettingName>` — unchanged existing PascalCase suffix (e.g. `ARSOOptOut`, `OptimizeDisks`).

**Surface-code dictionary:**

| Code | Surface | Example real path |
|---|---|---|
| `WS` | Windows Security app | Windows Security > Virus & threat protection |
| `ST` | Settings app (`ms-settings:`) | Settings > Privacy & Security > Diagnostics & feedback |
| `FE` | File Explorer / Folder Options | File Explorer > View > Show > Hidden items |
| `EG` | Microsoft Edge settings | Edge > Settings > Privacy, search, and services |
| `CP` | Legacy Control Panel-style dialog/applet | Network adapter Properties > WINS tab; Optimize Drives (dfrgui.exe) |
| `NX` | No UI exists anywhere (registry/GPO/console-tool only) | n/a — note this explicitly so the user doesn't go hunting |

**Documentation pairing:** the 2-letter code answers "which app." For the *exact* path, every
`Invoke-WA_Set*`/`Invoke-WA_Run*` function's comment-based help and the matching
`AtomicScripts/*.ps1` header comment get a standardized line:
`UI Location: <breadcrumb>` (or `UI Location: none (registry/GPO-only)` for `NX` items).
Several `AtomicScripts/*.ps1` files already have an informal version of this comment
(e.g. `SET_ARSOOptOut.ps1` already says "Drives the actual toggle on Settings > Accounts >
Sign-in options...") — this just standardizes the tag and back-fills the ones missing it.

## Scope

**Renamed:** the `Met` string literals in the four dashboard arrays (`$autoItems`, `$secItems`,
`$uiItems`, `$maintModel` in `wa.ps1`'s main loop) and the matching `AtomicScripts/*.ps1`
filenames.

**Added:** a `UI Location:` line in each function's/script's header comment.

**Not touched:** `Invoke-WA_*` function names, `Toggle_*`/`$s_*` variable names, registry
paths, any program logic. Purely a rename + documentation pass.

**Found but out of scope (flagging, not fixing here):** `AtomicScripts/GET_DeviceInfo.ps1`
and `AtomicScripts/Unlock_PhishingProtection.ps1` don't correspond to any current `Met` ID —
they look orphaned/stale. Worth a follow-up decision (delete vs. fold into the convention)
but not blocking this rename.

## Draft Mapping (all 36 steps)

Most are high-confidence from reading the code (registry path, `Set-MpPreference` target, or
the literal `ms-settings:`/`windowsdefender://` URI the function opens). A few are flagged
**[verify]** — Windows 11's exact page location for that control has shifted across feature
updates, so the surface code is a best-effort placement to confirm live during execution.

**Automation**
| Current Met | New Met | Notes |
|---|---|---|
| SET_GetMeUpToDate | `NX_SetGetMeUpToDate` | "IsExpedited" flag — no known visible toggle **[verify]** |
| SET_MicrosoftUpd | `ST_SetMicrosoftUpd` | Settings > Windows Update > Advanced options |
| SET_RestartIsReq | `ST_SetRestartIsReq` | Settings > Windows Update > Advanced options |
| SET_RestartApps | `ST_SetRestartApps` | Settings > Accounts > Sign-in options (exact sub-toggle) **[verify]** |
| SET_MeteredUpdates | `ST_SetMeteredUpdates` | confirmed: `ms-settings:windowsupdate-options` |
| SET_ARSOOptOut | `ST_SetARSOOptOut` | confirmed: `ms-settings:signinoptions` |

**Security**
| Current Met | New Met | Notes |
|---|---|---|
| SET_PSTranscription | `NX_SetPSTranscription` | GPO/registry-only |
| SET_Telemetry | `ST_SetTelemetry` | confirmed: `ms-settings:privacy-feedback` |
| SET_LLMNR | `NX_SetLLMNR` | GPO/registry-only |
| SET_PSScriptBlock | `NX_SetPSScriptBlock` | GPO/registry-only |
| SET_PSModuleLogging | `NX_SetPSModuleLogging` | GPO/registry-only |
| SET_NetBIOS | `CP_SetNetBIOS` | Network adapter Properties > IPv4 > Advanced > WINS tab |
| SET_RealTimeProt | `WS_SetRealTimeProt` | Windows Security > Virus & threat protection |
| SET_RealTimeProtUI | `WS_SetRealTimeProtUI` | confirmed: `windowsdefender://threat` |
| SET_PUABlockApps | `WS_SetPUABlockApps` | Windows Security, exact sub-page **[verify]** |
| SET_PUABlockDLs | `EG_SetPUABlockDLs` | Edge > Privacy, search, and services > Security |
| SET_MemoryInteg | `WS_SetMemoryInteg` | Windows Security > Device security > Core isolation |
| SET_KernelMode | `WS_SetKernelMode` | Windows Security > Device security > Core isolation details |
| SET_LocalSecurity | `WS_SetLocalSecurity` | "LSA protection" toggle is build-version-dependent **[verify]** |
| SET_FirewallON | `WS_SetFirewallON` | Windows Security > Firewall & network protection |
| SET_SmartScreenReg | `WS_SetSmartScreenReg` | confirmed: `windowsdefender://appbrowser` |
| SET_StoreSmartScreen | `ST_SetStoreSmartScreen` | Settings > Privacy & Security > General **[verify]** |
| SET_PhishingProtection | `WS_SetPhishingProtection` | confirmed: `windowsdefender://appbrowser` |
| SET_HideAdmin | `NX_SetHideAdmin` | no GUI control exists |
| SET_AdvertisingID | `ST_SetAdvertisingID` | Settings > Privacy & Security > General |

**User Interface**
| Current Met | New Met | Notes |
|---|---|---|
| SET_ClassicMenu | `NX_SetClassicMenu` | no Settings page; visible only via desktop right-click |
| SET_TaskbarSearch | `ST_SetTaskbarSearch` | Settings > Personalization > Taskbar |
| SET_TaskViewOFF | `ST_SetTaskViewOFF` | Settings > Personalization > Taskbar |
| SET_ShowHidden | `FE_SetShowHidden` | File Explorer > View > Show |
| SET_ShowExtensions | `FE_SetShowExtensions` | File Explorer > View > Show |
| SET_UIAnimations | `ST_SetUIAnimations` | Settings > Accessibility > Visual effects |
| SET_VisualEffects | `CP_SetVisualEffects` | legacy Performance Options dialog (`SystemPropertiesPerformance.exe`) |

**Maintenance**
| Current Met | New Met | Notes |
|---|---|---|
| RUN_UpdateSuite | `ST_RunUpdateSuite` | also touches Microsoft Store; ST is primary surface |
| RUN_OptimizeDisks | `CP_RunOptimizeDisks` | legacy Optimize Drives dialog (`dfrgui.exe`) |
| RUN_SystemCleanup | `ST_RunSystemCleanup` | Settings > System > Storage > Temporary files |
| RUN_WindowsRepair | `NX_RunWindowsRepair` | console-only (sfc/DISM), no GUI |

## Execution Steps

1. Verify the **[verify]** items live (open the actual page on this machine via
   `Start-Process ms-settings:...` / Windows Security, confirm exact location), correct the
   mapping table above as needed.
2. Update the four array literals in `wa.ps1` (`$autoItems`, `$secItems`, `$uiItems`,
   `$maintModel`) — change only the `Met = "..."` values, nothing else in each hashtable.
3. Rename each `AtomicScripts/*.ps1` file to match (`git mv` to preserve history).
4. Add/standardize the `UI Location:` line in each function's comment-based help in `wa.ps1`
   and the matching header comment in each renamed `AtomicScripts/*.ps1` file.
5. Decide and handle the two orphaned `AtomicScripts` files (flagged above) — likely a
   one-line note to the user rather than an in-scope fix.
6. Append a dated entry to `docs/HISTORY.md` per [CLAUDE.md](CLAUDE.md) §6, and document the
   convention itself (surface-code dictionary + format) somewhere durable — recommend adding
   a short section to `CLAUDE.md` so future steps follow the same scheme.

## Verification

- `PSParser.Tokenize` syntax check on `wa.ps1` after edits (same check used in prior sessions).
- Run the script interactively (or `-Module SmartRun -Silent` dry run) and confirm the
  dashboard renders all renamed Met IDs without overflowing the 52-wide box — spot check the
  longest new IDs (`WS_SetPhishingProtection`, `ST_SetStoreSmartScreen`).
- Diff `AtomicScripts/` before/after to confirm every file was renamed (not duplicated) and
  none were accidentally orphaned.
