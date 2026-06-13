# AtomicScripts Visual Identity & Style Guide

This document outlines the visual standards and UI conventions for the **AtomicScripts** suite (specifically `wa.ps1`). These rules ensure consistency across all scripts for branding, marketing, and user experience.

## 1. Color Palette & Functional Usage

| Color | ANSI Variable | Purpose / Usage |
| :--- | :--- | :--- |
| **Cyan** | `$Global:FGCyan` | **Action & Pending Execution.** Used for cursors (`>`, `<`), the active `v` icon, and the "Atomic Script" Method ID for items that **will run**. Also used for the dashboard's top/bottom frame. |
| **Inverted Cyan** | `$FGBlack$BGCyan` | **Execution Indicator.** Black text on a Cyan background indicates a line that will execute a major phase (Smart Run, Manual Mode, Configure, or Maintain) when **Enter** is pressed. Also used for the **Esc** and **Enter** keys in the footer. |
| **White** | `$Global:FGWhite` | **Enabled / Compliant.** Used for the `v` icon and step titles (e.g., 'Real-Time Protection') for items that are either **already enabled** (compliant) OR are **pending an enable action**. |
| **Gray** | `$Global:FGGray` | **Structural Framework.** Used for boundary lines (`_`), dashed separators (`-`), and info brackets `[ ]`. Also used for step titles when they have an empty `[ ]` box (Disabled). |
| **Dark Gray** | `$Global:FGDarkGray` | **Inactive / Non-Execution.** Used for titles, brackets, and method IDs of steps that **will not be run** with the current logic. Also used for entire sections when they are not currently being navigated. |

## 2. Structural Elements & Information Brackets

*   **Information Brackets (`[ ]`):** These boxes indicate the discovered system state and the user's intended action.
    *   **Initial Discovery State (Prior to Toggle)**:
        *   **`[ ]` (Empty)**: The script has discovered the state is **Disabled** on the computer. The script will **not** include this step in the run unless toggled.
        *   **`[v]` (Checked)**: The computer has the state **Enabled** already. The script will **not** include this step in the run unless toggled.
    *   **User Toggle Actions**:
        *   **Toggle `[ ]` -> `[v]`**: User wants to **Enable** this feature. The script will now run this step.
        *   **Toggle `[v]` -> `[ ]`**: User wants to **Disable/Revert** this feature. The script will set the state to its default value or the opposite binary value.
*   **Action Indicator**: For any step included in the run, the **`v`** icon and the **Atomic Script** Method ID turn **Cyan**. If not included, the Method ID dims to **Dark Gray**.
*   **Selection Cursors:** A Cyan `>` is placed at column 0 and a Cyan `<` is placed at column 55 of the selected line.

## 3. Keyboard Shortcuts & Interaction

| Key | Context | Action |
| :--- | :--- | :--- |
| **Enter** | **Smart Run / Manual Mode** | Executes the full selected sequence (Config + Maintenance). |
| | **Section / Item** | Executes **only** the selected section or specific Atomic Script. |
| **Spacebar** | **Manual Mode** | Enters/Expands the detailed dashboard view. |
| | **Section Header** | **Toggle All** for all items within that specific subsection. |
| | **Individual Step** | **Toggles** the pending action state (flips system state). |
| **Arrows** | **Navigation** | **Up/Down** navigates selection; jumps between section headers. |
| **Esc** | **In-Menu** | **Back (`Esc<=`)**: Clears screen, returns to top-level menu. |
| | **Top Level** | **Exit (`Esc=>`)**: Clears screen, terminates script. |
| **P / Space** | **Execution** | **Pauses** the script when an Atomic Script is running. |
| **Any Key** | **Countdowns** | **Skips** the current transition delay or timer. |

## 4. UI States

*   **Landing Page (Navigation Mode)**: Primary view for navigating `Smart Run` and `Manual Mode`. Focused on high-level choices with generous whitespace.
    *   **Smart Run**: Indented by 22 spaces.
    *   **Manual Mode**: Indented by 20 spaces.
*   **Expanded (Focus Mode)**: Triggered by **Spacebar** on 'Manual Mode'. All 28+ steps are visible.
    *   **Header Shift**: When navigating sub-items, the **`| Manual Mode |`** header stays **Cyan** and **`| Smart Run |`** dims to **Dark Gray**.
    *   **Active Focus**: To maintain focus, the section **not** currently being navigated is rendered entirely in **Dark Gray**, while the active section uses the high-contrast branding palette.
