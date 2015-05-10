Mixin = require 'mixto'

module.exports =
class ModelBaseMixin extends Mixin
  @models = {}

  initModel: ->
    @isInsert = false
    @changeFields = {}

  @included: ->
    ModelBaseMixin.models[this.name] = this if this.name

  # apply tableInfo's attributes into the Model's prototype,
  # so that the model has the db column variables
  @extendAttrs: (tableInfo) ->
    for name, opts in tableInfo.attributes when not @::hasOwnProperty(name)
      Object.defineProperty @property, name,
        writable: true, _value: opts.default ? null,
        get: -> _value
        set: (val) ->
          _value = val
          @changeFields[name] = val

  Object.defineProperty this, 'tableName', {writable: true}

  @extendModel: (tableName, tableInfo) ->
    @tableName = tableName
    @extendAttrs tableInfo

  find: ->

  findAll: ->

  save: ->
    unless @isInsert
      @query.insert ModelBaseMixin.tableName, @changeFields
    @changeFields = {}

  create: ->
