'use strict'

###*
 # @ngdoc function
 # @name dataplayApp.controller:SearchCtrl
 # @description
 # # SearchCtrl
 # Controller of the dataplayApp
###
angular.module('dataplayApp')
	.controller 'SearchCtrl', ['$scope', '$location', '$routeParams', 'User', 'Overview', 'PatternMatcher', 'ActivityMonitor', ($scope, $location, $routeParams, User, Overview, PatternMatcher, ActivityMonitor) ->
		$scope.query = if $routeParams.query? then $routeParams.query else ""
		$scope.results = []
		$scope.total = null
		$scope.tweets = []

		$scope.rowLimit = 3
		$scope.overview = []

		$scope.isSearch = !! $scope.query

		$scope.chartsRelated = []

		$scope.suggestions = []

		$scope.relatedChart = new RelatedCharts $scope.chartsRelated
		$scope.relatedChart.setPreview true
		$scope.relatedChart.width = 250
		$scope.relatedChart.height = 190

		$scope.init = (reset = false) ->
			# Initiate search if we have /search/:query
			if reset
				$scope.chartsRelated = []
				$scope.relatedChart.chartsRelated = $scope.chartsRelated
				$scope.tweets = []
				$scope.overview = []

			$scope.loading.related = ($scope.query.length > 0)
			$scope.loading.tweets = ($scope.query.length > 0)
			$scope.loading.overview = ($scope.query.length > 0)

			if $scope.isSearch
				$scope.search()
				$scope.getTweets()
				$scope.getNews()
			else
				$scope.getSuggestions()


		$scope.changePage = () ->
			query = $scope.query.replace(/\/|\\/g, ' ')
			newPath =  "/search/#{query}"
			if $location.path() isnt newPath
				$location.path newPath
			else
				$scope.init true

		$scope.search = (offset = 0, count = 6) ->
			return if $scope.query.length < 3

			$scope.loading.related = true

			User.search $scope.query, offset, count
				.success (data) ->
					$scope.loading.related = false

					$scope.results = data.Results
					$scope.total = data.Total

					$scope.results.forEach (r) ->
						r.graph = []
						r.error = null

						$scope.getRelated r
					return
				.error (status, data) ->
					$scope.loading.related = false
					console.log "Search::search::Error:", status
					return

			return

		$scope.getTweets = () ->
			return if $scope.query.length < 3

			$scope.loading.tweets = true

			User.searchTweets $scope.query
				.success (data) ->
					$scope.loading.tweets = false
					if data? and data instanceof Array
						$scope.tweets.splice(0)
						data.forEach (tw) ->
							$scope.query.split(/\s{1,}|\_{1,}/).forEach (searchWord) ->
								tw.comment = tw.comment.replace new RegExp("(#{searchWord})", 'gi'), '<span class="highlight">$1</span>'

							tw.comment = tw.comment.replace(/(<\/span>)(\s{1,}|\-{1,})(<span class="highlight">)/gi, '$2')

							tw.url = "https://twitter.com/#{tw.username}/status/#{tw.id}"

							$scope.tweets.push tw
				.error () ->
					$scope.loading.tweets = false

			return

		$scope.getNews = () ->
			return if $scope.query.length < 3

			$scope.loading.overview = true

			User.getNews $scope.query
				.success (data) ->
					$scope.loading.overview = false
					if data instanceof Array
						$scope.overview = data.map (item) ->
							date: Overview.humanDate new Date item.date
							title: item.title
							url: item.url
							thumbnail: item['image_url']

				.error (status, data) ->
					$scope.loading.overview = false
					console.log "Search::getNews::Error:", status
					return

		$scope.getSuggestions = () ->
			$scope.loading.suggestions = true
			$scope.suggestions = []

			ActivityMonitor.get 'popular'
				.success (data) ->
					$scope.loading.suggestions = false
					if data?
						popular = _.find data, { id: 'most_popular' }
						if popular? and popular.top instanceof Array
							$scope.suggestions = popular.top
							if $scope.suggestions.length > 8
								$scope.suggestions = $scope.suggestions.slice(0, 8)

				.error (status, data) ->
					$scope.loading.suggestions = false
					console.log "Search::getSuggestions::Error:", status
					return

		$scope.showMore = ->
			# get more results
			$scope.search $scope.chartsRelated.length

		$scope.collapse = (item) ->
			item.show = false

		$scope.uncollapse = (item) ->
			item.show = true

		$scope.getRelated = (item, offset = 0) ->
			res =
				loading: true
				title: item.Title
				guid: item.GUID

			$scope.chartsRelated.push res

			item.loading = true
			Overview.related item.GUID, offset, 1
				.success (data) ->
					if data? and data.charts? and data.charts.length > 0
						for key, chart of data.charts
							continue unless $scope.relatedChart.isPlotAllowed chart.type

							key = parseInt(key)
							chart.guid = item.GUID
							chart.key = key
							chart.id = "related-#{chart.guid}-#{chart.key + $scope.offset.related}-#{chart.type}"
							chart.url = "charts/related/#{chart.guid}/#{chart.key}/#{chart.type}/#{chart.xLabel}/#{chart.yLabel}"
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

							res.loading = false
							delete chart.title
							_.merge res, chart

					return
				.error (data, status) ->
					$scope.loading.related = false
					console.log "Overview::getRelated::Error:", status
					return

			return

		$scope.width = $scope.relatedChart.width
		$scope.height = $scope.relatedChart.height
		$scope.margin = $scope.relatedChart.margin
		$scope.loading = $scope.relatedChart.loading
		$scope.offset = $scope.relatedChart.offset
		$scope.limit = $scope.relatedChart.limit
		$scope.max = $scope.relatedChart.max

		$scope.hasRelatedCharts = $scope.relatedChart.hasRelatedCharts
		$scope.lineChartPostSetup = $scope.relatedChart.lineChartPostSetup
		$scope.rowChartPostSetup = $scope.relatedChart.rowChartPostSetup
		$scope.columnChartPostSetup = $scope.relatedChart.columnChartPostSetup
		$scope.pieChartPostSetup = $scope.relatedChart.pieChartPostSetup
		$scope.bubbleChartPostSetup = $scope.relatedChart.bubbleChartPostSetup

		return
	]
