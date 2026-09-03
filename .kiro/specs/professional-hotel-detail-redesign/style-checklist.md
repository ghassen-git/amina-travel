# Visual Style Checklist - Hotel Detail Page

Use this checklist to manually verify styles render correctly in the browser.

## Layout & Grid

- [ ] **Desktop (≥1024px)**: Two-column layout with 360px sidebar (catalog hotels)
- [ ] **Desktop (1024-1200px)**: Two-column layout with 300px sidebar (catalog hotels)
- [ ] **Mobile/Tablet (<1024px)**: Single-column layout for all hotels
- [ ] **Live-rate hotels**: Always single-column layout
- [ ] Main content sections have consistent vertical spacing (1.5rem → 2.5rem)
- [ ] Container max-width is 1280px with proper padding

## Highlights Section

- [ ] Grid layout: 1 column mobile, 2 columns tablet+
- [ ] Each highlight has gradient background (gold → secondary)
- [ ] Decorative ✦ icon appears before text
- [ ] Hover effect: card lifts up 2px with shadow
- [ ] Hover effect: icon rotates 90° and scales up
- [ ] Smooth transitions (0.25s)
- [ ] Proper gap between items (0.875rem)

## Services Section

- [ ] Grid layout: 1 col mobile, 2 col tablet, 3 col desktop
- [ ] Each service has appropriate icon (WiFi, Pool, etc.)
- [ ] Icons are gold color (var(--gold))
- [ ] Card background is white/card color with border
- [ ] Hover effect: slight lift with shadow
- [ ] Hover effect: icon scales 1.1x and changes to gold-dark
- [ ] Gap between items is 1rem
- [ ] Text is readable and properly aligned with icon

## Room Cards

- [ ] Vertical layout on mobile with 1rem gap
- [ ] Horizontal layout on tablet+ with space-between
- [ ] Room name is prominent (1.125rem, font-weight 600)
- [ ] Tags display board type and occupancy with icons
- [ ] Price display shows label, value (1.5rem display font), unit
- [ ] Booking button is visible and properly sized
- [ ] Hover effect: background lightens with gold tint
- [ ] Spacing between room cards is 1rem

## Location Section

- [ ] Location line has MapPin icon and city/country text
- [ ] Icon is gold-dark color
- [ ] Map embed has 16:9 aspect ratio
- [ ] Map has rounded corners (var(--radius-xl))
- [ ] Map has border (1px solid var(--border))
- [ ] Responsive: maintains aspect ratio on all screens

## Typography & Colors

- [ ] Primary text color is navy (var(--navy))
- [ ] Secondary text color is muted-foreground
- [ ] Gold accent used for icons and highlights (var(--gold))
- [ ] Font sizes are responsive where specified
- [ ] Display font (Playfair Display) used for prices
- [ ] Sans font used for body text

## Interactive Elements

- [ ] All hover states work smoothly
- [ ] Transitions are smooth (no jank)
- [ ] Focus states are visible (for accessibility)
- [ ] Buttons have proper cursor pointer
- [ ] Links have proper text decoration

## Responsive Behavior

- [ ] Test at 375px (iPhone SE)
- [ ] Test at 768px (tablet)
- [ ] Test at 1024px (desktop breakpoint)
- [ ] Test at 1280px (large desktop)
- [ ] Test at 1920px (full HD)
- [ ] All grids collapse/expand properly
- [ ] Text remains readable at all sizes
- [ ] No horizontal scroll at any size

## Browser Compatibility

- [ ] Chrome/Edge (Chromium)
- [ ] Firefox
- [ ] Safari (macOS/iOS)
- [ ] No CSS errors in console
- [ ] No layout shifts during load

## Accessibility

- [ ] Sufficient color contrast (WCAG AA)
- [ ] Focus indicators visible
- [ ] Icons don't interfere with text reading
- [ ] Touch targets are adequate on mobile (44px min)

## Notes

Add any observations or issues found during visual testing:

---

**Date Tested:** _________________

**Tested By:** _________________

**Issues Found:** 

_________________

**Status:** ☐ Pass  ☐ Fail (with issues noted)
