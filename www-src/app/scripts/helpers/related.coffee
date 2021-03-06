'use strict'

class RelatedCharts
	constructor: (chartsRelated) ->
		@chartsRelated = chartsRelated

	preview: false
	allowed: ['line', 'bar', 'row', 'column', 'pie', 'bubble']
	count: 3
	loading:
		related: false
	offset:
		related: 0
	limit:
		related: false
	max:
		related: 0
	chartsRelated: []

	xTicks: 6
	width: 275
	height: 200
	margin:
		top: 10
		right: 10
		bottom: 30
		left: 70
	marginPreview:
		top: 25
		right: 25
		bottom: 25
		left: 25

	monthNames: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

	humanDate: (date) =>
		"#{date.getDate()} #{@monthNames[date.getMonth()]}, #{date.getFullYear()}"

	findById: (id) ->
		data = _.where(@chartsRelated,
			id: id
		)

		if data?[0]? then data[0] else null

	setPreview: (bool = false) =>
		@preview = bool

	setCustomMargin: (margin = ({top:0,right:0,bottom:0,left:0})) ->
		@customMargin = margin

	setLabels: (chart) ->
		if chart.type isnt 'pie'
			chart.labels =
				x: chart.xLabel
				y: chart.yyLabel or chart.yLabel

	isPlotAllowed: (type) ->
		if type in @allowed then true else false

	hasRelatedCharts: () ->
		Object.keys(@chartsRelated).length

	getXScale: (data) ->
		xScale = switch data.patterns[data.xLabel].valuePattern?.toLowerCase()
			when 'label'
				d3.scale.ordinal()
					.domain data.ordinals
					.rangeBands [0, @width]
			when 'date', 'year'
				d3.time.scale()
					.domain d3.extent data.group.all(), (d) -> d.key
					.range [0, @width]
			else
				d3.scale.linear()
					.domain d3.extent data.group.all(), (d) -> parseInt d.key
					.range [0, @width]

		xScale

	getXUnits: (data) ->
		xUnits = switch data.patterns[data.xLabel].valuePattern?.toLowerCase()
			when 'date', 'year' then d3.time.years
			when 'intnumber' then dc.units.integers
			when 'label', 'text' then dc.units.ordinal
			else dc.units.ordinal

		xUnits

	getYScale: (data) ->
		yScale = switch data.patterns[data.yLabel].valuePattern?.toLowerCase()
			when 'label'
				d3.scale.ordinal()
					.domain data.ordinals
					.rangeBands [0, @height]
			when 'date', 'year'
				d3.time.scale()
					.domain d3.extent data.group.all(), (d) -> d.value
					.range [0, @height]
			else
				d3.scale.linear()
					.domain d3.extent data.group.all(), (d) -> parseInt d.value
					.range [0, @height]
					.nice()

		yScale

	lineChartPostSetup: (chart) =>
		data = @findById chart.anchorName()

		data.entry = crossfilter data.values
		data.dimension = data.entry.dimension (d) -> d.x
		data.group = data.dimension.group().reduceSum (d) -> d.y

		chart.dimension data.dimension
		chart.group data.group

		data.ordinals = []
		data.ordinals.push d.key for d in data.group.all() when d not in data.ordinals

		chart.colorAccessor (d, i) -> parseInt(d.y) % data.ordinals.length

		if @preview
			chart.xAxis().ticks(0).tickFormat (v) -> ""
			chart.yAxis?().ticks?(0).tickFormat (v) -> ""
			chart.margins @marginPreview
		else
			chart.xAxis().ticks @xTicks

		chart.margins @customMargin if @customMargin?

		chart.xAxisLabel false, 0
		chart.yAxisLabel false, 0

		chart.x @getXScale data

		return

	rowChartPostSetup: (chart) =>
		data = @findById chart.anchorName()

		data.entry = crossfilter data.values
		data.dimension = data.entry.dimension (d) -> d.x
		data.group = data.dimension.group().reduceSum (d) -> d.y

		chart.dimension data.dimension
		chart.group data.group

		data.ordinals = []
		data.ordinals.push d.key for d in data.group.all() when d not in data.ordinals

		chart.colorAccessor (d, i) -> i + 1

		if @preview
			chart.xAxis().ticks(0).tickFormat (v) -> ""
			chart.yAxis().ticks(0).tickFormat (v) -> ""
			chart.margins @marginPreview
		else
			chart.xAxis().ticks @xTicks

		chart.margins @customMargin if @customMargin?

		chart.x @getYScale data

		chart.xUnits @getXUnits data if data.ordinals?.length > 0

		return

	columnChartPostSetup: (chart) =>
		data = @findById chart.anchorName()

		data.entry = crossfilter data.values
		data.dimension = data.entry.dimension (d) -> d.x
		data.group = data.dimension.group().reduceSum (d) -> d.y

		chart.dimension data.dimension
		chart.group data.group

		data.ordinals = []
		data.ordinals.push d.key for d in data.group.all() when d not in data.ordinals

		chart.colorAccessor (d, i) -> i + 1

		if @preview
			chart.xAxis().ticks(0).tickFormat (v) -> ""
			chart.yAxis().ticks(0).tickFormat (v) -> ""
			chart.margins @marginPreview
		else
			chart.xAxis().ticks @xTicks

		chart.margins @customMargin if @customMargin?

		chart.x @getXScale data

		chart.xUnits @getXUnits data if data.ordinals?.length > 0

		margins = chart.margins()
		columnSpacing = 2
		totalColumnSpacing = columnSpacing * (data.ordinals.length + 1)
		columnWidth = (@width - margins.right - margins.left - totalColumnSpacing) / data.ordinals.length

		chart.renderlet (chart) ->
			width = columnWidth - (columnSpacing * 2)
			width = 3 if width < 1

			chart.selectAll "g.chart-body rect"
				.attr "width", width
				.attr "x", (d, i) -> (i * columnWidth) + (columnSpacing * 2)

		return

	pieChartPostSetup: (chart) =>
		data = @findById chart.anchorName()

		data.entry = crossfilter data.values
		data.dimension = data.entry.dimension (d) =>
			return @humanDate d.x if data.patterns[data.xLabel].valuePattern is 'date'
			x = if d.x? and (d.x.length > 0 || data.patterns[data.xLabel].valuePattern is 'date') then d.x else "N/A"
		data.groupSum = 0
		data.group = data.dimension.group().reduceSum (d) ->
			y = Math.abs parseFloat d.y
			data.groupSum += y
			y

		chart.innerRadius Math.min(@width, @height) / 4

		chart.dimension data.dimension
		chart.group data.group

		chart.colorAccessor (d, i) -> i + 1

		chart.renderLabel false

		return

	bubbleChartPostSetup: (chart) =>
		data = @findById chart.anchorName()

		minR = null
		maxR = null

		normaliseNumber = (i) ->
			if typeof i isnt 'number' then return normaliseNumber parseFloat i
			if i is 0 or isNaN(i) or typeof i isnt 'number' then return 0
			if i < 0 then return normaliseNumber i * -1
			if i < 1 then return normaliseNumber i * 100
			return i

		data.entry = crossfilter data.values
		data.dimension = data.entry.dimension (d) ->
			d.z = normaliseNumber d.z

			minR = if d.z is 0 then 1 else d.z if not minR? or minR > d.z

			maxR = if d.z is 0 then 1 else d.zif not maxR? or maxR <= d.z

			"#{d.x}|#{d.y}|#{d.z}"

		data.group = data.dimension.group().reduceSum (d) -> d.y

		chart.dimension data.dimension
		chart.group data.group

		data.ordinals = []
		data.ordinals.push d.key.split("|")[0] for d in data.group.all() when d not in data.ordinals

		chart.keyAccessor (d) -> d.key.split("|")[0]
		chart.valueAccessor (d) -> d.key.split("|")[1]
		chart.radiusValueAccessor (d) ->
			r = Math.abs parseInt d.key.split("|")[2]
			if r >= minR then r else minR

		chart.x switch data.patterns[data.xLabel].valuePattern?.toLowerCase()
			when 'label'
				d3.scale.ordinal()
					.domain data.ordinals
					.rangeBands [0, @width]
			when 'date', 'year'
				d3.time.scale()
					.domain d3.extent data.group.all(), (d) -> d.key.split("|")[0]
					.range [0, @width]
			else
				d3.scale.linear()
					.domain d3.extent data.group.all(), (d) -> parseInt d.key.split("|")[0]
					.range [0, @width]

		chart.y switch data.patterns[data.xLabel].valuePattern?.toLowerCase()
			when 'label'
				d3.scale.ordinal()
					.domain data.ordinals
					.rangeBands [0, @height]
			when 'date', 'year'
				d3.time.scale()
					.domain d3.extent data.group.all(), (d) -> d.key.split("|")[1]
					.range [0, @height]
			else
				d3.scale.linear()
					.domain d3.extent data.group.all(), (d) -> parseInt d.key.split("|")[1]
					.range [0, @height]

		rScale = d3.scale.linear()
			.domain d3.extent data.group.all(), (d) -> Math.abs parseInt d.key.split("|")[2]
		chart.r rScale

		if @preview
			chart.xAxis().ticks(0).tickFormat (v) -> ""
			chart.yAxis().ticks(0).tickFormat (v) -> ""
			chart.margins @marginPreview
		else
			chart.xAxis().ticks @xTicks

		chart.margins @customMargin if @customMargin?

		# chart.label (d) -> x = d.key.split("|")[0]

		chart.title (d) ->
			x = d.key.split("|")[0]
			y = d.key.split("|")[1]
			z = d.key.split("|")[2]
			"#{data.xLabel}: #{x}\n#{data.yLabel}: #{y}\n#{data.zLabel}: #{z}"

		minRL = Math.log minR
		maxRL = Math.log maxR
		scale = Math.abs Math.log (maxRL - minRL) / (maxR - minR)

		chart.maxBubbleRelativeSize scale / 100

		return

window.RelatedCharts = RelatedCharts
