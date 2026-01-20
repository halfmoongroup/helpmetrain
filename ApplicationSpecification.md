# Application Specification

## Overview
- **App Name**: HelpMeTrain
- **Purpose**: Show daily step progress against a user-defined goal, using a simple at-a-glance UI with Day and Week views (Month is blank in v1).
- **Primary Data Source**: Apple HealthKit
- **Core Concepts**:
  - Daily step goal
  - Streaks (consecutive goal achievement)
  - Bonus days (earned and consumed to preserve streaks)

## Goals & Success Criteria
- User can set a daily step goal and see progress immediately.
- User can understand “am I on track?” via a dial + a “Walking Bot” comparator.
- Streak behavior is consistent and does not change when the goal changes.
- HealthKit data is used as the source of truth for steps, distance, calories, heart rate.

## Navigation & Top Bar
- The top of the screen contains a menu:
  - **Right side**: Gear icon opens **Settings**
  - **Centered**: three entries: **Day**, **Week**, **Month**
- Selecting an entry swaps the main view accordingly.

## Views

### Day View
#### Dial (center of screen)
The dial contains three text fields:
1. **Top field**:
   - Displays **"Today"** if the dial is showing the current calendar day (local time).
   - Otherwise displays date formatted as **MM/DD/YYYY**.
2. **Middle field**:
   - Displays **actual step count** for that day (largest type on the dial).
3. **Bottom field**:
   - Displays: **"Of XXXX steps"** where `XXXX = targetSteps`.

#### Stat Tiles (below dial)
- A single **horizontal row** of tiles that **scrolls left/right** as tiles increase.
- Each tile contains **exactly one** metric (numeric value + label).
- Required tiles in Day view:
  - **Streak**: numeric streak value, label **"Streak"**
  - **Calories**: HealthKit **Active Energy Burned**, label **"kcal"**
  - **Distance**: HealthKit walking/running distance, displayed in **miles**
  - **Heart Rate**: **current heart rate**, as defined below

#### Steps Graph (below stat tiles)
- Displays step-count trend over **7 data points**: **last 6 completed days + current day**
- **Ordering**: oldest on left, most recent on right (rightmost is today)
- The rightmost point (today) **rises over the course of the day** as steps accumulate.
- **Curve**: smoothed using a **spline**
- **Grid/Lines**:
  - **No horizontal lines**
  - **Exactly 7 vertical guide lines**, one per day position
- **Scale/Frame**:
  - No axis labels or numeric scale displayed
  - The graph occupies **exactly the same vertical and horizontal space** on-screen at all times (every day, every week, every mode)
  - The plotted values are visually normalized to the displayed window:
    - If min != max: map displayed range to the fixed vertical space
    - If all 7 values are identical (min == max): render a **straight horizontal line in the middle** of the graph
- **Data values**:
  - Always use the **actual HealthKit step count** for each day (never adjusted by bonuses)

#### User vs Walking Bot List (below graph)
- An ordered list with **two entries**:
  - **User**
  - **Walking Bot**
- **Ordering rule**: sorted descending by the associated step count for the current timeframe.
  - **User wins ties** (User is #1 when equal).

##### Walking Bot (Day)
- Bot represents an idealized constant walking pace from midnight to end-of-day:
  - At **00:00:00**: botSteps = 0
  - At **23:59:59**: botSteps = targetSteps (maxed)
  - Linear interpolation by time of day.
  - Example for target=10,000:
    - 06:00 → 2,500
    - 12:00 → 5,000
    - 18:00 → 7,500
    - 23:59:59 → 10,000

---

### Week View
#### Definition of “Week”
- Week is always the **rolling last 7 days** (e.g., Wed → Tue).
- Not constrained to calendar weeks.

#### Top Visualization (replaces dial)
- The dial is replaced by a **vertical bar chart** for the last 7 days.
- For each day:
  - A vertical bar is shown
  - **Actual step count** for that day is displayed **just above the bar**

#### Stat Tiles (Week)
- The stat tile row remains in the same place/layout.
- Tiles reflect **totals over the last 7 days** (rolling).
  - Example: miles tile shows total miles walked in the last 7 days.
- **Heart rate is not displayed in Week view** (no HR tile).

#### Steps Graph (Week mode)
- The graph below stat tiles changes to show **7 consecutive 7-day blocks**:
  - **Last 6 completed blocks + current block**
  - The **current block** is the rolling window of **last 7 days ending today**
  - Previous blocks are the consecutive 7-day ranges immediately preceding it (non-overlapping)
- **Guide lines**:
  - **Exactly 7 vertical guide lines**
  - No horizontal lines
- Fixed frame and identical layout footprint (same as Day view graph rules).
- Uses **actual HealthKit step counts** aggregated per block (no bonus adjustment).

#### User vs Walking Bot List (Week)
- The list remains visible.
- Values shown are totals for the rolling **last 7 days**.
- **Ordering rule** remains the same (User wins ties).

##### Walking Bot (Week)
- Bot uses the same rules as User; only difference is steps are time-derived.
- For the rolling last 7 days total:
  - For each of the prior 6 days, bot is effectively at end-of-day → botStepsForDay = targetStepsForThatDay
  - For today, botStepsForDay is time-of-day derived (as in Day mode)
  - Week bot total is the sum across the 7 days.

---

### Month View (v1)
- **Month view is blank in v1.**
- Future constraint (when defined):
  - Month view will be a **standard calendar month view** displaying the **days of the current month**.

## HealthKit Data Requirements
### Required HealthKit Types (read-only)
- **Steps**: `HKQuantityTypeIdentifier.stepCount`
- **Heart rate**: `HKQuantityTypeIdentifier.heartRate`
- **Active energy burned**: `HKQuantityTypeIdentifier.activeEnergyBurned`
- **Walking/running distance**: `HKQuantityTypeIdentifier.distanceWalkingRunning`

### Heart Rate “Current” Definition
- “Current heart rate” = **most recent heart rate sample within the last X minutes**
- `X` is a **user setting**, default = **10**
- If no sample exists within that window, show a no-recent-data placeholder (e.g., `--`).

## Goal, Streaks, and Bonus Days

### Day Boundary
- A “day” is defined as **00:00:00 to 23:59:59 local time** (device timezone).

### Goal Achievement
- Every step recorded during the day counts toward the goal.
- A day’s goal is achieved if:
  - `actualSteps >= goalStepsForThatDate`

### Goal Changes and Historical Integrity
- Changing the goal **does not affect streaks**.
- Therefore, the app must maintain a per-day snapshot:
  - `goalStepsForThatDate`

### Streak Definition
- A **streak** is a run of consecutive days where the user maintains goal achievement status.
- A streak ends only if:
  - The user does **not** meet the goal for a day **and** has **0 bonus days** remaining.

### Bonus Days
- User-configurable settings:
  - **Earn bonus day every N consecutive achieved days**
  - **Maximum bonus days** cap
- Earning:
  - When the user completes N consecutive achieved days, add **+1 bonus day**, up to the max.
- Consuming:
  - If the user misses a day’s goal and has bonus days available:
    - consume **1 bonus day**
    - treat that day as “achieved” **for streak continuity**
- Important: even when a bonus day is used, all displayed values (including graphs) use **actual HealthKit step counts**.

## Settings
- **Daily step target**: `targetSteps` (integer)
- **Bonus earn interval**: `bonusEarnEveryNConsecutiveDays` (integer N)
- **Max bonus days**: `maxBonusDays` (integer)
- **Heart rate recency window**: `recentHRWindowMinutes` (integer X, default 10)

## Data Storage (v1)
- Persist settings locally.
- Persist enough state to ensure goal changes do not affect historical streak evaluation:
  - At minimum, store `goalStepsForThatDate` per day needed for streak continuity.
- (v2) App will add Core Data historical storage and allow selecting/viewing past days in the dial.

## Non-Functional Requirements
- Graph and major UI sections maintain **fixed layout footprint** across days/weeks/modes.
- Clear behavior when HealthKit permissions are missing or data is unavailable (show placeholders rather than failing).
- Local timezone is used for day boundaries and “Today” determination.

## Visual Design

### Theme
- Dark UI, near-black background with cyan/ice-blue accents.

### Color Palette (HEX)
- **Background (app)**: `#000000`
- **Primary Accent (dial progress / highlights)**: `#59BEF7`
- **Accent (chart line variant)**: `#77CDE9`
- **Dial Track / Inactive Ring**: `#212121`

### Top Bar
- **Settings gear icon**: `#85BFD1`
- **Selected tab underline**: `#59BEF7`
- **Selected tab text**: `#EDEDED`
- **Unselected tab text**: `#808083`

### Dial Text
- **“Today” / date label (accent text)**: `#59BEF7`
- **Primary steps number**: `#FFFFFF` (often renders ~`#EDEDED` due to antialiasing)
- **Secondary “of XXXX steps”**: `#808083`

### Day/Week Graph Styling
- **Spline line color**: `#77CDE9`
- **Point markers**: `#FFFFFF`
- **Vertical guide lines (7 total)**: `#3E3E40`
- **No horizontal lines**.

### Day Indicators (under graph)
- **Unselected day label text**: `#A3ACAE`
- **Selected day capsule**
  - Border/bright highlight: `#F4F8FD`
  - Fill: `#1C2022`

