# Requirements Document

## Introduction

This document specifies requirements for redesigning the hotel detail page (`/hotels/[slug]/page.tsx`) to provide a more professional, comprehensive presentation of hotel information. The redesign will organize all available hotel data into clear, scannable sections with improved visual hierarchy, similar to modern booking platforms like Booking.com and Expedia, while maintaining support for both live-rate hotels (TunisiaBeds supplier) and catalog hotels (fixed pricing).

## Glossary

- **Hotel_Detail_Page**: The webpage displaying comprehensive information about a single hotel
- **Live_Rate_Hotel**: A hotel with real-time pricing from TunisiaBeds supplier (hasLiveRates = true)
- **Catalog_Hotel**: A hotel with fixed pricing managed locally (hasLiveRates = false)
- **Hotel_Header**: The prominent top section displaying hotel name, location, stars, and key attributes
- **Image_Gallery**: The collection of hotel images displayed in a browsable format
- **Info_Section**: A distinct content area presenting specific category of hotel information
- **Quick_Facts_Grid**: A scannable summary of key hotel attributes (stars, location, services count, review score)
- **Availability_Panel**: The booking interface showing dates, rooms, and pricing options
- **Room_Card**: A visual card displaying room type information, capacity, board type, and price
- **Service_Badge**: A visual indicator for hotel amenities and services
- **Review_Display**: The presentation of review score and count
- **Promo_Badge**: A visual indicator showing promotional discount percentage
- **Breadcrumb**: Navigation trail showing page hierarchy
- **Sticky_Booking_Widget**: A fixed-position booking interface that remains visible during scroll (catalog hotels only)
- **Description_Section**: The text area displaying hotel descriptions (short and long)
- **Highlights_Display**: The presentation of hotel key selling points
- **Location_Section**: The map and geographic information display
- **Page_Layout**: The overall structure organizing header, content, and sidebar areas

## Requirements

### Requirement 1: Professional Page Header

**User Story:** As a potential guest, I want to see a professional, prominent header with the hotel's key information, so that I can quickly understand the hotel's identity and quality level.

#### Acceptance Criteria

1. THE Hotel_Header SHALL display the hotel name without supplier prefix (cleaned)
2. THE Hotel_Header SHALL display the star rating as visual star icons (★)
3. THE Hotel_Header SHALL display the city and country location with map icon
4. WHEN the hotel has reviews (reviewCount > 0), THE Hotel_Header SHALL display the review score and review count
5. WHEN the hotel has a promo (isPromo = true), THE Hotel_Header SHALL display the Promo_Badge with discount percentage
6. THE Hotel_Header SHALL use a visually distinct layout with clear typography hierarchy
7. THE Hotel_Header SHALL be responsive and adapt to mobile viewports

### Requirement 2: Prominent Image Gallery

**User Story:** As a potential guest, I want to see high-quality hotel images prominently, so that I can visualize the property before booking.

#### Acceptance Criteria

1. WHEN the hotel has gallery images, THE Image_Gallery SHALL display images in a browsable format
2. THE Image_Gallery SHALL be positioned prominently near the top of the page
3. THE Image_Gallery SHALL support full-screen image viewing
4. THE Image_Gallery SHALL display the main image (imageUrl) when gallery is empty
5. THE Image_Gallery SHALL display image navigation controls
6. THE Image_Gallery SHALL be responsive and touch-friendly on mobile devices

### Requirement 3: Quick Facts Overview

**User Story:** As a potential guest, I want to see a quick summary of key hotel facts at a glance, so that I can rapidly assess if the hotel meets my needs.

#### Acceptance Criteria

1. THE Quick_Facts_Grid SHALL display the star rating
2. THE Quick_Facts_Grid SHALL display the location (city, country)
3. THE Quick_Facts_Grid SHALL display the services count with appropriate icon
4. WHEN the hotel has reviews, THE Quick_Facts_Grid SHALL display the review score
5. THE Quick_Facts_Grid SHALL be positioned prominently after the header
6. THE Quick_Facts_Grid SHALL use icons and concise labels for scannability
7. THE Quick_Facts_Grid SHALL be responsive with grid layout adapting to screen size

### Requirement 4: Comprehensive Description Display

**User Story:** As a potential guest, I want to read detailed information about the hotel, so that I can understand what makes it unique and decide if it suits my preferences.

#### Acceptance Criteria

1. WHEN the hotel has longDescription, THE Description_Section SHALL display the long description
2. WHEN the hotel has no longDescription but has description, THE Description_Section SHALL display the short description
3. THE Description_Section SHALL support expandable text for lengthy descriptions (>300 characters)
4. THE Description_Section SHALL use readable typography with appropriate line height
5. THE Description_Section SHALL be positioned in a prominent Info_Section

### Requirement 5: Organized Highlights Display

**User Story:** As a potential guest, I want to see the hotel's key selling points clearly highlighted, so that I can quickly understand what makes this property special.

#### Acceptance Criteria

1. WHEN the hotel has highlights, THE Highlights_Display SHALL present each highlight as a distinct visual element
2. THE Highlights_Display SHALL use a grid or list layout for easy scanning
3. THE Highlights_Display SHALL include appropriate icons or visual indicators
4. THE Highlights_Display SHALL be positioned prominently in its own Info_Section

### Requirement 6: Clear Services and Amenities Section

**User Story:** As a potential guest, I want to see all available hotel services and amenities organized clearly, so that I can verify the hotel has the facilities I need.

#### Acceptance Criteria

1. WHEN the hotel has services, THE Page SHALL display all services in a Services_Section
2. EACH service SHALL be displayed as a Service_Badge with an appropriate icon
3. THE Services_Section SHALL organize services in a responsive grid layout
4. THE Services_Section SHALL categorize common service icons (WiFi, Pool, Restaurant, Spa, Gym, etc.)
5. THE Services_Section SHALL be easy to scan visually

### Requirement 7: Comprehensive Room Display for Catalog Hotels

**User Story:** As a potential guest viewing a catalog hotel, I want to see all available room types with their details and pricing, so that I can choose the room that fits my needs and budget.

#### Acceptance Criteria

1. WHEN the hotel is a Catalog_Hotel with rooms, THE Page SHALL display all rooms in a Room_List section
2. EACH room SHALL be displayed as a Room_Card showing name, board type, max occupancy, and price per night
3. THE Room_Card SHALL display the board type using localized labels (BOARD_LABELS)
4. THE Room_Card SHALL display capacity with person icon and count
5. THE Room_Card SHALL display price prominently with currency
6. THE Room_Card SHALL include a booking call-to-action button
7. THE Room_List SHALL be positioned prominently before or after the availability panel

### Requirement 8: Live Availability Panel for Supplier Hotels

**User Story:** As a potential guest viewing a live-rate hotel, I want to check real-time availability and pricing for my dates, so that I can see current options and book immediately.

#### Acceptance Criteria

1. WHEN the hotel is a Live_Rate_Hotel, THE Availability_Panel SHALL be displayed prominently
2. THE Availability_Panel SHALL allow date selection for check-in and check-out
3. THE Availability_Panel SHALL allow room configuration (adults and children per room)
4. THE Availability_Panel SHALL fetch and display real-time room availability and pricing
5. THE Availability_Panel SHALL display loading states during availability checks
6. THE Availability_Panel SHALL handle and display error states appropriately

### Requirement 9: Enhanced Location Section

**User Story:** As a potential guest, I want to see the hotel's location clearly on a map with address details, so that I can assess proximity to my destinations.

#### Acceptance Criteria

1. THE Location_Section SHALL display the city and country with map pin icon
2. THE Location_Section SHALL embed an interactive map using mapUrl or constructed query
3. THE Location_Section SHALL be positioned in a dedicated Info_Section
4. THE Location_Section SHALL be responsive on all device sizes

### Requirement 10: Responsive Layout with Professional Styling

**User Story:** As a user on any device, I want the page layout to be responsive and professional-looking, so that I have an optimal viewing experience regardless of screen size.

#### Acceptance Criteria

1. THE Page_Layout SHALL use a professional design system with consistent spacing and typography
2. THE Page_Layout SHALL adapt responsively to mobile, tablet, and desktop viewports
3. WHEN viewing on desktop AND the hotel is a Catalog_Hotel, THE Page_Layout SHALL use a two-column layout with sidebar
4. WHEN viewing on mobile OR the hotel is a Live_Rate_Hotel, THE Page_Layout SHALL use a single-column layout
5. THE Page_Layout SHALL maintain visual hierarchy with clear section separation
6. THE Page_Layout SHALL use professional color scheme and typography

### Requirement 11: Sticky Booking Widget for Catalog Hotels

**User Story:** As a potential guest viewing a catalog hotel on desktop, I want the booking widget to remain accessible as I scroll, so that I can easily proceed to booking after reviewing information.

#### Acceptance Criteria

1. WHEN the hotel is a Catalog_Hotel AND viewport is desktop size, THE Sticky_Booking_Widget SHALL be displayed in the sidebar
2. THE Sticky_Booking_Widget SHALL display the from price per night
3. THE Sticky_Booking_Widget SHALL display the unit description (e.g., "par nuit · chambre double")
4. WHEN the hotel has reviews, THE Sticky_Booking_Widget SHALL display review score and count
5. THE Sticky_Booking_Widget SHALL include the primary booking call-to-action button
6. THE Sticky_Booking_Widget SHALL include the "Demander un devis" secondary action
7. THE Sticky_Booking_Widget SHALL display the deposit percentage note
8. THE Sticky_Booking_Widget SHALL NOT show "À partir de" prefix (showFromPrefix = false)

### Requirement 12: SEO and Metadata

**User Story:** As the business, I want the hotel detail pages to have proper SEO metadata and structured data, so that they rank well in search engines and display rich snippets.

#### Acceptance Criteria

1. THE Page SHALL generate appropriate page title with hotel name, stars, city, and brand
2. THE Page SHALL generate meta description including key hotel information
3. THE Page SHALL include canonical URL for the hotel
4. THE Page SHALL include Open Graph metadata for social sharing
5. THE Page SHALL include Hotel structured data (JSON-LD) with all available hotel properties
6. THE Page SHALL include Breadcrumb structured data (JSON-LD) showing navigation hierarchy

### Requirement 13: Information Hierarchy and Scannability

**User Story:** As a potential guest, I want information organized in a logical hierarchy, so that I can quickly find what I'm looking for without reading everything.

#### Acceptance Criteria

1. THE Page SHALL organize content in clearly labeled Info_Sections
2. EACH Info_Section SHALL have a descriptive heading
3. THE Page SHALL prioritize information in order: Header, Gallery, Quick Facts, Description, Availability/Rooms, Highlights, Services, Location
4. THE Page SHALL use visual grouping and whitespace to separate content areas
5. THE Page SHALL use consistent styling for similar content types

### Requirement 14: Price Display Consistency

**User Story:** As a potential guest, I want pricing information displayed consistently and clearly, so that I understand the cost without confusion.

#### Acceptance Criteria

1. WHEN displaying prices, THE Page SHALL show the numeric value followed by currency
2. WHEN currency is TND, THE Page SHALL display "DT" instead of "TND"
3. WHEN displaying room prices, THE Page SHALL include "par nuit" or appropriate unit label
4. WHEN the hotel has fromPricePerNight > 0, THE Page SHALL display this prominently
5. ALL price displays SHALL use consistent formatting and styling

### Requirement 15: Promotional Content Display

**User Story:** As a potential guest, I want to see promotional offers clearly highlighted, so that I can take advantage of special deals.

#### Acceptance Criteria

1. WHEN the hotel has isPromo = true, THE Page SHALL display promotional indicators
2. WHEN promoPercent is provided, THE Promo_Badge SHALL display the discount percentage (e.g., "-20%")
3. WHEN promoPercent is null, THE Promo_Badge SHALL display a generic "Promo" label
4. THE Promo_Badge SHALL be visually prominent and positioned near key decision points

### Requirement 16: Review Display

**User Story:** As a potential guest, I want to see hotel reviews and ratings prominently, so that I can gauge the hotel's quality from other guests' experiences.

#### Acceptance Criteria

1. WHEN reviewCount > 0, THE Review_Display SHALL show the review score
2. WHEN reviewCount > 0, THE Review_Display SHALL show the number of reviews
3. THE Review_Display SHALL use star icon or similar visual indicator
4. THE Review_Display SHALL be positioned prominently in the header and booking widget
5. WHEN reviewCount = 0, THE Page SHALL NOT display review information

### Requirement 17: Accessible and Semantic HTML

**User Story:** As a user with assistive technology, I want the page to be properly structured and accessible, so that I can navigate and understand the content effectively.

#### Acceptance Criteria

1. THE Page SHALL use semantic HTML5 elements (header, nav, main, section, aside, article)
2. THE Page SHALL include appropriate ARIA labels for interactive elements
3. THE Page SHALL maintain proper heading hierarchy (h1, h2, h3)
4. THE Page SHALL ensure sufficient color contrast for text readability
5. THE Page SHALL support keyboard navigation for all interactive elements
6. ALL images SHALL include descriptive alt text

### Requirement 18: Performance and Loading

**User Story:** As a user, I want the page to load quickly and smoothly, so that I can view hotel information without delays.

#### Acceptance Criteria

1. THE Page SHALL render with force-dynamic to ensure fresh hotel data
2. THE Page SHALL optimize images with appropriate formats and lazy loading
3. THE Page SHALL handle loading states gracefully during data fetching
4. THE Page SHALL minimize layout shifts during content loading
5. THE Page SHALL prefetch critical resources

### Requirement 19: Error Handling

**User Story:** As a user, I want clear error messages when something goes wrong, so that I understand what happened and what to do next.

#### Acceptance Criteria

1. WHEN a hotel is not found, THE Page SHALL return 404 not found status
2. WHEN availability check fails, THE Availability_Panel SHALL display an appropriate error message
3. WHEN images fail to load, THE Page SHALL display fallback images
4. THE Page SHALL handle missing or null data fields gracefully without breaking layout

### Requirement 20: Breadcrumb Navigation

**User Story:** As a user, I want to see where I am in the site hierarchy and navigate back easily, so that I can explore related content.

#### Acceptance Criteria

1. THE Page SHALL display a Breadcrumb navigation component
2. THE Breadcrumb SHALL show: Accueil → Hôtels en Tunisie/Hôtels à l'étranger → Hotel Name
3. THE Breadcrumb SHALL link to each parent page
4. THE Breadcrumb SHALL adapt based on hotel country (Tunisie vs other countries)
5. THE Breadcrumb SHALL include structured data (JSON-LD) for search engines

