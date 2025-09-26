(function(){
  var mod;
  module.exports = {
    pkg: {
      name: 'radar',
      version: '0.0.1',
      extend: {
        name: "base",
        version: "0.0.1"
      },
      dependencies: []
    },
    init: function(arg$){
      var root, context, pubsub;
      root = arg$.root, context = arg$.context, pubsub = arg$.pubsub;
      return pubsub.fire('init', {
        mod: mod({
          context: context
        })
      }).then(function(it){
        return it[0];
      });
    }
  };
  mod = function(arg$){
    var context, d3, forceBoundary, ldColor, repeatString$;
    context = arg$.context;
    d3 = context.d3, forceBoundary = context.forceBoundary, ldColor = context.ldColor, repeatString$ = context.repeatString$;
    return {
      sample: function(){
        return {
          raw: [0, 1, 2, 3, 4].map(function(idx){
            return {
              val: [0, 1, 2].map(function(){
                return 0.5 + 0.5 * Math.random();
              }),
              cat: idx
            };
          }),
          binding: {
            radius: {
              key: 'val'
            },
            order: {
              key: 'cat'
            }
          }
        };
      },
      config: {},
      dimension: {
        radius: {
          type: 'R',
          name: "radius of point on radar line"
        },
        order: {
          type: 'R',
          name: "order of data point"
        }
      },
      init: function(){
        var svg, gs, this$ = this;
        svg = d3.select(this.svg);
        this.gs = gs = {};
        gs.all = svg.append('g');
        return this.line = d3.line().x(function(d, i){
          return this$.scale.r(d) * Math.cos(this$.scale.a(this$.orders[i]));
        }).y(function(d, i){
          return this$.scale.r(d) * -Math.sin(this$.scale.a(this$.orders[i]));
        });
      },
      parse: function(){
        this.orders = Array.from(new Set(this.data.map(function(it){
          return it.order;
        })));
        this.parsed = d3.transpose(this.data.map(function(it){
          return it.radius;
        }));
        this.parsed.map(function(d, i){
          return d.idx = i;
        });
        this.names = ['1', '2', '3'];
        this.radiusRange = d3.extent(this.parsed.map(function(d){
          return d3.extent(d);
        }).reduce(function(a, b){
          return a.concat(b);
        }, []));
        if (this.radiusRange[0] === this.radiusRange[1]) {
          return this.radiusRange[1]++;
        }
      },
      bind: function(){
        var x$, y$;
        x$ = this.gs.all.selectAll('path.data').data(this.parsed);
        x$.exit().attr('class', "").transition('exit').duration(500).attr('opacity', 0).remove();
        x$.enter().append('path').attr('class', 'data').attr('opacity', 0);
        y$ = this.gs.all.selectAll('g.data-group').data(this.parsed);
        y$.exit().attr('class', "").transition('exit').duration(500).attr('opacity', 0).remove();
        y$.enter().append('g').attr('class', 'data-group').attr('opacity', 0);
        return this.gs.all.selectAll('g.data-group').each(function(d, i){
          var x$;
          x$ = d3.select(this).selectAll('circle.node').data(d);
          x$.exit().attr('class', '').transition('exit').duration(500).attr('opacity', 0).remove();
          x$.enter().append('circle').attr('class', 'node').attr('opacity', 0);
          return x$;
        });
      },
      resize: function(){
        var size, ref$;
        size = (ref$ = Math.min(this.box.width, this.box.height) / 2) > 10 ? ref$ : 10;
        this.scale = {
          r: d3.scaleLinear().domain([0, this.radiusRange[1]]).range([0, size]),
          a: d3.scalePoint().domain(this.orders).range([0, 2 * Math.PI]),
          c: d3.interpolateTurbo
        };
        if (this.cfg != null && this.cfg.palette) {
          this.scale.c = d3.interpolateDiscrete(this.cfg.palette.colors.map(function(it){
            return ldColor.web(it.value || it);
          }));
        }
        return this.aTicks = d3.range(this.data.length);
      },
      render: function(){
        var scale, names, line, orders;
        scale = this.scale, names = this.names, line = this.line, orders = this.orders, orders = this.orders;
        this.gs.all.attr('transform', "translate(" + this.box.width / 2 + "," + this.box.height / 2 + ")");
        this.gs.all.selectAll('path.data').each(function(d, i){
          var color;
          color = scale.c(i / (names.length - 1));
          return d3.select(this).attr('fill', color).attr('fill-opacity', 0.2).attr('stroke', color).attr('stroke-width', 1).transition('morph').duration(350).attr('d', function(d, i){
            return line(d, i) + "Z";
          });
        }).transition('opacity').duration(350).attr('opacity', 1);
        return this.gs.all.selectAll('g.data-group').each(function(d, i){
          var color;
          color = scale.c(i / (names.length - 1));
          return d3.select(this).selectAll('circle.node').attr('fill', '#fff').attr('stroke', color).attr('stroke-width', 1).transition('morph').duration(350).attr('cx', function(d, i){
            return scale.r(d) * Math.cos(scale.a(orders[i]));
          }).attr('cy', function(d, i){
            return scale.r(d) * -Math.sin(scale.a(orders[i]));
          }).attr('r', 3).attr('opacity', 1);
        }).transition('opacity').duration(350).attr('opacity', 1);
      }
    };
  };
}).call(this);
