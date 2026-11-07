# radar 的 test case ( @makechart/viewer 的 mctest )
# 每份資料用自己的種子, 跟產生的先後順序無關. 同 sample: radius 的值本身是陣列, 每列一個軸, 陣列的每一項一條線
mk = (axes, lines = 3, seed = axes) ->
  rnd = mctest.random seed
  raw: [0 til axes].map (i) -> {cat: i, val: [0 til lines].map -> Math.round((0.5 + 0.5 * rnd!) * 100) / 100}
  binding: {order: {key: \cat}, radius: {key: \val}}

mctest.suite do
  size: [400, 400]
  data:
    five: mk 5
    eight: mk 8, 3, 2
    twolines: mk 6, 2
    one: mk 5, 1, 3
  cases:
    * name: "five", data: \five
    * name: "eight", data: \eight
    * name: "two-lines", data: \twolines
    * name: "one-line", data: \one
    * name: "palette", data: \five, config: {palette: {colors: <[#f00 #0a0 #00f]>}}
    * name: "update", data: \five, steps: (c) -> d = mk 7, 3, 9; c.set-raw d.raw, d.binding
    * name: "fewer-lines", data: \five, steps: (c) -> d = mk 5, 2, 4; c.set-raw d.raw, d.binding

# lite 版才有: 形狀變化的中間格
mctest.suite do
  size: [400, 400]
  data: five: mk 5
  cases:
    * name: "anim:update-frames", data: \five
      steps: (c, ctx) ->
        d = mk 5, 3, 9
        c.set-raw d.raw, d.binding
        for i from 1 to 4
          c.anim.step 100
          ctx.capture "t#{i * 100}"
