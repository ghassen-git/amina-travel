# Design Document: Professional Hotel Detail Page Redesign

## Overview

This design document specifies the technical architecture and implementation approach for redesigning the hotel detail page (`/hotels/[slug]/page.tsx`) to provide a professional, comprehensive presentation of hotel information inspired by modern booking platforms (Booking.com, Expedia) while maintaining the existing Amina Travel design system.

### Goals

- Transform the hotel detail page into a professional, comprehensive showcase of hotel information
- Provide clear visual hierarchy and scannable content organization
- Support dual display modes: live-rate hotels (supplier) and catalog hotels (local)
- Maintain responsive design across all device sizes
- Integrate seamlessly with existing design system and component library
- Ensure accessibility and SEO best practices

### Key Design Principles

1. **Information Hierarchy**: Prioritize content logically (header → gallery → quick facts → availability → rooms → highlights → services → location)
2. **Visual Clarity**: Use white space, clear section separation, and consistent styling
3. **Scannability**: Enable rapid information assessment through icons, badges, and structured layouts
4. **Professional Aesthetics**: Match modern booking platform standards while maintaining brand identity
5. **Responsive First**: Ensure optimal experience across all device sizes

## Architecture

### High-Level Component Structure

```
HotelDetailPage (Server Component)
├── JsonLd (SEO structured data)
├── DetailHero (Header section)
├── Section (Main content wrapper)
│   └── Container (Responsive layout)
│       ├── DetailMain (Primary content column)
│       │   ├── ImageGallery
│       │   ├── HotelAvailabilityPanel (live-rate only)
│       │   ├── RoomsPanel (catalog hotels)
│       │   ├── HighlightsPanel
│       │   ├── ServicesPanel
│       │   └── LocationPanel
│       └── PriceSticky (Sidebar - catalog hotels only)
```

### Page Layout Modes

The page supports two distinct layout modes based on hotel type:

**Mode 1: Live-Rate Hotels (Supplier Hotels)**
- Single-column layout
- No sidebar
- Availability panel appears inline in content flow
- Dynamic pricing with real-time availability checks

**Mode 2: Catalog Hotels**
- Two-column layout on desktop (content + sidebar)
- Sidebar contains sticky booking widget
- Fixed pricing with predefined rooms
- Single-column layout on mobile

Layout decision logic:
```typescript
const useSidebar = !hotel.hasLiveRates && hotel.fromPricePerNight > 0;
```

### Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│ Server Component (page.tsx)                                 │
│  - Fetch hotel data via getHotelBySlug()                   │
│  - Parse URL parameters (dates, rooms, adults)             │
│  - Generate SEO metadata                                    │
│  - Determine layout mode (sidebar vs single-column)        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ Static Presentation Components                              │
│  - DetailHero (hotel name, stars, location, reviews)       │
│  - ImageGallery (browsable photo gallery)                  │
│  - Panels (highlights, services, location)                 │
│  - PriceSticky (sidebar booking widget)                    │
└─────────────────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ Interactive Client Components                               │
│  - HotelAvailabilityPanel (live rate checking)            │
│  - ExpandableText (show more/less for descriptions)       │
│  - ImageGallery lightbox (full-screen viewing)            │
└─────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### 1. Page Container (`page.tsx`)

**Purpose**: Server component that orchestrates data fetching, layout determination, and component composition.

**Key Responsibilities**:
- Fetch hotel data from API
- Parse and validate URL parameters
- Generate SEO metadata (title, description, structured data)
- Determine layout mode (sidebar vs single-column)
- Compose static and interactive components
- Handle not found (404) cases

**Props Interface**:
```typescript
type Props = {
  params: Promise<{ slug: string }>;
  searchParams: Promise<{
    checkIn?: string;
    checkOut?: string;
    rooms?: string;
    adults?: string;
  }>;
};
```

**Layout Determination**:
```typescript
const useSidebar = !hotel.hasLiveRates && hotel.fromPricePerNight > 0;

// CSS class application
<div className={`container-x ${useSidebar ? "detail-layout" : ""}`}>
  <div className={useSidebar ? "detail-main" : ""}>
    {/* Main content */}
  </div>
  {useSidebar && <PriceSticky {...} />}
</div>
```

### 2. DetailHero Component

**Purpose**: Prominent header section displaying hotel identity, location, and key attributes.

**Current Implementation**: Existing component in `Cards.tsx`, used as-is with appropriate data mapping.

**Props**:
```typescript
interface DetailHeroProps {
  eyebrow: ReactNode;      // "Hôtel ★★★★ · Hammamet"
  title: string;           // "Hotel Name"
  subtitle: ReactNode;     // Description with ExpandableText
  image: string;           // Main hero image
  rating?: number;         // Review score (0-10)
  reviews?: number;        // Review count
  meta: Array<{
    icon: LucideIcon;
    label: string;
  }>;
}
```

**Usage Pattern**:
```typescript
<DetailHero
  eyebrow={<>Hôtel <span className="star-text">{"★".repeat(hotel.stars)}</span> · {hotel.city}</>}
  title={cleanHotelName(hotel.name)}
  subtitle={<ExpandableText text={hotel.longDescription ?? hotel.description ?? ""} max={220} />}
  image={hotel.imageUrl ?? hotel.gallery[0] ?? "/images/hero.jpg"}
  rating={hotel.reviewCount > 0 ? hotel.reviewScore : undefined}
  reviews={hotel.reviewCount > 0 ? hotel.reviewCount : undefined}
  meta={[
    { icon: MapPin, label: hotel.city },
    { icon: Sparkles, label: `${hotel.services.length} services` },
  ]}
/>
```

**Visual Styling**:
- Full-width hero with overlay gradient
- Large typography with clear hierarchy (eyebrow → title → subtitle)
- Translucent badge for reviews
- Icon-labeled metadata items

### 3. ImageGallery Component

**Purpose**: Browsable photo gallery with grid layout and full-screen lightbox.

**Current Implementation**: Existing component in `ImageGallery.tsx`, used with hotel gallery images.

**Props**:
```typescript
interface ImageGalleryProps {
  images: string[];  // Array of image URLs
  alt: string;       // Base alt text for images
}
```

**Features**:
- Grid layout: 1 main image + up to 4 thumbnails
- "View all X photos" overlay on last thumbnail when more images exist
- Lightbox with keyboard navigation (arrows, escape)
- Thumbnail strip in lightbox
- Touch-friendly on mobile
- Responsive grid layout

**Positioning**: Immediately below hero section, before any content panels.

### 4. HotelAvailabilityPanel Component

**Purpose**: Interactive availability checker for live-rate hotels with room selection and booking flow.

**Current Implementation**: Existing component in `HotelAvailabilityPanel.tsx`, rendered conditionally.

**Display Condition**:
```typescript
{hotel.hasLiveRates && (
  <HotelAvailabilityPanel
    hotelId={hotel.id}
    slug={hotel.slug}
    hotelName={hotel.name}
    city={hotel.city}
    initialCheckIn={checkIn ?? ""}
    initialCheckOut={checkOut ?? ""}
    initialRooms={initialRooms}
  />
)}
```

**Features**:
- Date range selection
- Occupancy configuration (adults/children per room)
- Real-time availability fetching
- Room type and board selection
- Price display with promotions
- Booking flow initiation
- Loading and error states

**Positioning**: For live-rate hotels, appears after ImageGallery and before other panels.

### 5. RoomsPanel Component (Catalog Hotels)

**Purpose**: Display fixed-price room options for catalog hotels.

**Implementation Strategy**: Use existing Panel component with custom room list rendering.

**Structure**:
```typescript
<Panel title="Chambres & tarifs" defaultExpanded={!!checkIn && !!checkOut}>
  {!hotel.hasLiveRates && (
    <p className="panel__hint">
      Tarifs par nuit. Choisissez une chambre, puis vos dates à l'étape suivante.
    </p>
  )}
  <div className="room-list">
    {hotel.rooms.map(room => (
      <div key={room.id} className="room-row">
        <div className="room-row__info">
          <p className="room-row__name">{room.name}</p>
          <div className="room-row__tags">
            <span className="tag">{BOARD_LABELS[room.board] ?? room.board}</span>
            <span className="tag">
              <Users /> {room.maxOccupancy} pers.
            </span>
          </div>
        </div>
        <div className="room-row__price price-mini">
          <p className="price-mini__label">dès</p>
          <p className="price-mini__value">
            {room.pricePerNight} {room.currency === "TND" ? "DT" : room.currency}
          </p>
          <p className="price-mini__unit">/ nuit</p>
        </div>
        <Link href={bookHref(room.id)} className="pill pill--gold room-row__book">
          Réserver
        </Link>
      </div>
    ))}
  </div>
</Panel>
```

**Room Card Elements**:
- Room name and type
- Board type badge (localized via BOARD_LABELS)
- Occupancy badge with icon
- Price per night with currency
- Booking CTA button

**Positioning**: 
- For catalog hotels: After ImageGallery
- For live-rate hotels: After HotelAvailabilityPanel (if rooms exist)

### 6. HighlightsPanel Component

**Purpose**: Display hotel key selling points in scannable format.

**Implementation Strategy**: Use Panel component with grid layout.

**Conditional Rendering**:
```typescript
{hotel.highlights.length > 0 && (
  <Panel title="Points forts">
    <div className="highlights-grid">
      {hotel.highlights.map((highlight) => (
        <div key={highlight} className="highlight">{highlight}</div>
      ))}
    </div>
  </Panel>
)}
```

**Styling Requirements** (to be added to `_hotels.scss`):
```scss
.highlights-grid {
  display: grid;
  gap: 0.875rem;
  grid-template-columns: 1fr;
  @include md {
    grid-template-columns: repeat(2, 1fr);
  }
}

.highlight {
  display: flex;
  align-items: flex-start;
  gap: 0.5rem;
  padding: 0.75rem;
  background: color-mix(in oklab, var(--gold) 5%, transparent);
  border-left: 3px solid var(--gold);
  border-radius: var(--radius-lg);
  font-size: 0.875rem;
  line-height: 1.5;
}
```

### 7. ServicesPanel Component

**Purpose**: Display all hotel amenities and services with appropriate icons.

**Implementation Strategy**: Use Panel component with icon mapping and grid layout.

**Icon Mapping Logic**:
```typescript
function getServiceIcon(serviceName: string): LucideIcon {
  const lower = serviceName.toLowerCase();
  
  if (lower.includes('spa') || lower.includes('hammam') || lower.includes('thalasso')) 
    return Sparkles;
  else if (lower.includes('wifi') || lower.includes('wi-fi')) 
    return Wifi;
  else if (lower.includes('piscine') || lower.includes('plage')) 
    return Waves;
  else if (lower.includes('restaurant') || lower.includes('picine')) 
    return Utensils;
  else if (lower.includes('chambre') || lower.includes('bedroom')) 
    return Bed;
  else if (lower.includes('bain') || lower.includes('bath') || lower.includes('douche') || lower.includes('shower')) 
    return Bath;
  else if (lower.includes('sport') || lower.includes('gym') || lower.includes('fitness')) 
    return Dumbbell;
  else if (lower.includes('kids') || lower.includes('enfant')) 
    return Users;
  else if (lower.includes('tennis') || lower.includes('yoga') || lower.includes('vélo') || lower.includes('bike')) 
    return Bike;
  
  return Sparkles; // default icon
}
```

**Structure**:
```typescript
{hotel.services.length > 0 && (
  <Panel title="Services & équipements">
    <div className="services-grid">
      {hotel.services.map((service) => {
        const Icon = getServiceIcon(service);
        return (
          <div key={service} className="service-item">
            <Icon /> {service}
          </div>
        );
      })}
    </div>
  </Panel>
)}
```

**Styling Requirements** (to be added to `_hotels.scss`):
```scss
.services-grid {
  display: grid;
  gap: 1rem;
  grid-template-columns: 1fr;
  @include sm {
    grid-template-columns: repeat(2, 1fr);
  }
  @include md {
    grid-template-columns: repeat(3, 1fr);
  }
}

.service-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.875rem;
  
  svg {
    height: 1.125rem;
    width: 1.125rem;
    color: var(--gold);
    flex-shrink: 0;
  }
}
```

### 8. LocationPanel Component

**Purpose**: Display hotel location with map embed and geographic information.

**Implementation Strategy**: Use Panel component with map embed utility.

**Structure**:
```typescript
<Panel title="Localisation">
  <div className="loc-line">
    <MapPin /> {hotel.city}, {hotel.country}
  </div>
  <MapEmbed query={mapQuery} />
</Panel>
```

**Map Query Construction**:
```typescript
const mapQuery = hotel.mapUrl || `${hotel.city}, ${hotel.country}`;
```

**MapEmbed Component** (existing utility):
```typescript
export function MapEmbed({ query }: { query: string }) {
  const encoded = encodeURIComponent(query);
  const src = `https://www.google.com/maps?q=${encoded}&output=embed`;
  
  return (
    <div className="map-embed">
      <iframe
        src={src}
        width="600"
        height="450"
        style={{ border: 0 }}
        allowFullScreen
        loading="lazy"
        referrerPolicy="no-referrer-when-downgrade"
        title="Hotel Location Map"
      />
    </div>
  );
}
```

### 9. PriceSticky Component (Sidebar)

**Purpose**: Sticky booking widget for catalog hotels displayed in sidebar.

**Current Implementation**: Existing component in `Cards.tsx`, rendered conditionally.

**Display Condition**:
```typescript
{useSidebar && (
  <PriceSticky
    price={Number(hotel.fromPricePerNight)}
    unit="par nuit · chambre double"
    badge={hotel.reviewCount > 0
      ? <><span className="star-text">★</span> {hotel.reviewScore} ({hotel.reviewCount} avis)</>
      : undefined}
    dates={[]}
    ctaHref={bookHref()}
    ctaLabel="Réserver maintenant"
    showFromPrefix={false}
  />
)}
```

**Props Customization**:
- `showFromPrefix={false}`: Hides "À partir de" prefix on detail pages
- `unit`: Descriptive pricing unit ("par nuit · chambre double")
- `badge`: Review score and count
- `ctaHref`: Booking link with optional room and stay parameters
- `note`: Default deposit percentage message

**Sticky Behavior**: Implemented via CSS (existing `.price-sticky` class with `position: sticky`)

### 10. Panel Component

**Purpose**: Reusable collapsible content section with consistent styling.

**Current Implementation**: Existing component in `Panel.tsx`, used throughout.

**Props**:
```typescript
interface PanelProps {
  title: string;
  children: ReactNode;
  defaultExpanded?: boolean;
}
```

**Features**:
- Collapsible/expandable with toggle button
- Card-style shell with rounded corners
- Consistent padding and spacing
- Animated expansion
- Accessibility (aria-expanded)

**Styling**: Existing `.panel` class in `_cards.scss`

## Data Models

### Hotel Data Structure

The hotel data is fetched from the API and conforms to the following structure:

```typescript
interface Hotel {
  id: string;
  slug: string;
  name: string;              // May include supplier prefix
  city: string;
  country: string;
  stars: number;             // 0-5
  
  // Visual assets
  imageUrl: string | null;
  gallery: string[];
  
  // Descriptions
  description: string | null;      // Short description
  longDescription: string | null;  // Detailed description
  
  // Highlights and services
  highlights: string[];
  services: string[];
  
  // Pricing and availability
  hasLiveRates: boolean;     // true = supplier hotel, false = catalog
  fromPricePerNight: number;
  currency: string;          // "TND", "EUR", etc.
  
  // Rooms (catalog hotels)
  rooms: Room[];
  
  // Reviews
  reviewScore: number;       // 0-10
  reviewCount: number;
  
  // Promotions
  isPromo: boolean;
  promoPercent: number | null;
  
  // Location
  mapUrl: string | null;
}

interface Room {
  id: string;
  name: string;
  board: string;             // Board type code
  maxOccupancy: number;
  pricePerNight: number;
  currency: string;
}
```

### URL Parameters

```typescript
interface SearchParams {
  checkIn?: string;     // ISO date string: "2024-12-25"
  checkOut?: string;    // ISO date string: "2024-12-28"
  rooms?: string;       // Encoded rooms: "2|3,4" = 2 adults + 2 children ages 3,4
  adults?: string;      // Legacy parameter, still accepted
}
```

### Booking Link Construction

```typescript
function buildBookingHref(hotel: Hotel, params: SearchParams, roomId?: string): string {
  const qs = new URLSearchParams();
  
  if (params.checkIn) qs.set('checkIn', params.checkIn);
  if (params.checkOut) qs.set('checkOut', params.checkOut);
  if (params.rooms) qs.set('rooms', params.rooms);
  if (roomId) qs.set('room', roomId);
  
  const queryString = qs.toString();
  return queryString 
    ? `/hotels/${hotel.slug}/reserver?${queryString}`
    : `/hotels/${hotel.slug}/reserver`;
}
```

## Styling Guidelines and Design System Integration

### Color Palette

The design uses the existing Amina Travel color system:

```scss
--navy: #0f172a;                    // Primary brand color
--navy-foreground: #f8fafc;         // Text on navy background
--gold: #f59e0b;                    // Accent color
--gold-dark: #d97706;               // Darker gold variant
--gold-foreground: #0f172a;         // Text on gold background
--background: #ffffff;              // Page background
--foreground: #0f172a;              // Primary text
--muted-foreground: #64748b;        // Secondary text
--border: #e2e8f0;                  // Border color
--secondary: #f1f5f9;               // Light background variant
```

### Typography

```scss
// Font families
--font-sans: system-ui, -apple-system, sans-serif;
--font-display: 'Playfair Display', Georgia, serif;

// Font sizes (mobile → desktop)
--text-xs: 0.75rem;      // 12px
--text-sm: 0.875rem;     // 14px
--text-base: 1rem;       // 16px
--text-lg: 1.125rem;     // 18px
--text-xl: 1.25rem;      // 20px
--text-2xl: 1.5rem;      // 24px → 36px (mobile → desktop)
--text-3xl: 1.875rem;    // 30px → 48px
--text-4xl: 2.25rem;     // 36px → 60px

// Heading hierarchy
h1: 2.25rem mobile / 3.75rem desktop (--text-4xl)
h2: 1.875rem mobile / 3rem desktop    (--text-3xl)
h3: 1.5rem                            (--text-2xl)
h4: 1.25rem                           (--text-xl)
```

### Spacing Scale

```scss
// Consistent spacing increments
--space-1: 0.25rem;   // 4px
--space-2: 0.5rem;    // 8px
--space-3: 0.75rem;   // 12px
--space-4: 1rem;      // 16px
--space-5: 1.25rem;   // 20px
--space-6: 1.5rem;    // 24px
--space-8: 2rem;      // 32px
--space-10: 2.5rem;   // 40px
--space-12: 3rem;     // 48px
--space-16: 4rem;     // 64px
--space-20: 5rem;     // 80px
```

### Border Radius

```scss
--radius-sm: 0.375rem;    // 6px
--radius-md: 0.5rem;      // 8px
--radius-lg: 0.75rem;     // 12px
--radius-xl: 1rem;        // 16px
--radius-2xl: 1.5rem;     // 24px
--radius-3xl: 2rem;       // 32px
```

### Shadow System

```scss
--shadow-elegant: 0 10px 40px rgba(0, 0, 0, 0.1);
--shadow-soft: 0 1px 3px rgba(0, 0, 0, 0.08);
```

### Component-Specific Styles

#### DetailHero Styles
```scss
.detail-hero {
  position: relative;
  padding: 7rem 0 3rem;
  overflow: hidden;
  color: var(--navy-foreground);
  
  @include md { 
    padding: 9rem 0 5rem; 
  }
  
  &__title {
    margin-top: 0.75rem;
    font-size: 2.25rem;
    max-width: 48rem;
    
    @include md { 
      font-size: 3.75rem; 
    }
  }
  
  &__meta {
    margin-top: 1.5rem;
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    column-gap: 1.5rem;
    row-gap: 0.75rem;
    font-size: 0.875rem;
  }
  
  &__rating {
    display: inline-flex;
    align-items: center;
    gap: 0.375rem;
    border-radius: 9999px;
    background: color-mix(in oklab, var(--background) 95%, transparent);
    padding: 0.375rem 0.75rem;
    color: var(--navy);
    font-weight: 600;
  }
}
```

#### Layout Grid Styles
```scss
.detail-layout {
  display: grid;
  gap: 2.5rem;
  
  @include lg { 
    grid-template-columns: 1fr 360px; 
  }
}

.detail-main > * + * { 
  margin-top: 2.5rem; 
}
```

#### Panel Styles
```scss
.panel {
  background: var(--background);
  border: 1px solid var(--border);
  border-radius: var(--radius-2xl);
  padding: 1.5rem;
  box-shadow: var(--shadow-soft);
  
  &__header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    width: 100%;
    background: none;
    border: none;
    padding: 0;
    cursor: pointer;
    text-align: left;
  }
  
  &__title {
    font-size: 1.5rem;
    font-weight: 600;
    color: var(--navy);
  }
  
  &__body {
    margin-top: 1.5rem;
  }
  
  &__hint {
    font-size: 0.875rem;
    color: var(--muted-foreground);
    margin-bottom: 1rem;
  }
}
```

#### Room Row Styles
```scss
.room-list > * + * { 
  margin-top: 1rem; 
}

.room-row {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  padding: 1.25rem;
  background: var(--secondary);
  border-radius: var(--radius-xl);
  transition: background 0.2s;
  
  @include md {
    flex-direction: row;
    align-items: center;
    justify-content: space-between;
  }
  
  &:hover {
    background: color-mix(in oklab, var(--gold) 5%, var(--secondary));
  }
  
  &__info {
    flex: 1;
    min-width: 0;
  }
  
  &__name {
    font-weight: 600;
    font-size: 1.125rem;
    color: var(--navy);
  }
  
  &__tags {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
    margin-top: 0.5rem;
  }
  
  &__book {
    flex-shrink: 0;
  }
}

.tag {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  padding: 0.25rem 0.625rem;
  background: var(--background);
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 600;
  color: var(--foreground);
  
  svg {
    height: 0.875rem;
    width: 0.875rem;
  }
}
```

#### Price Display Styles
```scss
.price-mini {
  display: flex;
  align-items: baseline;
  gap: 0.375rem;
  
  &__label {
    font-size: 0.75rem;
    color: var(--muted-foreground);
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }
  
  &__value {
    font-size: 1.5rem;
    font-weight: 700;
    color: var(--navy);
    font-family: var(--font-display);
  }
  
  &__unit {
    font-size: 0.875rem;
    color: var(--muted-foreground);
  }
}
```

#### PriceSticky Styles (existing)
```scss
.price-sticky {
  border-radius: var(--radius-3xl);
  background: var(--navy);
  color: var(--navy-foreground);
  padding: 2rem;
  position: sticky;
  top: 6rem;
  
  &__price {
    font-size: 2.5rem;
    font-weight: 700;
    font-family: var(--font-display);
    line-height: 1;
  }
  
  &__cta {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    width: 100%;
    padding: 1rem;
    background: var(--gold);
    color: var(--gold-foreground);
    border-radius: var(--radius-xl);
    font-weight: 600;
    text-decoration: none;
    transition: background 0.2s;
    
    &:hover {
      background: var(--gold-dark);
    }
  }
}
```

### Icon Usage Guidelines

1. **Consistency**: Use Lucide React icons consistently across all components
2. **Size**: Standard icon size is `1rem` (16px), larger for emphasis (1.125rem - 1.25rem)
3. **Color**: Icons inherit text color or use `var(--gold)` / `var(--gold-dark)` for emphasis
4. **Accessibility**: All icons should have descriptive aria-labels or be aria-hidden with adjacent text

Common icon mappings:
- MapPin: Location information
- Star: Ratings and reviews
- Sparkles: General services, highlights, luxury amenities
- Wifi: Internet connectivity
- Waves: Pool, beach, water features
- Utensils: Dining, restaurants
- Bed: Room amenities
- Bath: Bathroom features
- Dumbbell: Fitness, gym
- Users: Occupancy, children's facilities
- Bike: Activities, recreation

## Responsive Behavior Specifications

### Breakpoint System

```scss
// Defined in _mixins.scss
$breakpoint-sm: 640px;   // Small tablets
$breakpoint-md: 768px;   // Tablets
$breakpoint-lg: 1024px;  // Desktop
$breakpoint-xl: 1280px;  // Large desktop
```

### Mobile (< 768px)

**Layout**:
- Single-column layout for all hotel types
- No sidebar (PriceSticky not shown)
- Full-width components
- Reduced padding and spacing

**DetailHero**:
- Smaller title: `2.25rem` (36px)
- Reduced padding: `7rem 0 3rem`
- Stack meta items vertically if needed

**ImageGallery**:
- 1 column grid
- Touch-optimized lightbox controls
- Larger tap targets

**Panels**:
- Full-width cards
- Reduced padding: `1rem`
- Collapsible by default for longer content

**RoomRow**:
- Vertical stack: info → price → button
- Full-width booking button

**ServicesGrid**:
- 1 column or 2 columns maximum

### Tablet (768px - 1023px)

**Layout**:
- Single-column layout (sidebar not shown)
- Increased padding and spacing
- Optimal reading width

**DetailHero**:
- Medium title: `3rem` (48px)
- Increased padding: `9rem 0 5rem`
- Horizontal meta items

**ImageGallery**:
- Grid: 1 large + 4 thumbnails
- Larger thumbnails

**ServicesGrid**:
- 2-3 columns

**HighlightsGrid**:
- 2 columns

### Desktop (≥ 1024px)

**Layout**:
- Two-column layout for catalog hotels: `1fr 360px`
- Sidebar appears with PriceSticky
- Optimal content width with sidebar
- Single-column for live-rate hotels

**DetailHero**:
- Large title: `3.75rem` (60px)
- Maximum padding: `9rem 0 5rem`
- Horizontal meta items with generous spacing

**ImageGallery**:
- Grid: 1 main (60% width) + 4 thumbnails (40% width)
- Hover effects active

**RoomRow**:
- Horizontal layout: info | price | button
- Compact, scannable format

**ServicesGrid**:
- 3 columns for optimal scannability

**HighlightsGrid**:
- 2 columns

**PriceSticky** (catalog hotels only):
- Fixed width: `360px`
- Sticky positioning: `top: 6rem`
- Remains visible during scroll

### Layout Adaptation Examples

```scss
// Container width management
.container-x {
  width: 100%;
  max-width: 1280px;
  margin-inline: auto;
  padding-inline: 1rem;
  
  @include md {
    padding-inline: 2rem;
  }
  
  @include lg {
    padding-inline: 3rem;
  }
}

// Detail layout grid
.detail-layout {
  display: grid;
  gap: 2.5rem;
  
  @include lg {
    grid-template-columns: 1fr 360px;
    
    // Sidebar requires minimum viewport width
    @media (min-width: 1024px) and (max-width: 1200px) {
      grid-template-columns: 1fr 300px;
    }
  }
}

// Component spacing within detail-main
.detail-main {
  > * + * {
    margin-top: 1.5rem;
    
    @include md {
      margin-top: 2rem;
    }
    
    @include lg {
      margin-top: 2.5rem;
    }
  }
}
```

### Touch and Interaction Optimizations

**Mobile Tap Targets**:
- Minimum touch target size: `44px × 44px`
- Adequate spacing between interactive elements
- Larger buttons for primary actions

**Hover States** (desktop only):
```scss
@media (hover: hover) {
  .room-row:hover {
    background: color-mix(in oklab, var(--gold) 5%, var(--secondary));
  }
  
  .service-item:hover {
    color: var(--navy);
  }
}
```

**Focus States**:
All interactive elements must have visible focus indicators:
```scss
button:focus-visible,
a:focus-visible {
  outline: 2px solid var(--gold);
  outline-offset: 2px;
}
```

## Error Handling

### Not Found (404)

When a hotel slug doesn't exist:

```typescript
const hotel = await getHotelBySlug(slug).catch(() => null);
if (!hotel) notFound();
```

The `notFound()` function from Next.js triggers the nearest `not-found.tsx` page.

### Missing Data Graceful Degradation

**Principle**: Never break layout due to missing optional fields. Always provide fallbacks.

**Examples**:

```typescript
// Image fallback
<DetailHero
  image={hotel.imageUrl ?? hotel.gallery[0] ?? "/images/hero.jpg"}
/>

// Description fallback
<ExpandableText 
  text={hotel.longDescription ?? hotel.description ?? ""} 
/>

// Conditional sections
{hotel.highlights.length > 0 && <HighlightsPanel />}
{hotel.services.length > 0 && <ServicesPanel />}
{hotel.reviewCount > 0 && <ReviewDisplay />}

// Price display
{hotel.fromPricePerNight > 0 && (
  <PriceSticky price={hotel.fromPricePerNight} />
)}

// Map fallback
const mapQuery = hotel.mapUrl || `${hotel.city}, ${hotel.country}`;
```

### Availability Check Errors

The `HotelAvailabilityPanel` component handles its own error states:

- Network errors
- Timeout errors
- Invalid date ranges
- Overcapacity warnings
- No availability responses

These are displayed inline within the panel and don't affect other page components.

### Image Loading Errors

```typescript
// Next.js Image component handles loading states automatically
// For broken images, use onError handler:
<Image
  src={imageUrl}
  alt={alt}
  onError={(e) => {
    e.currentTarget.src = HOTEL_PLACEHOLDER;
  }}
/>
```

## Testing Strategy

### Property-Based Testing Assessment

**Assessment**: Property-based testing (PBT) is **NOT appropriate** for this feature.

**Reasoning**:

This feature is primarily concerned with:
1. **UI rendering and layout** - Presenting hotel information in a professional, responsive format
2. **Component composition** - Organizing existing components into a cohesive page structure  
3. **Conditional rendering logic** - Showing/hiding sections based on hotel data availability
4. **Responsive design** - Adapting layout across different viewport sizes
5. **Integration with external components** - Using existing Gallery, Panel, and availability checking components

None of these aspects are suitable for property-based testing because:
- UI rendering correctness cannot be verified through universal input properties
- Layout behavior is deterministic based on viewport size and hotel type, not a function with varied inputs
- Conditional rendering is tested better with specific example cases (hotel with/without gallery, reviews, etc.)
- There are no pure functions with universal properties to test (e.g., "for all X, property P holds")

**Recommended Testing Approach**:
- **Snapshot tests** for component rendering with various hotel data configurations
- **Example-based unit tests** for utility functions (cleanHotelName, icon mapping, price formatting)
- **Visual regression tests** to ensure UI matches design specifications
- **Integration tests** for user flows (viewing gallery, checking availability, booking)
- **Responsive design tests** across different viewport sizes

### Unit Testing (Vitest)

**Target Coverage**: Utility functions, data transformations, helper methods

**Test Files**:
- `stay.test.ts` - Room allocation, URL parameter parsing
- `hotel-utils.test.ts` - Name cleaning, price formatting, icon mapping

**Key Test Cases**:
1. `cleanHotelName()` - Removes supplier prefixes correctly
2. `parseRooms()` - Correctly parses room occupancy strings
3. `buildStayParams()` - Constructs valid query strings
4. Icon mapping logic - Returns correct icons for service names
5. Price formatting - Handles TND → DT conversion, null values

**Example Test**:
```typescript
describe('cleanHotelName', () => {
  it('removes supplier prefix from hotel name', () => {
    expect(cleanHotelName('TB - Hotel Paradise')).toBe('Hotel Paradise');
    expect(cleanHotelName('Hotel Paradise')).toBe('Hotel Paradise');
  });
  
  it('handles empty or null values', () => {
    expect(cleanHotelName('')).toBe('');
    expect(cleanHotelName(null)).toBe('');
  });
});
```

### Integration Testing

**Target Coverage**: Component interactions, data flow, API integration

**Test Scenarios**:
1. Page renders correctly with complete hotel data
2. Page renders correctly with minimal hotel data (graceful degradation)
3. Layout switches correctly between sidebar and single-column modes
4. Availability panel integrates with booking flow
5. Image gallery opens lightbox correctly
6. Panel expansion/collapse works correctly

**Tools**: Testing Library, Playwright (E2E)

### Manual Testing Checklist

**Visual Regression**:
- [ ] Compare with Booking.com/Expedia reference designs
- [ ] Verify consistency with Amina Travel brand guidelines
- [ ] Check spacing and alignment across breakpoints
- [ ] Verify icon sizing and colors

**Responsive Design**:
- [ ] Test on iPhone SE, iPhone 12, iPad, Desktop
- [ ] Verify touch targets on mobile
- [ ] Check sidebar behavior at 1024px breakpoint
- [ ] Verify image gallery on all devices

**Content Variations**:
- [ ] Hotel with all fields populated
- [ ] Hotel with minimal data (no gallery, no highlights, etc.)
- [ ] Hotel with very long description
- [ ] Hotel with many services (20+)
- [ ] Hotel with promotional pricing
- [ ] Hotel with no reviews

**Accessibility**:
- [ ] Keyboard navigation through all interactive elements
- [ ] Screen reader announces all content correctly
- [ ] Focus indicators visible on all elements
- [ ] Color contrast meets WCAG AA standards
- [ ] Images have descriptive alt text
- [ ] Semantic HTML structure (h1-h6 hierarchy)

**Performance**:
- [ ] Lighthouse score > 90
- [ ] Images load lazily below fold
- [ ] No layout shifts during load
- [ ] Fast TTI (Time to Interactive)

## SEO and Metadata

### Page Metadata Generation

```typescript
export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  const hotel = await getHotelBySlug(slug).catch(() => null);
  if (!hotel) return {};

  const name = cleanHotelName(hotel.name);
  const stars = hotel.stars > 0 ? `${hotel.stars}★ ` : "";
  const price = hotel.fromPricePerNight > 0
    ? ` À partir de ${Math.round(hotel.fromPricePerNight)} ${hotel.currency === "TND" ? "DT" : hotel.currency} la nuit.`
    : "";

  const title = `${name} — Hôtel ${stars}à ${hotel.city} | Amina Travel`;
  const description =
    hotel.description?.trim() ||
    `${name}, hôtel ${stars}à ${hotel.city}${hotel.country && hotel.country !== "Tunisie" ? `, ${hotel.country}` : ""}.${price} Réservez en ligne avec Amina Travel : acompte de ${DEPOSIT_PERCENT}%, solde à l'agence.`;

  return {
    title,
    description,
    alternates: { canonical: `/hotels/${slug}` },
    openGraph: {
      title,
      description,
      type: "website",
      images: hotel.imageUrl ? [hotel.imageUrl] : undefined,
    },
  };
}
```

### Structured Data (JSON-LD)

**Hotel Schema**:
```typescript
{
  "@context": "https://schema.org",
  "@type": "Hotel",
  "name": cleanHotelName(hotel.name),
  "description": hotel.description,
  "image": hotel.imageUrl || hotel.gallery[0],
  "address": {
    "@type": "PostalAddress",
    "addressLocality": hotel.city,
    "addressCountry": hotel.country
  },
  "starRating": {
    "@type": "Rating",
    "ratingValue": hotel.stars
  },
  "aggregateRating": hotel.reviewCount > 0 ? {
    "@type": "AggregateRating",
    "ratingValue": hotel.reviewScore,
    "reviewCount": hotel.reviewCount
  } : undefined,
  "priceRange": hotel.fromPricePerNight > 0 
    ? `${hotel.fromPricePerNight} ${hotel.currency}` 
    : undefined
}
```

**Breadcrumb Schema**:
```typescript
{
  "@context": "https://schema.org",
  "@type": "BreadcrumbList",
  "itemListElement": [
    {
      "@type": "ListItem",
      "position": 1,
      "name": "Accueil",
      "item": "https://amina-travel.com/"
    },
    {
      "@type": "ListItem",
      "position": 2,
      "name": hotel.country === "Tunisie" ? "Hôtels en Tunisie" : "Hôtels à l'étranger",
      "item": hotel.country === "Tunisie" 
        ? "https://amina-travel.com/hotels" 
        : "https://amina-travel.com/hotels-etranger"
    },
    {
      "@type": "ListItem",
      "position": 3,
      "name": cleanHotelName(hotel.name),
      "item": `https://amina-travel.com/hotels/${hotel.slug}`
    }
  ]
}
```

### Accessibility Compliance

**Semantic HTML Structure**:
```html
<main>
  <article itemscope itemtype="https://schema.org/Hotel">
    <header><!-- DetailHero --></header>
    <section aria-labelledby="gallery-heading">
      <!-- ImageGallery -->
    </section>
    <section aria-labelledby="availability-heading">
      <!-- HotelAvailabilityPanel or RoomsPanel -->
    </section>
    <section aria-labelledby="highlights-heading">
      <!-- HighlightsPanel -->
    </section>
    <section aria-labelledby="services-heading">
      <!-- ServicesPanel -->
    </section>
    <section aria-labelledby="location-heading">
      <!-- LocationPanel -->
    </section>
    <aside role="complementary">
      <!-- PriceSticky (catalog hotels) -->
    </aside>
  </article>
</main>
```

**ARIA Labels**:
- All panels have descriptive headings
- Interactive elements have aria-labels
- Images have descriptive alt text
- Lightbox has aria-modal="true"
- Form controls have associated labels

**Keyboard Navigation**:
- All interactive elements reachable via Tab
- Lightbox supports Escape, Arrow Left/Right
- Panel collapse supports Enter/Space
- Skip links for main content

**Color Contrast**:
- All text meets WCAG AA standards (4.5:1 for normal text, 3:1 for large text)
- Interactive elements have sufficient contrast in all states
- Focus indicators are clearly visible

## Performance Optimization

### Server-Side Rendering

```typescript
// Force dynamic rendering for fresh hotel data
export const dynamic = "force-dynamic";
```

This ensures hotel data is always current, especially important for:
- Live pricing
- Availability status
- Recently added content

### Image Optimization

**Next.js Image Component**:
```typescript
<Image
  src={imageSrc}
  alt={altText}
  fill
  sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
  priority={isAboveFold}
  loading={isBelowFold ? "lazy" : undefined}
/>
```

**Optimization Strategy**:
1. Hero image: `priority={true}` for LCP
2. Gallery images: Lazy load with appropriate sizes
3. Thumbnail images: Smaller sizes specification
4. Fallback images: Use optimized SVG placeholders

### Code Splitting

**Client Components**: Only interactive components use `"use client"`:
- HotelAvailabilityPanel
- ImageGallery (lightbox functionality)
- ExpandableText
- Panel (collapse functionality)

**Server Components**: All presentation components remain server-side:
- DetailHero
- RoomsPanel content
- HighlightsPanel content
- ServicesPanel content
- LocationPanel content

### Loading States

**Initial Page Load**:
- Suspense boundaries for async components
- Skeleton screens where appropriate
- Progressive enhancement

**Availability Checks**:
```typescript
{loading && (
  <p className="availbox__hint">
    <Loader2 className="animate-spin" /> 
    Recherche des tarifs en temps réel…
  </p>
)}
```

### Bundle Size Optimization

1. **Tree Shaking**: Import only needed icons from lucide-react
2. **Dynamic Imports**: Consider dynamic import for heavy components (e.g., map embeds)
3. **CSS Optimization**: Use CSS modules where appropriate, remove unused styles

## Migration Strategy

### Phase 1: Style Additions

Add new styles to `_hotels.scss` without modifying existing `page.tsx`:

```scss
// Add to _hotels.scss
.highlights-grid { /* ... */ }
.highlight { /* ... */ }
.services-grid { /* ... */ }
.service-item { /* ... */ }
.room-list { /* ... */ }
.room-row { /* ... */ }
.loc-line { /* ... */ }
.map-embed { /* ... */ }
```

### Phase 2: Component Refactoring

Update `page.tsx` incrementally:

1. ✅ Update DetailHero usage (review score display)
2. ✅ Refactor description display (ExpandableText in subtitle)
3. ✅ Add highlights section with new styles
4. ✅ Update services section with icon mapping
5. ✅ Refactor room display with new card layout
6. ✅ Update location section
7. ✅ Verify PriceSticky integration

### Phase 3: Testing and Refinement

1. Visual regression testing
2. Responsive testing across devices
3. Accessibility audit
4. Performance benchmarking
5. User acceptance testing

### Rollback Plan

If issues arise:
1. Revert to previous `page.tsx` version (git)
2. Remove new styles from `_hotels.scss`
3. Investigate issues offline
4. Re-deploy with fixes

## Open Questions and Future Enhancements

### Open Questions

1. **Review System**: Are reviews stored locally or fetched from supplier?
2. **Promotional Logic**: How is `promoPercent` calculated and applied?
3. **Board Type Labels**: Are all board types covered in `BOARD_LABELS`?
4. **Map Embed**: Should we use Google Maps, OpenStreetMap, or Mapbox?
5. **Analytics**: What events should be tracked (view, availability check, booking click)?

### Future Enhancements

1. **Quick Facts Grid**: Add dedicated section with scannable key facts (star rating, location, services count, review score)
2. **Comparison Feature**: Allow comparing multiple hotels side-by-side
3. **Virtual Tours**: Integrate 360° images or video tours
4. **Similar Hotels**: "You might also like" recommendation section
5. **Price History**: Show price trends over time for catalog hotels
6. **Weather Integration**: Display current/forecast weather for hotel location
7. **Distance Calculator**: Show distances to key points of interest
8. **Guest Reviews**: Full review system with filtering and sorting
9. **Accessibility Score**: Display hotel accessibility rating
10. **Sustainability Badge**: Eco-friendly hotel certification display

## Appendix

### Design Reference Sources

1. **Booking.com Hotel Pages**: Information hierarchy, section organization, quick facts display
2. **Expedia Hotel Pages**: Image gallery layout, room card design, availability interface
3. **Airbnb Listings**: Description formatting, highlights presentation, host information
4. **TripAdvisor**: Review display, rating badges, map integration

### Technology Stack

- **Framework**: Next.js 14+ (App Router)
- **Language**: TypeScript
- **Styling**: SCSS with CSS Modules
- **Icons**: Lucide React
- **Image Optimization**: next/image
- **Date Handling**: Native Date objects, ISO strings
- **State Management**: React hooks (useState, useEffect)
- **Data Fetching**: Server-side fetch with async/await

### Existing Component Library

**Used Components** (already exist):
- `DetailHero` - Hero banner with overlay
- `Section` - Content section wrapper
- `Panel` - Collapsible content card
- `ImageGallery` - Photo gallery with lightbox
- `ExpandableText` - Show more/less text
- `HotelAvailabilityPanel` - Live rate checker
- `PriceSticky` - Sidebar booking widget
- `JsonLd` - Structured data renderer
- `MapEmbed` - Google Maps iframe wrapper

**Utility Functions** (already exist):
- `cleanHotelName()` - Remove supplier prefix
- `getHotelBySlug()` - Fetch hotel data
- `buildStayParams()` - Construct query strings
- `parseRooms()` - Parse room occupancy
- `BOARD_LABELS` - Localized board type labels
- `DEPOSIT_PERCENT` - Default deposit percentage

### File Structure

```
front/apps/website/src/
├── app/
│   └── hotels/
│       └── [slug]/
│           ├── page.tsx                    # Main hotel detail page
│           ├── HotelAvailabilityPanel.tsx  # Live rate checker
│           └── reserver/
│               └── page.tsx                # Booking form page
├── components/
│   └── site/
│       ├── Cards.tsx                       # Card components (DetailHero, PriceSticky, etc.)
│       ├── Panel.tsx                       # Collapsible panel
│       ├── ImageGallery.tsx                # Photo gallery
│       ├── ExpandableText.tsx              # Show more/less
│       └── JsonLd.tsx                      # Structured data
├── styles/
│   ├── _cards.scss                         # Card and layout styles
│   ├── _hotels.scss                        # Hotel-specific styles
│   ├── _booking.scss                       # Booking flow styles
│   └── _mixins.scss                        # Responsive mixins
└── lib/
    ├── data.ts                             # API data fetching
    └── stay.ts                             # Stay/room utilities
```

---

**Document Version**: 1.0  
**Last Updated**: 2024-12-19  
**Status**: Ready for Implementation
