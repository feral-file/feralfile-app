# MCP Prompt for UI Code Generation from Figma Design

## Description

Generate Flutter widgets, based strictly on the provided Figma design. The output must be pixel-perfect and match the Figma layout exactly.

## Requirements

1. Read the entire prompt carefully before starting.
2. Create a checklist and apply all rules from the very first implementation.
3. Review against the checklist before finalizing.

## Rules

- Extract **Figma properties** directly from the design.
- Only use layout properties explicitly defined in Figma (e.g., justifyContent, alignItems, gap). If a property is not in Figma, do not add it automatically (e.g., items-center).
- Do not add responsive patterns or make layout assumptions beyond what Figma specifies.
- Preserve exact dimensions and positions from Figma (do not round if it impacts accuracy).
- Avoid hardcoding width and height values in layouts; these should only be applied to images, icons, and logos.
- Always use the built style tokens (/lib/design/build, /lib/design/build/components). If no utility exists, use a custom value.
- Allowed Figma Properties for Variable Linking:
  - If the design links one of FIGMA_VARIABLE_PROPERTIES to a Figma Variable, please check the built style tokens and use that in the code.
  - If no variable is linked, must skip that style entirely (do not hardcode).
- Export grouped images/vectors as a single file in corresponding file types.
- Apply the font family only when it differs from PP Mori.
- Break down the UI into smaller, reusable components if necessary, naming them appropriately and meaningfully.
- Keep the code clean, readable, and modular.
- No unnecessary comments.

## Output Requirements

- Clean, modular code matching the Figma layout.
- Responsive behavior across all devices (desktop, tablet, mobile)

## Design Token Strategy

**Token-First Approach**: Always look for an exact built style tokens match before using a custom value.
**Accuracy Over Convenience**: If Figma provides non-rounded values (e.g., 13.93px), use them exactly rather than approximating with the closest token.

## Input

A Figma node URL must be provided in the invoking file.

## Stack

Next.js + Tailwind CSS

## Allowed Figma Properties for Variable Linking

```ts
const FIGMA_VARIABLE_PROPERTIES = [
  'width',
  'height',
  'gap',
  'padding',
  'margin',
  'fontSize',
  'fontWeight',
  'fontFamily',
  'lineHeight',
  'letterSpacing',
  'color',
  'backgroundColor',
  'borderRadius',
  'borderWidth',
  'borderColor',
  'opacity',
  'boxShadow',
];
```
