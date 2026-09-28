# ModernUI (Classic Era 1.15.9+)

A WoW **Classic Era** (1.15.9+ / Interface 11509) addon that recreates the **retail (Midnight / Dragonflight+)** UI 1-for-1 on the Classic Era client.

## Goal

Make Classic Era look and behave like retail. Every frame, button, and panel should match retail as closely as the Classic Era client allows. Use retail Blizzard source as the design reference.

Two strategies, chosen per frame:

- **Reskin in place** — preferred when the native frame is secure, ESC-handled, UIPanel-managed, or deeply wired into Blizzard systems (ActionBars, Chat, GameMenu, Options, AddonList, UnitFrames). Keep the native frame, hide its visuals, overlay our border + widgets, hook its update functions with `hooksecurefunc`.
- **Rebuild from scratch** — for frames that are largely visual / non-secure (Spellbook, Talent tree, Character sheet panels, etc.). Hide the native frame entirely and show our own implementation alongside. Toggle via our own code or by hooking the show path.

Decide on a case-by-case basis; if in doubt, reskin first. Rebuilding replaces all the behaviour too, so the cost is higher.

## Sources of truth

- **This repo** — code is authoritative; comments and memory are snapshots that may drift.
- **Retail Blizzard source** — `D:\Games\World of Warcraft\_retail_\BlizzardInterfaceCode` — the target look and behaviour we're replicating.
- **Classic Era Blizzard source** — https://github.com/Gethe/wow-ui-source/tree/classic_era — the actual frames and functions we're hooking / modifying. Local clone: `D:\tmp\wow_interface\classic_era_1_15_9\Interface\AddOns` (`version.txt` = build; `git pull` to refresh). **Check it matches the client build** (`D:\Games\World of Warcraft\.build.info`, product `wow_classic_era`) before trusting it — a patch can rename half the UI.
  - The clone holds every flavor side by side. Only files whose TOC line loads for game type `vanilla` / `classic` exist on Era (`[Family]` = Classic, `[Game]` = Vanilla; TOC preference `_Vanilla.toc` > `_Classic.toc` > plain). Never cite a `Mainline/` file for Era.
  - `Blizzard_APIDocumentationGenerated` there is generated from the Era client — anything documented in it definitely exists.

## Architecture

Module system rooted in `MUI_Core`:

- `MUI_Core/` — class system (`MUI_Lua.lua`), module framework (`Module`), DB, helpers
- `MUI_Shared/` — reusable widget classes (`Frame`, `Texture`, `FontString`, `Button`, `AnimatedBar`, `MinimalScrollBar`, `Panel`, `DiamondBorder`, `MetalBorder`, …)
- `MUI_<Name>/` — one folder per UI element (ActionBars, BuffBar, Bags, Chat, CastBar, UnitFrames, Minimap, MicroMenu, GameMenu, Options, XPBar)
- `assets/` — textures, fonts
- Atlas metadata in `MUI_Shared/MUI_AtlasRegistry.lua`

### Class conventions

- `C` prefix: `Frame`, `Button`, `ActionBar`, `Module`, `ModuleChat`, …
- No trivial getters/setters — fields are public, accessed directly
- Never `local selfRef = self` — Lua 5.1 closures capture `self` cleanly
- Every module inherits `Module` and exposes an `OnEnable` that runs at `PLAYER_LOGIN`
- Class declaration syntax — bareword string for single inheritance, table for multi:
  ```lua
  class "Foo" : extends "Base" { … }
  class "Frame" : extends {"Widget", "ScriptObject"} { … }
  ```
  Note the space before `extends`. Plain `class "Foo" { … }` for no base.

### Widget rules — CRITICAL

**Never use raw WoW API calls outside base widget classes.**

- No raw `SetPoint`, `SetTexture`, `SetWidth`, `CreateTexture`, `CreateFontString`, `SetTexCoord`, etc. in module / skin code
- No `frame.native:METHOD(...)` in module / skin code or in non-base Shared widgets — go through wrapper methods
- Always use OOP wrappers: `Frame`, `Texture`, `FontString`, `Button`, `Line`
- Wrap an existing native: `Frame(nativeFrame)` / `Texture(nativeTexture)` / `FontString(nativeFS)`
- If a wrapper method doesn't exist, **add it to the base class first** (then call the wrapper, never the raw `.native:`)
- Raw API and `self.native:METHOD(...)` are ONLY allowed inside: `Widget.lua`, `Frame.lua`, `Texture.lua`, `FontString.lua`, `Button.lua`, `Line.lua`. Frame hosts wrappers for EditBox / Slider / StatusBar methods (with `if self.native.X then …` guards) so non-base widgets that wrap those primitives still call through the wrapper.

**Exception:** when positioning native secure Blizzard frames relative to other native frames — `SetPoint` is fine because we can't always wrap both sides.

### Layout helpers

Always use layout helpers (`AlignParentTop`, `CenterInParent`, `RightOf`, `Below`, `FillParent`, …) instead of raw `SetPoint` for our own frames.

### Shared constants

`MUI_Core/MUI_Constants.lua` exposes `MUI.FONT`, `MUI.TEX_BASE`, `MUI.TEX_SKIN`. Use these instead of redeclaring path strings — never `local MUI_FONT = "Interface\\AddOns\\..."` or `local TEX = "Interface\\AddOns\\..."` per file.

### Event registration

Use `cframe:RegisterEventHandler("EVENT", handler)` for all event subscriptions — never `frame.native:RegisterEvent` + `SetScript("OnEvent", …)`. Multiple `RegisterEventHandler` calls on the same frame compose into one internal `OnEvent` dispatcher.

## Classic Era API quirks

### 1.15.9 rewrite — shared mixin UI + Blizzard Edit Mode
1.15.9 moved Era onto the retail 12.0 engine and the shared (retail-style) FrameXML. Anything written against 1.15.8 or earlier — including older comments in this repo — may name things that no longer exist.

- **Global `Foo_Update(frame)` functions became mixin methods** (`TargetFrame:Update()`, `StanceBar:UpdateState()`, `PetActionBar:Update()`, `BuffFrame:UpdateAuraButtons()`, action button `:Update()` / `:OnEvent()` …). Mixins are *copied onto each frame at creation*, so hooking the mixin table does nothing for existing frames — hook the **instance**: `hooksecurefunc(TargetFrame, "Update", fn)`. Only `self:Method()` / `frame:Method()` call sites are hookable this way; a direct `SomeMixin.Method(self)` call is not — read how Blizzard invokes it first.
- **Edit Mode is live on Era.** Systems: `MainActionBar`, `MultiBar*`, `StanceBar`, `PetActionBar`, `PlayerFrame`, `TargetFrame`, `FocusFrame`, `PetFrame`, `PartyFrame`, `MinimapCluster`, `BuffFrame` / `DebuffFrame`, `ChatFrame1`, `MicroMenuContainer`, `BagsBar`, `PlayerCastingBarFrame`, `DurabilityFrame`, `MainStatusTrackingBarContainer`, … `EditModeSystemMixin:OnSystemLoad` **replaces the instance's `SetPoint` / `ClearAllPoints` / `SetScale` / `SetShown` / `Hide` with Lua overrides** that write Edit Mode state (`snappedFrames`, anchor-dirty flags) and rescale every anchor offset by old/new scale. Calling them from addon code runs that Lua under taint and corrupts saved layouts at scale ≠ 1.
  - Move/scale a system frame only through the C-method wrappers on `Frame`: `RawAddPoint`, `RawClearAllPoints`, `RawSetScale` (plus `RawSetPoint`, `RawSetDrawOrder`). Subclass pattern: `UnitFrameEditable` (MUI_UnitFramePlayer.lua), `DurabilityEditable` (MUI_Minimap.lua), `ChatFrame` (MUI_ChatFrame.lua) override `SetPoint` / `ClearAllPoints` / `SetScale` so every layout helper goes raw.
  - Blizzard re-anchors and re-scales a system on every layout apply: `hooksecurefunc(<frame>, "UpdateSystem", …)` and re-apply ours (`MUI_EditMode:ReassertLayout`); defer while `InCombatLockdown()` for protected frames.
  - Managed frames (`PetFrame`, `DurabilityFrame`) are also re-parented / laid out by `PlayerFrameBottomManagedFramesContainer` / `UIParentRightManagedFrameContainer`; `frame.ignoreFramePositionManager = true` opts out, but Edit Mode's `ApplySystemAnchor` clears it — set it again after `UpdateSystem`.
  - `UIPARENT_MANAGED_FRAME_POSITIONS` is gone; `UIParent_ManageFramePositions` still exists.
- **Deprecated globals are CVar-gated shims.** Everything in `Blizzard_Deprecated*` starts with `if not GetCVarBool("loadDeprecationFallbacks") then return end` and is slated for deletion: `UnitBuff` / `UnitDebuff` / `UnitAura`, `HasAction` / `IsActionInRange` / `GetActionBarPage` / `GetActionTexture` …, `GetItemInfo` / `GetItemCount`, `IsSpellKnown` / `IsPlayerSpell`, `GetTalentTabInfo` / `GetTalentInfo` / `GetActiveTalentGroup`, `GetCoinTextureString`, `CombatLogGetCurrentEventInfo`, `NUM_CHAT_WINDOWS` / `MAX_WOW_CHAT_CHANNELS`. Use the documented replacement (`C_UnitAuras`, `C_ActionBar`, `C_Item`, `C_SpellBook`, `C_SpecializationInfo`, `C_CurrencyInfo`, `C_CombatLog`, `Constants.ChatFrameConstants`) and mirror the shim body for argument / return order.
- **Removed outright (no shim):** `SetPortraitToTexture` (→ `Texture:SetPortrait` / `:ClearPortrait`, which attach a real `MaskTexture` of `Interface\\CharacterFrame\\TempPortraitAlphaMask` anchored to the icon, like Blizzard's portrait templates. Don't use the string form `tex:SetMask(file)` on an icon that also has `SetTexCoord` — it samples the mask through the texture's UVs and stretches. The engine also throws *"Cannot set tex coords when texture has mask"* if `SetTexCoord` runs while a mask is attached (a mask added after the texcoords is fine); the `Texture` wrapper lifts its portrait mask around every texcoord write, so go through the wrapper, never raw `native:SetTexCoord`, on an icon that may be round), `GetWatchedFactionInfo` (→ `C_Reputation.GetWatchedFactionData()` table, nil / `name == ""` = none watched), setting `alwaysShowActionBars`, event `LEARNED_SPELL_IN_TAB` (→ `LEARNED_SPELL_IN_SKILL_LINE`, same payload; registering an unknown event throws).
- **Addon `SecureActionButtonTemplate` buttons only act on a DOWN click by default.** The retail `SecureActionButton_OnClick(self, button, down, isKeyPress, isSecureAction)` never receives the last two args for addon buttons, so it falls back to `GetCVarBool("ActionButtonUseKeyDown")` and ignores `down == false` — a button registered for `AnyUp` silently does nothing (macros, `/click` chains, spell casts). Our `SecureActionButton` class sets the per-button attribute `useOnKeyDown = false` to opt out; anything made from the raw template must do the same (or register `AnyDown`). `_onclick` snippets (`SecureHandlerClickTemplate`) are not gated, and `/click Name [button] [down]` defaults `down` to false.
- **Native `FontString:GetStringWidth()` is bounded by the FontString's current width** (it measures the truncated "7..." rendering). `fs:SetWidth(fs:GetStringWidth())` on a reused label therefore ratchets narrower forever. Our `FontString:GetStringWidth` wrapper returns `GetUnboundedStringWidth()` — the natural single-line width every caller wants; add a `GetWrappedWidth` wrapper if a wrapped measure is ever needed. Even so, **don't exact-fit a label that lives on a frame whose scale changes** (nameplates grow ×1.3 when targeted): glyph advances round differently at each render size, so a width measured at one scale truncates to "..." at another. Use `SetWidth(0)` (auto-size) or a generous fixed width there.
- **A frame sized to 0 has no edge on that axis.** `SetHeight(0)` / `SetSize(w, 0)` means "height unset", so anything anchored `Below` / `Above` it loses that anchor and falls back to its remaining ones (the target cast bar landed on the mana bar when the aura container computed to 0 rows). Collapse a spacer/container to `0.1`, never `0` — or clamp a computed size with `math.max(h, 0.1)`. FontStrings are the exception: width 0 there means auto-size.
- Era ships the Midnight secret-value API (`C_Secrets`, `C_RestrictedActions`). `C_Secrets.HasSecretRestrictions()` says whether the build enforces it.

### Lua / event plumbing
- Lua 5.1: `...` instead of `arg` / `unpack(arg)`; no `this` / `arg1` globals
- Event handlers: `function(frame, event, ...)`
- OnUpdate handlers: `function(frame, elapsed)`

### Unit / power
- `UnitMana` → `UnitPower`, `UnitManaMax` → `UnitPowerMax`
- `UNIT_RAGE` / `UNIT_ENERGY` / `UNIT_FOCUS` / `UNIT_MANA` → single `UNIT_POWER_UPDATE`
- `UnitIsTapped` / `UnitIsTappedByPlayer` → `UnitIsTapDenied` (inverted semantics)
- **HP info is clamped 0-100 for other PLAYERS** (not you, not party/raid, not NPCs). Mana returns real values. For other-player health text, show percentage.

### Frame / template names (Classic Era)
- Stance bar: `StanceButton1..10` / `StanceBar` / `StanceBar:UpdateState()`. Stance and shapeshift are the same bar — only pet is separate (`PetActionBar` / `PetActionButton1..10` / `PetActionBar:Update()`).
- Target frame children live under a `TextureFrame` subframe (`TargetFrame.textureFrame`):
  - `TargetFrameTextureFrameTexture`, `TargetFrameTextureFrameLevelText`, `TargetFrameTextureFrameDeadText`, `TargetFrameTextureFramePVPIcon`
  - 1.15.9 added native status text there (parentKeys `HealthBarText[Left|Right]`, `ManaBarText[Left|Right]`) and a threat flash (`TargetFrameFlash`) — hide them or they draw over ours.
- Target-of-target is created dynamically as `TargetFrameToT` with children `TargetFrameToTHealthBar` / `TargetFrameToTTextureFrame{Name,Texture,DeadText}` / `TargetFrameToTPortrait`.
- Unit-frame hooks are instance methods: `TargetFrame.Update` / `.CheckClassification` / `.UpdateAuras`, `TargetFrameToT.Update`, `PetFrame.Update`. `PlayerFrame_UpdateStatus` and `ComboFrame_Update` are still globals. The `*_UpdateLevelTextAnchor` functions are gone — nothing re-anchors the level text any more.
- `PlayerFrame_ToPlayerArt` runs on **every** `PLAYER_ENTERING_WORLD` (each loading screen, not just login): it re-`Show()`s `PlayerFrameTexture`, adds a `CENTER` anchor to `PlayerName`, re-sizes the native bars. A one-shot `Hide()` at setup therefore only survives until the first teleport — blank native art with `SetTexture("")` (Blizzard never re-sets that file) and re-apply anchors from a `hooksecurefunc("PlayerFrame_ToPlayerArt", …)`.
- Pet debuffs are pooled buttons inside `PetFrame.AuraFrameContainer` (no `PetFrameDebuff1`).
- Player cast bar is `PlayerCastingBarFrame` (no `CastingBarFrame`).
- XP / reputation bars are pooled inside `StatusTrackingBarManager` (`MainStatusTrackingBarContainer` / `SecondaryStatusTrackingBarContainer`); `MainMenuExpBar`, `ReputationWatchBar`, `ExhaustionTick` are gone. `MAX_PLAYER_LEVEL` stays 0 on Era — use `IsPlayerAtEffectiveMaxLevel()`.
- Game menu is the retail pooled list: `GameMenuFrame.buttonPool:EnumerateActive()`, ordered by `layoutIndex`, `topPadding` marks a section; rebuilt on show and laid out a frame later, so act from a `GameMenuFrame.Layout` hook. No `GameMenuButton*` globals.
- Minimap's parent is `MinimapCluster.MinimapContainer` (Edit Mode moves / scales it); header art is `MinimapCluster.BorderTop`.
- Bag buttons are children of the `BagsBar` system, whose `Layout()` re-anchors them on Edit Mode apply **and on every cursor item pickup / drop**. `KeyringMixin:OnShow` calls `GetParent():Layout()`.
- Player buffs: `BuffFrame.auraFrames` / `DebuffFrame.auraFrames` (pre-created; skip `isAuraAnchor`), children are parentKeys (`Icon`, `Duration`, `Count`); hook `BuffFrame.UpdateGridLayout` / `.UpdateAuraButtons`, `DebuffFrame.UpdateGridLayout`. No `BuffButtonN` globals.

### Spellcast events
- `SPELLCAST_*` → `UNIT_SPELLCAST_*`
- Args: `(unit, castGUID, spellID)`; get spell info via `UnitCastingInfo("player")` / `UnitChannelInfo("player")` → `(name, text, texture, startTime_ms, endTime_ms, …)`
- Show `text` (2nd return) on a cast bar, as Blizzard's `CastingBarMixin` does — `name` is the internal spell name, which for some object interactions is literally `"Opening - No Text"`.

### Action bars
- Bars are `ActionBarMixin` frames: `MainActionBar`, `MultiBarBottomLeft` / `BottomRight` / `Right` / `Left` (+ `MultiBar5..7`), `StanceBar`, `PetActionBar`. Each button is created in `ActionBar_OnLoad` as a child of a per-button `<Bar>ButtonContainer<i>` frame and anchored `CENTER` to it once. Blizzard lays out / shows / scales the **containers**, never the buttons — so anchoring the buttons to our bars survives Blizzard layout. Legacy button names are kept: `ActionButton1..12`, `MultiBarBottomLeftButton1..12`, `StanceButton1..10`, `PetActionButton1..10`. No `BonusActionButton`s: stance paging swaps `actionpage` on the 12 main buttons.
- `MainMenuBar` / `MainMenuBarArtFrame` / `MainMenuBarTexture0..3` / end caps still exist as art only; Blizzard toggles `MainMenuBar` vs `MainActionBar.EndCaps` in `UpdateEndCaps`. Page arrows are `MainActionBar.ActionBarPageNumber` (`.UpButton`, `.DownButton`, `.Text`). Stance / pet art: `StanceBar.BackgroundArtLeft|Middle|Right`, `PetActionBar.BackgroundArt1|2` — Blizzard re-shows all of these via `SetShown`, so blank them with `SetTexture(nil)` rather than `Hide`.
- Button regions are parentKeys on `ActionButtonTemplate`: `icon`, `IconMask`, `SlotBackground` (`UI-Quickslot @ 0.4`, on **every** button — replaces `$parentFloatingBG`), `NormalTexture`, `Name`, `Border`, `Flash`, `cooldown`, `AutoCastOverlay` (frame: `.Corners` + shine sparkles; replaces `$parentShine` / `$parentAutoCastable`), `HotKey` / `Count` (live in a level-500 `TextOverlayContainer` child, aliased onto the button). No `NormalTexture2`.
- Every real action button registers with `ActionBarButtonEventsFrame`; `ActionBarButtonEventsFrame:ForEachFrame(fn)` enumerates them all. Events reach buttons as `frame:OnEvent(event, …)` from that frame, so per-button `hooksecurefunc(btn, "Update" | "OnEvent", fn)` sees everything. Stance / pet buttons have no `Update` method — hook `StanceBar.UpdateState` / `PetActionBar.Update`.
- Multibar pages: `BOTTOMLEFT = 6`, `BOTTOMRIGHT = 5`, `RIGHT = 3`, `LEFT = 4`.
- Native empty-slot visibility is the `showgrid` **secure attribute** (bit flags: event drag / per-bar "Always Show Buttons" Blizzard Edit Mode setting, default **off** in the Classic presets), set via `bar:SetShowGrid(show, reason)` — addon code can't write it (`SetShowGrid` is gated on `issecure()`). The old global "Always Show Action Bars" option and `MultiActionBar_UpdateGridVisibility` are gone.
  - So "Always Show Buttons" is **our own per-bar setting**: a checkbox in each multibar's MUI Edit Mode settings panel (`ActionBarEditable:EditModeAddAlwaysShowButtons`), default on, persisted with the bar's layout (`alwaysShowButtons = false` stored only when off). It drives our slot art only; a stripped native empty button is invisible either way, and Blizzard still shows the native grid during a drag so drops work.
- Options that 1.15.9 moved out of the Options panel into Blizzard's Edit Mode (unreachable from our Game Menu, still reachable with `/editmode`): "Always Show Action Bars" (above), "Rotate Minimap" (`MinimapFrame` has our own checkbox; Blizzard's `MinimapCluster:SetRotateMinimap` rewrites the CVar on every layout apply, so we re-assert from a hook on it), "Use Raid-Style Party Frames" (not ours — party frames aren't skinned).
- Bar visibility: `Settings.GetValue("PROXY_SHOW_ACTIONBAR_2..5")` — wrappers `MultiBar1_IsVisible()..MultiBar4_IsVisible()` expose them. `MultiActionBar_Update` is still a global — hook it to sync our ActionBar wrappers.
- `button.action` is the paged action ID (`button:GetPagedID()` just returns it); `CalculateAction` derives it from the `actionpage` attribute up the parent chain.
- Page number: `C_ActionBar.GetActionBarPage()`; paging via `ActionBar_PageUp()` / `ActionBar_PageDown()`.

### Buff / debuff
- Auras: `C_UnitAuras.GetBuffDataByIndex(unit, i)` / `GetDebuffDataByIndex` return an AuraData table or nil (`icon`, `applications`, `dispelName`, `sourceUnit`, `duration`, `expirationTime`, …). Debuff colors: `AuraUtil.GetDebuffDisplayInfoTable()[dispelName or "None"].color` (`DebuffTypeColor` is gone).
- Target buff frames are created dynamically via `TargetBuffFrameTemplate` as `TargetFrameBuff<i>` / `TargetFrameDebuff<i>` (+ `Icon` / `Count` / `Border`). **Do not manually `CreateFrame`** them — you'd get bare buttons missing `Count`/`Stealable`/etc. and break `TargetFrame:UpdateAuras`.
- Do **not** write `MAX_TARGET_BUFFS` / `MAX_TARGET_DEBUFFS` — writing a Blizzard global taints every subsequent `TargetFrame:UpdateAuras`. Use local constants.
- Hook `TargetFrame.UpdateAuras` (instance) for aura layout.
- Buff size: Blizzard uses `LARGE_AURA_SIZE` (21) for your own and `SMALL_AURA_SIZE` (17) for others'. Call `SetSize(ICON, ICON)` explicitly for uniform layout.

### Chat
- `ChatFrame1` is an Edit Mode system: `ChatFrame1:UpdateSystem()` re-anchors **and re-sizes** it on every layout apply (`FCF_RestorePositionAndDimensions` now skips the default frame). Hook `ChatFrame1.UpdateSystem` plus `FCF_DockUpdate` to re-apply our anchor and size, through the raw C geometry methods.
- ScrollingMessageFrame has **no** text-inset API. To add padding, shrink the frame and re-anchor `Background` to extend beyond (plus re-apply from a `FloatingChatFrame_UpdateBackgroundAnchors` hook).
- Scroll: `SetScrollOffset` / `GetScrollOffset` (line-based, multi-line-aware). Max offset = briefly `ScrollToTop()` → `GetScrollOffset()` → restore.
- `MinimalScrollBar` template expects a `ScrollBox` target; ScrollingMessageFrame doesn't fit. We use our `MinimalScrollBar` and wire manually.
- Fading: Blizzard fades individual bg textures via `FCF_FadeIn/FadeOutChatFrame` — hook those, not the frame itself, to sync overlays.
- Tab rest alpha: `CHAT_FRAME_TAB_SELECTED_NOMOUSE_ALPHA` / `CHAT_FRAME_TAB_NORMAL_NOMOUSE_ALPHA` (default 0).
- Class-colored sender names: `SetChatColorNameByClass(type, true)` (public API, persists through chat-config reloads). Channel types are `CHANNEL1..CHANNEL20`.

### Dock / tabs
- `GeneralDockManager:SetPoint("BOTTOMLEFT", chatFrame, "TOPLEFT", 0, 6)` is the default dock anchor — adjust if you resize chat vertically.
- `ChatFrame1ButtonFrame` uses `VerticalLayoutFrame` (LayoutMixin) that auto-positions children by `layoutIndex` KeyValues. To pull a child out: `btn.layoutIndex = nil; btn.ignoreInLayout = true; btn:SetParent(UIParent)`.

### Settings / CVars
- Unit-frame status text mode: `GetCVar("statusTextDisplay")` → `"NUMERIC"` / `"PERCENT"` / `"BOTH"` / `"NONE"`.
- React to user changes via `CVAR_UPDATE` event.
- Nameplate options live in their own category `Settings.NAMEPLATE_OPTIONS_CATEGORY_ID` (not Interface). Blizzard no longer references the `nameplateGlobalScale` CVar — size is `nameplateSize` (1-5); we scale our own plate visuals instead.
- `AddonList` and `SettingsPanel` use `ButtonFrameTemplate` — `NineSlice`, `Bg`, `Inset`, `TitleContainer`, `PortraitContainer`, border / corner regions.
  - `SettingsPanel.CloseButton` is the **bottom** "Close" action button (UIPanelButton). The **top-right X** is `SettingsPanel.ClosePanelButton` (from `SettingsFrameTemplate`, inherits `UIPanelCloseButtonDefaultAnchors`). Reskin ClosePanelButton for the X — don't hide either.

## Taint (protected-action blocks)

Combat errors of the form *"Interface action failed because of an AddOn"* come from **taint**. Diagnose with `/console taintLog 2`, reproduce, then read `Logs/taint.log`. Lines starting with `An action was blocked in combat because of taint from ModernUI — X` are the real problems; `Global variable X tainted` / `Execution tainted while reading Y` warnings are mostly harmless unless followed by a block.

### Rules

1. **`hooksecurefunc` over replacement.** Never `SomeBlizzardFunction = function(...) ... end`. Blizzard's secure callers would resolve to our insecure closure, tainting every subsequent secure call. Use `hooksecurefunc("SomeBlizzardFunction", function(...) ... end)`.
2. **Never `SetParent`** on a secure frame (action buttons, unit frames, target-buff buttons) from addon code. `SetParent` marks the frame addon-modified; secure reads later taint. Position via `SetPoint` cross-parent instead.
3. **Never `Hide` / `Show`** a secure button from inside a `hooksecurefunc` callback of a secure-path function. Toggle our own non-secure overlays (bg/border textures) instead.
4. **Never `SetAttribute`** on a secure frame from addon code. Attributes marked addon-modified propagate taint when secure code reads them via `SecureButton_GetModifiedAttribute`.
5. **Writing Blizzard globals** (`MAX_TARGET_BUFFS`, `ToggleGameMenu`, `UpdateMicroButtons`, `ActionButton_Update`, …) taints them. Reading is fine. Use `hooksecurefunc` for functions; for constants, use your own locals.
6. **Reskin, don't replace.** Keep Blizzard frames as containers (so ESC / `ShowUIPanel` / `ToggleGameMenu` keep working); hide native children, overlay your own border + buttons on top.
7. **Never call `SetPoint` / `ClearAllPoints` / `SetScale` on a Blizzard Edit Mode system frame through its instance methods** — they are Lua overrides that write Edit Mode state under our taint. Use the `Raw*` C-method wrappers (see "1.15.9 rewrite").
8. **A protected frame parented under, or anchored to, one of our frames makes that frame's `Show` / `Hide` / `SetPoint` / `SetSize` protected in combat too** (the multibars with Blizzard buttons anchored to them; quest rows when they were `SecureActionButtonTemplate`). Keep secure buttons out of any frame tree that must reflow in combat: the tracker's quest item buttons (`QuestTrackerItemButton`) are a root-parented pool seated by absolute offsets from each block's rect, re-bound / moved / shown / hidden only out of combat, with cooldown + range kept live.

## File + reload rules

- New `.lua` / texture files → **full client restart** required, not just `/reload`.
- Modifications to existing files → `/reload`.
- `MUI_SavedVars` lives in `WTF/Account/<ACCOUNT>/<Realm>/<Character>/SavedVariables/ModernUI.lua` — wipe to test fresh-install defaults.

## Code style

- No functions defined outside class bodies in module files — everything as class methods. Exception: small local helpers at file top (`local function CollectButtons() … end`).
- No unnecessary abstractions, helpers, or future-proofing — solve the problem at hand.
- No added comments, docstrings, or type annotations to code you didn't change.
- Don't add error handling for scenarios that can't happen.
- One concise `-- Section` comment per logical block is fine; multi-paragraph prose isn't.
