# DrumHub V1 Mechanical Enclosure Specification

Internal hardware identifier: DCLC V1

## 1. Purpose

This document specifies a 3D-printable mechanical enclosure for the DrumHub V1
prototype. The enclosure is for a finished-looking, serviceable project-box
prototype built without a custom PCB.

This phase is specification only. Do not generate CAD, STL, STEP, Fusion 360,
OpenSCAD, FreeCAD, or mesh files from this document until the open measurements
and test coupons are complete.

The enclosure shall support:

- ESP32-S3 development controller mounted on a 4 in x 6 in perfboard
- point-to-point wiring
- three SN74AHCT125N DIP buffer ICs in 14-pin sockets
- ten LED-strand connector ports
- external regulated 5 V power input
- MODE button
- RESET button
- removable lid
- rapid PLA iteration on a Creality Ender 3 V3 SE

Priority order:

1. Fit
2. Serviceability
3. Printability
4. Connector retention
5. External appearance

## 2. Known Hardware Dimensions

### ESP32-S3 Controller

| Item | Dimension |
| --- | ---: |
| Overall assembly length | 63.50 mm |
| Main controller PCB length | 57.15 mm |
| Maximum PCB width | 28.575 mm |
| Pin rows | 2 x 22 |
| Pin-row center spacing | 25.40 mm |
| Pin pitch | 2.54 mm |
| Antenna overhang | 6.35 mm |
| Antenna width | 17.4625 mm |
| USB-C connector count | 2 |
| USB-C edge | one short edge |
| USB connector face position | flush with PCB edge |
| Top USB center offset from nearest long edge | 7.9375 mm |
| Bottom USB center offset from opposite long edge | 7.9375 mm |

The ESP32 plugs into two straight 1 x 22 female through-hole headers on the
perfboard. The ESP32 is not separately mounted to the enclosure.

Vertical clearance must include:

- solder joints and trimmed leads under the perfboard
- 18 AWG power wiring under or beside the perfboard
- female headers
- ESP32 PCB
- USB-C connectors
- ESP32 board buttons and tall components
- safe lid clearance above the tallest component

The antenna region must not be blocked by metal, screws, dense power wiring, or
thick internal structures. Plastic walls are acceptable.

### Perfboard

| Item | Dimension |
| --- | ---: |
| Nominal board size | 101.6 mm x 152.4 mm |
| Hole grid | 2.54 mm |
| Board type | double-sided plated-through |
| Length tolerance to allow | +/- 1 mm |
| Width tolerance to allow | +/- 1 mm |

Do not assume factory mounting holes are accurately placed. Final CAD must be
checked against the purchased board.

### Connector And Panel Part Dimensions

The following values are not fixed by this specification and must be measured
from the purchased parts before CAD:

| Part | Required measurements |
| --- | --- |
| JST-SM 3-pin connector | body width, body height, body depth, latch height, wire-exit position, insertion clearance |
| MODE button | panel-hole diameter, threaded-body diameter, bezel diameter, body depth, nut thickness, terminal depth, rear clearance |
| RESET button | panel-hole diameter, threaded-body diameter, bezel diameter, body depth, nut thickness, terminal depth, rear clearance |
| Power input connector | panel cutout, body depth, flange size, nut/retainer geometry, wire terminal envelope, current rating |
| Optional power switch | panel cutout, body depth, terminal envelope, current rating, ON/OFF orientation |

Mark unmeasured dimensions in CAD as:

`TBD — MEASURE PURCHASED PART`

## 3. Proposed Enclosure Dimensions

The preliminary target of 170 mm x 125 mm x 45 mm is mechanically tight once
the 4 in x 6 in perfboard, ten connector pockets, 18 AWG wiring, and service
clearance are included.

Recommended V1 external dimensions:

| Dimension | Recommended value |
| --- | ---: |
| Width, left to right | 185 mm |
| Depth, front to back | 140 mm |
| Overall height | 52 mm |
| Base outside height | 40 mm |
| Lid outside height | 12 mm |
| Wall thickness | 2.8 mm |
| Bottom thickness | 2.8 mm |
| Lid top thickness | 2.4 mm |
| External corner radius | 6 mm |
| Internal corner fillet | 1.5 mm to 3 mm where useful |

Derived nominal internal dimensions:

| Dimension | Value |
| --- | ---: |
| Internal width | 179.4 mm |
| Internal depth | 134.4 mm |
| Internal height below lid underside | about 46.8 mm |

This size provides enough room for:

- a 152.4 mm x 101.6 mm perfboard with tolerance
- one long-side LED connector bank
- a front wiring and connector-retention corridor
- side clearance for USB access and power entry
- wiring loops and cable-tie anchors
- lid posts independent of perfboard standoffs

Do not reduce the enclosure below 180 mm x 135 mm x 50 mm until the JST-SM
connector pocket, power connector, and button rear-clearance coupons have been
validated.

## 4. Coordinate System

Use this coordinate convention for CAD:

- X axis: left to right across the long dimension
- Y axis: front to back across the short dimension
- Z axis: bottom to top
- Origin: inside lower-left-front corner of the base interior
- Front wall: LED connector bank
- Left wall: ESP32 USB opening
- Right wall: power input and optional switch
- Rear wall: MODE and RESET buttons

Top view, lid removed:

```text
                  REAR WALL - user controls
        +------------------------------------------------+
        |     MODE        RESET                          |
        |                                                |
LEFT    | USB     ESP32-S3 on perfboard                  | RIGHT
WALL    | OPEN    antenna zone kept open                 | WALL
USB     |                                                | 5V IN
        |      +----------------------------------+      |
        |      |                                  |      |
        |      |      4 in x 6 in perfboard       |      |
        |      |      on four standoffs           |      |
        |      |                                  |      |
        |      +----------------------------------+      |
        |                                                |
        | LED connector pocket and wiring corridor       |
        |  1   2   3   4   5   6   7   8   9   10       |
        +------------------------------------------------+
                  FRONT WALL - LED ports
```

## 5. Base Specification

The base is the primary structural and wiring component.

Base requirements:

- print bottom-down
- no required support
- 2.8 mm nominal wall and bottom thickness
- rounded external corners
- integrated perfboard standoffs
- four independent lid screw posts
- LED connector-retention pockets along the front wall
- power-input retention geometry on the right wall
- MODE and RESET button retention on the rear wall
- USB access cutout on the left wall
- cable-tie slots and low-profile wire guides
- no enclosed wire tunnels
- no lid-mounted wiring in the default configuration

Recommended base features:

| Feature | Recommended geometry |
| --- | --- |
| Wall thickness | 2.8 mm nominal |
| Bottom thickness | 2.8 mm nominal |
| Internal floor fillet | 1.5 mm to 2 mm |
| External corner radius | 6 mm |
| Lid ledge | 1.2 mm to 1.6 mm vertical step |
| Lid lip clearance | 0.25 mm to 0.35 mm per side |
| Wire-tie slots | 2.5 mm x 8 mm slots with rounded ends |
| Wire-guide height | 2 mm to 3 mm, rounded top |

Connector pockets and panel parts must mount to the base whenever practical so
the lid can be removed without disconnecting wiring.

## 6. Lid Specification

The lid is removable and screw-retained.

Lid requirements:

- overlap or recess into the base with a shallow locating lip
- align with four base screw posts
- provide clearance holes and screw-head recesses
- include raised or embossed DrumHub branding
- include DCLC V1 marking
- include no support-heavy underside geometry
- remain stiff enough to avoid warping when screwed down

Recommended lid geometry:

| Feature | Recommended geometry |
| --- | --- |
| Top thickness | 2.4 mm |
| Skirt/lip height | 4 mm to 6 mm |
| Lip wall thickness | 1.4 mm to 1.8 mm |
| Lip clearance to base | 0.25 mm to 0.35 mm per side |
| Screw counterbore | sized for selected M3 screw head |
| Branding height | 0.5 mm to 0.8 mm raised |
| Minimum text stroke width | 0.8 mm to 1.0 mm |

Preferred print orientation:

- Lid outer face up if raised lettering prints cleanly enough.
- Lid outer face down only if the top surface quality is more important and
  recessed lettering is chosen.

For V1, raised outer-face text is preferred because it avoids support on the
underside and is easy to inspect.

## 7. Internal Component Layout

Recommended internal placement:

| Component | Placement |
| --- | --- |
| Perfboard | centered left/right, shifted slightly rearward to create front connector corridor |
| ESP32-S3 | on perfboard near left wall, USB-C connectors facing left USB opening |
| ESP32 antenna | points inward or toward plastic wall, away from power bus wiring |
| SN74AHCT125N ICs | on perfboard with service clearance around sockets |
| LED connector pockets | front long wall, one row of ten |
| Power input | right wall, near front-right or mid-right |
| Optional switch | right wall near power input, only if included |
| MODE button | rear wall, more prominent than RESET |
| RESET button | rear wall, spaced from MODE and less prominent if possible |
| Lid posts | near corners, outside perfboard envelope |
| Perfboard posts | inside board footprint, matched to selected grid holes |

Nominal top-view dimensions:

```text
External width: 185 mm
External depth: 140 mm
Internal width: 179.4 mm
Internal depth: 134.4 mm

Inside top view, nominal:

Y=134.4 rear
  +---------------------------------------------------+
  |  button zone, 18 mm rear service band             |
  |                                                   |
  |  +---------------------------------------------+  |
  |  | perfboard, 152.4 x 101.6 nominal            |  |
  |  | shifted rearward for front connector space  |  |
  |  | ESP32 USB edge faces left wall              |  |
  |  +---------------------------------------------+  |
  |                                                   |
  |  LED connector corridor, target 18 mm to 22 mm    |
  +---------------------------------------------------+
Y=0 front
```

Maintain these minimum clearances unless test coupons prove smaller values are
acceptable:

| Clearance | Minimum |
| --- | ---: |
| Perfboard edge to non-connector side wall | 5 mm |
| Perfboard edge to LED pocket corridor | 18 mm target |
| Perfboard bottom to enclosure floor | 7 mm standoff height |
| Trimmed solder lead tip to floor | 3 mm minimum |
| Tallest component to lid underside | 5 mm minimum |
| ESP32 antenna to power wiring bundle | 15 mm preferred |
| Lid post to perfboard edge | 3 mm minimum |
| Wire bend radius for 18 AWG | generous loop, no sharp pinch |

## 8. Perfboard Mounting

Use four printed standoffs and self-tapping screws.

Recommended standoff specification:

| Feature | Recommended value |
| --- | ---: |
| Standoff height | 7 mm |
| Standoff OD | 8 mm |
| Pilot hole | 2.2 mm to 2.5 mm |
| Screw | M2.5 or M3 self-tapping for plastic |
| Minimum clearance under trimmed leads | 3 mm |
| Top support pad | flat, no sharp bosses against traces |

Preferred mounting-hole strategy:

- Select four holes from the purchased perfboard's 2.54 mm grid.
- Keep selected holes at least 5 mm from board edges.
- Keep selected holes away from high-density wiring and IC sockets.
- Use washers only if they do not short traces.
- Confirm actual hole locations physically before final CAD.

Recommended nominal mounting-hole rectangle:

| Item | Nominal value |
| --- | ---: |
| X spacing between left/right board screws | 139.7 mm |
| Y spacing between front/rear board screws | 88.9 mm |
| Hole inset from board edges | about 6.35 mm |

These values correspond to a practical grid-based rectangle on many 4 in x 6 in
perfboards. They are not final until checked against the purchased board.

## 9. USB Opening

The enclosure must expose both ESP32 USB-C connectors through the left wall.

Preferred approach:

- one shared rectangular opening
- rounded corners
- no thin divider between USB connectors
- enough clearance for molded USB-C cable ends
- connector faces flush or slightly recessed from the outer wall

Known USB center references:

| Reference | Dimension |
| --- | ---: |
| ESP32 maximum PCB width | 28.575 mm |
| USB center from one long edge | 7.9375 mm |
| Other USB center from opposite long edge | 7.9375 mm |
| USB center-to-center spacing | about 12.7 mm |

Recommended opening, to be verified with a USB coupon:

| Feature | Starting value |
| --- | ---: |
| Opening width along Y | 30 mm |
| Opening height along Z | 13 mm |
| Corner radius | 2 mm |
| Extra plug clearance | 0.5 mm to 1.0 mm total beyond measured plug envelope |
| Wall clearance around connector faces | 0.5 mm minimum |

USB opening position depends on final ESP32 placement on the perfboard. The CAD
model must derive the cutout from the measured board/header/ESP32 stack, not
from the enclosure origin alone.

Required test before full enclosure:

- Print Coupon B, the dual-USB wall section.
- Confirm both USB-C plugs insert fully.
- Confirm molded cable bodies do not hit the enclosure wall.
- Confirm plugging force does not move the perfboard.

## 10. LED Connector-Retention System

The enclosure requires ten external LED-strand connector ports.

Preferred connector family:

- 3-pin JST-SM locking wire-to-wire connectors
- retained by printed enclosure features
- not mounted directly to the perfboard

Each port carries:

- 5 V
- DATA
- GND

Do not assume connector dimensions. Measure the actual purchased connector and
enter the values as CAD parameters:

| Parameter | Value |
| --- | --- |
| Connector body width | TBD — MEASURE PURCHASED PART |
| Connector body height | TBD — MEASURE PURCHASED PART |
| Connector body depth | TBD — MEASURE PURCHASED PART |
| Latch height | TBD — MEASURE PURCHASED PART |
| Wire-exit position | TBD — MEASURE PURCHASED PART |
| Required insertion clearance | TBD — MEASURE PURCHASED PART |

Retention pocket requirements:

- prevent the connector from being pushed inward during mating
- reduce pull force transmitted to solder joints and wires
- provide latch access from outside
- allow connector replacement when the enclosure is opened
- avoid glue as the only retention method
- use printable shoulders, clamp bars, or lid-assisted capture
- avoid snap-fit-only retention for V1

Preferred pocket concept:

1. Front-wall rectangular connector aperture.
2. Internal rear shoulder that stops inward movement.
3. Side clearance based on measured connector plus 0.2 mm to 0.4 mm per side.
4. Removable printed retention bar screwed or trapped by the lid.
5. Rear wire channel that exits upward or inward without sharp bending.

Port layout:

| Feature | Recommended value |
| --- | ---: |
| Port count | 10 |
| Layout | one horizontal row on front long side |
| Center-to-center spacing | 15 mm starting point |
| First/last port center margin | 20 mm minimum target |
| Label position | above or below each port on exterior front face |
| Port numbering | 1 through 10, left to right |
| Internal corridor depth | 18 mm to 22 mm target |

Use two rows of five only if test coupons prove the one-row connector access is
impractical. Do not split ports across both sides unless forced by purchased
connector geometry.

Front elevation concept:

```text
+---------------------------------------------------------+
|  1   2   3   4   5   6   7   8   9   10               |
| [ ] [ ] [ ] [ ] [ ] [ ] [ ] [ ] [ ] [ ]               |
+---------------------------------------------------------+
```

## 11. Button Mounting

Provide two externally accessible buttons:

- MODE: firmware-defined user function
- RESET: hardware reset, connects ESP32 EN to ground while pressed

Use panel-mount, momentary, normally-open buttons for the finished enclosure.
Preferred initial part class is 12 mm non-illuminated momentary pushbuttons.

Do not finalize holes until the exact buttons are selected and measured:

| Parameter | MODE | RESET |
| --- | --- | --- |
| Panel-hole diameter | TBD — MEASURE PURCHASED PART | TBD — MEASURE PURCHASED PART |
| Threaded-body diameter | TBD — MEASURE PURCHASED PART | TBD — MEASURE PURCHASED PART |
| Bezel diameter | TBD — MEASURE PURCHASED PART | TBD — MEASURE PURCHASED PART |
| Body depth | TBD — MEASURE PURCHASED PART | TBD — MEASURE PURCHASED PART |
| Nut thickness | TBD — MEASURE PURCHASED PART | TBD — MEASURE PURCHASED PART |
| Terminal depth | TBD — MEASURE PURCHASED PART | TBD — MEASURE PURCHASED PART |
| Required rear clearance | TBD — MEASURE PURCHASED PART | TBD — MEASURE PURCHASED PART |

Placement requirements:

- same user-facing rear panel
- at least 25 mm center-to-center
- clear labels: MODE and RESET
- away from LED connector bank if possible
- mounted to base, not lid
- wiring service loop must allow access without strain

RESET should be less prominent than MODE when possible. Acceptable V1 methods:

- smaller RESET button
- recessed RESET button
- same button size with clear offset and labeling

Use available parts over perfect visual differentiation for V1.

## 12. Power-Input Recommendation

The enclosure requires external regulated 5 V input. The supply may be 5 V up
to 10 A, so the connector must safely support the expected current.

Avoid a standard low-current barrel jack unless the exact part is rated for the
required current with margin.

Recommended V1 power input:

- primary recommendation: XT30 panel-mount connector
- acceptable fallback: short captured XT30 pigtail with printed strain relief

Reason:

- comfortable current margin for a 5 V, 10 A prototype
- polarized connector
- common parts availability
- robust insertion force
- easier high-current wiring than many barrel jacks
- visually acceptable for a serviceable prototype

Required power-connector CAD parameters:

| Parameter | Value |
| --- | --- |
| Connector type selected | TBD — MEASURE PURCHASED PART |
| Rated current | TBD — MEASURE PURCHASED PART |
| Panel cutout | TBD — MEASURE PURCHASED PART |
| Flange or nut geometry | TBD — MEASURE PURCHASED PART |
| Body depth | TBD — MEASURE PURCHASED PART |
| Terminal envelope | TBD — MEASURE PURCHASED PART |
| Minimum wire bend clearance | TBD — MEASURE PURCHASED PART |

Power input placement:

- right wall near the front or midline
- near 5 V/GND distribution wiring
- away from ESP32 antenna region
- away from MODE and RESET button wiring where practical
- with enough rear clearance for 18 AWG wiring and heat-shrink

Label exterior as:

```text
5V IN
```

## 13. Power-Switch Recommendation

Do not include a power switch in the default V1 enclosure unless a panel switch
rated for the full expected current is selected.

Recommendation:

- omit the power switch for first enclosure CAD
- reserve a flat right-wall region near the power input for a future switch
- add the switch only after selecting a DC-rated part with adequate current
  capacity and safe terminal coverage

If included later, requirements are:

- SPST panel mount
- rated for at least the actual maximum 5 V current with margin
- externally accessible
- labeled ON/OFF
- terminals insulated after assembly
- located near 5V IN
- does not block perfboard removal or wire service

## 14. Fasteners

Use screws as the primary retention method. Avoid snap-fit-only lid retention
for V1.

### Lid Fasteners

Preferred:

- four M3 self-tapping screws for plastic
- screws inserted through lid into printed base posts

Starting geometry:

| Feature | Recommended value |
| --- | ---: |
| Screw | M3 self-tapping for plastic |
| Screw length | 10 mm to 12 mm, confirm with lid/post stack |
| Lid clearance hole | 3.2 mm to 3.4 mm |
| Base post pilot hole | 2.4 mm to 2.6 mm |
| Post OD | 8 mm minimum |
| Post wall thickness around pilot | 2.5 mm minimum |
| Screw-head counterbore | measured screw head diameter + 0.4 mm |
| Counterbore depth | measured screw head height + 0.2 mm |

Place lid posts near corners, outside the perfboard keepout and away from LED
connector pockets.

### Perfboard Fasteners

Preferred:

- M2.5 or M3 self-tapping screws into printed standoffs
- screw length selected to avoid bottoming out

Starting geometry:

| Feature | Recommended value |
| --- | ---: |
| Standoff pilot | 2.2 mm to 2.5 mm |
| Standoff OD | 8 mm |
| Standoff height | 7 mm |
| Screw length | 6 mm to 8 mm, verify with board thickness |

Coupon D must validate pilot-hole size before full enclosure printing.

## 15. Wiring Management

The enclosure must provide simple printed features for:

- red 5 V bus wires
- black GND bus wires
- ten LED data wires
- MODE wiring
- RESET wiring
- power-input wiring

Preferred features:

- low-profile wire guides
- small internal hooks with rounded edges
- cable-tie slots in the floor
- open harness channels
- tie-down points near connector bank
- tie-down points near power input

Avoid:

- enclosed tunnels
- sharp wire bends
- wire paths under screw tips
- routing high-current power bundles through the ESP32 antenna region
- lid-mounted electrical parts in the default V1 design

The enclosure must open without tearing wires from the lid. Mount connectors
and buttons to the base whenever practical.

## 16. Branding And Labels

Lid branding:

| Feature | Requirement |
| --- | --- |
| Main text | DrumHub |
| Secondary text | DCLC V1 |
| Text style | raised or embossed |
| Raised height | 0.5 mm to 0.8 mm |
| Minimum stroke width | 0.8 mm to 1.0 mm |

External labels:

| Location | Label |
| --- | --- |
| LED ports | 1 through 10 |
| MODE button | MODE |
| RESET button | RESET |
| Power input | 5V IN |
| Optional switch | ON/OFF |

Avoid excessive text. Do not add "Drumcabulary LED Controller" unless there is
clear space and the text remains readable after printing.

## 17. Printability Rules

Target printer:

- Creality Ender 3 V3 SE
- 0.4 mm nozzle
- PLA for early prototypes

Recommended starting print settings:

| Setting | Value |
| --- | ---: |
| Layer height | 0.20 mm |
| Perimeters/walls | 3 |
| Top layers | 5 |
| Bottom layers | 5 |
| Infill | 15% to 25% gyroid or grid |
| Brim | optional for base; recommended if corners lift |
| Supports | none preferred |

Base print orientation:

- bottom-down
- no support required
- connector apertures and button holes shaped with printable overhangs
- avoid horizontal internal shelves

Lid print orientation:

- outer face up for raised text
- no support required
- avoid deep underside cavities

Geometry rules:

- avoid bridges longer than about 12 mm unless chamfered or arched
- use chamfers instead of unsupported 90-degree overhangs
- keep vertical walls at least 2.4 mm thick
- use fillets at standoffs and posts
- avoid sharp internal corners in wire-contact areas

## 18. Tolerances

Default FDM tolerances for first CAD:

| Interface | Starting tolerance |
| --- | ---: |
| General clearance | 0.25 mm to 0.4 mm per side |
| Sliding fit | 0.3 mm to 0.5 mm per side |
| Lid lip | 0.25 mm to 0.35 mm per side |
| Perfboard pocket clearance | board measured size + 1.0 mm total each axis |
| Connector pocket | measured connector + 0.2 mm to 0.4 mm per side |
| USB opening | measured plug envelope + 0.5 mm to 1.0 mm total |
| Button panel hole | measured thread/body requirement plus coupon result |
| Retention bar clearance | 0.3 mm to 0.5 mm per side |
| Screw clearance holes | screw major diameter + 0.2 mm to 0.4 mm |

Definitions:

- Nominal CAD size: the intended model dimension.
- Print tolerance: extra clearance added to account for FDM variation.
- Test-coupon parameter: a value that must be validated before committing to
  full enclosure CAD.

All connector, button, switch, and power-input cutouts are test-coupon
parameters.

## 19. Test-Coupon Plan

Print coupons before modeling or printing the full enclosure.

### Coupon A - JST-SM Retention

Purpose:

- validate connector aperture
- validate capture pocket
- validate latch access
- validate removable retention bar
- validate connector insertion and pull resistance

Include:

- one front-wall section
- one JST-SM opening
- one internal capture pocket
- one retention-bar concept
- at least three side-clearance variants

Suggested variants:

| Variant | Clearance |
| --- | ---: |
| A1 | measured connector + 0.2 mm per side |
| A2 | measured connector + 0.3 mm per side |
| A3 | measured connector + 0.4 mm per side |

### Coupon B - USB Opening

Purpose:

- validate dual USB-C wall opening
- validate cable plug clearance
- validate no interference with ESP32 position

Include:

- wall section at planned thickness
- shared dual-USB opening
- correct USB center spacing from measured ESP32 placement
- plug-body clearance envelope

### Coupon C - Button Hole

Purpose:

- validate panel button hole size
- validate nut seating
- validate rear clearance

Include:

- panel wall section
- MODE/RESET hole candidate
- nut seating surface
- at least two hole-diameter variants

Do not use the final button hole until the purchased button is measured.

### Coupon D - Screw Post

Purpose:

- validate lid screw clearance
- validate self-tapping pilot hole
- validate post strength
- validate screw-head recess

Include:

- lid tab with clearance hole
- base post with pilot-hole variants
- M3 screw test
- optional M2.5/M3 perfboard standoff test

Suggested pilot variants:

| Variant | Pilot hole |
| --- | ---: |
| D1 | 2.2 mm |
| D2 | 2.4 mm |
| D3 | 2.6 mm |

## 20. Open Measurements Still Required

Measure these before final CAD:

| Item | Measurement |
| --- | --- |
| Purchased perfboard | exact length and width |
| Purchased perfboard | usable mounting-hole coordinates |
| ESP32 on headers | total height above perfboard |
| ESP32 on headers | USB connector location relative to perfboard edges |
| ESP32 on headers | antenna keepout region relative to perfboard |
| JST-SM connector | body width, height, depth |
| JST-SM connector | latch height and latch access envelope |
| JST-SM connector | insertion force and plug-body clearance |
| MODE button | all panel and rear-clearance dimensions |
| RESET button | all panel and rear-clearance dimensions |
| Power input connector | panel geometry and rear clearance |
| Power input connector | current rating confirmation |
| Optional switch | current rating and panel geometry, if used |
| Selected screws | head diameter, head height, thread length |

Recommended purchased parts that must be measured:

- actual 4 in x 6 in perfboard
- actual ESP32-S3 development board
- actual 1 x 22 female headers
- actual 3-pin JST-SM connector pair
- actual MODE and RESET panel buttons
- actual XT30 panel connector or XT30 pigtail strain-relief part
- actual M3 self-tapping screws
- actual M2.5 or M3 perfboard screws

## 21. CAD Acceptance Criteria

Future CAD is acceptable when:

- the 4 in x 6 in perfboard fits with practical tolerance
- perfboard screw holes align with the selected physical board
- trimmed solder leads have at least 3 mm floor clearance
- the ESP32 fits on headers with lid clearance
- both USB-C cables plug in without wall interference
- the antenna region remains unobstructed
- all ten JST-SM connectors are retained by enclosure geometry
- JST-SM connectors cannot be pushed inward during insertion
- connector latches remain accessible
- MODE and RESET buttons mount securely
- RESET is visually or physically less prominent than MODE where practical
- the 5 V power connector mounts securely
- all high-current wiring has safe bend and service clearance
- all panel parts have adequate internal depth
- the base prints bottom-down without required support
- the lid prints without required support or with only trivial support
- the lid fits and screws down without warping
- wiring can be installed, inspected, and repaired
- the lid can be removed without disconnecting wiring
- LED port labels 1 through 10 are legible
- MODE, RESET, and 5V IN labels are legible
- DrumHub and DCLC V1 branding print cleanly
- the full enclosure fits within the Ender 3 V3 SE build area

## 22. CAD Transition Checklist

Before CAD:

- select the exact JST-SM connector parts
- select exact MODE and RESET buttons
- select exact power input connector
- decide whether V1 omits or includes a power switch
- measure all purchased parts listed above
- print and evaluate Coupons A through D
- update CAD parameters from coupon results
- verify perfboard mounting-hole rectangle against physical board
- verify ESP32 USB opening from real board/header placement

During CAD:

- model base and lid as separate printable parts
- keep connector/button/power dimensions parameterized
- include named keepout regions for ESP32 antenna and wiring corridors
- keep lid wiring-free
- avoid support-heavy geometry
- include screw posts, standoffs, wire guides, and labels

Before full print:

- slice base and lid in intended orientation
- inspect unsupported bridges and overhangs
- inspect screw-post perimeters
- inspect connector-pocket bridges
- verify all cutouts against measured dimensions
- print a low-height footprint test if needed

## 23. Scope Control

Do not add:

- displays
- Bluetooth controls
- additional buttons
- fans
- decorative lighting
- internal batteries
- new connector families without a strong mechanical or electrical reason
- production injection-molding features
- snap-fit-only lid retention
- cosmetic complexity that slows rapid iteration

This is a rapid-iteration V1 enclosure. Serviceability and validated fit matter
more than minimum size.
