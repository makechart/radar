# Change Logs

## v0.0.3

 - redesign the chart: concentric grid ( polygon or circle ) with optional stripes, axis lines, axis labels
   aligned by angle, tick labels, series fill and stroke, data points, selectable legend, tooltip with series
   highlight, and layout that adapts to the container ( long labels are truncated, crowded labels thinned,
   legend and ticks dropped when there is no room )
 - **breaking**: new flat data model. every cell is a scalar, so the data is editable in the sheet.
   one row is an axis, one numeric column is a series:
   - dimensions `radius` and `order` are removed
   - new dimension `name` ( axis label ) and `value` ( `multiple: true`, one column per series )
   - rows whose `radius` cell held an array are no longer supported; charts bound to the old dimensions
     render nothing ( no error ) until they are rebound
 - value domain starts from 0 by default so radii stay proportional. `domain` can start from the data minimum
   or use custom bounds; ticks are rounded while keeping the configured number of levels; the zero ring is
   emphasized when the domain crosses 0. the domain ignores legend selection, so toggling a series does not
   rescale the others
 - handle missing values ( `series.missing`: gap / skip / zero ), negative values, blank trailing rows, duplicated
   axis names and series columns, a single series, and fewer than 3 axes ( the grid falls back to circles )
 - morph in polar coordinates via `chart.anim`, including when the number of axes or series changes
 - add config: `grid`, `axis`, `label`, `tick`, `orientation`, `domain`, `series`, `dot`, `animation`, with zh-TW
   labels. `legend.position` now defaults to `bottom` and `tip.format` to automatic
 - add `src/index.styl`, rewrite test cases and snapshots


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
