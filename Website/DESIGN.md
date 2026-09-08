---
name: Dictate website
description: The incumbent Dictate website and its operating-system download guide.
colors:
  bg: "#f7f6f2"
  surface: "#ffffff"
  raised: "#fbfaf7"
  text: "#151512"
  muted: "#686861"
  subtle: "#8a8981"
  border: "#dddcd5"
  action: "#3155d9"
  dark-bg: "#151512"
  dark-surface: "#20201d"
  dark-raised: "#292925"
  dark-text: "#f3f0e7"
  dark-muted: "#aaa79d"
  dark-subtle: "#858279"
  dark-border: "#3a3a34"
  dark-action: "#7390ff"
  download-hover: "#2544ba"
  amber: "#e5aa2f"
  warm-emphasis: "#f0be4f"
  moss: "#4e7c62"
typography:
  display:
    fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Display", ui-sans-serif, system-ui, sans-serif'
    fontSize: "clamp(3.35rem, 6vw, 6.6rem)"
    fontWeight: 650
    lineHeight: 0.95
    letterSpacing: "-0.06em"
  emphasis:
    fontFamily: 'Georgia, "Times New Roman", serif'
    fontWeight: 400
  download-headline:
    fontSize: "clamp(48px, 7vw, 80px)"
    fontWeight: 500
    lineHeight: 1.02
    letterSpacing: "-0.04em"
  body:
    fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Display", ui-sans-serif, system-ui, sans-serif'
    lineHeight: 1.6
  download-label:
    fontSize: "14px"
    fontWeight: 550
  mono:
    fontFamily: "ui-monospace, SFMono-Regular, Menlo, monospace"
rounded:
  pill: "999px"
  download: "9px"
  disclosure: "8px"
  badge: "5px"
  code: "4px"
spacing:
  download-page: "40px"
  download-mobile: "22px"
  platform: "32px"
  disclosure-inline: "18px"
components:
  button-primary:
    backgroundColor: "{colors.action}"
    textColor: "{colors.surface}"
    rounded: "{rounded.pill}"
    padding: "0.7rem 0.92rem"
  button-secondary:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    rounded: "{rounded.pill}"
    padding: "0.7rem 0.92rem"
  download:
    backgroundColor: "{colors.action}"
    textColor: "{colors.surface}"
    rounded: "{rounded.download}"
    padding: "14px 20px"
  platform-link:
    textColor: "{colors.text}"
    rounded: "{rounded.disclosure}"
    padding: "12px 20px"
  beta-badge:
    backgroundColor: "{colors.raised}"
    rounded: "{rounded.badge}"
    padding: "4px 8px"
  disclosure:
    rounded: "{rounded.disclosure}"
    padding: "0 18px"
  paper-panel:
    backgroundColor: "{colors.surface}"
    padding: "clamp(1.4rem, 3.5vw, 2.6rem)"
---

# Design System: Dictate website

## Overview

**Creative North Star: "A calmer writing instrument"**

Preserve the incumbent warm paper/charcoal website, tightly set system-sans headlines, and Georgia italic emphasis. The `/download` extension translates that vocabulary into readable OS rows and expandable instructions. It is a code-led extension of an existing identity, not a redesign of the site or native app.

**Key Characteristics:**

- Strong typographic hierarchy with blue actions and generous open space.
- Restrained rules and tonal surfaces, with a synthetic product-state preview on the homepage.
- Direct OS downloads, readable setup steps, and contextual compatibility disclosures.

Source of truth: `src/layouts/BaseLayout.astro`, `src/pages/index.astro`, and `src/pages/download.astro`; use existing shared components for the logo and homepage preview. `PRODUCT.md` is absent, so product statements come from the README and implementation. Evidence is `../docs/evidence/ui/portability/home-desktop.png` and `download-{desktop,mobile,dark}.png`. The finish verdict is **ship within the reviewed browser/source UI scope**, with the reviewed download craft fixes resolved. Portable app screenshots use synthetic mock IPC; the homepage demo is explicitly synthetic. Neither establishes native microphone/runtime validation. No generated raster artwork was added; app icon conversions retain `../Sources/Dictate/Resources/AppIcon.svg` as their source.

## Colors

Primary blue provides links, focus, homepage emphasis, and calls to action. Homepage feature sections retain the existing amber and moss accents; these are not requirements for OS rows. Warm neutrals and charcoal theme equivalents define the reading surface, with restrained borders and muted supporting text.

`BaseLayout` selects the saved theme or system preference before paint. The homepage theme toggle persists the choice. The download page inherits that theme. Download button fill deliberately stays the light-theme action blue with white text in both themes; its hover uses `download-hover`. Other theme-aware links use `--action`.

## Typography

System sans carries headings, instructions, and controls; Georgia italic supplies deliberate emphasis inside major headings. The homepage uses compact, bold pill labels and mono supporting details. The download heading has its own quieter scale, OS headings are (29px), the lede is (20px), and disclosure text is (15px) with (1.7) line height. Installation lists use (1.8) line height and readable bold steps. Download-page Georgia emphasis inherits the text color; it does not copy the homepage's blue emphasis automatically.

## Layout

The homepage has a maximum (1280px) container with (4vw) gutters, a split hero and demo, three-step flow strip, and two feature panels. At (900px) the hero stacks; at (680px) the flow, actions, and feature panels stack with (1.2rem) page gutters. Coarse pointers get larger buttons and theme-toggle targets.

The download page uses a maximum (1080px) container and (40px) gutters. Three in-page OS links precede sequential ruled sections; each aligns platform identity and requirements with its download action. Installation steps remain visible, while detailed exceptions live in disclosures. At (650px), gutters become (22px), buttons fill their row, OS navigation divides evenly, and footer/help links stack. The base page supports a minimum (320px) viewport. Long inline commands wrap within their container.

## Elevation & Depth

The download guide is flat, using whitespace and fine borders. Homepage primary pills have a soft blue shadow (`0 10px 24px rgba(49, 85, 217, 0.2)`), with modest hover lift and an active return. Homepage feature panels use tonal contrast; retain the existing preview component's styling separately. Theme color transitions take (180ms); homepage action transitions take (160ms). Reduced-motion preference removes smooth scrolling and effectively disables transitions/animation. `.impeccable/design.json` stores extension metadata and component snippets; synthesized tonal ramps are preview aids, not additional runtime colors.

## Shapes

Homepage actions stay pill-shaped; homepage feature panels stay square. Download buttons have gently curved corners, with slightly smaller disclosure and OS-link corners. Beta badges and inline code have compact corners. These surface-specific shapes coexist intentionally: do not globally substitute one for the other.

## Components

- **Homepage actions:** Blue primary pill and bordered surface secondary pill; subtle hover lift, visible active return, and shared keyboard focus. Preserve the shared logo and honest synthetic-demo caption.
- **OS navigation and download rows:** Real fragment links address Mac, Windows, and Linux sections with named headings. Download anchors name the OS or package and pair the label with a decorative arrow. Keep version, beta, architecture, and system requirements near the relevant action.
- **Instructions:** Numbered setup steps remain in normal reading order. Native `details`/`summary` controls expose security, compatibility, and dependency information without hiding the basic installation path. Links inside steps, help, and disclosures are underlined and action-colored; commands wrap.
- **Beta badges:** Small bordered, raised-surface labels supplement the platform heading; they do not replace explicit compatibility copy.
- **Keyboard and motion:** Global focus is a (3px) blue outline with (4px) offset, including links and disclosure summaries. Preserve native disclosure keyboard behavior and reduced-motion handling.
- **Release data:** Download destinations and version come from `src/data/release`; retain the release notes, manifest, and validation links. Distinguish installers from source-build instructions and preserve the documented beta/testing limits.

## Do's and Don'ts

- **Do** preserve the incumbent warm/charcoal website, system sans, Georgia emphasis, and blue actions.
- **Do** extend downloads through OS rows, visible numbered steps, and expandable supporting instructions.
- **Do** check light/dark, mobile wrapping, keyboard focus, and expanded disclosures when changing the guide.
- **Don't** turn synthetic previews or CI build results into claims of native device validation.
- **Don't** impose the desktop app's violet sidebar or serif page-heading pattern on the website.
