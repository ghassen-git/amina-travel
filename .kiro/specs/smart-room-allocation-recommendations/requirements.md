# Requirements Document

## Introduction

This feature addresses a critical usability gap in the hotel search experience. Currently, when users configure a room with too many occupants (e.g., "1 chambre, 3 adultes, 2 enfants, 2 bébés" = 7 people), the system allows them to proceed with the search without warning. Since most hotel rooms have a maximum capacity of 4 people, this configuration typically returns no results or causes booking failures, leading to user frustration.

The Smart Room Allocation Recommendations feature will proactively detect overcapacity situations and provide intelligent suggestions to redistribute guests across multiple rooms, improving search success rates and user experience.

## Glossary

- **Occupancy_Picker**: The UI component that allows users to configure rooms and guest counts (adults, children, babies)
- **Room_Configuration**: A single room's occupancy specification containing adult count and children ages array
- **Total_Occupants**: The sum of adults, children (enfants), and babies (bébés) in a room
- **Standard_Room_Capacity**: The typical maximum number of occupants a hotel room can accommodate (4 people)
- **Overcapacity_Threshold**: The point at which a room configuration exceeds practical hotel limits
- **Allocation_Algorithm**: The logic that distributes guests optimally across multiple rooms
- **Warning_Banner**: The UI element displaying the overcapacity alert message
- **Auto_Allocation_Button**: The interactive element that applies recommended room distribution
- **Enfants**: Children aged 2-12 years who are counted as occupants
- **Bébés**: Infants aged 0-1 years (less than 2 years) who may not count toward room capacity limits
- **MAX_ADULTS_PER_ROOM**: The system constant defining maximum adults per room (currently 6)
- **MAX_CHILDREN_PER_ROOM**: The system constant defining maximum children per room (currently 4)
- **MAX_ROOMS**: The system constant defining maximum number of rooms allowed (currently 8)

## Requirements

### Requirement 1: Detect Overcapacity Conditions

**User Story:** As a user searching for hotel rooms, I want the system to detect when my room configuration exceeds typical hotel capacity, so that I am warned before initiating a search that may return no results.

#### Acceptance Criteria

1. WHEN a Room_Configuration has Total_Occupants greater than Standard_Room_Capacity, THE Occupancy_Picker SHALL identify it as an overcapacity condition
2. THE Occupancy_Picker SHALL calculate Total_Occupants as the sum of adults plus enfants plus bébés for detection purposes
3. THE Occupancy_Picker SHALL use 4 as the Standard_Room_Capacity threshold value
4. WHEN the user modifies any stepper control that results in overcapacity, THE Occupancy_Picker SHALL immediately detect the condition
5. WHEN multiple Room_Configurations exist and at least one exceeds Standard_Room_Capacity, THE Occupancy_Picker SHALL identify only the overcapacity rooms

### Requirement 2: Display Overcapacity Warning

**User Story:** As a user who has configured too many guests in a single room, I want to see a clear warning message, so that I understand the issue and can take corrective action.

#### Acceptance Criteria

1. WHEN an overcapacity condition is detected, THE Occupancy_Picker SHALL display a Warning_Banner
2. THE Warning_Banner SHALL contain the text "⚠️ Cette configuration dépasse la capacité standard d'une chambre (4 personnes). Nous recommandons [N] chambres." where [N] is the recommended room count
3. THE Warning_Banner SHALL appear above the room configuration controls within the occupancy panel
4. THE Warning_Banner SHALL use a visually distinct style (warning color scheme) to draw attention
5. WHEN the overcapacity condition is resolved, THE Occupancy_Picker SHALL hide the Warning_Banner
6. THE Warning_Banner SHALL display for each individual overcapacity room when multiple rooms are configured

### Requirement 3: Calculate Optimal Room Distribution

**User Story:** As a user with an overcapacity configuration, I want the system to calculate how to optimally distribute my guests across multiple rooms, so that I can quickly fix the issue without manual trial and error.

#### Acceptance Criteria

1. WHEN an overcapacity condition exists, THE Allocation_Algorithm SHALL calculate the minimum number of rooms needed
2. THE Allocation_Algorithm SHALL distribute guests as evenly as possible across recommended rooms
3. THE Allocation_Algorithm SHALL prioritize keeping adults together before distributing children
4. THE Allocation_Algorithm SHALL respect MAX_ADULTS_PER_ROOM and MAX_CHILDREN_PER_ROOM constraints in the distribution
5. THE Allocation_Algorithm SHALL ensure each recommended room has at least 1 adult
6. THE Allocation_Algorithm SHALL distribute bébés after adults and enfants are allocated
7. FOR ALL valid Room_Configurations with overcapacity, THE Allocation_Algorithm SHALL produce a distribution where no room exceeds Standard_Room_Capacity

### Requirement 4: Provide One-Click Auto-Allocation

**User Story:** As a user viewing an overcapacity warning, I want to click a button to automatically apply the recommended room distribution, so that I can quickly fix the issue and continue my search.

#### Acceptance Criteria

1. WHEN the Warning_Banner is displayed, THE Occupancy_Picker SHALL show an Auto_Allocation_Button with the text "Répartir automatiquement"
2. WHEN the Auto_Allocation_Button is clicked, THE Occupancy_Picker SHALL apply the Allocation_Algorithm result
3. WHEN the Auto_Allocation_Button is clicked, THE Occupancy_Picker SHALL replace the current Room_Configurations with the recommended distribution
4. WHEN the allocation is applied, THE Occupancy_Picker SHALL preserve the total count of adults, enfants, and bébés
5. WHEN the allocation is applied and results in fewer rooms than MAX_ROOMS, THE Occupancy_Picker SHALL update the display to show the new room count
6. WHEN the allocation is applied, THE Warning_Banner SHALL disappear because overcapacity is resolved

### Requirement 5: Display Recommended Allocation Preview

**User Story:** As a user considering the auto-allocation suggestion, I want to see what the recommended room distribution will be before applying it, so that I can make an informed decision.

#### Acceptance Criteria

1. WHEN the Warning_Banner is displayed, THE Occupancy_Picker SHALL show a preview of the recommended allocation
2. THE preview SHALL display in a readable format such as "• Chambre 1: X adultes, Y enfants, Z bébés • Chambre 2: X adultes, Y enfants, Z bébés"
3. THE preview SHALL display the configuration for each recommended room
4. THE preview SHALL omit zero counts (e.g., if no children, don't show "0 enfants")
5. THE preview SHALL appear near the Auto_Allocation_Button within the Warning_Banner

### Requirement 6: Handle Edge Cases in Allocation

**User Story:** As a user with complex guest configurations, I want the allocation algorithm to handle edge cases gracefully, so that I receive valid recommendations regardless of my input.

#### Acceptance Criteria

1. WHEN the recommended room count would exceed MAX_ROOMS, THE Allocation_Algorithm SHALL distribute guests across MAX_ROOMS rooms
2. WHEN distributing guests across MAX_ROOMS still results in overcapacity per room, THE Occupancy_Picker SHALL display a modified warning message indicating manual adjustment is needed
3. WHEN a single Room_Configuration contains only bébés exceeding Standard_Room_Capacity, THE Allocation_Algorithm SHALL add at least 1 adult to each resulting room
4. WHEN the total adults count is less than the recommended room count, THE Allocation_Algorithm SHALL create rooms with 1 adult and distribute remaining guests
5. IF allocation fails to produce a valid distribution, THEN THE Occupancy_Picker SHALL disable the Auto_Allocation_Button and display an error message

### Requirement 7: Maintain Feature Consistency Across Variants

**User Story:** As a user interacting with different search interfaces, I want the room allocation recommendations to work consistently, so that I receive the same helpful guidance regardless of where I start my search.

#### Acceptance Criteria

1. THE Occupancy_Picker SHALL implement overcapacity detection for variant="hero"
2. THE Occupancy_Picker SHALL implement overcapacity detection for variant="bar"
3. THE Warning_Banner SHALL display consistently in both "hero" and "bar" variants
4. THE Auto_Allocation_Button SHALL function identically in both "hero" and "bar" variants
5. THE Allocation_Algorithm SHALL produce identical results for the same input regardless of variant

### Requirement 8: Preserve Existing Occupancy Picker Functionality

**User Story:** As a user of the existing occupancy picker, I want all current features to continue working as before, so that adding new recommendations doesn't break my existing workflow.

#### Acceptance Criteria

1. THE Occupancy_Picker SHALL continue to support manual room addition via "+ Ajouter une chambre" button
2. THE Occupancy_Picker SHALL continue to enforce MAX_ADULTS_PER_ROOM, MAX_CHILDREN_PER_ROOM, and MAX_ROOMS limits on manual input
3. THE Occupancy_Picker SHALL continue to support manual room removal via "Retirer" button
4. THE Occupancy_Picker SHALL continue to support all stepper controls for adults, enfants, and bébés
5. WHEN manual changes resolve an overcapacity condition, THE Occupancy_Picker SHALL hide the Warning_Banner
6. THE Occupancy_Picker SHALL continue to pass Room_Configurations to onChange callback in the same format

### Requirement 9: Implement Allocation Algorithm Logic

**User Story:** As a developer, I want the allocation algorithm implemented as a pure function with clear logic, so that it can be tested independently and reused across components.

#### Acceptance Criteria

1. THE system SHALL implement a pure function `calculateOptimalAllocation(rooms: RoomOccupancy[]): RoomOccupancy[]`
2. THE function SHALL accept the current Room_Configurations array as input
3. THE function SHALL return a new Room_Configurations array representing the optimal distribution
4. THE function SHALL be deterministic (same input always produces same output)
5. FOR ALL valid inputs, parsing then formatting then parsing the output SHALL produce an equivalent result (round-trip property)
6. THE function SHALL reside in the stay.ts utility module alongside other occupancy logic

### Requirement 10: Test Allocation Algorithm Properties

**User Story:** As a developer, I want comprehensive tests for the allocation algorithm, so that I can be confident it handles all guest configurations correctly.

#### Acceptance Criteria

1. THE test suite SHALL verify that total guest counts are preserved (invariant property: sum of all adults/children/babies before = after)
2. THE test suite SHALL verify that no recommended room exceeds Standard_Room_Capacity
3. THE test suite SHALL verify that each recommended room contains at least 1 adult
4. THE test suite SHALL verify that recommended room count does not exceed MAX_ROOMS
5. THE test suite SHALL verify round-trip property: applying allocation twice produces the same result as applying once (idempotence)
6. THE test suite SHALL test edge cases: single baby, max adults, max children, mixed configurations
7. THE test suite SHALL verify metamorphic property: recommended room count is always greater than or equal to original room count when overcapacity exists

