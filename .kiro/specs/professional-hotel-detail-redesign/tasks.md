# Implementation Plan: Professional Hotel Detail Page Redesign

## Overview

This implementation plan transforms the hotel detail page into a professional, comprehensive showcase with improved information hierarchy, enhanced visual presentation, and responsive layout that adapts based on hotel type (live-rate vs catalog). The redesign maintains the existing Amina Travel design system while introducing modern booking platform patterns.

## Tasks

- [x] 1. Verify and update SCSS styles for new components
  - Review existing `_hotels.scss` to confirm highlights, services, rooms, and location styles are complete
  - Add any missing responsive breakpoint variants
  - Add detail layout grid styles if not present
  - Test all new component styles render correctly
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6_

- [x] 2. Create service icon mapping utility function
  - [x] 2.1 Implement `getServiceIcon()` function in `/Users/macos/Desktop/amina-travel/front/apps/website/src/lib/hotel-utils.ts`
    - Accept service name string as parameter
    - Return appropriate Lucide icon component based on keyword matching
    - Support mappings: spa/hammam/thalasso → Sparkles, wifi → Wifi, piscine/plage → Waves, restaurant → Utensils, chambre/bedroom → Bed, bain/bath/douche/shower → Bath, sport/gym/fitness → Dumbbell, kids/enfant → Users, tennis/yoga/vélo/bike → Bike
    - Default to Sparkles icon for unmatched services
    - _Requirements: 6.4_
  
  - [x] 2.2 Write unit tests for service icon mapping
    - Test each icon mapping category
    - Test case-insensitive matching
    - Test default fallback behavior
    - Test compound keywords (e.g., "piscine chauffée" → Waves)
    - _Requirements: 6.4_

- [x] 3. Update hotel detail page structure and layout
  - [x] 3.1 Add layout mode determination logic
    - Calculate `useSidebar` based on `!hotel.hasLiveRates && hotel.fromPricePerNight > 0`
    - Apply conditional CSS classes to container: `detail-layout` and `detail-main`
    - Update container structure to support two-column grid on desktop
    - _Requirements: 10.3, 10.4, 11.1_
  
  - [x] 3.2 Update DetailHero component usage
    - Move ExpandableText into subtitle prop for better hierarchy
    - Ensure review display is conditional on `reviewCount > 0`
    - Update eyebrow to include star rating and city
    - Add meta array with location and services count
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.6, 16.1, 16.2, 16.3, 16.4_
  
  - [x] 3.3 Position ImageGallery prominently
    - Ensure ImageGallery is first component after DetailHero
    - Verify gallery displays even when hotel.gallery is empty (using imageUrl fallback)
    - Confirm responsive behavior and touch-friendliness
    - _Requirements: 2.1, 2.2, 2.4_

- [x] 4. Implement enhanced highlights section
  - [x] 4.1 Add conditional HighlightsPanel rendering
    - Check if `hotel.highlights.length > 0` before rendering
    - Use Panel component with title "Points forts"
    - Map over highlights array with unique keys
    - Apply `highlights-grid` and `highlight` CSS classes
    - _Requirements: 5.1, 5.2, 5.3, 5.4_
  
  - [x] 4.2 Test highlights display with various data scenarios
    - Test with 0 highlights (section hidden)
    - Test with 3-6 highlights (common case)
    - Test with 10+ highlights (grid overflow)
    - Test responsive grid layout on mobile/tablet/desktop
    - _Requirements: 5.1, 5.2_

- [x] 5. Implement enhanced services section
  - [x] 5.1 Update ServicesPanel with icon mapping
    - Check if `hotel.services.length > 0` before rendering
    - Use Panel component with title "Services & équipements"
    - Import `getServiceIcon` utility function
    - Map over services array, call `getServiceIcon(service)` for each
    - Render service with icon and text using `services-grid` and `service-item` classes
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_
  
  - [x] 5.2 Test services display with various scenarios
    - Test with 0 services (section hidden)
    - Test with services matching all icon categories
    - Test with services having no keyword matches (default icon)
    - Test responsive grid: 1 column mobile, 2 tablet, 3 desktop
    - _Requirements: 6.1, 6.2, 6.5_

- [x] 6. Update room display for catalog hotels
  - [x] 6.1 Refactor RoomsPanel layout and styling
    - Keep conditional rendering: `hotel.rooms.length > 0`
    - Update room-row structure with info, tags, price, and CTA sections
    - Apply responsive classes: vertical on mobile, horizontal on tablet+
    - Use BOARD_LABELS for board type display
    - Display max occupancy with Users icon
    - Format price with currency (TND → DT conversion)
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 14.1, 14.2, 14.3_
  
  - [x] 6.2 Test room cards with various configurations
    - Test with different board types (verify BOARD_LABELS mapping)
    - Test with TND currency (displays as "DT")
    - Test with EUR/USD currencies (displays as-is)
    - Test with varying occupancy numbers (2-8 persons)
    - Test responsive layout transformation
    - _Requirements: 7.2, 7.3, 7.4, 7.5, 14.1, 14.2_

- [x] 7. Implement enhanced location section
  - [x] 7.1 Update LocationPanel with map embed
    - Use Panel component with title "Localisation"
    - Add location line with MapPin icon, city, and country
    - Construct map query: `hotel.mapUrl || ${hotel.city}, ${hotel.country}`
    - Render MapEmbed component with constructed query
    - Apply `loc-line` CSS class
    - _Requirements: 9.1, 9.2, 9.3, 9.4_
  
  - [x] 7.2 Test location display scenarios
    - Test with custom mapUrl
    - Test with generated query (city + country)
    - Test map embed responsiveness
    - Test international locations (non-Tunisia)
    - _Requirements: 9.1, 9.2, 9.4_

- [x] 8. Update PriceSticky sidebar integration
  - [x] 8.1 Configure PriceSticky for catalog hotels
    - Render PriceSticky only when `useSidebar === true`
    - Set `showFromPrefix={false}` to hide "À partir de" prefix
    - Set unit to "par nuit · chambre double"
    - Include review badge when `hotel.reviewCount > 0`
    - Pass `bookHref()` as ctaHref
    - Set ctaLabel to "Réserver maintenant"
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6, 11.8_
  
  - [x] 8.2 Test sidebar behavior across breakpoints
    - Test sidebar appears only for catalog hotels with pricing
    - Test sidebar is hidden for live-rate hotels
    - Test sidebar is hidden on mobile/tablet (< 1024px)
    - Test sticky positioning on desktop scroll
    - Test review badge conditional display
    - _Requirements: 11.1, 11.4, 10.3, 10.4_

- [x] 9. Checkpoint - Verify component integration and layout
  - Test complete page renders without errors
  - Verify layout switches correctly between single-column and two-column modes
  - Check all conditional sections render/hide appropriately
  - Ensure no visual regressions in existing components
  - Test with minimal hotel data (graceful degradation)
  - Test with complete hotel data (all sections visible)
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 13.1, 13.2, 13.3, 19.3_

- [x] 10. Enhance SEO and accessibility
  - [x] 10.1 Verify metadata generation
    - Confirm title includes hotel name, stars, city, and brand
    - Confirm description includes key hotel information with price
    - Verify canonical URL is set
    - Verify Open Graph metadata for social sharing
    - Check image fallback in Open Graph
    - _Requirements: 12.1, 12.2, 12.3, 12.4_
  
  - [x] 10.2 Verify structured data (JSON-LD)
    - Confirm Hotel schema includes all available properties
    - Confirm starRating is included when stars > 0
    - Confirm aggregateRating is conditional on reviewCount > 0
    - Confirm Breadcrumb schema adapts based on hotel country
    - _Requirements: 12.5, 12.6_
  
  - [x] 10.3 Add semantic HTML and ARIA labels
    - Wrap main content in semantic `<main>` element
    - Use `<section>` with `aria-labelledby` for each panel
    - Use `<aside role="complementary">` for PriceSticky
    - Ensure all images have descriptive alt text
    - Verify heading hierarchy (h1 → h2 → h3)
    - _Requirements: 17.1, 17.2, 17.3, 17.6_
  
  - [x] 10.4 Test accessibility compliance
    - Test keyboard navigation through all interactive elements
    - Test screen reader announces content correctly
    - Verify focus indicators are visible on all elements
    - Check color contrast meets WCAG AA standards (use browser dev tools)
    - Test with VoiceOver (macOS) or NVDA (Windows)
    - _Requirements: 17.4, 17.5_

- [x] 11. Responsive design verification
  - [x] 11.1 Test mobile viewport (< 768px)
    - Verify single-column layout for all hotel types
    - Verify PriceSticky is not shown
    - Verify reduced title size (2.25rem)
    - Verify vertical room-row layout
    - Verify 1-2 column service/highlight grids
    - Verify touch-friendly ImageGallery controls
    - _Requirements: 1.7, 10.4, 10.5_
  
  - [x] 11.2 Test tablet viewport (768px - 1023px)
    - Verify single-column layout (no sidebar)
    - Verify medium title size (3rem)
    - Verify horizontal room-row layout
    - Verify 2-3 column service/highlight grids
    - _Requirements: 10.4, 10.5_
  
  - [x] 11.3 Test desktop viewport (≥ 1024px)
    - Verify two-column layout for catalog hotels (content + sidebar)
    - Verify single-column layout for live-rate hotels
    - Verify PriceSticky appears and is sticky (catalog hotels only)
    - Verify large title size (3.75rem)
    - Verify 3 column services grid
    - Verify hover effects on interactive elements
    - _Requirements: 10.3, 10.4, 11.1_

- [x] 12. Performance optimization
  - [x] 12.1 Verify image optimization
    - Confirm hero image uses `priority={true}` for LCP
    - Confirm gallery images use lazy loading
    - Verify appropriate `sizes` attribute on all images
    - Check fallback images are optimized
    - _Requirements: 18.2, 18.4_
  
  - [x] 12.2 Test loading states and performance
    - Verify force-dynamic rendering ensures fresh data
    - Test HotelAvailabilityPanel loading states
    - Measure and verify Lighthouse score > 85
    - Check for layout shifts during load (CLS)
    - Verify Time to Interactive (TTI) is acceptable
    - _Requirements: 18.1, 18.3_

- [x] 13. Error handling and edge cases
  - [x] 13.1 Test error scenarios
    - Test with non-existent hotel slug (404 not found)
    - Test with hotel missing imageUrl (fallback to gallery[0] or placeholder)
    - Test with hotel missing description (empty or default text)
    - Test with hotel having 0 highlights (section hidden)
    - Test with hotel having 0 services (section hidden)
    - Test with hotel having 0 rooms (panel hidden/empty state)
    - Test with hotel having 0 reviews (review display hidden)
    - _Requirements: 19.1, 19.2, 19.3, 19.4_
  
  - [x] 13.2 Test data variations and edge cases
    - Test with very long hotel names (truncation/wrapping)
    - Test with very long descriptions (ExpandableText)
    - Test with 20+ services (grid overflow/scrolling)
    - Test with international hotels (non-Tunisia countries)
    - Test with hotels having promoPercent set
    - Test with 0-star hotels (no star display)
    - Test with hotels having both live rates and catalog rooms
    - _Requirements: 19.3, 15.1, 15.2, 15.3_

- [x] 14. Final integration testing and polish
  - [x] 14.1 Cross-browser testing
    - Test in Chrome/Edge (Chromium)
    - Test in Firefox
    - Test in Safari (macOS/iOS)
    - Verify all layouts render correctly
    - Check for browser-specific CSS issues
    - _Requirements: 10.1, 10.2, 10.5_
  
  - [x] 14.2 User flow testing
    - Test viewing hotel from search results
    - Test clicking into image gallery and navigating
    - Test expanding/collapsing panels
    - Test checking availability (live-rate hotels)
    - Test selecting room and proceeding to booking
    - Test clicking "Réserver" CTA from sidebar
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 7.6_
  
  - [x] 14.3 Visual polish and consistency
    - Compare with Booking.com/Expedia reference designs
    - Verify consistent spacing and alignment
    - Check icon sizes and colors match design system
    - Verify typography hierarchy is clear
    - Ensure all hover states work correctly
    - _Requirements: 10.1, 10.6, 13.4, 13.5_

- [x] 15. Final checkpoint - Production readiness
  - Ensure all tests pass
  - Verify no console errors or warnings
  - Check accessibility audit passes
  - Confirm performance metrics meet targets
  - Review code for any TODOs or temporary fixes
  - Document any known limitations or future enhancements
  - _Requirements: All requirements verified_

## Notes

- Tasks marked with `*` are optional test tasks that can be skipped for faster MVP but are highly recommended for production quality
- The design uses existing components (DetailHero, Panel, ImageGallery, HotelAvailabilityPanel, PriceSticky) with configuration updates
- Most SCSS styles are already present in `_hotels.scss`, task 1 verifies completeness
- The layout mode (`useSidebar`) determines the entire page structure and component composition
- Service icon mapping provides visual scannability without requiring icon data in the API
- All price displays must handle TND → DT currency conversion
- Responsive behavior is critical: single-column on mobile, conditional two-column on desktop
- Error handling ensures graceful degradation when optional fields are missing
- Accessibility compliance requires semantic HTML, ARIA labels, and keyboard navigation
- Performance optimization focuses on image loading and minimizing layout shifts

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1", "2.1"] },
    { "id": 1, "tasks": ["2.2", "3.1"] },
    { "id": 2, "tasks": ["3.2", "3.3"] },
    { "id": 3, "tasks": ["4.1", "5.1", "6.1", "7.1"] },
    { "id": 4, "tasks": ["4.2", "5.2", "6.2", "7.2", "8.1"] },
    { "id": 5, "tasks": ["8.2", "9"] },
    { "id": 6, "tasks": ["10.1", "10.2", "10.3"] },
    { "id": 7, "tasks": ["10.4", "11.1", "11.2", "11.3"] },
    { "id": 8, "tasks": ["12.1", "12.2", "13.1", "13.2"] },
    { "id": 9, "tasks": ["14.1", "14.2", "14.3"] },
    { "id": 10, "tasks": ["15"] }
  ]
}
```
