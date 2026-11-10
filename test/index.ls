# radar 的 test case ( @makechart/viewer 的 mctest )
# 資料一律是平坦的表格: 一列一個軸, 一欄一個系列. 每份資料用自己的種子, 跟產生順序無關
AXIS = <[Power Speed Range Comfort Safety Value Noise Weight Style Grip Cost Tech]>
mk = (axes, lines = 3, seed = axes) ->
  rnd = mctest.random seed
  raw: [0 til axes].map (i) ->
    ret = {axis: (AXIS[i] or "Axis #{i + 1}")}
    for j from 1 to lines => ret["s#j"] = Math.round(20 + 80 * rnd!)
    ret
  binding:
    name: {key: \axis}
    value: [1 to lines].map -> {key: "s#it", name: "Series #it"}

# 改幾格
patch = (d, f) -> f(d.raw); d

mctest.suite do
  size: [480, 400]
  data:
    five: mk 5
    six: mk 6, 3, 11
    eight: mk 8, 3, 2
    many: mk 24, 2, 5
    series: mk 6, 8, 7
    one: mk 6, 1, 3
    two-axes: mk 2, 2, 4
    one-axis: mk 1, 2, 4
    empty: {raw: [], binding: mk(1).binding}
    nobind: {raw: mk(5).raw, binding: {}}
    noname: {raw: mk(5).raw, binding: {value: mk(5).binding.value}}
    # 舊版的資料: 儲存格是陣列. 不支援了, 但不能丟錯
    legacy:
      raw: [0 til 5].map -> {val: [1, 2, 3], cat: it}
      binding: {order: {key: \cat}, radius: {key: \val}}
    gaps: patch mk(7, 2, 8), (r) ->
      r.1.s1 = ''
      r.2.s1 = null
      r.5.s2 = 'n/a'
    # 試算表尾端的空白列不算軸, 同名的列仍是各自的軸, 重複綁定的欄位只算一次
    messy: do ->
      d = mk 4, 2, 6
      d.raw.1.axis = d.raw.0.axis
      d.raw.push {axis: '', s1: '', s2: ''}, {axis: null, s1: null, s2: null}
      d.binding.value.push {key: \s1, name: "dup"}
      d
    neg: patch mk(6, 2, 9), (r) ->
      r.1.s1 = -40
      r.4.s2 = -15
    zeros: patch mk(5, 2, 1), (r) -> r.map (d) -> d.s1 = d.s2 = 0
    allneg: patch mk(5, 1, 1), (r) -> r.map (d, i) -> d.s1 = -10 - i * 5
    long:
      raw: mk(6, 2, 12).raw.map (d, i) -> d <<< {axis: "A rather long axis name number #{i + 1} for wrapping"}
      binding: mk(6, 2, 12).binding
    unit: patch mk(5, 2, 3), ->
  cases:
    * name: "sample", data: \six, steps: (c) -> d = c.mod.sample!; c.set-raw d.raw, d.binding
    * name: "default", data: \six
    * name: "five", data: \five
    * name: "eight", data: \eight
    * name: "many-axes", data: \many
    * name: "many-series", data: \series
    * name: "one-series", data: \one
    * name: "two-axes", data: \twoAxes
    * name: "one-axis", data: \oneAxis
    * name: "empty", data: \empty
    * name: "no-binding", data: \nobind
    * name: "no-name-binding", data: \noname
    * name: "legacy-binding", data: \legacy
    * name: "missing-gap", data: \gaps
    * name: "missing-skip", data: \gaps, config: {series: {missing: \skip}}
    * name: "missing-zero", data: \gaps, config: {series: {missing: \zero}}
    * name: "messy-rows", data: \messy
    * name: "negative", data: \neg
    * name: "all-zero", data: \zeros
    * name: "all-negative", data: \allneg
    * name: "long-labels", data: \long
    * name: "domain-custom", data: \six, config: {domain: {min: \custom, min-value: 20, max: \custom, max-value: 120}}
    * name: "domain-clamp", data: \six, config: {domain: {max: \custom, max-value: 50}}
    * name: "domain-invalid", data: \six, config: {domain: {min: \custom, min-value: 200, max: \custom, max-value: 100}}
    * name: "domain-data", data: \six, config: {domain: {min: \data}}
    * name: "domain-no-nice", data: \six, config: {domain: {nice: false}}
    * name: "grid-circle", data: \six, config: {grid: {shape: \circle, levels: 6}}
    * name: "grid-style", data: \six, config: {grid: {color: \#09f, opacity: 0.5, stroke-width: 2, stripe: 0}, axis: {show: false}}
    * name: "curve", data: \six, config: {series: {curve: \curve, fill-opacity: 0.3, stroke-width: 3}}
    * name: "curve-gap", data: \gaps, config: {series: {curve: \curve}}
    * name: "start-ccw", data: \five, config: {orientation: {start-angle: 90, direction: \ccw}}
    * name: "no-labels", data: \six, config: {label: {show: false}, tick: {show: false}}
    * name: "label-style", data: \six, config: {label: {size: 1.1, color: \#c00, padding: 16}, tick: {format: \.0f, size: 0.8, color: \#090}}
    * name: "dots-off", data: \six, config: {dot: {show: false}}
    * name: "dots-big", data: \six, config: {dot: {size: 6, fill: \#fff}}
    * name: "palette", data: \five, config: {palette: {colors: <[#f00 #0a0 #00f]>}}
    * name: "legend-right", data: \six, config: {legend: {position: \right}}
    * name: "legend-off", data: \six, config: {legend: {enabled: false}}
    * name: "legend-toggle", data: \six
      steps: (c) ->
        c.legend.select [\s1 \s3]
        c.bind!; c.resize!; c.render!
    * name: "legend-dim", data: \six, config: {legend: {subset: {mode: \dim}}}
      steps: (c) ->
        c.legend.select [\s2]
        c.bind!; c.resize!; c.render!
    * name: "update-axes", data: \five, steps: (c) -> d = mk 8, 3, 9; c.set-raw d.raw, d.binding
    * name: "update-fewer-axes", data: \eight, steps: (c) -> d = mk 3, 3, 9; c.set-raw d.raw, d.binding
    * name: "update-series", data: \five, steps: (c) -> d = mk 5, 1, 4; c.set-raw d.raw, d.binding
    * name: "update-to-empty", data: \five, steps: (c) -> c.set-raw [], mk(1).binding
    * name: "update-from-empty", data: \empty, steps: (c) -> d = mk 6; c.set-raw d.raw, d.binding
    * name: "hover-tip", data: \six
      steps: (c) ->
        h = c.hit.0
        box = c.layout.get-node(\view).getBoundingClientRect!
        c.root.dispatchEvent new MouseEvent \mousemove, do
          bubbles: true, clientX: box.x + c.cx + h.pos.x, clientY: box.y + c.cy + h.pos.y
    * name: "config-change", data: \six
      steps: (c) ->
        c.config {grid: {shape: \circle, levels: 3}}
        c.parse!; c.bind!; c.resize!; c.render!

# 小尺寸不能爆版
mctest.suite do
  size: [300, 300]
  data:
    six: mk 6, 3, 11
    many: mk 24, 2, 5
    series: mk 6, 8, 7
    one: mk 6, 1, 3
    long:
      raw: mk(6, 2, 12).raw.map (d, i) -> d <<< {axis: "A rather long axis name number #{i + 1} for wrapping"}
      binding: mk(6, 2, 12).binding
  cases:
    * name: "small", data: \six
    * name: "small-many-axes", data: \many
    * name: "small-many-series", data: \series
    * name: "small-one-series", data: \one
    * name: "small-long-labels", data: \long
    * name: "small-legend-right", data: \six, config: {legend: {position: \right}}

mctest.suite do
  size: [120, 120]
  data: six: mk 6, 3, 11
  cases: [{name: "tiny", data: \six}]

mctest.suite do
  size: [800, 240]
  data: six: mk 6, 3, 11
  cases:
    * name: "wide", data: \six
    * name: "wide-legend-right", data: \six, config: {legend: {position: \right}}

# 動畫逐格: 形狀變化的中間格
mctest.suite do
  size: [400, 400]
  data: five: mk 5
  cases:
    * name: "anim:update-frames", data: \five
      steps: (c, ctx) ->
        d = mk 5, 3, 9
        c.set-raw d.raw, d.binding
        for i from 1 to 4
          c.anim.step 125
          ctx.capture "t#{i * 125}"
    * name: "anim:axes-change-frames", data: \five
      steps: (c, ctx) ->
        d = mk 7, 3, 9
        c.set-raw d.raw, d.binding
        for i from 1 to 2
          c.anim.step 200
          ctx.capture "t#{i * 200}"
    * name: "anim:ease-linear", data: \five, config: {animation: {ease: \linear, duration: 200}}
      steps: (c, ctx) ->
        d = mk 5, 3, 9
        c.set-raw d.raw, d.binding
        c.anim.step 100
        ctx.capture \t100
    * name: "anim:disabled", data: \five, config: {animation: {enabled: false}}
      steps: (c, ctx) ->
        d = mk 5, 3, 9
        c.set-raw d.raw, d.binding
        ctx.capture \t0
