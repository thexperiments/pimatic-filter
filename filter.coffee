module.exports = (env) ->
  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  _ = env.require('lodash')

  class FilterPlugin extends env.plugins.Plugin

    init: (app, @framework, @config) =>
      deviceConfigDef = require("./device-config-schema")

      @framework.deviceManager.registerDeviceClass("SimpleMovingAverageFilter", {
        configDef: deviceConfigDef.SimpleMovingAverageFilter,
        createCallback: (config, lastState) =>
          return new SimpleMovingAverageFilter(config, lastState)
      })

      @framework.deviceManager.registerDeviceClass("SimpleTruncatedMeanFilter", {
        configDef: deviceConfigDef.SimpleTruncatedMeanFilter,
        createCallback: (config, lastState) =>
          return new SimpleTruncatedMeanFilter(config, lastState)
      })

  plugin = new FilterPlugin

  class SimpleMovingAverageFilter extends env.devices.Device

    filterValues: []
    sum: 0.0
    mean: 0.0
    attributeValue: null

    constructor: (@config, lastState) ->
      @id = config.id
      @name = config.name
      @size = config.size
      @output = config.output

      @varManager = plugin.framework.variableManager #so you get the variableManager
      @_exprChangeListeners = []

      name = @output.name
      info = null

      if lastState[name]?
        @attributeValue = lastState[name]

      #@attributes = _.cloneDeep(@attributes)
      @attributes[name] = {
        description: name
        label: (if @output.label? then @output.label else "$#{name}")
        type: "number"
      }

      if @output.unit? and @output.unit.length > 0
        @attributes[name].unit = @output.unit

      if @output.discrete?
        @attributes[name].discrete = @output.discrete

      if @output.acronym?
        @attributes[name].acronym = @output.acronym

      @_createGetter(name, =>
        return Promise.resolve @attributeValue
      )

      evaluate = ( =>
        # wait till VariableManager is ready
        return Promise.delay(10).then( =>
          unless info?
            info = @varManager.parseVariableExpression(@output.expression)
            @varManager.notifyOnChange(info.tokens, evaluate)
            @_exprChangeListeners.push evaluate

          switch info.datatype
            when "numeric" then @varManager.evaluateNumericExpression(info.tokens)
            when "string" then @varManager.evaluateStringExpression(info.tokens)
            else
              assert false
        ).then((val) =>
          if val
            val = Number(val)
            @filterValues.push val
            @sum = @sum + val
            if @filterValues.length > @size
              @sum = @sum - @filterValues.shift()
            @mean = @sum / @filterValues.length

            env.logger.debug @mean, @filterValues
            @_setAttribute name, @mean
          return @attributeValue
        )
      )
      evaluate()
      super()

    _setAttribute: (attributeName, value) ->
      @attributeValue = value
      @emit attributeName, value


  class SimpleTruncatedMeanFilter extends env.devices.Device

    filterValues: []
    mean: 0.0
    attributeValue: null

    constructor: (@config, lastState) ->
      @id = config.id
      @name = config.name
      @size = config.size
      @output = config.output

      @varManager = plugin.framework.variableManager #so you get the variableManager
      @_exprChangeListeners = []

      name = @output.name
      info = null

      if lastState[name]?
        @attributeValue = lastState[name]

      #@attributes = _.cloneDeep(@attributes)
      @attributes[name] = {
        description: name
        label: (if @output.label? then @output.label else "$#{name}")
        type: "number"
      }

      if @output.unit? and @output.unit.length > 0
        @attributes[name].unit = @output.unit

      if @output.discrete?
        @attributes[name].discrete = @output.discrete

      if @output.acronym?
        @attributes[name].acronym = @output.acronym

      @_createGetter(name, =>
        return Promise.resolve @attributeValue
      )

      evaluate = ( =>
        # wait till VariableManager is ready
        return Promise.delay(10).then( =>
          unless info?
            info = @varManager.parseVariableExpression(@output.expression)
            @varManager.notifyOnChange(info.tokens, evaluate)
            @_exprChangeListeners.push evaluate

          switch info.datatype
            when "numeric" then @varManager.evaluateNumericExpression(info.tokens)
            when "string" then @varManager.evaluateStringExpression(info.tokens)
            else
              assert false
        ).then((val) =>
          if val
            val = Number(val)
            @filterValues.push val
            if @filterValues.length > @size
              @filterValues.shift()

            processedValues = _.clone(@filterValues)
            if processedValues.length > 2
              processedValues.sort()
              processedValues.shift()
              processedValues.pop()

            @mean = processedValues.reduce(((a, b) => return a + b), 0) / processedValues.length

            env.logger.debug @mean, @filterValues, processedValues
            @_setAttribute name, @mean
          return @attributeValue
        )
      )
      evaluate()
      super()

    _setAttribute: (attributeName, value) ->
      @attributeValue = value
      @emit attributeName, value

  return plugin
