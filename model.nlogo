globals [
  sample-car
  ;speed-limit  ;initially speed limit was set to 1
  speed-min
  disposed_cars
  tick_of_first_disposed
]

turtles-own [
  speed
  own-max-speed
  own-line-delay
  is-car
]

to setup
  clear-all
  ;set speed-limit 1
  set speed-min 0
  set disposed_cars 0
  set tick_of_first_disposed -1
  ask patches [ setup-road ]
  setup-barriers
  ;watch sample-car ;make the "light" around samle cap
  reset-ticks
end

to setup-road ;; patch procedure
              ;;changing colours, current patches are on ycor 2 and -2 (maybe it doesn't make sense honestly and maybe we can make global variable out of it)
  if pycor = 1 [ set pcolor white ]
  if pycor = -1 [ set pcolor white ]

end

to setup_one_car

  let future_ycor -1
  let start_patch patch (min-pxcor + 3) future_ycor
  if any? turtles-on start_patch [
    set future_ycor 1
    set start_patch patch (min-pxcor + 3) future_ycor
    if any? turtles-on start_patch [
      if (tick_of_first_disposed = -1) [set tick_of_first_disposed ticks]
      set disposed_cars (disposed_cars + 1)
      stop
    ]
  ]

   create-turtles 1 [
    set color blue
    set xcor (min-pxcor + 3) ;;;nejde se dívat na místa "mimo", a my se u změny směru díváme o dvě dozadu a o jedno dopředu, proto to musí být odsazené
    set ycor future_ycor
    set heading 90
    ;; set initial speed between 0.1 and speed limit
    set own-max-speed (random-float 0.1) + speed-limit - 0.05
    set speed speed-limit ;;;0.1 + random-float (speed-limit - speed)
    set own-line-delay 0
    set is-car true
    set shape "car"
  ]
end


to setup-barriers
  if barriers [
    ;; Create top barrier row
    if barrier-top >= 0[
      create-turtles 1 [
        set color green
        set xcor barrier-top - 25
        set ycor 1
        set heading 90
        ;; set initial speed between 0.1 and speed limit
        set speed 0
        set own-line-delay 0
        set own-max-speed 0
        set is-car false
        set shape "x"
      ]
    ]

    ;; Create bottom barrier row
    if barrier-bottom >= 0 [
      create-turtles 1 [
        set color green
        set xcor barrier-bottom - 25
        set ycor -1
        set heading 90
        ;; set initial speed between 0.1 and speed limit
        set speed 0
        set own-line-delay 0
        set is-car false
        set shape "x"
      ]
    ]
  ]
end


to go
  ask turtles [

    if not is-car
    [
      stop
    ]

    if own-line-delay >= 0 ; decrements line swap delay
    [
      set own-line-delay (own-line-delay - 0.01)
    ]

    ifelse ycor > 0 and can_switch ;;;if is in left lane and is there free in right, change lanes
    [
      switch_lane
    ]
    [
      let car-ahead one-of turtles-on patch-ahead 1
      ifelse car-ahead != nobody
      [
        ifelse can_switch
        [
          switch_lane
        ]
        [
          ;set color green ;;; debugging
          slow-down-car car-ahead
        ]
      ]
      [
        speed-up-car
      ]
    ]

    move-car

    ;;remove when they leave right end
    if xcor > (max-pxcor - 2) [ die ]
  ]

  ;if ticks mod spawn_period = 0 [ setup_one_car ]

  ifelse (ticks mod spawn_period) = 0 [
    setup_one_car
  ]
  [
    if disposed_cars > 0 [
      setup_one_car
      set disposed_cars (disposed_cars - 1)
    ]
  ]
  tick
end

;to go_old ;;primary keep driving in current lane, switch just when there is somebody in front
;          ;;we can keep diferetn "go" funcition as "different strategies" of run them simultaneously under each other
;  ;; if there is a car right ahead of you, match its speed then slow down
;  ask turtles [
;
;    if not is-car
;    [
;      stop
;    ]
;
;    let car-ahead one-of turtles-on patch-ahead 1
;    ifelse car-ahead != nobody
;      [
;         ;;if there is enough space on the left lane, change lanes
;        ;;;let left-lane-clear not any? turtles-on patch-left 1
;        ;;;let left-lane-clear any? turtles-on patch-left-and-ahead 1 0
;        let lane-clear can_switch
;        ifelse lane-clear
;        [
;          switch_lane
;        ]
;        [
;          ;set color green ;;; debugging
;          slow-down-car car-ahead
;        ]
;      ]
;      [ speed-up-car ] ;; otherwise, speed up
;
;    move-car
;  ]
;  tick
;end

to move-car
  ;; don't slow down below speed minimum or speed up beyond speed limit
  if speed < speed-min [ set speed speed-min ]
  if speed > own-max-speed [ set speed own-max-speed ] ;here was initially speed-limit, changed it individual max speed
  fd speed
end

to slow-down-car [ car-ahead ] ;; turtle procedure
  ;; slow down so you are driving more slowly than car ahead
  set speed [ speed ] of car-ahead - deceleration
end

to speed-up-car ;; turtle procedure
  set speed speed + acceleration
end

to switch_lane
  ifelse ycor > 0 [set ycor -1 ] [set ycor 1 ]
  set speed speed - deceleration
  set own-line-delay lane-delay
  ;;;set color green
end

to-report turtles-in-box [t diameterx diametery ofx ofy]
  report other turtles-on patches with [
    pxcor >= [xcor] of t - diameterx + ofx and pxcor <= [xcor] of t + diameterx + ofx and
    pycor >= [ycor] of t - diametery + ofy and pycor <= [ycor] of t + diametery + ofy
  ]
end

to-report can_switch ;;;reporter = function that return something
  if own-line-delay >= 0 ;and speed > 0; if car was in line for long enough
  [
    report false
  ]

  let other-lane-patch patch-right-and-ahead 90 2 ;there must be some initialization here, so i just copied it.

  let olp-y 0

  ifelse ycor > 0
  [
    ;;set other-lane-patch patch-right-and-ahead 90 2  ;look in 90 degrees 4 patches to right. Idiotic i know
    set olp-y -2
  ]
  [
    set olp-y 2
  ]

  ;; car behind
  let pat turtles-in-box self 4 1 -2 olp-y

  if any? turtles-on pat[

    let nearby-one one-of pat
    set pat turtles-in-box self 3 1 -1 olp-y

    ifelse any? turtles-on pat[

      set nearby-one one-of pat
      set pat turtles-in-box self 2 1 0 olp-y
      ifelse any? turtles-on pat [
        report False
      ]
      [
        report [speed] of nearby-one < acceleration * 5
      ]
    ]

    [
      report [speed] of nearby-one < acceleration * 10
    ]
  ]
  report True

  report (not any? pat)
end

to-report just-cars
  report turtles with [is-car = true]
end

to-report mean_speed
  let aux just-cars
  ifelse (count aux) > 0 [ report (mean [speed] of aux )] [ report speed-limit ]
end

to-report min_speed
  let aux just-cars
  ifelse count aux > 0 [ report (min [speed] of just-cars) ][ report speed-limit ]
end

to-report max_speed
  let aux just-cars
  ifelse count aux > 0 [ report (max [speed] of just-cars) ][ report speed-limit ]
end


to-report mean_speed_complex
  let car_list just-cars
  let n count car_list
  if n = 0 [report speed-limit]

  let speed_sum sum [speed] of car_list
  report speed_sum / (n + disposed_cars)
end
@#$#@#$#@
GRAPHICS-WINDOW
10
410
987
590
-1
-1
19.0
1
10
1
1
1
0
0
0
1
-25
25
-4
4
1
1
1
ticks
30.0

BUTTON
0
100
72
141
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
83
101
154
141
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
0

SLIDER
15
370
160
403
deceleration
deceleration
0
.099
0.045
.005
1
NIL
HORIZONTAL

SLIDER
14
328
159
361
acceleration
acceleration
0
.099
0.075
.005
1
NIL
HORIZONTAL

PLOT
260
10
678
207
Car speeds
time
speed
0.0
300.0
0.0
1.1
true
true
"" ""
PENS
"min speed" 1.0 0 -13345367 true "" "plot min_speed"
"max speed" 1.0 0 -10899396 true "" "plot max_speed"
"mean speed" 1.0 0 -2674135 true "" "plot mean_speed"

BUTTON
164
103
227
136
NIL
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
0
60
172
93
speed-limit
speed-limit
0.1
1
0.3
0.05
1
NIL
HORIZONTAL

SLIDER
15
285
187
318
lane-delay
lane-delay
0
2
0.2
0.01
1
NIL
HORIZONTAL

SWITCH
250
280
353
313
barriers
barriers
0
1
-1000

SLIDER
250
325
422
358
barrier-top
barrier-top
-1
50
-1.0
1
1
NIL
HORIZONTAL

SLIDER
250
370
422
403
barrier-bottom
barrier-bottom
-1
50
32.0
1
1
NIL
HORIZONTAL

SLIDER
0
15
172
48
spawn_period
spawn_period
1
50
10.0
1
1
NIL
HORIZONTAL

PLOT
720
10
1250
205
Car speed relative to speed limit
NIL
NIL
0.0
300.0
0.0
1.0
true
true
"" ""
PENS
"percent speed limit" 1.0 0 -16777216 true "" "plot mean_speed / speed-limit"

MONITOR
1130
240
1237
285
NIL
disposed_cars
17
1
11

PLOT
1125
310
1635
460
Car speed relative to speed limit inlcuding disposed cars
NIL
NIL
0.0
10.0
0.0
1.1
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean_speed_complex"

MONITOR
1290
240
1442
285
NIL
tick_of_first_disposed
17
1
11

@#$#@#$#@
## WHAT IS IT?


## HOW TO USE IT

Click on the SETUP button to set up the cars.

Set the NUMBER-OF-CARS slider to change the number of cars on the road.

Click on GO to start the cars moving.  Note that they wrap around the world as they move, so the road is like a continuous loop.

The ACCELERATION slider controls the rate at which cars accelerate (speed up) when there are no cars ahead.

When a car sees another car right in front, it matches that car's speed and then slows down a bit more.  How much slower it goes than the car in front of it is controlled by the DECELERATION slider.




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

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
setup
repeat 180 [ go ]
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>mean [speed] of turtles</metric>
    <enumeratedValueSet variable="number-of-cars">
      <value value="10"/>
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed-limit">
      <value value="1"/>
      <value value="0.9"/>
      <value value="0.8"/>
      <value value="0.7"/>
      <value value="0.6"/>
      <value value="0.5"/>
      <value value="0.4"/>
      <value value="0.3"/>
      <value value="0.2"/>
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment complex" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2000"/>
    <metric>mean_speed</metric>
    <enumeratedValueSet variable="spawn_period">
      <value value="5"/>
      <value value="10"/>
      <value value="15"/>
      <value value="20"/>
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed-limit">
      <value value="1"/>
      <value value="0.9"/>
      <value value="0.8"/>
      <value value="0.7"/>
      <value value="0.6"/>
      <value value="0.5"/>
      <value value="0.4"/>
      <value value="0.3"/>
      <value value="0.2"/>
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="acceleration">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deceleration">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lane-delay">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment_first_disposed_tick" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <exitCondition>disposed_cars &gt; 1</exitCondition>
    <metric>tick_of_first_disposed</metric>
    <enumeratedValueSet variable="lane-delay">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="barrier-bottom">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="spawn_period">
      <value value="5"/>
      <value value="10"/>
      <value value="15"/>
      <value value="20"/>
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="barriers">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="acceleration">
      <value value="0.075"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="barrier-top">
      <value value="34"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed-limit">
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.3"/>
      <value value="0.4"/>
      <value value="0.5"/>
      <value value="0.6"/>
      <value value="0.7"/>
      <value value="0.8"/>
      <value value="0.9"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deceleration">
      <value value="0.05"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="complex 2" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2000"/>
    <exitCondition>disposed_cars = 200</exitCondition>
    <metric>mean_speed_complex</metric>
    <enumeratedValueSet variable="lane-delay">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="spawn_period">
      <value value="10"/>
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="barriers">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="acceleration">
      <value value="0.075"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="barrier-top">
      <value value="-1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed-limit">
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.3"/>
      <value value="0.4"/>
      <value value="0.5"/>
      <value value="0.6"/>
      <value value="0.7"/>
      <value value="0.8"/>
      <value value="0.9"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deceleration">
      <value value="0.045"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="complex 2 precise" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2000"/>
    <exitCondition>disposed_cars = 200</exitCondition>
    <metric>mean_speed_complex</metric>
    <enumeratedValueSet variable="lane-delay">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="spawn_period">
      <value value="5"/>
      <value value="10"/>
      <value value="15"/>
      <value value="20"/>
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="barriers">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="acceleration">
      <value value="0.075"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="barrier-top">
      <value value="-1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed-limit">
      <value value="0.05"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.2"/>
      <value value="0.25"/>
      <value value="0.3"/>
      <value value="0.35"/>
      <value value="0.4"/>
      <value value="0.45"/>
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deceleration">
      <value value="0.045"/>
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
1
@#$#@#$#@
