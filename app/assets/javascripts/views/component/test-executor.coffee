$(window).on('load', ->
  new Crucible.TestExecutor()
)

class Crucible.TestExecutor
  suites: []
  suitesById: {}

  individualTests: []
  individualTestsById: {}

  templates:
    suiteSelect: 'views/templates/servers/suite_select'
    suiteResult: 'views/templates/servers/suite_result'
    testResult: 'views/templates/servers/test_result'
    individualTestResult: 'views/templates/servers/individual_test_result'
  html:
    selectAllButton: '<i class="fa fa-check"></i>&nbsp;Deselect All Test Suites'
    deselectAllButton: '<i class="fa fa-check"></i>&nbsp;Select All Test Suites'
    collapseAllButton: '<i class="fa fa-expand"></i>&nbsp;Collapse All Test Suites'
    expandAllButton: '<i class="fa fa-expand"></i>&nbsp;Expand All Test Suites'
    spinner: '<span class="fa fa-lg fa-fw fa-spinner fa-pulse tests"></span>'
  statusWeights: {'pass': 1, 'skip': 2, 'fail': 3, 'error': 4}

  constructor: ->
    @element = $('.test-executor')
    return unless @element.length
    @element.data('testExecutor', this)
    @serverId = @element.data('server-id')
    @registerHandlers()
    @loadTests()

  registerHandlers: =>
    @element.find('.execute').click(@execute)
    @element.find('.selectDeselectAll').click(@selectDeselectAll)
    @element.find('.expandCollapseAll').click(@expandCollapseAll)
    @element.find('.filter-by-executed a').click(@showAllSuites)
    @filterBox = @element.find('.test-results-filter')
    @filterBox.on('keyup', @filter)
    @element.find('.group-by-suite').click(@groupBySuite)
    @element.find('.group-by-individual-test').click(@groupByIndividualTest)

  loadTests: =>
    $.getJSON("api/tests.json").success((data) =>
      @suites = data['tests']
      @individualTests = $($.map(@suites, (e) -> e.methods))
      @renderSuites()
      @element.trigger('testsLoaded')
      @renderIndividualTests()
    )

  renderSuites: =>
    suitesElement = @element.find('.test-suites')
    suitesElement.empty()
    $(@suites).each (i, suite) =>
      @suitesById[suite.id] = suite
      suitesElement.append(HandlebarsTemplates[@templates.suiteSelect]({suite: suite}))
      suiteElement = suitesElement.find("#test-#{suite.id}")
      suiteElement.data('suite', suite)
      $(suite.methods).each (i, test) =>
        @addClickTestHandler(test, suiteElement)

  renderIndividualTests: =>
    testsElement = @element.find('.individual-test-results')
    testsElement.empty()
    $(@individualTests).each (i, test) =>
      @individualTestsById[test.id] = test
      testsElement.append(HandlebarsTemplates[@templates.individualTestResult]({test: test}))

  selectDeselectAll: =>
    suiteElements = @element.find('.test-run-result :checkbox')
    button = $('.selectDeselectAll')
    if !$(suiteElements).prop('checked')
      $(suiteElements).prop('checked', true)
      $(button).html(@html.selectAllButton)
    else
      $(suiteElements).prop('checked', false)
      $(button).html(@html.deselectAllButton)

  expandCollapseAll: =>
    suiteElements = @element.find('.test-run-result .collapse')
    button = $('.expandCollapseAll')
    if !$(suiteElements).hasClass('in')
      $(suiteElements).collapse('show')
      $(button).html(@html.collapseAllButton)
    else
      $(suiteElements).collapse('hide')
      $(button).html(@html.expandAllButton)

  execute: =>
    suiteIds = $($.map(@element.find(':checked'), (e) -> e.name))
    @showOnlyExecutedSuites()
    progress = $("##{this.element.data('progress')}")
    progress.parent().collapse('show')
    progress.find('.progress-bar').css('width',"2%")
    @element.queue("executionQueue", this.registerTestRun)
    suiteIds.each (i, suiteId) =>
      testElement = @element.find("#test-#{suiteId}")
      testElement.find('.test-status').empty().append(@html.spinner)
      @element.queue("executionQueue", =>
        $.post("/servers/#{@serverId}/tests/#{suiteId}/execute",{test_result: {test_run_id: @testRunId}}).success((result) =>
          progress.find('.progress-bar').css('width',"#{(i+1)/suiteIds.length*100}%")
          @handleSuiteResult(@suitesById[suiteId], result, testElement)
          if i < suiteIds.length-1
            @element.dequeue("executionQueue")
          else
            progress.parent().collapse('hide')
            progress.find('.progress-bar').css('width',"0%")
            @element.dequeue("executionQueue")
        )
      )
    @element.queue("executionQueue", this.regenerateSummary)
    @element.dequeue("executionQueue")

  filter: =>
    debugger
    filterValue = @filterBox.val().toLowerCase()
    elements = @element.find('.test-run-result')
    if (filterValue.length == 0)
      elements.show()
      return
    $(elements).each (i, suiteElement) =>
      suiteElement = $(suiteElement)
      suite = suiteElement.data('suite')
      if (suite.name.toLowerCase()).indexOf(filterValue) < 0
        suiteElement.hide()
      else
        suiteElement.show()
        
  showAllSuites: =>
    @element.find('.filter-by-executed').collapse('hide')
    @element.find('.test-run-result').show()

  showOnlyExecutedSuites: =>
    @element.find('.filter-by-executed').collapse('show')
    @element.find('.test-run-result').hide()
    @element.find(':checked').closest('.test-run-result').show()
    @element.find('.test-run-result.executed').show()
  
  registerTestRun: =>
    $.post("/api/test_runs", {test_run: {server_id: @serverId}}).success((result) =>
      @testRunId = result.test_run.id
      @element.dequeue("executionQueue")
    )

  groupBySuite: =>
    @element.find('.group-by-suite').addClass('selected')
    @element.find('.test-suites').removeClass('hide')
    @element.find('.group-by-individual-test').removeClass('selected')
    @element.find('.individual-test-results').addClass('hide')

  groupByIndividualTest: =>
    @element.find('.group-by-individual-test').addClass('selected')
    @element.find('.individual-test-results').removeClass('hide')
    @element.find('.group-by-suite').removeClass('selected')
    @element.find('.test-suites').addClass('hide')

  regenerateSummary: =>
    $.post("/api/servers/#{@serverId}/generate_summary", {test_run_id: @testRunId}).success((result) =>
      new Crucible.Summary()
      @element.dequeue("executionQueue")
    )
  
  handleSuiteResult: (suite, result, suiteElement) =>
    suiteStatus = 'pass'
    $(result.tests).each (i, test) =>
      suiteStatus = test.status if @statusWeights[suiteStatus] < @statusWeights[test.status]
    result.suiteStatus = suiteStatus

    suiteElement.replaceWith(HandlebarsTemplates[@templates.suiteResult]({suite: suite, result: result}))
    suiteElement = @element.find("#test-"+suite.id)
    suiteElement.data('suite', suite)
    $(result.tests).each (i, test) =>
      @addClickTestHandler(test, suiteElement)

  addClickTestHandler: (test, suiteElement) => 
    handle = suiteElement.find(".suite-handle[data-key='#{test.key}']")
    handle.click =>
      suiteElement.find(".suite-handle").removeClass('active')
      handle.addClass('active')
      suiteElement.find('.test-results').empty().append(HandlebarsTemplates[@templates.testResult]({test: test}))
