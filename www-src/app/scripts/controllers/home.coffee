'use strict'

###*
 # @ngdoc function
 # @name dataplayApp.controller:HomeCtrl
 # @description
 # # HomeCtrl
 # Controller of the dataplayApp
###
d3.selection::duration = -> @
# d3.selection::transition = -> @

angular.module('dataplayApp')
	.controller 'HomeCtrl', ['$scope', '$location', 'Home', 'Auth', 'Overview', 'PatternMatcher', 'config', ($scope, $location, Home, Auth, Overview, PatternMatcher, config) ->
		$scope.config = config
		$scope.Math = window.Math

		$scope.searchquery = ''

		$scope.approvePatterns = null

		$scope.myActivity = null
		$scope.recentObservations = null
		$scope.dataExperts = null

		$scope.loading =
			charts: true

		$scope.chartsRelated = []

		$scope.relatedChart = new RelatedCharts $scope.chartsRelated
		$scope.relatedChart.setPreview true
		$scope.relatedChart.width = 225
		$scope.relatedChart.height = 175

		$scope.init = ->
			$scope.loading.charts = true

			Home.getAwaitingCredit()
				.success (data) ->
					$scope.loading.charts = false

					if data? and data.charts? and data.charts.length > 0
						counter = 0
						for key, chart of data.charts
							break if counter is 4

							continue unless $scope.relatedChart.isPlotAllowed chart.type

							key = parseInt(key)

							if chart.relationid?
								counter++

								guid = chart.relationid.split("/")[0]

								chart.key = key
								chart.id = "related-#{guid}-#{chart.key + $scope.relatedChart.offset.related}-#{chart.type}"
								chart.url = "charts/related/#{guid}/#{chart.key}/#{chart.type}/#{chart.xLabel}/#{chart.yLabel}"
								chart.url += "/#{chart.zLabel}" if chart.type is 'bubble'

								chart.patterns = {}
								chart.patterns[chart.xLabel] =
									valuePattern: PatternMatcher.getPattern chart.values[0]['x']
									keyPattern: PatternMatcher.getKeyPattern chart.values[0]['x']

								if chart.patterns[chart.xLabel].valuePattern is 'date'
									for value, key in chart.values
										chart.values[key].x = new Date(value.x)

								if chart.yLabel?
									chart.patterns[chart.yLabel] =
										valuePattern: PatternMatcher.getPattern chart.values[0]['y']
										keyPattern: PatternMatcher.getKeyPattern chart.values[0]['y']

								$scope.relatedChart.setLabels chart

								$scope.chartsRelated.push chart

							else if chart.correlationid?
								chartObj = new CorrelatedChart chart.type

								if not chartObj.error
									counter++

									chartObj.info =
										key: key
										id: "correlated-#{chart.correlationid}"
										url: "charts/correlated/#{chart.correlationid}"
										title: [chart.table1.title, chart.table2.title]

									[1..2].forEach (i) ->
										vals = chartObj.translateData chart['table' + i].values, chart.type
										dataRange = do ->
											min = d3.min vals, (item) -> parseFloat item.y
											[
												if min > 0 then 0 else min
												d3.max vals, (item) -> parseFloat item.y
											]
										type = if chart.type is 'column' or chart.type is 'bar' then 'bar' else 'area'

										chartObj.data.push
											key: chart['table' + i].title
											type: type
											yAxis: i
											values: vals
										chartObj.options.chart['yDomain' + i] = dataRange
										chartObj.options.chart['yAxis' + i].tickValues = [0]
										chartObj.options.chart.xAxis.tickValues = []

									chartObj.setAxisTypes 'none', 'none', 'none'
									chartObj.setSize null, 200
									chartObj.setMargin 25, 25, 25, 25
									chartObj.setLegend false
									chartObj.setTooltips false
									chartObj.setPreview true
									chartObj.setLabels chart

									$scope.chartsRelated.push chartObj

						console.log $scope.chartsRelated
					else
						$scope.approvePatterns = []
				.error ->
					$scope.approvePatterns = []

			Home.getActivityStream()
				.success (data) ->
					if data instanceof Array
						$scope.myActivity = data.map (d) ->
							date: Overview.humanDate new Date d.time
							pretext: d.activitystring
							linktext: d.patternid
							url: d.linkstring
							action: d.action
							actor: d.actor
							title: d.title
							points:
								value: d.points
								text: if Math.abs(d.points) is 1 then "point" else "points"
								class: if d.points < 0 then "danger" else "success"
					else
						$scope.myActivity = []
				.error ->
					$scope.myActivity = []

			Home.getRecentObservations()
				.success (data) ->
					if data instanceof Array
						$scope.recentObservations = data.map (d) ->
							user:
								name: d.username
								avatar: d.avatar or "http://www.gravatar.com/avatar/#{d.MD5email}?d=identicon"
							text: d.comment
							url: d.linkstring
					else
						$scope.recentObservations = []
				.error ->
					$scope.recentObservations = []

			Home.getDataExperts()
				.success (data) ->
					if data instanceof Array

						medals = ['gold', 'silver', 'bronze']

						$scope.dataExperts = data
							.filter (d) ->
								d.reputation > 0
							.map (d, key) ->
								obj =
									rank: key + 1
									name: d.username
									avatar: d.avatar or "http://www.gravatar.com/avatar/#{d.MD5email}?d=identicon"
									score: d.reputation

								if obj.rank <= 3 then obj.rankclass = medals[obj.rank - 1]

								obj
					else
						$scope.dataExperts = []
				.error ->
					$scope.dataExperts = []

		$scope.search = ->
			$location.path "/search/#{$scope.searchquery}"

		$scope.width = $scope.relatedChart.width
		$scope.height = $scope.relatedChart.height
		$scope.margin = $scope.relatedChart.margin

		$scope.hasRelatedCharts = $scope.relatedChart.hasRelatedCharts
		$scope.lineChartPostSetup = $scope.relatedChart.lineChartPostSetup
		$scope.rowChartPostSetup = $scope.relatedChart.rowChartPostSetup
		$scope.columnChartPostSetup = $scope.relatedChart.columnChartPostSetup
		$scope.pieChartPostSetup = $scope.relatedChart.pieChartPostSetup
		$scope.bubbleChartPostSetup = $scope.relatedChart.bubbleChartPostSetup

		return
	]
