# Pagination Implementation for Hotels Pages

## Overview
Added pagination functionality to both Tunisian and international hotels pages to improve user experience and performance when browsing hotels.

## Changes Made

### 1. New Component: Pagination Component
**File:** `front/apps/website/src/components/site/Pagination.tsx`

A reusable pagination component that:
- Shows page numbers with ellipsis for large page counts
- Displays Previous/Next navigation buttons
- Highlights the current page
- Auto-disables buttons at boundaries
- Accessible with ARIA labels

**Features:**
- Smart page number display (shows 1, ..., current-1, current, current+1, ..., last)
- Previous/Next buttons with icons
- Active page highlighting
- Fully accessible with ARIA attributes

### 2. Updated: Abroad Hotels Search
**File:** `front/apps/website/src/app/hotels-etranger/AbroadHotelsSearch.tsx`

**Changes:**
- Added pagination state (`currentPage`)
- Set items per page to 12 (`ITEMS_PER_PAGE`)
- Split filtering and pagination logic:
  - `filtered` - all hotels matching current filters
  - `shown` - paginated subset of filtered results
- Added `handlePageChange` function to handle page changes and scroll to top
- Reset to page 1 when filters change (query or star filters)
- Updated results count to show filtered count vs total
- Added `<Pagination />` component to the results section

### 3. Updated: Tunisian Hotels Availability Search
**File:** `front/apps/website/src/app/hotels/HotelsAvailabilitySearch.tsx`

**Changes:**
- Added pagination state (`currentPage`)
- Set items per page to 12 (`ITEMS_PER_PAGE`)
- Implemented pagination for three different result types:
  1. **Availability Search Results** (live pricing from supplier)
     - Added `totalFiltered` and `totalPages` calculations
     - Paginated `shown` results
  2. **Name Search Results** (catalogue search)
     - Added `totalNameFiltered` and `totalNamePages` calculations
     - Paginated `shownByName` results
  3. **Discovery Mode** (initial random selection - kept at 6 items, no pagination needed)
- Added `handlePageChange` function with smooth scroll to top
- Modified `toggleStar` to reset to page 1 when filters change
- Reset page to 1 in `run()` and `runByName()` when new searches are performed
- Increased `pageSize` in `runByName` from 24 to 100 to support pagination
- Updated result counts to show total filtered results
- Added `<Pagination />` component to both availability and name search result sections

### 4. Updated: Styles
**File:** `front/apps/website/src/styles/_hotels.scss`

**Enhanced pagination styles:**
- Button styles for Previous/Next navigation
- Page number button styles with hover effects
- Active page highlighting with gold background
- Ellipsis styling
- Disabled state styling
- Responsive design with flex-wrap
- Smooth transitions and hover effects

## Technical Details

### Pagination Logic
- **Items per page:** 12 hotels per page
- **Page calculation:** `totalPages = Math.ceil(totalResults / ITEMS_PER_PAGE)`
- **Slice calculation:** `start = (currentPage - 1) * ITEMS_PER_PAGE`
- **Reset triggers:** New search, filter changes

### User Experience Improvements
1. **Smooth scrolling:** When changing pages, the page smoothly scrolls to the top
2. **Filter preservation:** Star filters and search queries are preserved across page changes
3. **Auto-reset:** Page resets to 1 when filters or search queries change
4. **Clear feedback:** Shows total count of filtered results
5. **Accessibility:** Full ARIA labels and keyboard navigation support

## Backend Support
The backend already supported pagination through the `/api/hotels/search` endpoint with `page` and `pageSize` query parameters. No backend changes were required.

## Testing Recommendations
1. Test pagination with various filter combinations
2. Verify smooth scrolling behavior
3. Test with different screen sizes (responsive design)
4. Verify accessibility with keyboard navigation
5. Test edge cases (1 page, 0 results, etc.)

## Performance Considerations
- **Abroad Hotels:** Fetches all results once and paginates client-side (small dataset ~100 hotels)
- **Tunisian Hotels:** Could be optimized to use server-side pagination in the future if the dataset grows significantly
- **Smooth scrolling:** Uses `window.scrollTo({ behavior: 'smooth' })` which is well-supported

## Future Enhancements
- Add URL query parameters to preserve pagination state on page refresh
- Add "Items per page" selector (12, 24, 48)
- Implement server-side pagination for Tunisian hotels if dataset grows
- Add loading state during page transitions
- Add keyboard shortcuts (arrow keys) for page navigation
