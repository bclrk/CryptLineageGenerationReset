breed [nodes node]

globals [current_line xspace yspace]

nodes-own [
  cell_state            ; can be "immature", "mature", "wholly-mature", or "dead"
  age                   ; number of cycles since birth of cell

  cell_mc               ; maturation cycle of the cell
  cell_wm               ; time to whole maturation of the cell
  cell_ls               ; life span of the cell

  is_stem?              ; flags whether or not the cell is a stem cell
  generation            ; number of generations removed from stem cell

  line                  ; determines which line of the tree a cell belongs
  child_direction       ; positive or negative number that determines which direction children are placed in tree
                        ; see "line propagation" in the info tab for define conventions

  cxcor                 ; placeholder x coordinate used to avoid unnecessary replotting before the final coordinates are calculated
  cycor                 ; placeholder y coordinate used to avoid unnecessary replotting before the final coordinates are calculated
]

to Setup
  clear-all
  set current_line 0
  set xspace 1
  set yspace 1.5

  ; create the original stem cell
  create-nodes 1 [
    set cell_state "immature"

    set cell_mc stem-mc
    set cell_wm stem-wm ; lifespan                 ; the stem cell never reaches whole-maturation and is fertile for the duration of its life
    set cell_ls lifespan

    set is_stem? true

    set child_direction (xspace / 10)

    set cxcor 0
    set cycor max-pycor * 0.95

    setxy cxcor cycor
    FormatCell                           ; function defined below to "set desired shapes and colors based on cell state"
  ]
  reset-ticks
end

to Go
  ; function call which tells all nodes representing cells on the current line to advance/split according to the model
  Propagate (nodes with [line = (current_line)])

  ; function call which Draws next line of nodes that has just been produced by Propagate
  Draw (nodes with [line = (current_line + 1)])

  ; increment the current_line variable to prepare for next iteration
  set current_line (current_line + 1)

  tick
end

; Calculates data for next successive line of cells in the tree based on cell reproduction rules. The resulting level is in
; correct relative order but not correct absolute coordinates.
to Propagate [current_line_set]

  ask current_line_set with [ ReportState (age + 1) != "dead" ][      ; ReportState: a function defined below

    let tree-parent self                   ; stores the cell that is on the current line, which will become the parent node on the tree structure
    let next-line-cell nobody              ; stores the cell that will be on the next line which is the same cell that is represented by the tree-parent
    hatch 1 [ set next-line-cell self ]

    ; determine whether to split based on rabbit? and upcoming cell_states
    ; the use of ReportState is necessary to determine which state the cell WILL be at the next age without actually changing the age
    if (not rabbit? and ReportState (age + 1) = "mature") or (ReportState (age) = "mature" and ReportState (age + 1) = "mature") [
      ; So rabbits have a child as soon as they become mature. Other the cell must be mature for a cycle.
      ; split into a new child cell
      hatch 1 [
        set cell_state "immature"
        set age 0
        set generation (generation + 1)
        set is_stem? false

        ; call to function which calculates characteristic mc, wm, and ls values based on the generation number and the interface controls
        let characteristic-parameters (GetCharacteristicParameters generation)
        set cell_mc item 0 characteristic-parameters
        set cell_wm item 1 characteristic-parameters
        set cell_ls item 2 characteristic-parameters

        ; increment line and child_directions; see info tab for convention details
        set line (line + 1)
        ;set child_direction (0 - child_direction)    ; "child-direction is flipped with every generation so that the tree remains balanced"
        set cxcor cxcor + child_direction

        ; create a visual link to connect to the tree parent
        create-link-with tree-parent
      ]
    ]

    ; we also want the current-cell to move Propagate down the tree and update properties
    ask next-line-cell [
      set age (age + 1)
      set cell_state (ReportState age)

      ; increment line and child_dirfections; see info tab for convention details
      set line (line + 1)
      set child_direction (0 - child_direction) ; NEW
      set cxcor cxcor + child_direction

      ; create a visual link to connect to the tree parent
      create-link-with tree-parent
    ]
  ]
end

;; Defines maturation cycle, life span, and time until whole maturation values for the next generation of cells
to-report GetCharacteristicParameters [ cell-generation ]

  ; create list of generational rules for stem-mc and stem-wm time according to sliders
  let mc-list (list stem-mc gen1-mc gen2-mc gen3-mc gen4-mc gen5-mc gen6-mc gen7-mc gen8-mc gen9-mc)
  let wm-list (list lifespan gen1-wm gen2-wm gen3-wm gen4-wm gen5-wm gen6-wm gen7-wm gen8-wm gen9-wm)

  let new-mc 0
  let new-wm 0
  let new-ls lifespan         ; all cells have the same lifespan under this model

  ; set the new mc and wm values based on the generation using the mc-list and wm-list
  ; if generation exceeds the sliders, then set the values to be equal to that of the last available slider setting
  ifelse (generation < length mc-list) [
    set new-mc item cell-generation mc-list
    set new-wm item cell-generation wm-list
  ][
    set new-mc item ((length mc-list) - 1) mc-list
    set new-wm item ((length wm-list) - 1) wm-list
  ]

  ; if no-whole-maturation? is on then set wm to be lifespan for all cells
  if no-whole-maturation? [ set new-wm lifespan ]

  ; Maturation cycle of zero or less is equivalent to infertile (conventionally defined to be -1)
  if new-mc <= 0 [ set new-mc -1 ]

  report (list new-mc new-wm new-ls)
end

; Takes a set of nodes to Draw on the next line in the final positions. The cells must have cxcors that are in relative
; order of the final positions so that the function can evenly space and center the nodes.
to Draw [current_line_set]

  ; sort cells by the current cxcor, which should be correct relative to each other and add to list
  let current_line-list sort-on [cxcor] current_line_set
  let i 0

  ; loop through and reposition the nodes in the list
  foreach current_line-list [ x ->
    ask x [
      ; move down to next line
      set cycor cycor - yspace

      ; reposition the cxcor cor in equal spacing from left to right
      set cxcor ( i * xspace - 0.5 * (length current_line-list - 1) * xspace )
      ifelse (abs cxcor < max-pxcor and abs cycor < max-pycor)
      [ setxy cxcor cycor ]
      [ hide-turtle ]
      ;FormatCell
    ]
    set i (i + 1)
  ]
  foreach current_line-list [ x ->
    ask x [
      ;-------------------------resets generation-------------------------
      if is_stem? and ReportState (age) = "wholly-mature" [
        ask nodes-on neighbors4 [
          if line = (current_line + 1) [
            set generation 0
            set is_stem? true
          ]
        ]
      ]
    ]
  ]
  foreach current_line-list [ x ->
    ask x [
      FormatCell
    ]
  ]
end

; Set desired shapes and colors based on cell state
to FormatCell
  set shape "hex"
  if cell_state = "immature" [ set color red ]
  if cell_state = "mature" [ set color blue ]
  if cell_state = "wholly-mature" [ set color lime - 1 ] ;green - 3 ]
  if cell_state = "dead" [ hide-turtle ]

  if is_stem? [ set shape "hex outlined" ]
end

; Given an age, it reports what the state of the cell should be. Used to update cell states or inquire the cell states
; for some future hypothetical age without actually changing the age
to-report ReportState [ cell-age ]
  if immortal-stem-cell? and is_stem? and cell-age > cell_mc [
    report "mature"
  ]

  if cell-age >= cell_ls [ report "dead" ]
  if cell-age >= cell_wm [ report "wholly-mature" ]
  if cell-age >= cell_mc [ report "mature" ]
  if cell-age < cell_mc [ report "immature" ]
end

;; Set up a "small world" where there are fewer, larger patches
;; Use for close examination of individual cell activity
to SmallWorld
;  set-patch-size 13 ;10
;  resize-world (0 - 43) 43 (0 - 23) 23 ;(0 - 53) 53 (0 - 23) 23
  set-patch-size 10
  resize-world (0 - 49) 49 (0 - 24) 24
  Setup
end

;; Set up a "large world" where there are more, smaller patches
;; Use for macroscopic view of the cellular structure
to LargeWorld
  set-patch-size 4 ;1
  resize-world (0 - 123) 123 (0 - 62) 62 ;(0 - 540) 540 (0 - 240) 240
  Setup
end
@#$#@#$#@
GRAPHICS-WINDOW
246
10
1242
519
-1
-1
4.0
1
10
1
1
1
0
1
1
1
-123
123
-62
62
1
1
1
ticks
30.0

BUTTON
28
43
91
76
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
154
43
217
76
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
2
81
92
114
rabbit?
rabbit?
1
1
-1000

SWITCH
2
114
244
147
immortal-stem-cell?
immortal-stem-cell?
1
1
-1000

SLIDER
122
150
226
183
lifespan
lifespan
1
50
13.0
1
1
NIL
HORIZONTAL

MONITOR
258
42
319
87
Live Cells
count nodes with [line = current_line]
17
1
11

BUTTON
28
10
133
43
small world
SmallWorld
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
121
10
222
43
large world
LargeWorld
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
18
217
122
250
gen1-mc
gen1-mc
0
6
4.0
1
1
NIL
HORIZONTAL

SLIDER
18
250
122
283
gen2-mc
gen2-mc
0
6
4.0
1
1
NIL
HORIZONTAL

SLIDER
18
283
122
316
gen3-mc
gen3-mc
0
6
4.0
1
1
NIL
HORIZONTAL

SLIDER
18
316
122
349
gen4-mc
gen4-mc
0
6
4.0
1
1
NIL
HORIZONTAL

SLIDER
18
349
122
382
gen5-mc
gen5-mc
0
6
4.0
1
1
NIL
HORIZONTAL

BUTTON
91
43
154
76
step
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
18
382
122
415
gen6-mc
gen6-mc
0
6
4.0
1
1
NIL
HORIZONTAL

SLIDER
18
415
122
448
gen7-mc
gen7-mc
0
6
4.0
1
1
NIL
HORIZONTAL

SLIDER
18
448
122
481
gen8-mc
gen8-mc
0
6
4.0
1
1
NIL
HORIZONTAL

SLIDER
18
481
122
514
gen9-mc
gen9-mc
0
6
4.0
1
1
NIL
HORIZONTAL

SLIDER
122
217
226
250
gen1-wm
gen1-wm
0
12
5.0
1
1
NIL
HORIZONTAL

SLIDER
122
250
226
283
gen2-wm
gen2-wm
0
12
6.0
1
1
NIL
HORIZONTAL

SLIDER
122
283
226
316
gen3-wm
gen3-wm
0
12
6.0
1
1
NIL
HORIZONTAL

SLIDER
122
316
226
349
gen4-wm
gen4-wm
0
12
6.0
1
1
NIL
HORIZONTAL

SLIDER
122
349
226
382
gen5-wm
gen5-wm
0
12
6.0
1
1
NIL
HORIZONTAL

SLIDER
122
382
226
415
gen6-wm
gen6-wm
0
12
5.0
1
1
NIL
HORIZONTAL

SLIDER
122
415
226
448
gen7-wm
gen7-wm
0
12
5.0
1
1
NIL
HORIZONTAL

SLIDER
122
448
226
481
gen8-wm
gen8-wm
0
12
5.0
1
1
NIL
HORIZONTAL

SLIDER
122
481
226
514
gen9-wm
gen9-wm
0
12
5.0
1
1
NIL
HORIZONTAL

SLIDER
18
185
122
218
stem-mc
stem-mc
2
6
4.0
2
1
NIL
HORIZONTAL

SWITCH
92
81
244
114
no-whole-maturation?
no-whole-maturation?
1
1
-1000

SLIDER
122
184
226
217
stem-wm
stem-wm
0
25
12.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
## BACKGROUND

This program serves as a tool for modeling cell division according to current research in agent-based mathematical modeling of cell reproduction. One of the important unexplained phenomena of cellular biology is the observation of "dynamic stability". The vast majority of the human organs consist of cells that are constantly dividing and dying within a timescale that is much shorter than the human lifespan. Remarkably, organs remain macroscopically stable and intact despite the perpetual turnover. This leads to the concept of dynamic stability. While many classes of tissue exhibit this behavior, this research focuses on modeling dynamic stability as seen in the colonic crypt to reduce the scope.

While organs are highly intricate structures, it is assumed to be unlikely that the cells possess the complexity to explictly know their place and role within the macroscopic organ. Instead, this research is predicated upon the possibility of "emergent complexity". In the field of agent-based modeling, there is well documented research in a multitude of domains whereby highly interesting behavior is observed from the interactions between highly simplistic agents. This research presupposes that dynamically stable cell structures are an instance of emergent complexity. The purpose of this research, therefore, is to explore the possible rules that might govern the cells in these structures.

This program in particular is aimed at modeling the cell lineage tree that results from the implementation of certain conjectured rules of cell division. The temporal evolution of the cell population is charted over time in this model.

## Included Files

The cell-tree model acts as a stand-alone file that includes both the model details as well as all interface features. For a related model that shows the single-time-frame spatial evolution of cells, see the related "Cell-Structure" set of programs.

## Defining the Model - Tree Structure

The underlying model is formulated as an agent-based model, with the only agents being the cells themselves. Cells have rules that dictate when cells divide and and when they die. These are the only rules modeled in this program. All other considerations such as spatial positioning of the cells are not included.

The agents in this NetLogo program are nodes of a tree data structure each of which represents a cell at some given moment in time. Beginning with a single stem cell at time zero, each successive line of nodes represents the cell population at the next time step. Nodes are linked back to a node on the prior line if the two nodes represent 1) the same cell or 2) a child/parent pairing after a recent cell division.

All cells of a current time-step are drawn with the same vertical y coordinate. All lines are equally spaced. Finally, the horizontal distance between adjacent cells on any line are equal. This ensures that the node count (and therefore the instantaneous cell population) on any given line is exactly proportional to the geometric width of the line.

## Defining the Model - Cells

Many of the properties owned by nodes are better interpreted from the perspective of the cell that the nodes are representing.

All cells have two changing properties: age, and cell-state. Since cells divide asymmetrically in this model, it is possible to distinguish the resultant cells into a “child” and a “parent”. The age of a cell is then defined by the number of discrete time steps since a cell split from its parent. The cell-state is a string that defines the current part of the cell lifecycle ("immature", "mature", "wholly-mature", or "dead"). Since nodes represent cells at a particular instant in time, each node will have fixed values for all of these properties.

Cells themselves also have a set of three characteristic values which dictate their progression through the cell-states: a maturation-cycle, a time to reach whole-maturation, and a lifespan. These correspond to the variables cell-mc, cell-wm, and cell-ls, respectively. The values specify the age at which cells change state. Beginning at age zero, a cell is “immature”. At age cell-mc, a cell becomes “mature”.  At age cell-wm, a cell becomes “wholly-mature” and at age cell-ls, the cell has reached the end of its life cycle and becomes “dead”. Cells will divide if and only if it is in its “mature” state. If two nodes represent the same cell, they will have the same values for cell-mc, cell-wm, and cell-ls

Cells also have two properties that determine their cell-mc, cell-wm, and cell-ls values at birth: is-stem? and generation. Effectively, all cells with the same is-stem? and generation values will experience the same lifecycle. As with cell-mc, cell-wm, and cell-ls, all nodes representing the same cell will have the same values for these properties.

In the event of a cell division, two new nodes on the next line are created to represent the division. More information on the mechanism behind adding the next line can be found in the next section.

## Defining the Model - Nodes

Two properties owned by nodes are exclusive to nodes and have no connections to the underlying cell representation.

The first is the "line" value, which simply tracks the line of the tree to which the node belongs. Only nodes on the last line are affected by any type of operation; all higher nodes remaining static after they have been placed.

The "child-direction" is a small positive or negative number which dictates how nodes on the next line will be drawn in the event of a cell division. If a split occurs, then a positive child-direction number indicates that the new node representing the child cell will be drawn to the right of the new node that represents the parent cell. If the child-direction is negative, then the opposite occurs. The child-direction is flipped with every generation so that the tree remains as balanced as possible.

The magnitude of the child-direction number can be any magnitude smaller than half the size of the standard horizontal distance between adjacent cells. When a new line of nodes is created, they are temporarily placed directly below the parent nodes with a slight displacement determined by the child-direction. By keeping the magnitude of the child-direction value sufficiently small, this ensures that the relative ordering of the next line of cells is in the corrected order. A separate function can then be used to space the cells appropriately in the same order.

## Interface

The following controls are provided for the interface.

- small-world - Initialies a new model with a small area and high resolution.

- large-world - Initializes a new model with a large area and low resolution.

- setup - Initializes a new model under the current area and resolution setting. Area size and resolution are manually adjustable by right clicking the display area and clicking "edit".

- step - Advances the model by one time step

- go - Advances the model continuously. Click the go button again to stop the model.

- rabbit? - If set to on, cells start to divide on the time step after they reach whole-maturation. Otherwise, cells divide on the same time step when they reach whole-maturation.

- no-whole-maturation? - If set to on, cells never reach whole-maturation and are fertile for the duration of their lifespan. Otherwise, cells reach whole-maturation according to the gen1-wm, gen2-wm.... gen10-wm sliders below.

- immortal-stem-cell? - If set to on, the stem cell will never die. Otherwise, dies once its age exceeds the lifespan slider.

- stem-mc - Determines the mautration cycle of the stem cell.

- lifespan - Determines the lifespan for all cells

- gen1-mc ... gen10-mc - Determines the maturation cycle value for each generation of cells. Note that values MUST be a factor of the stem-mc value. E.g. if the stem-mc is 6, then allowable values for gen1-mc ... gen1-mc are 1, 2, 3, and 6. Setting the value to 0 is also acceptable and equivalent to defining the generation of cells to be completely infertile.

- gen1-wm ... gen10-wm - Determines the time to whole maturation for each generation of cells.

Visual displays are defined by the following.

- Stem Cells - colored white
- Immature Cells - colored red
- Mature Cells - colored blue
- Wholly Mature Cells - colored dark green
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

hex
false
0
Polygon -7500403 true true 0 150 75 30 225 30 300 150 225 270 75 270

hex outlined
false
0
Polygon -1 true false 0 150 75 30 225 30 300 150 225 270 75 270
Circle -7500403 true true 105 105 90

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="findsteadystate" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="35"/>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="rabbit?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gen3-wm">
      <value value="2"/>
      <value value="4"/>
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gen9-mc">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gen2-mc">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gen2-wm">
      <value value="2"/>
      <value value="4"/>
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gen8-mc">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gen1-mc">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gen9-wm">
      <value value="2"/>
      <value value="4"/>
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gen1-wm">
      <value value="2"/>
      <value value="4"/>
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gen7-mc">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="immortal-stem-cell?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gen8-wm">
      <value value="2"/>
      <value value="4"/>
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="no-whole-maturation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gen6-mc">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lifespan">
      <value value="3"/>
      <value value="5"/>
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gen7-wm">
      <value value="2"/>
      <value value="4"/>
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gen5-mc">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gen6-wm">
      <value value="2"/>
      <value value="4"/>
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gen4-mc">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stem-mc">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stem-wm">
      <value value="2"/>
      <value value="4"/>
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gen5-wm">
      <value value="2"/>
      <value value="4"/>
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gen3-mc">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gen4-wm">
      <value value="2"/>
      <value value="4"/>
      <value value="6"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
