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
      if opts.primaryKey then @primaryKeyName = name
      Object.defineProperty @property, name,
        writable: true, _value: opts.default ? null,
        get: -> _value
        set: (val) ->
          _value = val
          @changeFields[name] = val

  Object.defineProperty this, 'tableName', {writable: true}
  Object.defineProperty this, 'primaryKeyName', {writable: true}

  @extendModel: (tableName, tableInfo) ->
    @tableName = tableName
    @extendAttrs tableInfo

  @find: ->

  @findAll: (opts) ->

  save: ->
    keyName = ModelBaseMixin.primaryKeyName
    unless @isInsert
      @query.insert(ModelBaseMixin.tableName, @changeFields).then (rowId) =>
        this[keyName] = rowId
    else
      tableName = ModelBaseMixin.tableName
      @query.update tableName, @changeFields, "#{keyName}": this[keyName]
    @changeFields = {}

  @create: ->
