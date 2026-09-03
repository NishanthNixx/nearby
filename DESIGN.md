# Nearby — Design System

Nearby is a mobile marketplace for booking local services in India. The first
category is tailoring; laundry, bakery, salon and repairs follow. Never write UI
copy that assumes a single trade — the generic nouns are **services**,
**businesses** and **places**.

## Appearance

**Light only.** There is no dark mode. The ground is warm paper, not white and
not grey.

Two reasons, both load-bearing. The app is opened outdoors in daylight, where a
dark screen is hardest to read. And the brand's colour only survives in opaque
foreground fills — on a near-black ground it has to sit in dim atmospheric
layers, where measurement showed four distinct hues compositing to four
near-blacks.

## Colour

| Role | Hex | Notes |
|---|---|---|
| Page background | `#F7F2E9` | warm bone paper — never white, never grey |
| Grouped background | `#F0E9DC` | field fills, inset panels |
| Card / sheet | `#FFFFFF` | |
| Primary text | `#17120C` | 16.69:1 on the ground |
| Secondary text | `#6B5F4F` | 5.58:1 — safe for real information |
| Tertiary text | `#857A6B` | 3.77:1 — decorative only, never unique info |
| Hairline | `#E2D8C4` | dividers and unselected borders |
| **Primary (interactive)** | `#6B3F1D` | saddle brown, 8.00:1 on the ground |
| On primary | `#FFFFFF` | |
| Primary container | `#EFDFC8` | with `#4A2C17` text at 9.65:1 |
| **Accent (informational)** | `#B93217` | rust, 5.33:1 on the ground |
| Accent container | `#FFDCC6` | with `#8A2F0E` text at 6.54:1 |
| Caution container | `#FBE7C6` | with `#7A4408` text, `#8F5406` hairline |
| Error | `#B31239` | |
| Skeleton | `#E6DAC7` | never carries text |

### The hero action

A full-width pill, 56px tall, filled with a left-to-right gradient from
`#7A4420` to `#4A2C17`, white semibold label, no shadow and no border.

This gradient is leather, and brown is not a stylistic preference — it is the
only kind of hue that can do this job. A text-bearing fill has to be dark, and
brown is natively dark, so it reaches APCA Lc 91.7 under white ink at full
chroma. Bright hues cannot: they are either too light to carry a label at all,
or must be darkened until their chroma collapses.

**Disabled drops the gradient entirely** for a flat surface with `#857A6B`
text. A faded gradient still reads as decoration; a flat fill reads as
unavailable.

## Rules

1. **Form separates interactive from factual.** Primary `#6B3F1D` appears only
   as a filled shape or a bold text link. Accent `#B93217` appears only as text
   or a container tint. The two sit 14 degrees apart in hue, so hue cannot do
   this work — form must.
2. **No alpha washes.** Every tinted surface is an opaque hex. Low-opacity
   colour over this warm ground turns to grey sludge — a 10% tint measured
   1.15:1 against the background.
3. **Selection is a fill inversion**, never a glow, shadow or faint tint. A
   selected item becomes a solid brown fill with white text. Glow-based
   selection measured 1.06:1 between states and fails WCAG 1.4.11.
4. **Unselected cards and chips carry a 1px `#E2D8C4` hairline**, because
   white-on-bone is only a 1.12:1 value step.
5. **Body and secondary text stay high contrast.** No light grey text.
6. A tinted container that is nearly the ground's own value — the caution peach
   is 1.09:1 — must pair with a full-strength hairline so its shape is findable.

## Typography

System UI font (SF Pro / Roboto). Use **Inter** where a web font is required.

| Level | Size | Weight | Tracking |
|---|---|---|---|
| Large title | 34 | bold | -0.6 |
| Title 1 | 28 | bold | -0.4 |
| Title 2 | 22 | semibold | -0.3 |
| Title 3 | 20 | semibold | -0.2 |
| Headline | 17 | semibold | -0.2 |
| Body | 17 | regular | -0.1 |
| Callout | 16 | semibold | -0.1 |
| Subhead | 15 | regular | 0 |
| Footnote | 13 | regular | +0.05 |
| Caption | 12 | regular | 0 |

## Spacing and shape

Spacing scale: **4, 8, 12, 16, 20, 24, 32, 40**. Screen side margin is 16.

Radii: 8 small, 12 medium, **16 default**, 24 large, 32 extra large, fully
rounded for pills.

Minimum touch target 44×44. Primary button 56 tall, secondary 48.

## Components

**Text fields** are filled, not outlined. Fill `#F0E9DC`, radius 16, height 56,
16px horizontal padding, 20px leading icon in `#6B5F4F`, hint `#857A6B`. No
border at rest; a 1.5px `#17120C` border on focus, `#B31239` on error.

**Cards** are white, radius 16, 1px `#E2D8C4` hairline, no shadow.

**Chips** are pills. Unselected white with a hairline; selected solid `#6B3F1D`
with white text.

## Brand

The mark is a lowercase **n** in dark brown `#4A2C17` whose right leg tapers
into a calligraphic swash, with a dashed arc curving off its shoulder down to a
map pin in lighter brown `#6B3F1D`. The wordmark is the mark followed by
**NEARBY** in bold, widely letter-spaced caps.

The signature device is a **horizontal dashed rule** in `#6B3F1D`, about 3px
thick with rounded dash ends, sitting under the wordmark. It echoes the icon's
dashed arc — use it instead of a solid divider on brand-forward screens.

## Feel

Warm, tactile, artisanal — leather, thread and kraft paper, the materials of a
workshop. Confident and premium, never playful and never tech-blue. Generous
whitespace. Content is calm; only the primary action is loud.
