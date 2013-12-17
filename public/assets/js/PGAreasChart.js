// Generated by CoffeeScript 1.6.3
(function() {
  var _ref,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  window.PGAreasChart = (function(_super) {
    __extends(PGAreasChart, _super);

    function PGAreasChart() {
      _ref = PGAreasChart.__super__.constructor.apply(this, arguments);
      return _ref;
    }

    PGAreasChart.prototype.areas = null;

    PGAreasChart.prototype.createModeButtons = function() {
      var _this = this;
      PGAreasChart.__super__.createModeButtons.apply(this, arguments);
      return $('button.mode').click(function() {
        return _this.renderAreas();
      });
    };

    PGAreasChart.prototype.createAreas = function() {
      return this.areas = this.chart.append('g').attr("id", "areas").attr('clip-path', 'url(#chart-area)');
    };

    PGAreasChart.prototype.initChart = function() {
      PGAreasChart.__super__.initChart.apply(this, arguments);
      this.createAreas();
      return this.renderAreas();
    };

    PGAreasChart.prototype.renderAreas = function() {
      var area, areas,
        _this = this;
      area = d3.svg.area().interpolate(this.mode).x(function(d) {
        return _this.scale.x(d[0]);
      }).y0(function(d) {
        return _this.scale.y(0);
      }).y1(function(d) {
        return _this.scale.y(d[1]);
      });
      areas = this.areas.selectAll('path.area').data([this.currDataset]);
      areas.enter().append('path').attr('class', 'area');
      areas.exit().remove();
      return areas.transition().duration(1000).attr("d", function(d) {
        return area(d);
      });
    };

    PGAreasChart.prototype.updateChart = function(dataset, axes) {
      PGAreasChart.__super__.updateChart.call(this, dataset, axes);
      return this.renderAreas();
    };

    return PGAreasChart;

  })(PGLinesChart);

}).call(this);
