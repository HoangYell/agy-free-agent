---
name: rigorous-visual-reviewer
description: Visual verification protocol enforcing real-world browser rendering checks via Chrome DevTools Protocol across Mobile and Desktop viewports.
---

# Rigorous Visual Reviewer & Ground-Truth Verification

Code without visual proof is unverified. This skill defines the mandatory protocol for verifying frontend and UI rendering before completing tasks.

## 1. Real Viewport Verification Matrix
Never rely solely on build success logs or unit tests. Visually inspect components across:
- **Mobile Viewport**: 375x812 (iPhone standard) or 390x844.
- **Desktop Viewport**: 1440x900 (standard laptop resolution).

## 2. Common Visual Defects to Prevent
- **Horizontal Overflow**: Elements leaking past the viewport edge causing horizontal scrolling on mobile.
- **Text Truncation**: Awkward truncation (`...`) or word wrapping inside buttons, headers, or cards.
- **Header Crowding**: Multiple actions overflowing a single mobile header row.
- **Broken Tag Closure**: Unclosed DOM elements breaking layout cascades.

## 3. Chrome DevTools Protocol (CDP) Integration
Use native `chrome-devtools` MCP server tools:
1. `new_page` / `navigate_page` to the target local preview URL (e.g. `http://localhost:4321`).
2. `resize_page` to 375x812.
3. `take_screenshot` to visually inspect mobile layout.
4. `resize_page` to 1440x900 and verify desktop layout.
5. `close_page` when verification is complete.
