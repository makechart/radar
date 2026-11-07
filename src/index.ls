module.exports =
  pkg:
    name: 'radar', version: '0.0.1'
    # lite: 不帶 d3 的 base. 補間改用 chart.anim, 可以逐格錄影 ( 見 @plotdb/chart utils/anim )
    extend: {name: "@makechart/base", path: "lite/index.html"}
    dependencies: []
  init: ({root, context, pubsub}) ->
    # 這張圖沒有 layout ( 直接畫在 svg 上 ), 要關掉, 不然 core 找不到 .pdl-layout 會丟錯
    pubsub.fire \init, mod: mod({context}), layout: false .then ~> it.0

mod = ({context}) ->
  {chart,ldcolor} = context
  {scale: Scale, shape, color: {turbo, discrete}, anim: {join}} = chart.utils
  svgns = "http://www.w3.org/2000/svg"
  # 同 d3.extent: 略過 null / NaN
  extent = (list) ->
    vs = list.filter -> it? and +it >= +it
    if vs.length => [vs.reduce(((a,b) -> if b < a => b else a)), vs.reduce(((a,b) -> if b > a => b else a))]
    else [undefined, undefined]
  # 同 d3.transpose
  transpose = (m) ->
    n = if m.length => Math.min.apply(Math, m.map -> it.length) else 0
    [[r[j] for r in m] for j from 0 til n]
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
    # 沒有 layout 時 svg 接在 base 的 layout 區塊後面, 會被擠到可視範圍外; 疊回左上角
    @svg.style <<< position: \absolute, left: 0, top: 0
    @gs = gs = {}
    gs.all = @svg.appendChild document.createElementNS(svgns, \g)
    @line = shape.line!
      .x (d,i) ~> @scale.r(d) * Math.cos(@scale.a(@orders[i]))
      .y (d,i) ~> @scale.r(d) * -Math.sin(@scale.a(@orders[i]))
  parse: ->
    @orders = Array.from(new Set(@data.map(->it.order)))
    @parsed = transpose(@data.map(-> it.radius))
    @parsed.map (d,i) -> d.idx = i
    # 每條線的名字 ( 目前只用來分顏色 ), 依線的數量
    @names = @parsed.map (d, i) -> "#{i + 1}"
    @radiusRange = extent(@parsed
      .map (d) -> extent d
      .reduce(((a,b) -> a.concat(b)), [])
    )
    if @radiusRange.0 == @radiusRange.1 => @radiusRange.1++

  bind: ->
    # 移除的先淡出再拿掉 ( class 清掉, 之後的 join / render 就不會再選到它 )
    leave = (n) ~>
      n.setAttribute \class, ''
      @anim.tween n, {opacity: 0}, {duration: 500, remove: true}
    pj = join root: @gs.all, tag: \path, cls: \data, data: @parsed
    pj.exit.map leave
    pj.enter.map -> it.setAttribute \opacity, 0
    gj = join root: @gs.all, tag: \g, cls: \data-group, data: @parsed
    gj.exit.map leave
    gj.enter.map -> it.setAttribute \opacity, 0
    gj.nodes.map (g) ->
      cj = join root: g, tag: \circle, cls: \node, data: g.__data__
      cj.exit.map leave
      cj.enter.map -> it.setAttribute \opacity, 0
  resize: ->
    size = (Math.min(@box.width, @box.height) / 2) >? 10
    @scale =
      r: Scale.linear!domain [0, @radiusRange.1] .range [0, size]
      # 一圈平分給每個軸: 最後一軸停在 2π 前一格, 不跟第一軸重疊
      a: Scale.point!domain @orders .range [0, 2 * Math.PI * ((@orders.length - 1) >? 0) / (@orders.length or 1)]
      c: turbo
    if @cfg? and @cfg.palette =>
      @scale.c = discrete @cfg.palette.colors.map -> ldcolor.web(it.value or it)
    @aTicks = [0 til @data.length]
  render: ->
    {scale, names, line, orders, orders} = @
    # 只有一條線時 i / 0 會是 NaN
    nc = (names.length - 1) or 1
    @gs.all.setAttribute \transform, "translate(#{@box.width/2},#{@box.height/2})"
    tween = (n, attrs) ~> @anim.tween n, attrs, {duration: 350}
    kids = (cls) ~> Array.from(@gs.all.querySelectorAll ":scope > .#cls")

    kids(\data).map (n, i) ->
      d = n.__data__
      color = scale.c(i / nc)
      n.setAttribute \fill, color
      n.setAttribute \fill-opacity, 0.2
      n.setAttribute \stroke, color
      n.setAttribute \stroke-width, 1
      tween n, {d: line(d) + "Z", opacity: 1}

    kids(\data-group).map (g, i) ->
      color = scale.c(i / nc)
      Array.from(g.querySelectorAll ':scope > circle.node').map (n, j) ->
        d = n.__data__
        n.setAttribute \fill, \#fff
        n.setAttribute \stroke, color
        n.setAttribute \stroke-width, 1
        tween n, do
          cx: scale.r(d) * Math.cos(scale.a(orders[j]))
          cy: scale.r(d) * -Math.sin(scale.a(orders[j]))
          r: 3
          opacity: 1
      tween g, {opacity: 1}
