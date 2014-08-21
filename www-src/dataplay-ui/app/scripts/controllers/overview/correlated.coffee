'use strict'

###*
 # @ngdoc function
 # @name dataplayApp.controller:OverviewCorrelatedCtrl
 # @description
 # # OverviewCtrl
 # Controller of the dataplayApp
###
angular.module('dataplayApp')
	.controller 'OverviewCorrelatedCtrl', ['$scope', '$routeParams', 'Overview', 'PatternMatcher', ($scope, $routeParams, Overview, PatternMatcher) ->
		$scope.allowed = ['line', 'bar', 'row', 'column', 'pie', 'bubble']
		# $scope.allowed = ['bubble']
		$scope.params = $routeParams
		$scope.count = 3
		$scope.loading =
			correlated: false
		$scope.offset =
			correlated: 0
		$scope.limit =
			correlated: false
		$scope.max =
			correlated: 0
		$scope.chartsCorrelated = []

		$scope.xTicks = 6
		$scope.width = 350
		$scope.height = 200
		$scope.margin =
			top: 10
			right: 10
			bottom: 30
			left: 70

		$scope.isPlotAllowed = (type) ->
			if type in $scope.allowed then true else false

		$scope.getCorrelatedCharts = () ->
			console.log "getCorrelatedCharts", dc.chartRegistry.list().length
			Overview.updateChartRegistry dc.chartRegistry.list().length

			$scope.getCorrelated Overview.charts 'correlated'

			return

		$scope.getCorrelated = (count) ->
			$scope.loading.correlated = true

			if not count?
				count = $scope.max.correlated - $scope.offset.correlated
				count = if $scope.max.correlated and count < $scope.count then count else $scope.count

			Overview.correlated $scope.params.id, $scope.offset.correlated, count
				.success (data) ->
					if data? and data.Charts? and data.Charts.length > 0
						$scope.loading.correlated = false

						$scope.max.correlated = data.Count

						for key, chart of data.Charts
							continue unless $scope.isPlotAllowed chart.type

							chart.id = "correlated-#{$scope.params.id}-#{chart.table1.xLabel}-#{chart.table1.yLabel}-#{chart.table2.xLabel}-#{chart.table2.yLabel}-#{chart.type}"

							console.log chart.table1

							chart.patterns = {}
							chart.patterns[chart.table1.xLabel] =
								valuePattern: PatternMatcher.getPattern chart.table1.values[0]['x']
								keyPattern: PatternMatcher.getKeyPattern chart.table1.values[0]['x']

							if chart.patterns[chart.table1.xLabel].valuePattern is 'date'
								for value, key in chart.table1.values
									chart.table1.values[key].x = new Date(value.x)
								for value, key in chart.table2.values
									chart.table2.values[key].x = new Date(value.x)

							if chart.table1.yLabel?
								chart.patterns[chart.table1.yLabel] =
									valuePattern: PatternMatcher.getPattern chart.table1.values[0]['y']
									keyPattern: PatternMatcher.getKeyPattern chart.table1.values[0]['y']

							$scope.chartsCorrelated.push chart if PatternMatcher.includePattern(
								chart.patterns[chart.table1.xLabel].valuePattern,
								chart.patterns[chart.table1.xLabel].keyPattern
							)

						$scope.offset.correlated += count
						if $scope.offset.correlated >= $scope.max.correlated
							$scope.limit.correlated = true

						Overview.charts 'correlated', $scope.offset.correlated

						console.log "$scope.chartsCorrelated", $scope.chartsCorrelated
					return
				.error (data, status) ->
					console.log "Overview::getCorrelated::Error:", status
					return

			return

		$scope.getXScale = (data) ->
			xScale = switch data.patterns[data.table1.xLabel].valuePattern
				when 'label'
					d3.scale.ordinal()
						.domain data.ordinals
						.rangeBands [0, $scope.width]
				when 'date'
					d3.time.scale()
						.domain d3.extent data.group.all(), (d) -> d.key
						.range [0, $scope.width]
				else
					d3.scale.linear()
						.domain d3.extent data.group.all(), (d) -> parseInt d.key
						.range [0, $scope.width]

			xScale

		$scope.getXUnits = (data) ->
			xUnits = switch data.patterns[data.table1.xLabel].valuePattern
				when 'date' then d3.time.years
				when 'intNumber' then dc.units.integers
				when 'label', 'text' then dc.units.ordinal
				else dc.units.ordinal

			xUnits

		$scope.getYScale = (data) ->
			yScale = switch data.patterns[data.table1.xLabel].valuePattern
				when 'label'
					d3.scale.ordinal()
						.domain data.ordinals
						.rangeBands [0, $scope.height]
				when 'date'
					d3.time.scale()
						.domain d3.extent data.group.all(), (d) -> d.value
						.range [0, $scope.height]
				else
					d3.scale.linear()
						.domain d3.extent data.group.all(), (d) -> parseInt d.value
						.range [0, $scope.height]
						.nice()

			yScale

		$scope.lineChartPostSetup = (chart) ->
			data = $scope.chartsCorrelated[Overview.getChartOffset chart]

			data.entry = crossfilter data.table1.values
			data.dimension = data.entry.dimension (d) -> d.x
			data.group = data.dimension.group().reduceSum (d) -> d.y

			# data.entry2 = crossfilter data.table2.values
			# data.dimension2 = data.entry2.dimension (d) -> d.x
			# data.group2 = data.dimension2.group().reduceSum (d) -> d.y

			chart.dimension data.dimension
			chart.group data.group, data.table1.title
			# chart.stack data.group2, data.table2.title

			data.ordinals = []
			data.ordinals.push d.key for d in data.group.all() when d not in data.ordinals

			chart.colorAccessor (d, i) -> parseInt(d.y) % data.ordinals.length

			chart.xAxis().ticks $scope.xTicks

			chart.x $scope.getXScale data

			return

		$scope.rowChartPostSetup = (chart) ->
			data = $scope.chartsCorrelated[Overview.getChartOffset chart]

			data.entry = crossfilter data.table1.values
			data.dimension = data.entry.dimension (d) -> d.x
			data.group = data.dimension.group().reduceSum (d) -> d.y

			chart.dimension data.dimension
			chart.group data.group

			data.ordinals = []
			data.ordinals.push d.key for d in data.group.all() when d not in data.ordinals

			chart.colorAccessor (d, i) -> i + 1

			chart.xAxis().ticks $scope.xTicks

			chart.x $scope.getYScale data

			# chart.xUnits $scope.getXUnits data if data.ordinals?.length > 0

			return

		$scope.columnChartPostSetup = (chart) ->
			data = $scope.chartsCorrelated[Overview.getChartOffset chart]
			console.log "columnChartPostSetup", data, Overview.getChartOffset chart

			data.entry = crossfilter data.table1.values
			data.dimension = data.entry.dimension (d) -> d.x
			data.group = data.dimension.group().reduceSum (d) -> d.y

			chart.dimension data.dimension
			chart.group data.group

			data.ordinals = []
			data.ordinals.push d.key for d in data.group.all() when d not in data.ordinals

			chart.colorAccessor (d, i) -> i + 1

			chart.x $scope.getXScale data

			chart.xUnits $scope.getXUnits data if data.ordinals?.length > 0

			return

		$scope.pieChartPostSetup = (chart) ->
			data = $scope.chartsCorrelated[Overview.getChartOffset chart]

			data.entry = crossfilter data.table1.values
			data.dimension = data.entry.dimension (d) ->
				if data.patterns[data.table1.xLabel].valuePattern is 'date'
					return "#{d.x.getDate()} #{Overview.monthNames[d.x.getMonth()]} #{d.x.getFullYear()}"
				x = if d.x? and (d.x.length > 0 || data.patterns[data.table1.xLabel].valuePattern is 'date') then d.x else "N/A"
			data.groupSum = 0
			data.group = data.dimension.group().reduceSum (d) ->
				y = Math.abs parseFloat d.y
				data.groupSum += y
				y

			chart.dimension data.dimension
			chart.group data.group

			chart.colorAccessor (d, i) -> i + 1

			chart.renderLabel false
			chart.label (d) ->
				percent = d.value / data.groupSum * 100
				"#{d.key} (#{Math.floor percent}%)"

			chart.renderTitle false
			chart.title (d) ->
				percent = d.value / data.groupSum * 100
				"#{d.key}: #{d.value} [#{Math.floor percent}%]"

			return

		$scope.bubbleChartPostSetup = (chart) ->
			data = $scope.chartsCorrelated[Overview.getChartOffset chart]

			minR = null
			maxR = null

			data.entry = crossfilter data.table1.values
			data.dimension = data.entry.dimension (d) ->
				z = Math.abs parseInt d.z

				if not minR? or minR > z
					minR = if z is 0 then 1 else z

				if not maxR? or maxR <= z
					maxR = if z is 0 then 1 else z

				"#{d.x}|#{d.y}|#{d.z}"

			data.group = data.dimension.group().reduceSum (d) -> d.y

			chart.dimension data.dimension
			chart.group data.group

			data.ordinals = []
			for d in data.group.all() when d not in data.ordinals
				data.ordinals.push d.key.split("|")[0]

			chart.keyAccessor (d) -> d.key.split("|")[0]
			chart.valueAccessor (d) -> d.key.split("|")[1]
			chart.radiusValueAccessor (d) ->
				r = Math.abs parseInt d.key.split("|")[2]
				if r >= minR then r else minR

			chart.x switch data.patterns[data.table1.xLabel].valuePattern
				when 'label'
					d3.scale.ordinal()
						.domain data.ordinals
						.rangeBands [0, $scope.width]
				when 'date'
					d3.time.scale()
						.domain d3.extent data.group.all(), (d) -> d.key.split("|")[0]
						.range [0, $scope.width]
				else
					d3.scale.linear()
						.domain d3.extent data.group.all(), (d) -> parseInt d.key.split("|")[0]
						.range [0, $scope.width]

			chart.y switch data.patterns[data.table1.xLabel].valuePattern
				when 'label'
					d3.scale.ordinal()
						.domain data.ordinals
						.rangeBands [0, $scope.height]
				when 'date'
					d3.time.scale()
						.domain d3.extent data.group.all(), (d) -> d.key.split("|")[1]
						.range [0, $scope.height]
				else
					d3.scale.linear()
						.domain d3.extent data.group.all(), (d) -> parseInt d.key.split("|")[1]
						.range [0, $scope.height]

			rScale = d3.scale.linear()
				.domain d3.extent data.group.all(), (d) -> Math.abs parseInt d.key.split("|")[2]
			chart.r rScale

			# chart.label (d) -> x = d.key.split("|")[0]

			chart.title (d) ->
				x = d.key.split("|")[0]
				y = d.key.split("|")[1]
				z = d.key.split("|")[2]
				"#{data.table1.xLabel}: #{x}\n#{data.table1.yLabel}: #{y}\n#{data.table1.zLabel}: #{z}"

			minRL = Math.log minR
			maxRL = Math.log maxR
			scale = Math.abs Math.log (maxRL - minRL) / (maxR - minR)

			chart.maxBubbleRelativeSize scale / 100

			return

		$scope.resetAll = ->
			dc.filterAll()
			dc.redrawAll()

		return
	]
