window.ChaiBioTech.ngApp.service 'AmplificationChartHelper', [
  'SecondsDisplay'
  '$filter'
  (SecondsDisplay, $filter) ->

    @chartSeries = (type, is_dual_channel) ->
      channels_count = if is_dual_channel then 2 else 1
      series = []
      for channel_i in [1..channels_count] by 1
        for well_i in [0..15] by 1

          label = if channels_count is 1 then "well_#{well_i}: " else "channel_#{channel_i}, well_#{well_i}: "

          series.push
            axis: 'y'
            dataset: "channel_#{channel_i}"
            key: "well_#{well_i}_#{type}"
            color: @COLORS[well_i]
            type: 'line'
            id: "channel_#{channel_i}_well_#{well_i}"
            label: label

      return series

    @chartConfig = (is_dual_channel = false) ->
      channels_count = if is_dual_channel then 2 else 1

      axes:
        x:
          min: 1
          key: 'cycle_num'
          ticks: 8
          tickFormat: (x) ->
            return parseInt(x)
        y:
          ticks: 10
      margin:
        left: 100
        right: 0
      grid:
        x: false
        y: false

      series: []
      # tooltipHook: (items) ->
      #   rows = []
      #   for item in items by 1
      #     rows.push
      #       label: item.series.label
      #       value: "#{item.row.y1}"
      #       id: item.series.id
      #       color: item.series.color

      #   abscissas: "#{item.row.x}"
      #   rows: rows

    # end chartConfig


    @neutralizeData = (amplification_data, is_dual_channel=false) ->
      amplification_data = angular.copy amplification_data
      channel_datasets = {}
      channels_count = if is_dual_channel then 2 else 1
      neutralized_baseline_data = []
      neutralized_background_data = []

      # get max cycle
      max_cycle = 0
      for datum in amplification_data by 1
        max_cycle = if datum[2] > max_cycle then datum[2] else max_cycle

      for channel_i in [1..channels_count] by 1
        channel_datasets["channel_#{channel_i}"] = []
        channel_data = _.filter amplification_data, (datum) ->
          datum[0] is 1
        for cycle_i in [1..max_cycle] by 1
          data_by_cycle = _.filter channel_data, (datum) ->
            datum[2] is cycle_i
          data_by_cycle = _.sortBy data_by_cycle, (d) ->
            d[1]
          channel_datasets["channel_#{channel_i}"].push data_by_cycle

        channel_datasets["channel_#{channel_i}"] = _.map channel_datasets["channel_#{channel_i}"], (datum) ->
          pt = cycle_num: datum[0][2]
          for y_item, i in datum by 1
            pt["well_#{i}_background"] = y_item[3]
            pt["well_#{i}_baseline"] = y_item[4]

          return pt

      return channel_datasets

    @paddData = (cycle_num = 0) ->
      paddData = cycle_num: cycle_num
      for i in [0..15] by 1
        paddData["well_#{i}_baseline"] = 0
        paddData["well_#{i}_background"] = 0

      channel_1: paddData
      channel_2: paddData

    @getMaxExperimentCycle = (exp) ->
      stages = exp.protocol.stages || []
      cycles = []

      for stage in stages by 1
        cycles.push stage.stage.num_cycles

      Math.max.apply Math, cycles

    @getMaxCalibration = (amplification_data) ->
      calibs = _.map amplification_data, (datum) ->
        datum[4]

      max_baseline = Math.max.apply Math, calibs

      calibs = _.map amplification_data, (datum) ->
        datum[3]

      max_background = Math.max.apply Math, calibs

      return if max_baseline > max_background then max_baseline else max_background

    @getMaxCycleFromAmplification = (amplification_data) ->
      cycles = []
      for datum in [0...amplification_data.length] by 1
        cycles.push parseInt(datum[2])

      return Math.max.apply Math, cycles

    @Xticks = (min, max)->
      num_ticks = 10
      ticks = []
      if max - min < num_ticks
        for i in [min..max] by 1
          ticks.push i
      else
        chunkSize = Math.floor((max-min)/num_ticks)
        for i in [min..max] by chunkSize
          ticks.push i
        ticks.push max if max % num_ticks isnt 0

      return ticks

    @COLORS = [
        '#04A0D9'
        '#1578BE'
        '#2455A8'
        '#3B2F90'
        '#73258C'
        '#B01C8B'
        '#FA1284'
        '#FF004E'
        '#EA244E'
        '#FA3C00'
        '#EF632A'
        '#F5AF13'
        '#FBDE26'
        '#B6D333'
        '#67BC42'
        '#13A350'
      ]

    @moveData = (data, zoom, scroll, max_cycle) ->
      data = angular.copy data
      scroll = if scroll < 0 then 0 else scroll
      scroll =if scroll > 1 then 1 else scroll

      if zoom is max_cycle
        cycle_start = 1
        cycle_end = angular.copy max_cycle

      else
        cycle_start = Math.floor(scroll * (max_cycle - zoom) ) + 1
        cycle_end = cycle_start + zoom - 1

      # new_data = _.filter data, (datum) ->
      #   datum.cycle_num >= cycle_start and datum.cycle_num <= cycle_end

      # new_data = if new_data.length > 0 then new_data else @paddData(cycle_start)

      min_cycle: cycle_start
      max_cycle: cycle_end
      amplification_data: data

    return
]