module.exports =
  pkg:
    name: 'radar', version: '0.0.1'
    extend: {name: "base", version: "0.0.1"}
    dependencies: []
  init: ({root, context, pubsub}) ->
    pubsub.fire \init, mod: mod {context} .then ~> it.0

mod = ({context}) ->
  {d3,forceBoundary,ldColor,repeatString$} = context
  sample: ->
    raw: [0 to 4].map (idx) ~> {val: [0 to 2].map(->0.5 + 0.5 * Math.random!), cat: idx}
    binding:
      radius: {key: \val}
      order: {key: \cat}
  config: {}
  dimension:
    radius: { type: \R, name: "radius of point on radar line" },
    order: { type: \R, name: "order of data point" }
  init: ->
    svg = d3.select @svg
    @gs = gs = {}
    gs.all = svg.append \g
    @line = d3.line!
      .x (d,i) ~> @scale.r(d) * Math.cos(@scale.a(@orders[i]))
      .y (d,i) ~> @scale.r(d) * -Math.sin(@scale.a(@orders[i]))
  parse: ->
    @orders = Array.from(new Set(@data.map(->it.order)))
    @parsed = d3.transpose(@data.map(-> it.radius))
    @parsed.map (d,i) -> d.idx = i
    @names = <[1 2 3]> #@dimension.radius.fieldName || <[1 2 3]>
    @radiusRange = d3.extent(@parsed
      .map (d) -> d3.extent d
      .reduce(((a,b) -> a.concat(b)), [])
    )
    if @radiusRange.0 == @radiusRange.1 => @radiusRange.1++

  bind: ->
    @gs.all.selectAll \path.data .data @parsed
      ..exit!
        .attr \class, ""
        .transition \exit .duration 500
        .attr \opacity, 0
        .remove!
      ..enter!
        .append \path
        .attr \class, \data
        .attr \opacity, 0
    @gs.all.selectAll \g.data-group .data @parsed
      ..exit!
        .attr \class, ""
        .transition \exit .duration 500
        .attr \opacity, 0
        .remove!
      ..enter!
        .append \g
        .attr \class, \data-group
        .attr \opacity, 0
    @gs.all.selectAll \g.data-group .each (d,i) ->
      d3.select @ .selectAll \circle.node .data d
        ..exit!
          .attr \class, ''
          .transition \exit .duration 500
          .attr \opacity, 0
          .remove!
        ..enter!
          .append \circle
          .attr \class, \node
          .attr \opacity, 0
  resize: ->
    size = (Math.min(@box.width, @box.height) / 2) >? 10
    @scale =
      r: d3.scaleLinear!domain [0, @radiusRange.1] .range [0, size]
      a: d3.scalePoint!domain @orders .range [0, 2 * Math.PI]
      c: d3.interpolateTurbo
    if @cfg? and @cfg.palette =>
      @scale.c = d3.interpolateDiscrete @cfg.palette.colors.map -> ldColor.web(it.value or it)
    @aTicks = d3.range(@data.length)
  render: ->
    {scale, names, line, orders, orders} = @
    @gs.all.attr \transform, "translate(#{@box.width/2},#{@box.height/2})"

    @gs.all.selectAll \path.data
      .each (d,i) ->
        color = scale.c(i / (names.length - 1))
        d3.select @
          .attr \fill, color
          .attr \fill-opacity, 0.2
          .attr \stroke, color
          .attr \stroke-width, 1
          .transition \morph .duration 350
            .attr \d, (d,i) -> line(d,i) + "Z"
      .transition \opacity .duration 350
        .attr \opacity, 1 

    @gs.all.selectAll \g.data-group
      .each (d,i) ->
        color = scale.c(i / (names.length - 1))
        d3.select @ .selectAll \circle.node
          .attr \fill, \#fff
          .attr \stroke, color
          .attr \stroke-width, 1
          .transition \morph .duration 350
            .attr \cx, (d,i) ~> scale.r(d) * Math.cos(scale.a(orders[i]))
            .attr \cy, (d,i) ~> scale.r(d) * -Math.sin(scale.a(orders[i]))
            .attr \r, 3
            .attr \opacity, 1
      .transition \opacity .duration 350
        .attr \opacity, 1
