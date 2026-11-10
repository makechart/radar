module.exports =
  pkg:
    name: 'radar', version: '0.0.1'
    # lite: 不帶 d3 的 base. 補間改用 chart.anim, 可以逐格錄影 ( 見 @plotdb/chart utils/anim )
    extend: {name: "@makechart/base", path: "lite/index.html"}
    dependencies: []
    i18n:
      "zh-TW":
        # 維度
        "axis": "軸"
        "value": "數值"
        # 設定項目
        "Shape": "形狀"
        "Levels": "層數"
        "Color": "顏色"
        "Opacity": "透明度"
        "Line width": "線寬"
        "Stripe opacity": "間隔底色透明度"
        "Show": "顯示"
        "Font size (em)": "字級 (em)"
        "Number format": "數字格式"
        "Distance from grid (px)": "與格線距離 (px)"
        "Max width (em)": "最大寬度 (em)"
        "Start angle": "起始角度"
        "Direction": "方向"
        "Minimum": "最小值"
        "Custom minimum": "自訂最小值"
        "Maximum": "最大值"
        "Custom maximum": "自訂最大值"
        "Round to nice values": "取整到好讀的刻度"
        "Fill opacity": "填色透明度"
        "Line": "線條"
        "Missing values": "缺值處理"
        "Size": "大小"
        "Fill": "填色"
        "Enabled": "啟用"
        "Duration (ms)": "長度 (ms)"
        "Easing": "緩動"
        # 選項
        "Polygon": "多邊形"
        "Circle": "圓形"
        "Clockwise": "順時針"
        "Counter-clockwise": "逆時針"
        "From zero": "從 0 起算"
        "From data minimum": "從資料最小值起算"
        "Custom": "自訂"
        "Auto": "自動"
        "Straight": "直線"
        "Curve": "曲線"
        "Leave a gap": "留空斷開"
        "Connect neighbors": "連接相鄰點"
        "Treat as minimum": "視為最小值"
        "Linear": "線性"
        "Ease in-out": "緩入緩出"
        "Ease out": "緩出"
  init: ({root, context, pubsub, t}) ->
    pubsub.fire \init, mod: mod {context, t}

svgns = "http://www.w3.org/2000/svg"
TAU = 2 * Math.PI
finite = -> typeof(it) == \number and isFinite(it)
mk-g = (p, cls) ->
  n = p.appendChild document.createElementNS(svgns, \g)
  if cls => n.setAttribute \class, cls
  n
# 去掉浮點誤差: 0.30000000000000004 -> 0.3
clean = -> +(+it).toPrecision(12)
# 角度走最短的方向補間
lerp-angle = (a, b, t) ->
  d = (((b - a + Math.PI) % TAU) + TAU) % TAU - Math.PI
  a + d * t
pt = (a, r) -> {x: r * Math.sin(a), y: -r * Math.cos(a)}

# 把值域擴到好讀的刻度, 層數維持使用者設定的 n: 每層一個 1 / 2 / 2.5 / 5 x 10^k 的步距.
# lock: 下界不動 ( 從 0 或自訂值起算 ), 否則下界也對齊步距
nice-domain = (lo, hi, n, lock) ->
  base = Math.pow 10, Math.floor(Math.log10((hi - lo) / n))
  for m in [1 2 2.5 5 10 20 25 50 100]
    step = m * base
    l0 = if lock => lo else Math.floor(lo / step + 1e-9) * step
    if l0 + step * n >= hi - step * 1e-9 => return [clean(l0), clean(l0 + step * n)]
  [lo, hi]

# ---------------------------------------------------------------- path
# 兩段之間的 bezier 控制點 ( catmull-rom ). 控制點限制在外圈內, 曲線才不會凸出格線
ctrl = (p0, p1, p2, p3, R) ->
  fit = (p) ->
    r = Math.hypot p.x, p.y
    if R? and r > R => {x: p.x * R / r, y: p.y * R / r} else p
  c1 = fit {x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6}
  c2 = fit {x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6}
  "C#{c1.x},#{c1.y} #{c2.x},#{c2.y} #{p2.x},#{p2.y}"

# 封閉的路徑
closed-path = (list, curved, R) ->
  n = list.length
  if !n => return ''
  if !curved or n < 3 => return "M" + list.map(-> "#{it.x},#{it.y}").join("L") + "Z"
  segs = [ctrl(list[(i - 1 + n) % n], list[i], list[(i + 1) % n], list[(i + 2) % n], R) for i from 0 til n]
  "M#{list.0.x},#{list.0.y}" + segs.join('') + "Z"

# 開放的路徑 ( 缺值斷開時的一段 ). 回傳不含開頭 M 的部分, 填色時要接在圓心之後
open-path = (list, curved, R) ->
  n = list.length
  if !curved or n < 3 => return list.map(-> "#{it.x},#{it.y}").join("L")
  segs = [ctrl(list[(i - 1) >? 0], list[i], list[i + 1], list[(i + 2) <? (n - 1)], R) for i from 0 til n - 1]
  "#{list.0.x},#{list.0.y}" + segs.join('')

# 系列的形狀. list: 依軸順序的點 ( 缺值的 def 為 false )
geometry = (list, {missing, curved, R}) ->
  n = list.length
  if n == 1 =>
    if !list.0.def => return {area: '', stroke: ''}
    return {area: '', stroke: "M0,0L#{list.0.x},#{list.0.y}"}
  defs = list.filter (.def)
  if defs.length == n or missing != \gap =>
    d = closed-path defs, curved, R
    return {area: d, stroke: d}
  # 留空: 連續的幾段各自畫線, 填色只到圓心, 不去補出沒有資料的面積
  if !defs.length => return {area: '', stroke: ''}
  s = list.findIndex (-> !it.def)
  runs = []
  cur = []
  for i from 1 to n
    p = list[(s + i) % n]
    if p.def => cur.push p
    else if cur.length => runs.push cur; cur = []
  if cur.length => runs.push cur
  runs = runs.filter -> it.length > 1
  {
    area: runs.map(-> "M0,0L" + open-path(it, curved, R) + "Z").join('')
    stroke: runs.map(-> "M" + open-path(it, curved, R)).join('')
  }

# ---------------------------------------------------------------- 版面
# 軸標籤的對齊方式, 隨角度變化: 左右兩側往外長, 上下兩端置中
label-align = (a) ->
  s = Math.sin a
  # 上半部的字在錨點上方, 下半部在下方 ( 單位 em )
  dy = 0.35 - 0.55 * Math.cos(a)
  {
    anchor: if Math.abs(s) < 0.18 => \middle else if s > 0 => \start else \end
    fx: if Math.abs(s) < 0.18 => 0.5 else if s > 0 => 0 else 1
    dy
  }

# 半徑 R 時, 格線 + 標籤的外框 ( 相對圓心 )
bounds = (R, {items, pad, circle, axes}) ->
  [l, r, t, b] = if circle => [-R, R, -R, R] else [0, 0, 0, 0]
  if !circle => for a in axes
    p = pt a, R
    l = l <? p.x
    r = r >? p.x
    t = t <? p.y
    b = b >? p.y
  for it in items
    continue if !it.shown
    b0 = box-of it, R, pad
    l = l <? b0.l
    r = r >? b0.r
    t = t <? b0.t
    b = b >? b0.b
  {l, r, t, b}

box-of = (it, R, pad) ->
  p = pt it.ang, R + pad
  a = label-align it.ang
  x0 = p.x - it.w * a.fx
  base = p.y + a.dy * it.fs
  {l: x0, r: x0 + it.w, t: base - it.fs * 0.95, b: base + it.fs * 0.25}

# 找得下的最大半徑. 回傳半徑與讓圖置中的圓心
solve = (W, H, margin, o) ->
  [lo, hi] = [0, (Math.min(W, H) / 2) >? 1]
  for i from 0 til 32
    mid = (lo + hi) / 2
    b = bounds mid, o
    if b.r - b.l <= W - 2 * margin and b.b - b.t <= H - 2 * margin => lo = mid else hi = mid
  b = bounds lo, o
  {R: lo, cx: (W - b.r - b.l) / 2, cy: (H - b.b - b.t) / 2}

overlap = (a, b) -> a.l < b.r + 2 and b.l < a.r + 2 and a.t < b.b + 1 and b.t < a.b + 1

mod = ({context, t}) ->
  {chart, ldcolor} = context
  {format, anim: {join}} = chart.utils
  sample: ->
    # 一列一個軸, 一欄一個系列. 全部是純量, 表格裡直接編輯
    rows =
      * <[Power 82 64 71]>
      * <[Speed 74 88 60]>
      * <[Range 58 72 92]>
      * <[Comfort 90 55 68]>
      * <[Safety 77 81 73]>
      * <[Value 49 76 85]>
    keys = ["Model A", "Model B", "Model C"]
    raw: rows.map (r) -> {metric: r.0} <<< Object.fromEntries(keys.map (k, i) -> [k, +r[i + 1]])
    binding:
      name: {key: \metric}
      value: keys.map -> {key: it}
  config: do ->
    N = (s) -> t s
    # values: 選項. [value, 英文標籤], 標籤先翻譯 ( konfig 的 widget 拿不到圖表自己的 i18n )
    choice = (name, list, def) ->
      {type: \choice, name: N(name), default: def, values: list.map -> {value: it.0, name: N(it.1)}}
    number = (name, def, min, max, step) -> {type: \number, name: N(name), default: def, min, max, step}
    bool = (name, def) -> {type: \boolean, name: N(name), default: def}
    color = (def = \currentColor) -> {type: \color, name: N("Color"), default: def}
    fmt = (def) -> {type: \format, name: N("Number format"), default: def}
    c = chart.utils.config.from {preset: \default, legend: \legend, tip: \tip}
    # 雷達圖兩側要留給軸標籤, 圖例預設放下面
    c.legend.position.default = \bottom
    # 留空 = 依數值大小自動 ( 見 local.number-format ): 小於 1000 不用 SI 前綴, 0.5 才不會變 500m
    c.tip.format.default = ''
    c <<<
      grid:
        shape: choice "Shape", [<[polygon Polygon]>, <[circle Circle]>], \polygon
        levels: number "Levels", 4, 1, 20, 1
        color: color!
        opacity: number "Opacity", 0.18, 0, 1, 0.01
        stroke-width: number "Line width", 1, 0, 10, 0.5
        stripe: number "Stripe opacity", 0.03, 0, 1, 0.01
      axis:
        show: bool "Show", true
        color: color!
        opacity: number "Opacity", 0.18, 0, 1, 0.01
        stroke-width: number "Line width", 1, 0, 10, 0.5
      label:
        show: bool "Show", true
        size: number "Font size (em)", 0.8, 0.3, 4, 0.05
        color: color!
        format: fmt ''
        padding: number "Distance from grid (px)", 8, 0, 64, 1
        max-width: number "Max width (em)", 10, 2, 60, 0.5
      tick:
        show: bool "Show", true
        size: number "Font size (em)", 0.65, 0.3, 4, 0.05
        color: color!
        format: fmt ''
      orientation:
        start-angle: number "Start angle", 0, -360, 360, 1
        direction: choice "Direction", [<[cw Clockwise]>, <[ccw Counter-clockwise]>], \cw
      domain:
        min: choice "Minimum", [["zero", "From zero"], ["data", "From data minimum"], ["custom", "Custom"]], \zero
        min-value: number "Custom minimum", 0, -1e12, 1e12, 0.01
        max: choice "Maximum", [["auto", "Auto"], ["custom", "Custom"]], \auto
        max-value: number "Custom maximum", 100, -1e12, 1e12, 0.01
        nice: bool "Round to nice values", true
      series:
        fill-opacity: number "Fill opacity", 0.16, 0, 1, 0.01
        stroke-width: number "Line width", 2, 0, 20, 0.5
        curve: choice "Line", [<[linear Straight]>, <[curve Curve]>], \linear
        missing: choice "Missing values", [["gap", "Leave a gap"], ["skip", "Connect neighbors"], ["zero", "Treat as minimum"]], \gap
      dot:
        show: bool "Show", true
        size: number "Size", 3, 0.5, 30, 0.5
        fill:
          type: \color, name: N("Fill"), default: \auto, presets: <[auto]>
          i18n: en: {"auto": "Auto"}, "zh-TW": {"auto": "自動"}
      animation:
        enabled: bool "Enabled", true
        duration: number "Duration (ms)", 500, 0, 5000, 10
        # chart.anim 的 ease 表是駝峰的 key
        ease: choice "Easing", [["cubicInOut", "Ease in-out"], ["cubicOut", "Ease out"], ["linear", "Linear"]], \cubicInOut
    c
  dimension:
    name: {type: \NCO, name: "axis", priority: 1}
    value: {type: \R, name: "value", multiple: true, priority: 2}
  init: ->
    @g = view: @layout.get-group(\view)
    @g.root = mk-g @g.view
    <[stripe grid zero axis series tick label]>.map ~> @g[it] = mk-g @g.root
    @tint = tint = new chart.utils.tint!
    # 調色盤裡淺色 ( 淡黃之類 ) 的線在白底上看不見, 依亮度壓暗. 圖例色塊用同一個色, 對得起來
    @color = (key) ->
      l = ldcolor.hcl(tint.get key).l
      if l > 72 => tint.get(key, -((l - 66) / 18) <? 0) else tint.get(key)
    color-of = @color
    @tip = new chart.utils.tip {root: @root, range: ~> @layout.get-node(\view).getBoundingClientRect!}
    @legend = new chart.utils.legend do
      layout: @layout
      root: @root
      name: \legend
      shape: (d) -> @setAttribute \fill, color-of(d.key)
      direction: \horizontal
      cfg: selectable: true
    @legend.on \select, ~>
      if (@cfg.legend or {}).crossfilter => @local.legend-to-filter!
      @bind!; @resize!; @render!
    @_evthdr = {}
    @root.addEventListener \mousemove, @_evthdr.move = (evt) ~> @local.hover evt
    @root.addEventListener \mouseout, @_evthdr.out = ~> @local.unhover!
    @axes = []
    @series = []

  destroy: ->
    @root.removeEventListener \mousemove, @_evthdr.move
    @root.removeEventListener \mouseout, @_evthdr.out
    @tip.destroy!
    @legend.destroy!

  filter-dims: -> if (@cfg.legend or {}).crossfilter => [\value] else []
  filter: (filters, internal) ->
    if (@cfg.legend or {}).crossfilter =>
      vs = (((@binding.value or [])[0] or {}).filter or {}).value
      @legend.select (if vs? => vs else null)

  parse: ->
    has-name = !!(@binding.name and @binding.name.key?)
    binds = @binding.value or []
    seen = {}
    @binds = binds
      .map (b, i) -> {b, i}
      .filter ({b}) -> if seen[b.key] => false else seen[b.key] = true
    # 試算表尾端的空白列 ( 沒名字也沒有任何值 ) 不算一個軸
    rows = @data
      .map (d, i) -> {d, i}
      .filter ({d}) ->
        named = d.name? and "#{d.name}".trim! != ''
        named or d.value.some(-> finite it)
    used = {}
    @axes = rows.map ({d, i}, j) ->
      text = if has-name => (if d.name? => "#{d.name}".trim! else '') else "#{j + 1}"
      id = text or "row-#i"
      # 同名的列仍是各自的軸, key 要分開
      used[id] = (used[id] or 0) + 1
      key = if used[id] > 1 => "#{id}\u0000#{used[id]}" else id
      {key, text, d}

  bind: ->
    @local.sync-legend!
    @legend.data @binds.map ({b}) -> {key: b.key, text: b.name or b.key}
    {axes} = @
    @series = @binds
      .filter ({b}) ~> @legend.is-visible b.key
      .map ({b, i}) ->
        key: b.key
        name: b.name or b.key
        unit: b.unit or ''
        pts: axes.map (a) ->
          v = a.d.value[i]
          {axis: a, v, _raw: a.d._raw, _idx: a.d._idx, def: finite(v)}

  resize: ->
    @tip.toggle(if @cfg.{}tip.enabled? => @cfg.tip.enabled else true)
    @tint.set @cfg.palette
    @local.sync-legend!
    @legend.update!
    @layout.update false
    box = @layout.get-box \view
    @local.domain!
    {axes, cfg} = @
    n = axes.length
    o = cfg.orientation or {}
    dir = if o.direction == \ccw => -1 else 1
    start = (o.start-angle or 0) * Math.PI / 180
    axes.map (a, i) -> a.ang = start + dir * i * TAU / (n or 1)
    # 少於三軸圍不出多邊形
    @circle = cfg.grid.shape == \circle or n < 3
    @local.layout box.width, box.height
    @legend.render!

  render: ->
    {axes, cfg, R, circle, g} = @
    n = axes.length
    opt = @local.anim-opt!
    tween = (nd, attrs, o = opt) ~> @anim.tween nd, attrs, o
    set = (nd, attrs) -> for k, v of attrs => nd.setAttribute k, v
    leave = (nd) ~>
      nd.setAttribute \class, ''
      @anim.tween nd, {opacity: 0}, {} <<< opt <<< {remove: true}

    # 圓心
    if g.root._placed => tween g.root, {transform: "translate(#{@cx},#{@cy})"}
    else
      g.root.setAttribute \transform, "translate(#{@cx},#{@cy})"
      g.root._placed = true

    ring = (r) ->
      if circle => "M0,#{-r}A#r,#r,0,1,1,0,#{r}A#r,#r,0,1,1,0,#{-r}Z"
      else "M" + axes.map(-> p = pt(it.ang, r); "#{p.x},#{p.y}").join("L") + "Z"
    # 形狀不同的路徑數字對不起來, 直接換掉不補間
    sig = "#{if circle => \c else n}"
    morph = (nd, d, attrs = {}) ->
      if nd._sig != sig =>
        nd.setAttribute \d, d
        nd._sig = sig
        tween nd, attrs
      else tween nd, {d} <<< attrs

    # 格線
    levels = if n and R > 0 => [1 to @levels] else []
    grid = cfg.grid
    gj = join root: g.grid, tag: \path, cls: \grid, data: levels
    gj.exit.map leave
    gj.enter.map -> set it, {fill: \none, opacity: 0}
    gj.nodes.map (nd) ~>
      set nd, {stroke: grid.color or \currentColor, "stroke-width": grid.stroke-width ? 1}
      morph nd, ring(R * nd.__data__ / @levels), {opacity: grid.opacity ? 0.18}

    # 間隔底色: 每兩層塗一層
    bands = if grid.stripe => levels.filter((d) ~> (@levels - d) % 2 == 0) else []
    bj = join root: g.stripe, tag: \path, cls: \band, data: bands
    bj.exit.map leave
    bj.enter.map -> set it, {"fill-rule": \evenodd, stroke: \none, opacity: 0}
    bj.nodes.map (nd) ~>
      d = nd.__data__
      nd.setAttribute \fill, grid.color or \currentColor
      inner = if d > 1 => ring(R * (d - 1) / @levels) else ''
      morph nd, ring(R * d / @levels) + inner, {opacity: grid.stripe}

    # 值域跨過 0 時, 0 那圈畫重一點: 負值的半徑不再代表大小, 要看得出基準在哪
    [lo, hi] = @dom
    zeros = if n and R > 0 and lo < 0 and hi > 0 => [0] else []
    zj = join root: g.zero, tag: \path, cls: \zero, data: zeros
    zj.exit.map leave
    zj.enter.map -> set it, {fill: \none, opacity: 0}
    zj.nodes.map (nd) ~>
      set nd, {stroke: grid.color or \currentColor, "stroke-width": (grid.stroke-width ? 1) + 0.5}
      morph nd, ring(@r 0), {opacity: 0.45}

    # 軸線: 也用極座標補間, 軸數改變時才會跟著資料點一起轉
    ax = cfg.axis
    aj = join root: g.axis, tag: \line, cls: \axis, data: (if ax.show != false and R > 0 => axes else []), key: (.key)
    aj.exit.map leave
    aj.enter.map -> set it, {x1: 0, y1: 0, opacity: 0}
    aj.nodes.map (nd) ->
      d = nd.__data__
      set nd, {stroke: ax.color or \currentColor, "stroke-width": ax.stroke-width ? 1}
      p0 = nd._p or {a: d.ang, r: 0}
      at = (t) -> pt lerp-angle(p0.a, d.ang, t), p0.r + (R - p0.r) * t
      tween nd, do
        x2: (t) -> (nd._p = {a: lerp-angle(p0.a, d.ang, t), r: p0.r + (R - p0.r) * t}); at(t).x
        y2: (t) -> at(t).y
        opacity: ax.opacity ? 0.18

    # 系列
    @local.render-series tween, leave, set

    # 刻度
    tick = cfg.tick
    fmt = @local.number-format tick.format, 3
    units = Array.from(new Set(@series.map (.unit)))
    unit = if units.length == 1 => units.0 else ''
    u0 = if n => pt(axes.0.ang, 1) else {x: 0, y: -1}
    # 沿順時針切線方向偏移, 字才不會壓在第一軸上
    tan = {x: -u0.y, y: u0.x}
    anchor = if Math.abs(tan.x) < 0.3 => \middle else if tan.x > 0 => \start else \end
    tj = join root: g.tick, tag: \text, cls: \radar-tick, data: (if tick.show != false => @ticks else []), key: (.k)
    tj.exit.map leave
    pos = (d) ->
      p = pt axes.0.ang, d.r
      {x: p.x + tan.x * 4, y: p.y + tan.y * 8}
    tj.enter.map (nd) ->
      p = pos nd.__data__
      set nd, {x: p.x, y: p.y, opacity: 0}
    bg = @local.background!
    tj.nodes.map (nd) ->
      d = nd.__data__
      p = pos d
      nd.textContent = "#{fmt d.v}#{unit}"
      nd.style.fontSize = "#{tick.size or 0.65}em"
      set nd, do
        "text-anchor": anchor
        dy: ".35em"
        fill: tick.color or \currentColor
        stroke: bg
        "stroke-width": 3
      tween nd, {x: p.x, y: p.y, opacity: 0.7}

    # 軸標籤 ( 內容與大小在 resize 量好了 )
    pad = @label-pad
    Array.from(g.label.childNodes).map (nd) ->
      if nd.getAttribute(\class) != \radar-label => return
      d = nd.__data__
      a = label-align d.ang
      p = pt d.ang, R + pad
      if nd._fresh =>
        delete nd._fresh
        set nd, {x: p.x, y: p.y}
      nd.setAttribute \text-anchor, a.anchor
      nd.setAttribute \dy, "#{a.dy}em"
      nd.setAttribute \fill, cfg.label.color or \currentColor
      tween nd, {x: p.x, y: p.y, opacity: if d._shown => 0.9 else 0}

    @legend.render!

  # 這張圖自己的工具方法. `local` 是核心保留給圖表的位置, 建構時會綁到實例上
  local:
    # spec 留空時依值域大小決定. digits: 有效位數
    number-format: (spec, digits) ->
      if spec => return format.from spec
      big = Math.max(Math.abs(@dom.0), Math.abs(@dom.1)) >= 1000
      format.from ".#{digits}~#{if big => \s else \r}"

    anim-opt: ->
      c = @cfg.animation or {}
      {duration: (if c.enabled == false => 0 else (c.duration ? 500)), ease: c.ease or \cubicInOut}

    legend-to-filter: ->
      vs = @legend.selected!
      @filter {value: (if vs? => {type: \index, value: vs} else undefined)}, true

    # 只有一個系列時沒什麼好選的, 全選 / 全不選只會佔位置; 窄的時候圖例一律放下面
    sync-legend: ->
      c = @cfg.legend or {}
      rbox = @root.getBoundingClientRect!
      bottom = c.position == \bottom or rbox.width < 420
      @root.querySelector('.pdl-layout').classList.toggle \legend-bottom, bottom
      # 小到放不下圖例時圖優先
      @legend.config({} <<< c <<< {
        enabled: c.enabled != false and Math.min(rbox.width, rbox.height) >= 180
        position: (if bottom => \bottom else \right)
        selectable: c.selectable != false and ((@binds or []).length > 1)
      })

    # 值域. 預設從 0 起算, 半徑才等比於數值; 其它情況由使用者明確選擇
    domain: ->
      c = @cfg.domain or {}
      n = (@cfg.grid.levels or 4) >? 1
      @levels = n
      # dataframe 播放時用所有格的值域, 刻度才不會每格跳 ( 舊版 @plotdb/chart 沒有 frame )
      vals = if @frame and @frame.active! => @frame.all! else @data
      bi = @binds.map (.i)
      vs = []
      vals.map (d) -> bi.map (i) -> if finite(d.value[i]) => vs.push d.value[i]
      [dlo, dhi] = if vs.length => [Math.min.apply(Math, vs), Math.max.apply(Math, vs)] else [0, 1]
      custom-lo = c.min == \custom and finite(+(c.min-value or 0))
      custom-hi = c.max == \custom and finite(+c.max-value)
      lo = if custom-lo => +(c.min-value or 0)
      else if c.min == \data => dlo
      else (dlo <? 0)
      hi = if custom-hi => +c.max-value
      else if c.min == \data => dhi
      else (dhi >? 0)
      # 自訂值矛盾時退回資料的範圍, 不要畫出倒過來的圖
      if !(hi > lo) =>
        if custom-lo and custom-hi =>
          lo = (dlo <? 0)
          hi = (dhi >? 0)
          # 已經不是自訂值了, 照常取整
          custom-lo = custom-hi = false
        else if custom-hi => lo = ((hi <? 0) - (Math.abs(hi) or 1))
        else hi = lo + (Math.abs(lo) or 1)
      if !(hi > lo) => hi = lo + 1
      if c.nice != false and !custom-hi =>
        # 全是負值時外圈就是 0, 不要為了對齊刻度多出一圈正值
        if hi == 0 and lo < 0 and !custom-lo =>
          [a, b] = nice-domain 0, -lo, n, true
          [lo, hi] = [-b, 0]
        else
          lock = custom-lo or (c.min != \data and lo >= 0)
          [lo, hi] = nice-domain lo, hi, n, lock
      @dom = [lo, hi]

    layout: (W, H) ->
      {axes, cfg} = @
      n = axes.length
      lc = cfg.label
      nodes = @local.label-nodes!
      fs = if nodes.length => (parseFloat(window.getComputedStyle(nodes.0).fontSize) or 12) else 12
      dot = @local.dot-size 200
      margin = dot + ((cfg.series.stroke-width ? 2) / 2) + 2
      pad = lc.padding ? 8
      if lc.show == false or !n => pad = 0
      # ------ 標籤寬度
      est = (text) -> text.length * fs * 0.6
      measure = (nd, text, maxw) ->
        nd.textContent = text
        if !text => return {text, w: 0}
        w = nd.getComputedTextLength!
        if !w => w = est text
        if w <= maxw => return {text, w}
        k = text.length
        cut = (i) ->
          try
            nd.getSubStringLength 0, i
          catch e
            i * fs * 0.6
        while k > 1 and cut(k) + fs > maxw => k--
        out = text.slice(0, k).trim! + "…"
        nd.textContent = out
        {text: out, w: (nd.getComputedTextLength! or est out)}
      halfmin = Math.min(W, H) / 2
      rmin = halfmin * 0.62
      maxw = ((lc.max-width or 10) * fs) >? (fs * 2)
      items = axes.map (a) -> {ang: a.ang, fs, w: 0, shown: !!(lc.show != false)}
      arg = {items, pad, circle: @circle, axes: axes.map (.ang)}
      for pass from 0 til 8
        nodes.map (nd, i) ->
          m = measure nd, (nd.__data__.label or ''), maxw
          items[i].w = m.w
        res = solve W, H, margin, arg
        if res.R >= rmin or maxw <= fs * 3 => break
        maxw = maxw * 0.75 >? fs * 3
      # ------ 標籤互相打架就隔 k 個才顯示一個
      if lc.show != false and n =>
        for k from 1 to n
          idx = [i for i from 0 til n when i % k == 0]
          boxes = idx.map (i) -> box-of items[i], res.R, pad
          ok = true
          for j from 0 til boxes.length
            if boxes.length > 1 and overlap(boxes[j], boxes[(j + 1) % boxes.length]) => ok = false
          if ok => break
        items.map (it, i) -> it.shown = (i % k == 0)
        res = solve W, H, margin, arg
        # 真的太小就不放標籤了, 圖優先
        if res.R < halfmin * 0.35 =>
          items.map -> it.shown = false
          res = solve W, H, margin, arg
      nodes.map (nd, i) ->
        nd.__data__._shown = items[i].shown
      @R = res.R
      @cx = res.cx
      @cy = res.cy
      @label-pad = pad
      # ------ 比例尺與刻度
      [lo, hi] = @dom
      @r = (v) ~> (((v - lo) / (hi - lo)) >? 0 <? 1) * @R
      tfs = fs * ((cfg.tick.size or 0.65) / (lc.size or 0.8))
      stride = Math.ceil((tfs * 1.3) / ((@R / @levels) or 1)) >? 1
      @ticks = []
      # 半徑太小時刻度只會糊成一團
      if n and @R >= 40 => for k from 0 to @levels
        v = clean(lo + (hi - lo) * k / @levels)
        # 圓心的 0 不用標; 下界不是 0 的時候一定要標, 不然看不出被截斷
        if k == 0 and lo == 0 => continue
        if k and ((@levels - k) % stride) => continue
        @ticks.push {k, v, r: @R * k / @levels}

    label-nodes: ->
      {axes, cfg} = @
      fmt = if cfg.label.format => format.from(cfg.label.format) else null
      j = join root: @g.label, tag: \text, cls: \radar-label, data: axes, key: (.key)
      j.exit.map (nd) ~>
        nd.setAttribute \class, ''
        @anim.tween nd, {opacity: 0}, {} <<< @local.anim-opt! <<< {remove: true}
      j.enter.map (nd) ->
        nd.setAttribute \opacity, 0
        nd._fresh = true
      j.nodes.map (nd) ->
        d = nd.__data__
        d.label = if fmt and d.text != '' and !isNaN(+d.text) => fmt(+d.text) else d.text
        nd.style.fontSize = "#{cfg.label.size or 0.8}em"
      j.nodes

    # 軸很多時點不要比軸距還大
    dot-size: (R) ->
      n = @axes.length or 1
      s = @cfg.dot.size or 3
      if n < 3 => return s <? ((R * 0.05) >? 1)
      s <? ((R * Math.min(Math.sin(Math.PI / n) * 0.45, 0.05)) >? 1)

    # 字的外框要蓋住底下的東西, 需要實際的背景色. 背景透明就往外層找
    background: ->
      c = @cfg.background
      if c and c != \transparent => return c
      n = @root
      while n and n.nodeType == 1
        bg = window.getComputedStyle(n).backgroundColor
        m = /rgba?\(([^)]+)\)/.exec(bg or '')
        if m =>
          v = m.1.split(',').map -> parseFloat it
          if !(v.3 == 0) => return bg
        n = n.parentNode
      \#fff

    render-series: (tween, leave, set) ->
      {g, cfg, R} = @
      missing = cfg.series.missing or \gap
      curved = cfg.series.curve == \curve
      dot-cfg = cfg.dot
      size = @local.dot-size R
      opacity-of = (s) ~> if @legend.is-selected(s.key) => 1 else @legend.opacity!
      self = @
      # 有效的點留給 hover
      @hit = []
      j = join root: g.series, tag: \g, cls: \series, data: @series, key: (.key)
      j.exit.map leave
      j.enter.map (nd) ->
        nd.setAttribute \opacity, 0
        nd._area = nd.appendChild document.createElementNS(svgns, \path)
        nd._line = nd.appendChild document.createElementNS(svgns, \path)
        nd._dots = nd.appendChild document.createElementNS(svgns, \g)
        nd._area.setAttribute \stroke, \none
        nd._line.setAttribute \fill, \none
        nd._line.setAttribute \stroke-linejoin, \round
        nd._line.setAttribute \stroke-linecap, \round
      j.nodes.map (nd) ->
        s = nd.__data__
        color = self.color s.key
        # 目標: 依軸順序的極座標; 起點: 上一次畫到的位置, 新的軸從圓心長出來
        cur = nd._cur or {}
        goal = s.pts.map (p) ->
          def = p.def or missing == \zero
          r = if p.def => self.r(p.v) else 0
          {key: p.axis.key, a: p.axis.ang, r, def}
        orig = goal.map (p) -> cur[p.key] or {a: p.a, r: 0}
        at = (i, t) ->
          [f, o] = [orig[i], goal[i]]
          a = lerp-angle f.a, o.a, t
          r = f.r + (o.r - f.r) * t
          pt(a, r) <<< {a, r, def: o.def}
        memo = {t: -1}
        geom = (t) ->
          if memo.t == t => return memo.g
          list = goal.map (o, i) -> at i, t
          nd._cur = Object.fromEntries goal.map (o, i) -> [o.key, {a: list[i].a, r: list[i].r}]
          memo <<< {t, g: geometry(list, {missing, curved, R})}
          memo.g
        set nd._area, {fill: color, "fill-opacity": cfg.series.fill-opacity ? 0.16}
        set nd._line, {stroke: color, "stroke-width": cfg.series.stroke-width ? 2}
        tween nd._area, {d: (t) -> geom(t).area}
        tween nd._line, {d: (t) -> geom(t).stroke}
        tween nd, {opacity: opacity-of(s)}
        # 資料點: 缺值的不畫
        data = if dot-cfg.show == false => [] else s.pts.filter (p, i) -> goal[i].def and p.def
        dj = join root: nd._dots, tag: \circle, cls: \data, data: data, key: (.axis.key)
        dj.exit.map (n) -> n.parentNode.removeChild n
        dj.enter.map -> set it, {cx: 0, cy: 0, r: 0}
        # konfig 的 color widget 會把預設值 `auto` 轉成 `transparent`, 兩者都算自動
        fill = if !dot-cfg.fill or dot-cfg.fill in <[auto transparent]> => color else dot-cfg.fill
        dj.nodes.map (n) ->
          p = n.__data__
          i = s.pts.indexOf p
          set n, {fill, stroke: color, "stroke-width": 1}
          tween n, do
            cx: (t) -> at(i, t).x
            cy: (t) -> at(i, t).y
            r: size
        if self.legend.is-selected s.key =>
          s.pts.map (p, i) -> if p.def and goal[i].def => self.hit.push {s, p, node: nd, pos: pt(goal[i].a, goal[i].r)}

    hover: (evt) ->
      if !@hit or !@hit.length => return
      box = @layout.get-node(\view).getBoundingClientRect!
      x = evt.clientX - box.x - @cx
      y = evt.clientY - box.y - @cy
      best = null
      for h in @hit
        d = (h.pos.x - x) ** 2 + (h.pos.y - y) ** 2
        if !best or d < best.d => best = {d, h}
      if !best or best.d > (30 >? @R * 0.3) ** 2 => return @local.unhover!
      h = best.h
      Array.from(@g.series.childNodes).map (n) -> n.classList.toggle \hl, n == h.node
      @g.series.classList.add \radar-hover
      fmt = @local.number-format (@cfg.tip or {}).format, 4
      @tip.render do
        data:
          group: h.s.name
          name: h.p.axis.text
          value: "#{fmt h.p.v}#{h.s.unit}"
        evt: evt
        box: {x: box.x - @root.getBoundingClientRect!x + @cx + h.pos.x, y: box.y - @root.getBoundingClientRect!y + @cy + h.pos.y}

    unhover: ->
      @g.series.classList.remove \radar-hover
      @tip.hide!now!
