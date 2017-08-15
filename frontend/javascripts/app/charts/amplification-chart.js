(function() {

  // "use strict";

  function AmplificationChart(elem, data, config) {

    // Global vars
    var Globals = null;
    var bisectX = function(line_config) {
      return d3.bisector(function(d) {
        return d[line_config.x];
      }).left;
    };
    var prevClosestLineIndex;
    var prevMousePosition;

    function initGlobalVars() {
      Globals = {
        width: 0,
        height: 0,
        data: null,
        config: null,
        chartSVG: null,
        viewSVG: null,
        box: null,
        gX: null,
        gY: null,
        xAxis: null,
        yAxis: null,
        mouseOverlay: null,
        activePath: null,
        activePathConfig: null,
        lines: null,
        circle: null,
        whiteBorderLine: null,
        xScale: null,
        yScale: null,
        zooomBehavior: null,
        zoomTransform: {
          k: 1,
          x: 0,
          y: 0
        },
        lastXScale: null,
        onZoomAndPan: null,
        normalPathStrokeWidth: 2,
        hoveredPathStrokeWidth: 3,
        activePathStrokeWidth: 5,
        dashedLineStrokeWidth: 2,
        circleStrokeWidth: 2,
        circleRadius: 7
      };
    }

    initGlobalVars();

    var superscript = "⁰¹²³⁴⁵⁶⁷⁸⁹",
      formatPower = function(d) {
        return (d + "").split("").map(function(c) {
          return superscript[c];
        }).join("");
      };
    // end global vars

    function d3Mouse(node) {
      var mouse;
      try {
        mouse = d3.mouse(node);
      } catch (e) {
        if (Globals.activePathConfig && Globals.circle) {
          Globals.circle.attr('transform', 'translate(0,0) scale(1)');
          mouse = [Globals.circle.attr('cx'), Globals.circle.attr('cy')];
        } else {
          mouse = [0, 0];
        }
      }
      return mouse;
    }

    function hideMouseIndicators() {
      if (Globals.circle) {
        Globals.circle.attr('opacity', 0);
      }
    }

    function showMouseIndicators() {
      if (Globals.circle && Globals.activePath) {
        Globals.circle.attr('opacity', 1);
      }
    }

    function getPathConfig(path) {
      var activePathConfig, activePathIndex;
      for (var i = Globals.lines.length - 1; i >= 0; i--) {
        var l = Globals.lines[i];
        if (l === path) {
          activePathConfig = Globals.config.series[i];
          activePathIndex = i;
          break;
        }
      }
      return {
        config: activePathConfig,
        index: activePathIndex,
      };
    }

    function setActivePath(path, mouse) {
      if (Globals.activePath) {
        Globals.activePath.attr('stroke-width', Globals.normalPathStrokeWidth);
      }
      Globals.activePathConfig = getPathConfig(path);
      var activePathConfig = Globals.activePathConfig.config;
      var activePathIndex = Globals.activePathConfig.index;
      var xScale = Globals.zoomTransform.k > 1 ? Globals.lastXScale : Globals.xScale;
      makeWhiteBorderLine(xScale, activePathConfig);
      var newLine = makeColoredLine(xScale, activePathConfig).attr('stroke-width', Globals.activePathStrokeWidth);
      Globals.lines[activePathIndex] = newLine;
      Globals.activePath = newLine;
      makeCircle();
      path.remove();

      drawBox(Globals.activePathConfig.config);

      if (mouse) {
        showMouseIndicators();
        setBoxRFYAndCycleTexts(mouse[0]);
        mouseMoveCb();
      } else {
        hideMouseIndicators();
      }

      if (Globals.onSelectLine) {
        Globals.onSelectLine(Globals.activePathConfig);
      }
      prevMousePosition = mouse;

    }

    function unsetActivePath() {
      if (!Globals.activePath) {
        return;
      }
      hideMouseIndicators();
      Globals.activePath.attr('stroke-width', Globals.normalPathStrokeWidth);
      Globals.whiteBorderLine.remove();
      Globals.activePathConfig = null;
      Globals.activePath = null;
      if (Globals.box) {
        Globals.box.container.remove();
      }
      if (Globals.onUnselectLine) {
        Globals.onUnselectLine();
      }
    }

    function drawBox(line_config) {

      if (Globals.box) {
        Globals.box.container.remove();
      }

      var headerHeight = 25;
      var headerTextSize = 15;
      var valuesTextSize = 12;
      var boxWidth = 130;
      var bodyHeight = 70;
      var boxBorderWidth = 1;
      var boxMargin = {
        top: 0,
        left: 10
      };

      Globals.box = {};

      Globals.box.container = Globals.chartSVG.append('g')
        .attr('stroke-width', 0)
        .attr('transform', 'translate(' + (boxMargin.left + Globals.config.margin.left) + ',' + (boxMargin.top + Globals.config.margin.top) + ')')
        .attr('fill', '#fff')
        .on('mousemove', mouseMoveCb);

      Globals.box.container.append('rect')
        .attr('fill', "#ccc")
        .attr('width', boxWidth + boxBorderWidth * 2)
        .attr('height', bodyHeight + headerHeight + boxBorderWidth * 2);

      Globals.box.header = Globals.box.container.append('rect')
        .attr('x', boxBorderWidth)
        .attr('y', boxBorderWidth)
        .attr('fill', line_config.color)
        .attr('width', boxWidth)
        .attr('height', headerHeight);

      Globals.box.headerText = Globals.box.container.append('text')
        .attr('x', function() {
          return (boxWidth + boxBorderWidth * 2) / 2;
        })
        .attr("text-anchor", "middle")
        .attr("alignment-baseline", "middle")
        .attr("font-size", headerTextSize + 'px')
        .attr("fill", "#fff")
        .attr("stroke-width", 0)
        .text(function() {
          var wells = ['A1', 'A2', 'A3', 'A4', 'A5', 'A6', 'A7', 'A8', 'B1', 'B2', 'B3', 'B4', 'B5', 'B6', 'B7', 'B8'];
          return wells[line_config.well] + ', ' + (line_config.dataset === 'channel_1' ? 'Ch1' : 'Ch2');
        })
        .attr('font-weight', 700)
        .attr('class', 'header-text');

      Globals.box.headerText.attr('y', function() {
        var textDims = Globals.box.headerText.node().getBBox();
        return (headerHeight / 2 + (headerHeight - textDims.height) / 2) + boxBorderWidth;
      });

      Globals.box.body = Globals.box.container.append('rect')
        .attr('x', boxBorderWidth)
        .attr('y', headerHeight + boxBorderWidth)
        .attr('fill', '#fff')
        .attr('width', boxWidth)
        .attr('height', bodyHeight);

      Globals.box.CqText = Globals.box.container.append('text')
        .attr("font-size", headerTextSize + 'px')
        .attr('fill', "#000")
        .attr("font-weight", 700)
        .attr('x', 10 + boxBorderWidth)
        .attr('y', headerHeight + 20 + boxBorderWidth)
        .text('Cq');

      var ctTextDims = Globals.box.CqText.node().getBBox();

      Globals.box.RFYTextLabel = Globals.box.container.append('text')
        .attr("font-weight", 700)
        .attr("font-size", valuesTextSize + 'px')
        .attr('fill', "#000")
        .attr('x', 10 + boxBorderWidth)
        .attr('y', headerHeight + ctTextDims.height + 20 + boxBorderWidth)
        .text('RFU');

      var rfyLabelDims = Globals.box.RFYTextLabel.node().getBBox();

      Globals.box.RFYTextValue = Globals.box.container.append('text')
        .attr("font-size", valuesTextSize + 'px')
        .attr('fill', "#000")
        .attr('x', 10 + boxBorderWidth)
        .attr('y', headerHeight + ctTextDims.height + rfyLabelDims.height + 20 + boxBorderWidth);

      Globals.box.cycleTextLabel = Globals.box.container.append('text')
        .attr("font-weight", 700)
        .attr("font-size", valuesTextSize + 'px')
        .attr('fill', "#000")
        .attr('x', 70 + boxBorderWidth)
        .attr('y', headerHeight + ctTextDims.height + 20 + boxBorderWidth)
        .text('Cycle');

      var cycleLabelDims = Globals.box.cycleTextLabel.node().getBBox();

      Globals.box.cycleTextValue = Globals.box.container.append('text')
        .attr("font-size", valuesTextSize + 'px')
        .attr('fill', "#000")
        .attr('x', 70 + boxBorderWidth)
        .attr('y', headerHeight + cycleLabelDims.height + ctTextDims.height + 20 + boxBorderWidth);
    }

    function setBoxRFYAndCycleTexts(x) {
      // get data point at point x
      var line_config = Globals.activePathConfig.config;
      var x0 = Globals.zoomTransform.k > 1 ? Globals.zoomTransform.rescaleX(Globals.xScale).invert(x) : Globals.xScale.invert(x);
      var i = bisectX(line_config)(Globals.data[line_config.dataset], x0, 1);
      var d0 = Globals.data[line_config.dataset][i - 1];
      if (!d0) {
        return;
      }

      var d1 = Globals.data[line_config.dataset][i];
      if (!d1) {
        return;
      }

      var d = x0 - d0[line_config.x] > d1[line_config.x] - x0 ? d1 : d0;

      if (Globals.box && Globals.activePath) {
        var conf = Globals.activePathConfig;
        if (Globals.box.RFYTextValue) {
          Globals.box.RFYTextValue.text(d[Globals.config.series[conf.index].y]);
        }
        if (Globals.box.cycleTextValue) {
          Globals.box.cycleTextValue.text(d[Globals.config.series[conf.index].x]);
        }
        if (Globals.box.CqText && Globals.activePathConfig.config.cq) {
          conf = Globals.activePathConfig.config;
          var cqText = 'Cq: ' + (conf.cq[conf.channel - 1] || '');
          Globals.box.CqText.text(cqText);
        }
      }
    }

    function makeGuidingLine(xScale, line_config) {
      var line = d3.line();
      if (Globals.config.axes.y.scale === 'log') {
        line.curve(d3.curveMonotoneX);
      } else {
        line.curve(d3.curveBasis);
      }
      line.x(function(d) {
          return xScale(d[line_config.x]);
        })
        .y(function(d) {
          return Globals.yScale(d[line_config.y]);
        });
      var trans;
      var _path = Globals.viewSVG.append("path")
        .datum(Globals.data[line_config.dataset])
        .attr("class", "guiding-line")
        .attr("stroke", 'transparent')
        .attr('fill', 'none')
        .attr("d", line)
        .attr('stroke-width', Globals.normalPathStrokeWidth)
        .on('mousemove', mouseMoveCb)
        .on('click', unsetActivePath);

      return _path;
    }

    function makeColoredLine(xScale, line_config) {
      var line = d3.line();
      if (Globals.config.axes.y.scale === 'log') {
        line.curve(d3.curveMonotoneX);
      } else {
        line.curve(d3.curveBasis);
      }
      line.x(function(d) {
          return xScale(d[line_config.x]);
        })
        .y(function(d) {
          return Globals.yScale(d[line_config.y]);
        });

      if (Globals.config.axes.y.scale === 'log') {
        line.defined(function(d) {
          return d[line_config.y] > 10;
        });
      }
      var trans;
      var _path = Globals.viewSVG.append("path")
        .datum(Globals.data[line_config.dataset])
        .attr("class", "colored-line")
        .attr("stroke", line_config.color)
        .attr('fill', 'none')
        .attr("d", line)
        .attr('stroke-width', Globals.normalPathStrokeWidth)
        .on('click', function(e, a, path) {
          setActivePath.call(this, _path, d3Mouse(this));
          mouseMoveCb();
        })
        .on('mousemove', function(e, a, path) {
          if (_path !== Globals.activePath) {
            _path.attr('stroke-width', Globals.hoveredPathStrokeWidth);
            Globals.hoveredLine = _path;
            Globals.hovering = true;
          }
          mouseMoveCb();
        })
        .on('mouseout', function(e, a, path) {
          if (_path !== Globals.activePath) {
            _path.attr('stroke-width', Globals.normalPathStrokeWidth);
            Globals.hovering = false;
          }
        });


      return _path;
    }

    function makeWhiteBorderLine(xScale, line_config) {
      if (Globals.whiteBorderLine) {
        Globals.whiteBorderLine.remove();
      }
      var line = d3.line();
      if (Globals.config.axes.y.scale === 'log') {
        line.curve(d3.curveMonotoneX);
      } else {
        line.curve(d3.curveBasis);
      }
      line.x(function(d) {
          return xScale(d[line_config.x]);
        })
        .y(function(d) {
          return Globals.yScale(d[line_config.y]);
        });
      if (Globals.config.axes.y.scale === 'log') {
        line.defined(function(d) {
          return d[line_config.y] > 10;
        });
      }
      var trans;
      var _path = Globals.viewSVG.append("path")
        .datum(Globals.data[line_config.dataset])
        .attr("class", "white-border-line")
        .attr("stroke", "#fff")
        .attr('fill', 'none')
        .attr("d", line)
        .attr('stroke-width', Globals.activePathStrokeWidth + 3);

      Globals.whiteBorderLine = _path;
    }

    function drawLines() {
      var series = Globals.config.series,
        i,
        s;
      if (!series) {
        return;
      }


      Globals.guidingLines = Globals.guidingLines || [];
      Globals.guidingLines.forEach(function(line) {
        line.remove();
      });
      Globals.guidingLines = [];

      Globals.lines = Globals.lines || [];
      Globals.lines.forEach(function(line) {
        line.remove();
      });
      Globals.lines = [];
      Globals.activePath = null;
      var xScale = Globals.zoomTransform.k > 1 ? Globals.lastXScale : Globals.xScale;

      for (i = 0; i < series.length; i++) {
        s = series[i];
        Globals.guidingLines.push(makeGuidingLine(xScale, s));
      }

      for (i = 0; i < series.length; i++) {
        s = series[i];
        Globals.lines.push(makeColoredLine(xScale, s));
      }


      if (Globals.activePathConfig) {
        var m = prevMousePosition;
        var p = null;

        makeCircle();

        for (i = 0; i < series.length; i++) {
          s = series[i];
          if (s.well === Globals.activePathConfig.config.well && s.channel === Globals.activePathConfig.config.channel) {
            p = Globals.lines[i];
            break;
          }
        }
        if (p) {
          setActivePath(p);
          showMouseIndicators();
        }
      }

    }

    function getDataLength() {
      if (!Globals.config) return 0;
      if (!Globals.config.series) return 0;
      if (!Globals.data) return 0;
      var total = 0;
      Globals.config.series.forEach(function(s) {
        total += Globals.data[s.dataset].length;
      });
      return total / Globals.config.series.length;
    }

    function makeCircle() {
      var lastPos;
      if (Globals.circle) {
        lastPos = {
          cx: Globals.circle.attr('cx'),
          cy: Globals.circle.attr('cy'),
        };
        Globals.circle.remove();
      }
      Globals.circle = Globals.viewSVG.append('circle')
        .attr('opacity', 0)
        .attr('r', Globals.circleRadius)
        .attr('stroke', '#fff')
        .attr('stroke-width', Globals.circleStrokeWidth)
        .attr('transform', 'translate (50,50)')
        .on('mouseout', hideMouseIndicators)
        .on('mousemove', mouseMoveCb)
        .on('click', function() {
          this.remove();
          unsetActivePath();
          if (Globals.hoveredLine) {
            var mouse = d3Mouse(Globals.mouseOverlay.node());
            setActivePath(Globals.hoveredLine, mouse);
          }
        });
      if (Globals.activePathConfig) {
        Globals.circle.attr('fill', Globals.activePathConfig.config.color);
      }
      if (lastPos) {
        Globals.circle.attr('cx', lastPos.cx);
        Globals.circle.attr('cy', lastPos.cy);
      }
    }

    function zoomed() {
      var transform = d3.event.transform;
      transform.x = transform.x || 0;
      transform.y = transform.y || 0;
      transform.k = transform.k || 0;

      if (transform.x > 0) {
        transform.x = 0;
      }

      if (transform.x + (Globals.width * transform.k) < Globals.width) {
        transform.x = -(Globals.width * transform.k - Globals.width);
      }

      if (transform.y > 0) {
        transform.y = 0;
      }

      if (transform.y + (Globals.height * transform.k) < Globals.height) {
        transform.y = -(Globals.height * transform.k - Globals.height);
      }

      if (transform.k < 1) {
        transform.k = 1;
      }

      Globals.lastXScale = transform.rescaleX(Globals.xScale);
      Globals.gX.call(Globals.xAxis.scale(Globals.lastXScale));
      Globals.zoomTransform = transform;
      drawLines();
      updateXAxisExtremeValues();

      if (Globals.onZoomAndPan) {
        Globals.onZoomAndPan(Globals.zoomTransform, Globals.width, Globals.height, getScaleExtent());
      }

    }

    function getMinX() {
      var min = d3.min(Globals.config.series, function(s) {
        return d3.min(Globals.data[s.dataset], function(d) {
          return d[s.x];
        });
      });
      return min || 0;
    }

    function getMaxX() {
      var max = d3.max(Globals.config.series, function(s) {
        return d3.max(Globals.data[s.dataset], function(d) {
          return d[s.x];
        });
      });
      return max || 1;
    }

    function getMinY() {
      if (Globals.config.axes.y.min) {
        return Globals.config.axes.y.min;
      }
      var min_y = d3.min(Globals.config.series, function(s) {
        return d3.min(Globals.data[s.dataset], function(d) {
          return d[s.y];
        });
      });
      return min_y || 0;
    }

    function getMaxY() {
      if (Globals.config.axes.y.max) {
        return Globals.config.axes.y.max;
      }
      var max_y = d3.max(Globals.config.series, function(s) {
        return d3.max(Globals.data[s.dataset], function(d) {
          return d[s.y];
        });
      });
      return max_y || 1;
    }

    function getScaleExtent() {
      return Globals.config.axes.x.max || getMaxX();
    }

    function getYLogticks() {
      var num = getMaxY();
      num = num + num * 0.2;
      var calib, calibs, i, j, num_length, ref, roundup;
      num_length = num.toString().length;
      roundup = '1';
      for (i = j = 0, ref = num_length; j < ref; i = j += 1) {
        roundup = roundup + "0";
      }
      roundup = roundup * 1;
      calibs = [];
      calib = 10;
      while (calib <= roundup) {
        calibs.push(calib);
        calib = calib * 10;
      }
      return calibs;
    }

    function setYAxis() {

      Globals.chartSVG.selectAll('g.axis.y-axis').remove();

      var svg = Globals.chartSVG.select('.chart-g');

      // add allowance for interpolation curves
      var max = getMaxY();
      var min = getMinY();
      var diff = max - min;
      var allowance = diff * (Globals.config.axes.y.scale === 'log' ? 0.2 : 0.05);
      max += allowance;
      min = Globals.config.axes.y.scale === 'log' ? 5 : min - allowance;

      Globals.yScale = Globals.config.axes.y.scale === 'log' ? d3.scaleLog() : d3.scaleLinear();

      Globals.yScale.range([Globals.height, 0])
        .domain([min, max]);

      Globals.yAxis = d3.axisLeft(Globals.yScale);

      if (Globals.config.axes.y.tickFormat) {
        Globals.yAxis.tickFormat(Globals.config.axes.y.tickFormat);
      }

      if (Globals.config.axes.y.scale === 'log') {
        Globals.yAxis
          .tickValues(getYLogticks())
          .tickFormat(function(d) {
            return '10' + formatPower(Math.round(Math.log(d) / Math.LN10));
          });
      }
      Globals.gY = svg.append("g")
        .attr("class", "axis y-axis")
        .attr('fill', 'none')
        .call(Globals.yAxis)
        .on('mouseenter', hideMouseIndicators);

      if (Globals.zoomTransform.rescaleY) {
        Globals.gY.call(Globals.yAxis.scale(Globals.zoomTransform.rescaleY(Globals.yScale)));
      }
    }

    function setXAxis() {

      Globals.chartSVG.selectAll('g.axis.x-axis').remove();

      var svg = Globals.chartSVG.select('.chart-g');

      Globals.xScale = d3.scaleLinear()
        .range([0, Globals.width]);

      var min = Globals.config.axes.x.min || getMinX() || 0;
      var max = Globals.config.axes.x.max || getMaxX() || 1;
      Globals.xScale.domain([min, max]);

      Globals.xAxis = d3.axisBottom(Globals.xScale);

      Globals.gX = svg.append("g")
        .attr("class", "axis x-axis")
        .attr('fill', 'none')
        .attr("transform", "translate(0," + (Globals.height) + ")")
        .call(Globals.xAxis);

      if (Globals.zoomTransform.rescaleX) {
        Globals.gX.call(Globals.xAxis.scale(Globals.zoomTransform.rescaleX(Globals.xScale)));
      }
    }

    function updateZoomScaleExtent() {
      if (!Globals.zooomBehavior) {
        return;
      }
      Globals.zooomBehavior.scaleExtent([1, getScaleExtent()]);
    }

    function drawAxesExtremeValues() {
      Globals.chartSVG.selectAll('.axes-extreme-value').remove();
      drawXAxisRightExtremeValue();
      drawXAxisLeftExtremeValue();
      updateXAxisExtremeValues();
    }

    // function drawXAxisRightExtremeValue() {

    //   var textG = Globals.chartSVG.append('g')
    //     .attr('class', 'axes-extreme-value tick');

    //   var conWidth = 30;
    //   var offsetTop = 8.5;
    //   var offsetRight = 5;
    //   var xScale = Globals.lastXScale || Globals.xScale;

    //   textG.append('rect')
    //     .attr('fill', '#ffffff')
    //     .attr('width', conWidth)
    //     .attr('height', 10)
    //     .attr('y', Globals.height + Globals.config.margin.top + offsetTop)
    //     .attr('x', Globals.width + Globals.config.margin.left - conWidth + offsetRight);

    //   var text = textG.append('text')
    //     .attr('fill', '#000')
    //     .attr('y', Globals.height + Globals.config.margin.top + offsetTop)
    //     .attr('dy', '0.71em')
    //     .attr('font-size', '10px')
    //     .text(Math.round(xScale.invert(Globals.width) * 10) / 10);

    //   var textWidth = text.node().getBBox().width;
    //   text.attr('x', Globals.width + Globals.config.margin.left - textWidth + offsetRight);

    //   Globals.xAxisRightExtremeValueText = text;
    // }

    function drawXAxisLeftExtremeValue() {

      var textContainer = Globals.chartSVG.append('g')
        .attr('class', 'axes-extreme-value tick');

      Globals.xAxisLeftExtremeValueContainer = textContainer;

      var conWidth = 30;
      var conHeight = 14;
      var offsetTop = 8.5;
      var underlineStroke = 2;
      var lineWidth = 15;

      var rect = textContainer.append('rect')
        .attr('fill', '#fff')
        .attr('width', conWidth)
        .attr('height', conHeight)
        .attr('y', Globals.height + Globals.config.margin.top + offsetTop)
        .attr('x', Globals.config.margin.left - (conWidth / 2))
        .on('mousemove', function() {
          if (Globals.xAxisLeftExtremeValueTextUnderline) {
            Globals.xAxisLeftExtremeValueTextUnderline.attr('opacity', 1);
          }
        })
        .on('mouseout', function() {
          if (Globals.xAxisLeftExtremeValueTextUnderline) {
            Globals.xAxisLeftExtremeValueTextUnderline.attr('opacity', 0);
          }
        });

      var line = textContainer.append('line')
        .attr('stroke', '#000')
        .attr('stroke-width', underlineStroke)
        .attr('x1', Globals.config.margin.left - (lineWidth / 2))
        .attr('y1', Globals.height + Globals.config.margin.top + offsetTop + conHeight - underlineStroke)
        .attr('x2', Globals.config.margin.left - (lineWidth / 2) + lineWidth)
        .attr('y2', Globals.height + Globals.config.margin.top + offsetTop + conHeight - underlineStroke)
        .attr('opacity', 0);

      var text = textContainer.append('text')
        .attr('fill', '#000')
        .attr('y', Globals.height + Globals.config.margin.top + offsetTop)
        .attr('dy', '0.71em')
        .attr('font-size', '10px')
        .on('mousemove', function() {
          if (Globals.xAxisLeftExtremeValueTextUnderline) {
            Globals.xAxisLeftExtremeValueTextUnderline.attr('opacity', 1);
          }
        })
        .on('mouseout', function() {
          if (Globals.xAxisLeftExtremeValueTextUnderline) {
            Globals.xAxisLeftExtremeValueTextUnderline.attr('opacity', 0);
          }
        });

      Globals.xAxisLeftExtremeValueText = text;
      Globals.xAxisLeftExtremeValueTextUnderline = line;
    }

    function drawXAxisRightExtremeValue() {

      var textContainer = Globals.chartSVG.append('g')
        .attr('class', 'axes-extreme-value tick');

      Globals.xAxisLeftExtremeValueContainer = textContainer;

      var conWidth = 30;
      var conHeight = 14;
      var offsetTop = 8.5;
      var underlineStroke = 2;
      var lineWidth = 20;

      var rect = textContainer.append('rect')
        .attr('fill', '#fff')
        .attr('width', conWidth)
        .attr('height', conHeight)
        .attr('y', Globals.height + Globals.config.margin.top + offsetTop)
        .attr('x', Globals.config.margin.left + Globals.width - (conWidth / 2))
        .on('mousemove', function() {
          if (Globals.xAxisRightExtremeValueTextUnderline) {
            Globals.xAxisRightExtremeValueTextUnderline.attr('opacity', 1);
          }
        })
        .on('mouseout', function() {
          if (Globals.xAxisRightExtremeValueTextUnderline) {
            Globals.xAxisRightExtremeValueTextUnderline.attr('opacity', 0);
          }
        });

      var line = textContainer.append('line')
        .attr('stroke', '#000')
        .attr('stroke-width', underlineStroke)
        .attr('x1', Globals.config.margin.left + Globals.width - (lineWidth / 2))
        .attr('y1', Globals.height + Globals.config.margin.top + offsetTop + conHeight - underlineStroke)
        .attr('x2', Globals.config.margin.left + Globals.width - (lineWidth / 2) + lineWidth)
        .attr('y2', Globals.height + Globals.config.margin.top + offsetTop + conHeight - underlineStroke)
        .attr('opacity', 0);

      var text = textContainer.append('text')
        .attr('fill', '#000')
        .attr('y', Globals.height + Globals.config.margin.top + offsetTop)
        .attr('dy', '0.71em')
        .attr('font-size', '10px')
        .on('mousemove', function() {
          if (Globals.xAxisRightExtremeValueTextUnderline) {
            Globals.xAxisRightExtremeValueTextUnderline.attr('opacity', 1);
          }
        })
        .on('mouseout', function() {
          if (Globals.xAxisRightExtremeValueTextUnderline) {
            Globals.xAxisRightExtremeValueTextUnderline.attr('opacity', 0);
          }
        });

      Globals.xAxisRightExtremeValueText = text;
      Globals.xAxisRightExtremeValueTextUnderline = line;
    }

    function updateXAxisExtremeValues() {
      var xScale = Globals.lastXScale || Globals.xScale;
      var lineWidth, textWidth;
      var minWidth = 10;
      if (Globals.xAxisLeftExtremeValueText) {
        var text = Globals.xAxisLeftExtremeValueText;
        textWidth = text.node().getBBox().width;
        text.text(Math.round(xScale.invert(0) * 10) / 10)
          .attr('x', Globals.config.margin.left - (textWidth / 2));
      }
      if (Globals.xAxisLeftExtremeValueTextUnderline) {
        lineWidth = textWidth;
        lineWidth = lineWidth > minWidth ? lineWidth : minWidth;
        Globals.xAxisLeftExtremeValueTextUnderline
          .attr('x1', Globals.config.margin.left - (lineWidth / 2))
          .attr('x2', Globals.config.margin.left - (lineWidth / 2) + lineWidth);
      }
      if (Globals.xAxisRightExtremeValueText) {
        Globals.xAxisRightExtremeValueText.text(Math.round(xScale.invert(Globals.width) * 10) / 10);
        textWidth = Globals.xAxisRightExtremeValueText.node().getBBox().width;
        Globals.xAxisRightExtremeValueText.attr('x', Globals.width + Globals.config.margin.left - (textWidth / 2));
      }
      if (Globals.xAxisRightExtremeValueTextUnderline) {
        lineWidth = textWidth;
        lineWidth = lineWidth > minWidth ? lineWidth : minWidth;
        Globals.xAxisRightExtremeValueTextUnderline
          .attr('x1', Globals.width + Globals.config.margin.left - (lineWidth / 2))
          .attr('x2', Globals.width + Globals.config.margin.left - (lineWidth / 2) + lineWidth);
      }
    }

    function initChart(elem, data, config) {

      Globals.data = data;
      Globals.config = config;
      Globals.zooomBehavior = d3.zoom().on("zoom", zoomed);

      d3.select(elem).selectAll("*").remove();

      var width = elem.parentElement.offsetWidth - config.margin.left - config.margin.right;
      var height = elem.parentElement.offsetHeight - config.margin.top - config.margin.bottom;

      Globals.width = width;
      Globals.height = height;

      var chartSVG = Globals.chartSVG = d3.select(elem).append("svg")
        .attr("width", width + config.margin.left + config.margin.right)
        .attr("height", height + config.margin.top + config.margin.bottom)
        .call(Globals.zooomBehavior);

      var svg = chartSVG.append("g")
        .attr("transform", "translate(" + config.margin.left + "," + config.margin.top + ")")
        .attr('class', 'chart-g');

      Globals.viewSVG = svg.append('svg')
        .attr('width', width)
        .attr('height', height)
        .append('g')
        .attr('width', width)
        .attr('height', height)
        .attr('class', 'viewSVG');

      Globals.mouseOverlay = Globals.viewSVG.append('rect')
        .attr('width', width)
        .attr('height', height)
        .attr('fill', 'transparent')
        .on('mousemove', mouseMoveCb)
        .on('mouseenter', showMouseIndicators)
        .on('mouseout', hideMouseIndicators)
        .on('click', function() {
          unsetActivePath();
          if (Globals.hoveredLine) {
            var mouse = d3Mouse(Globals.mouseOverlay.node());
            setActivePath(Globals.hoveredLine, mouse);
          }
        });

      setYAxis();
      setXAxis();
      drawLines(config.series);
      makeCircle();
      updateZoomScaleExtent();
      drawAxesExtremeValues();

    }

    function getPathPositionByX(path, x) {
      if (!path) {
        return;
      }
      var pathEl = path.node();
      var pathLength = pathEl.getTotalLength();
      var beginning = x,
        end = pathLength,
        target,
        pos;

      while (true) {
        target = Math.floor(((beginning + end) / 2) * 100) / 100;
        target = window.isFinite(target) ? target : 1;
        pos = pathEl.getPointAtLength(target);
        if ((target === end || target === beginning) && pos.x !== x) {
          break;
        }
        if (pos.x > x) {
          end = target;
        } else if (pos.x < x) {
          beginning = target;
        } else {
          break; //position found
        }
      }

      return {
        x: x,
        y: pos.y
      };

    }

    function mouseMoveCb() {
      setHoveredLine();
      if (!Globals.activePath) {
        hideMouseIndicators();
        return;
      }
      var x = d3Mouse(Globals.mouseOverlay.node())[0];
      var pos = getPathPositionByX(Globals.guidingLines[Globals.activePathConfig.index], x);
      var max_x = ((getMaxX() - 1) / (Globals.config.axes.x.max - 1)) * Globals.width;

      if (x > max_x) {
        hideMouseIndicators();
      } else {
        if (window.isFinite(x)) {
          Globals.circle
            .attr("cx", x);
        } else {
          hideMouseIndicators();
        }
        Globals.circle
          .attr("cy", pos.y)
          .attr('transform', 'translate(0,0) scale(1)');

        setBoxRFYAndCycleTexts(x);
        showMouseIndicators();
      }

      prevMousePosition = [pos.x, pos.y];
    }

    function setHoveredLine() {
      var mouse = d3Mouse(Globals.mouseOverlay.node());
      var mouseX = mouse[0];
      var mouseY = mouse[1];
      var closestLineIndex;
      var distances = [];
      var lineIndex;
      var maxDistance = 20 * Globals.zoomTransform.k;

      for (lineIndex in Globals.lines) {
        var pos = getPathPositionByX(Globals.lines[lineIndex], mouseX);
        var distance = Math.abs(pos.y - mouseY);
        distances.push(distance);

        if (closestLineIndex === undefined) {
          closestLineIndex = lineIndex;
        }
        if (distance < distances[closestLineIndex]) {
          closestLineIndex = lineIndex;
        }
        if (distances[closestLineIndex] > maxDistance) {
          closestLineIndex = undefined;
          Globals.hoveredLine = null;
        }
        if (prevClosestLineIndex !== closestLineIndex) {
          if (prevClosestLineIndex !== undefined && Globals.lines[prevClosestLineIndex]) {
            if (Globals.lines[prevClosestLineIndex] !== Globals.activePath && Globals.lines[prevClosestLineIndex] !== Globals.hoveredLine && !Globals.hovering) {
              Globals.lines[prevClosestLineIndex].attr('stroke-width', Globals.normalPathStrokeWidth);
            }
            if (!Globals.hovering && Globals.hoveredLine) {
              Globals.hoveredLine.attr('stroke-width', Globals.normalPathStrokeWidth);
              Globals.hoveredLine = null;
            }
          }
          if (closestLineIndex !== undefined && !Globals.hovering && Globals.lines[closestLineIndex] !== Globals.activePath) {
            Globals.lines[closestLineIndex].attr('stroke-width', Globals.hoveredPathStrokeWidth);
            Globals.hoveredLine = Globals.lines[closestLineIndex];
          }
          prevClosestLineIndex = closestLineIndex;
        }
      }
    }

    this._getTransformXFromScroll = function(scroll) {
      scroll = scroll < 0 ? 0 : (scroll > 1 ? 1 : scroll);
      var transform = this.getTransform();
      var new_width = Globals.width * transform.k;
      var transform_x = -((new_width - Globals.width) * scroll);
      return transform_x;
    };

    this.scroll = function scroll(s) { // s = {0..1}
      var transform = this.getTransform();
      var transform_x = this._getTransformXFromScroll(s);
      var new_transform = d3.zoomIdentity.translate(transform_x, transform.y).scale(transform.k);
      Globals.chartSVG.call(Globals.zooomBehavior.transform, new_transform);
    };

    this.onZoomAndPan = function(fn) {
      // fn will receive (transform, width, height)
      Globals.onZoomAndPan = fn;
    };

    this.onSelectLine = function(fn) {
      Globals.onSelectLine = fn;
    };

    this.onUnselectLine = function(fn) {
      Globals.onUnselectLine = fn;
    };

    this.getDimensions = function() {
      return {
        width: Globals.width,
        height: Globals.height
      };
    };

    this.getTransform = function() {
      if (!Globals.chartSVG) {
        return;
      }
      return d3.zoomTransform(Globals.chartSVG.node());
    };

    this.reset = function() {
      Globals.chartSVG.call(Globals.zooomBehavior.transform, d3.zoomIdentity);
    };

    this.zoomTo = function(zoom_percent) { // zoom_percent = {0..1}
      zoom_percent = zoom_percent || 0;
      zoom_percent = zoom_percent < 0 ? 0 : (zoom_percent > 1 ? 1 : zoom_percent);
      var k = ((getScaleExtent() - 1) * zoom_percent) + 1;
      Globals.chartSVG.call(Globals.zooomBehavior.scaleTo, k);
    };

    this.updateSeries = function(series) {
      Globals.config.series = series;
      updateXAxisExtremeValues();
    };

    this.updateData = function(data) {
      Globals.data = data;
      updateZoomScaleExtent();
      updateXAxisExtremeValues();
    };

    this.updateConfig = function(config) {
      Globals.config = config;
    };

    this.updateInterpolation = function(i) {
      Globals.config.axes.y.scale = i;
    };

    this.getScaleExtent = function() {
      return getScaleExtent() || 1;
    };

    this.empty = function() {
      d3.select(elem).selectAll('*').remove();
    };

    this.resize = function(elem, data, config) {
      initChart(elem, data, config);
    };

    this.setYAxis = setYAxis;
    this.setXAxis = setXAxis;
    this.drawLines = drawLines;

    initChart(elem, data, config);

  }

  window.ChaiBioCharts = window.ChaiBioCharts || {};
  window.ChaiBioCharts.AmplificationChart = AmplificationChart;

})();