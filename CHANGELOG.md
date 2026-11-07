# Change Logs

## v0.0.2

 - extend the lite base ( `@makechart/base` `lite/index.html`, no d3 ): needs `@makechart/base` >= 0.2.0
   and `@plotdb/chart` >= 3.7.0.
   transitions run on `chart.anim`, so animation can be recorded frame by frame ( `anim.manual` / `step` )
 - fix bug: it didn't render at all. layout is now disabled ( it has no layout markup ) and the svg is
   positioned at the top left instead of being pushed below the layout block
 - fix bug: the first and the last axis overlapped; axes now split the circle evenly
 - fix bug: line colors assumed exactly 3 lines
 - fix bug: setting a palette threw ( `ldColor` instead of `ldcolor` )
 - add test cases ( `test/index.ls`, run with `npm test` via `@makechart/viewer` )


## v0.0.1

init release
