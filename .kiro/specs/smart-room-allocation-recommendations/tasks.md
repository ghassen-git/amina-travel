# Implementation Plan: Smart Room Allocation Recommendations

## Overview

This implementation plan converts the smart room allocation design into discrete coding tasks. The feature adds intelligent guest redistribution suggestions to the OccupancyPicker component, detecting when users configure too many guests per room and providing automated reallocation with a single click.

The implementation follows a bottom-up approach: build and test the pure allocation algorithm first, then integrate it into the UI component, and finally add styling and cross-variant verification.

## Tasks

- [x] 1. Set up property-based testing infrastructure
  - Install fast-check as a dev dependency: `npm install --save-dev fast-check`
  - Verify fast-check imports work in existing test files
  - Add test configuration constants (MIN_PBT_ITERATIONS = 100)
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7_

- [x] 2. Implement core allocation algorithm and utilities
  - [x] 2.1 Add STANDARD_ROOM_CAPACITY constant to stay.ts
    - Export const STANDARD_ROOM_CAPACITY = 4
    - Place alongside other capacity constants (MAX_ROOMS, MAX_ADULTS_PER_ROOM, etc.)
    - _Requirements: 1.3_
  
  - [x] 2.2 Implement calculateOptimalAllocation function in stay.ts
    - Accept rooms: RoomOccupancy[] parameter
    - Return RoomOccupancy[] with optimal guest distribution
    - Follow the First-Fit Decreasing algorithm outlined in design (Steps 1-7)
    - Handle edge cases: insufficient adults, MAX_ROOMS overflow, idempotence
    - Export function with JSDoc documentation describing behavior and constraints
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 9.1, 9.2, 9.3, 9.4, 9.6_
  
  - [x] 2.3 Implement formatAllocationPreview helper function in stay.ts
    - Accept rooms: RoomOccupancy[] parameter
    - Return formatted string with "• Chambre N: X adultes, Y enfants, Z bébés" pattern
    - Omit zero counts (e.g., if no children, don't include "0 enfants")
    - Join multiple room entries with " • " separator
    - Export function with JSDoc documentation
    - _Requirements: 5.2, 5.3, 5.4_
  
  - [x] 2.4 Write property-based tests for allocation algorithm
    - **Property 1: Total Guest Preservation**
    - **Validates: Requirements 4.4, 10.1**
    - Create roomOccupancyArb arbitrary generator (1-6 adults, 0-4 children ages 0-12)
    - Create roomsArrayArb generator (1-8 rooms)
    - Test that sum of adults before = sum of adults after
    - Test that sum of all children before = sum of all children after
    - Run with 100 iterations minimum
  
  - [x] 2.5 Write property test for capacity constraint
    - **Property 2: Capacity Constraint Satisfaction**
    - **Validates: Requirements 3.7, 10.2**
    - Test that all output rooms have ≤ 4 total occupants (when total ≤ 32 guests)
    - Use roomsArrayArb generator
    - Run with 100 iterations
  
  - [x] 2.6 Write property test for adult presence
    - **Property 3: Adult Presence Guarantee**
    - **Validates: Requirements 3.5, 10.3**
    - Test that each output room has ≥ 1 adult (when total adults ≥ required rooms)
    - Filter test cases to only those with sufficient adults
    - Run with 100 iterations
  
  - [x] 2.7 Write property test for room count bounds
    - **Property 4: Room Count Bounds**
    - **Validates: Requirements 3.1, 10.4**
    - Test that output room count ≤ MAX_ROOMS (8)
    - Test that output room count = ⌈total / 4⌉ when possible
    - Run with 100 iterations
  
  - [x] 2.8 Write property test for idempotence
    - **Property 5: Idempotence**
    - **Validates: Requirements 10.5**
    - Test that applying allocation twice produces same result as applying once
    - Compare calculateOptimalAllocation(input) with calculateOptimalAllocation(calculateOptimalAllocation(input))
    - Run with 100 iterations
  
  - [x] 2.9 Write property test for distribution balance
    - **Property 6: Distribution Balance**
    - **Validates: Requirements 3.2**
    - Test that difference between max and min room occupancy ≤ 1
    - Account for constraint limitations (MAX_ADULTS_PER_ROOM, MAX_CHILDREN_PER_ROOM)
    - Run with 100 iterations
  
  - [x] 2.10 Write property test for determinism
    - **Property 7: Determinism**
    - **Validates: Requirements 9.4, 7.5**
    - Call allocation algorithm 3 times with same input
    - Test that all 3 outputs are identical
    - Run with 100 iterations
  
  - [x] 2.11 Write property test for metamorphic room count relationship
    - **Property 8: Metamorphic Room Count Relationship**
    - **Validates: Requirements 10.7**
    - Test that overcapacity input produces ≥ same number of rooms
    - Filter to only overcapacity inputs (any room with > 4 occupants)
    - Run with 100 iterations
  
  - [x] 2.12 Write unit tests for edge cases and formatAllocationPreview
    - Test single baby (0 adults, 1 baby) allocation
    - Test max adults (6 adults per room) distribution
    - Test max children (4 children per room) distribution
    - Test mixed configurations (adults + enfants + bébés)
    - Test formatAllocationPreview omits zero counts
    - Test formatAllocationPreview includes all guest types when present
    - Test formatAllocationPreview formats multiple rooms correctly
    - _Requirements: 10.6_

- [x] 3. Checkpoint - Ensure all algorithm tests pass
  - Run test suite: `npm test stay.test.ts` or `npm test stay.allocation.test.ts`
  - Verify all 8 property-based tests pass with 100 iterations each
  - Verify all unit tests pass
  - Fix any failing tests before proceeding
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Integrate allocation logic into OccupancyPicker component
  - [x] 4.1 Add overcapacity detection helper functions to OccupancyPicker.tsx
    - Implement hasOvercapacity(rooms: RoomOccupancy[]): boolean
    - Implement getRecommendation(rooms: RoomOccupancy[]): RoomOccupancy[] | null
    - Place functions inside component file before main component definition
    - _Requirements: 1.1, 1.4, 1.5_
  
  - [x] 4.2 Add overcapacity detection and recommendation calculation
    - Inside OccupancyPicker component body, calculate recommendation using getRecommendation(rooms)
    - Store result in const recommendation variable (computed inline, no new state)
    - _Requirements: 1.1, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_
  
  - [x] 4.3 Render warning banner UI when overcapacity detected
    - Add conditional rendering: {recommendation && (<div className="occupancy__warning">...</div>)}
    - Place warning banner above .occupancy__rooms div
    - Display warning text: "⚠️ Cette configuration dépasse la capacité standard d'une chambre (4 personnes). Nous recommandons {N} chambre{s}."
    - Display preview using formatAllocationPreview(recommendation)
    - Add "Répartir automatiquement" button with onClick={() => onChange(recommendation)}
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 5.1, 5.2, 5.5, 4.1_
  
  - [x] 4.4 Wire auto-allocation button to apply recommendation
    - Button onClick handler calls onChange(recommendation)
    - Verify onChange callback receives the recommended RoomOccupancy[] array
    - _Requirements: 4.2, 4.3, 4.4, 4.5_
  
  - [x] 4.5 Verify warning disappears after allocation applied
    - After onChange called with recommendation, component should re-render
    - getRecommendation should return null (no overcapacity)
    - Warning banner should not render
    - _Requirements: 2.5, 4.6_

- [x] 5. Add styling for warning banner and auto-allocation button
  - [x] 5.1 Create CSS classes for warning banner
    - Add .occupancy__warning with warning yellow background (#fff3cd), border, padding
    - Add .occupancy__warning-text with appropriate font size and color (#856404)
    - Add .occupancy__warning-preview with slightly different styling for preview text
    - Place styles in existing SCSS file (likely _occupancy.scss or similar)
    - _Requirements: 2.3, 2.4_
  
  - [x] 5.2 Create CSS classes for auto-allocation button
    - Add .occupancy__auto-allocate with warning yellow button style (#ffc107)
    - Include hover state (#ffb300)
    - Include disabled state (opacity 0.5, cursor not-allowed)
    - Ensure button styling matches existing occupancy picker buttons
    - _Requirements: 4.1_
  
  - [x] 5.3 Write integration tests for warning banner rendering
    - Test that warning banner appears when single room exceeds 4 occupants
    - Test that warning banner displays correct recommended room count
    - Test that preview text is formatted correctly
    - Test that "Répartir automatiquement" button is present
    - Use React Testing Library with render and getByText
    - _Requirements: 2.1, 2.2, 5.2, 4.1_
  
  - [x] 5.4 Write integration tests for auto-allocation functionality
    - Test that clicking "Répartir automatiquement" calls onChange callback
    - Test that onChange receives recommended room configuration
    - Test that total guest counts are preserved after allocation
    - Test that warning disappears after allocation applied
    - Mock onChange with jest.fn()
    - _Requirements: 4.2, 4.3, 4.4, 2.5, 4.6_

- [x] 6. Ensure feature consistency across variants
  - [x] 6.1 Test overcapacity detection in variant="hero"
    - Verify hasOvercapacity and getRecommendation work correctly
    - Verify warning banner renders in hero variant UI
    - Verify auto-allocation button functions correctly
    - _Requirements: 7.1, 7.3, 7.4, 7.5_
  
  - [x] 6.2 Test overcapacity detection in variant="bar"
    - Verify hasOvercapacity and getRecommendation work correctly
    - Verify warning banner renders in bar variant UI
    - Verify auto-allocation button functions correctly
    - _Requirements: 7.2, 7.3, 7.4, 7.5_
  
  - [x] 6.3 Write integration tests for variant consistency
    - Test both "hero" and "bar" variants with same overcapacity configuration
    - Verify both render warning banner
    - Verify both apply identical allocation recommendations
    - Verify UI differences are only visual (same behavior)
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [x] 7. Verify existing functionality preservation (regression testing)
  - [x] 7.1 Test manual room addition still works
    - Click "+ Ajouter une chambre" button
    - Verify new room added to configuration
    - Verify room count increments correctly
    - _Requirements: 8.1_
  
  - [x] 7.2 Test stepper controls still work
    - Increment/decrement adults stepper
    - Increment/decrement enfants stepper
    - Increment/decrement bébés stepper
    - Verify counts update correctly
    - Verify constraints (MAX_ADULTS_PER_ROOM, MAX_CHILDREN_PER_ROOM) still enforced
    - _Requirements: 8.2, 8.4_
  
  - [x] 7.3 Test manual room removal still works
    - Click "Retirer" button on a room
    - Verify room removed from configuration
    - Verify room count decrements correctly
    - _Requirements: 8.3_
  
  - [x] 7.4 Test manual changes resolve overcapacity
    - Configure overcapacity (5+ occupants in one room)
    - Verify warning appears
    - Manually add a second room and redistribute guests
    - Verify warning disappears when no room exceeds 4 occupants
    - _Requirements: 8.5_
  
  - [x] 7.5 Write regression integration tests
    - Test that all existing OccupancyPicker functionality works with new feature
    - Test that onChange callback format unchanged
    - Test that rooms prop structure unchanged
    - Test that MAX_ROOMS, MAX_ADULTS_PER_ROOM, MAX_CHILDREN_PER_ROOM limits still enforced
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6_

- [x] 8. Handle edge cases and error scenarios
  - [x] 8.1 Test extreme overcapacity (>32 guests)
    - Configure 40 total guests (exceeds MAX_ROOMS × 4)
    - Verify warning displays with modified message if needed
    - Verify allocation distributes across MAX_ROOMS (8 rooms)
    - Document behavior: some rooms may exceed 4 occupants in this edge case
    - _Requirements: 6.1, 6.2_
  
  - [x] 8.2 Test insufficient adults edge case
    - Configure 2 adults, 10 children (needs 3 rooms, only 2 adults available)
    - Verify allocation creates 3 rooms
    - Document behavior: some rooms may have 0 adults
    - Consider adding additional warning message if desired
    - _Requirements: 6.3, 6.4_
  
  - [x] 8.3 Add error handling for algorithm failures
    - Wrap calculateOptimalAllocation call in try-catch
    - If error occurs, log to console and return null (disable auto-allocation button)
    - Display error message: "⚠️ Erreur lors du calcul de la répartition. Veuillez ajuster manuellement."
    - _Requirements: 6.5_
  
  - [x] 8.4 Write unit tests for edge case handling
    - Test extreme overcapacity scenario (40 guests)
    - Test insufficient adults scenario (2 adults, 15 children)
    - Test single baby scenario (0 adults, 1 baby)
    - Test algorithm failure handling (mock error throw)
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

- [x] 9. Final checkpoint - Ensure all tests pass
  - Run full test suite: `npm test`
  - Verify all property-based tests pass (8 properties × 100 iterations)
  - Verify all unit tests pass (edge cases, formatAllocationPreview)
  - Verify all integration tests pass (component rendering, auto-allocation, variants, regression)
  - Check test coverage: should achieve ≥80% line coverage, ≥75% branch coverage
  - Fix any failing tests
  - Ensure all tests pass, ask the user if questions arise.

- [~] 10. Manual testing and verification (browser pass still owed — Chrome extension not connected)
  - Open OccupancyPicker in hero variant (homepage search)
  - Configure single room with 5+ occupants, verify warning appears
  - Click "Répartir automatiquement", verify allocation applied
  - Open OccupancyPicker in bar variant (search results page bar)
  - Repeat same test, verify consistent behavior
  - Test edge cases manually: extreme overcapacity, insufficient adults
  - Test regression: add/remove rooms, adjust steppers, verify all works
  - Test cross-browser (Chrome, Firefox, Safari if available)
  - Ask the user if questions arise or if any unexpected behavior observed.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP delivery
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation and early error detection
- Property-based tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- Integration tests validate component behavior and user interactions
- Regression tests ensure existing functionality is preserved
- The algorithm is a pure function, making it easy to test independently
- All tests should run in CI/CD pipeline before deployment
