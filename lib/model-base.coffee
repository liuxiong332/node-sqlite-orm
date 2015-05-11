Mixin = require 'mixto'

module.exports =
class ModelBaseMixin extends Mixin
  @models = {}

  initModel: (mapper) ->
    @isInsert = false
    @changeFields = {}
    @query = mapper.query

  @included: ->
    ModelBaseMixin.models[this.name] = this if this.name

  @defineAttr: (name, opts) ->
    _value = opts.default ? null
    Object.defineProperty @prototype, name,
      get: -> _value
      set: (val) ->
        _value = val
        @changeFields[name] = val
  # apply tableInfo's attributes into the Model's prototype,
  # so that the model has the db column variables
  @extendAttrs: (tableInfo) ->
    for name, opts of tableInfo.attributes when not @::hasOwnProperty(name)
      @primaryKeyName = name if opts.primaryKey
      @defineAttr name, opts

  Object.defineProperty this, 'tableName', {writable: true}
  Object.defineProperty this, 'primaryKeyName', {writable: true}

  @extendModel: (tableName, tableInfo) ->
    @tableName = tableName
    @extendAttrs tableInfo

  @wrapWhere: (where) ->
    unless _.isObject where
      where = {"#{@primaryKeyName}": where}
    where

  @find: (mapper, where, opts) ->
    opts.limit = 1
    @query.selectOne(@tableName, @wrapWhere(where), opts).then (res) =>
      @create(mapper, res)

  @findAll: (mapper, where, opts) ->
    @query.select(@tableName, @wrapWhere(where), opts).then (results) =>
      createPromises = for res in results
        @create(mapper, res)
      Q.all createPromises

  save: ->
    Constructor = @constructor
    keyName = Constructor.primaryKeyName
    tableName = Constructor.tableName
    unless @isInsert
      @query.insert(tableName, @changeFields).then (rowId) =>
        this[keyName] = rowId
        @changeFields = {}
        @isInsert = true
    else
      where = "#{keyName}": this[keyName]
      @query.update(tableName, @changeFields, where).then =>
        @changeFields = {}

  @create: (mapper, obj) ->
    model = new this(mapper)
    console.log model.hasOwnProperty('id')
    for key, value of obj when @::hasOwnProperty(key)
      model[key] = value
    model.save().then -> model

  @drop: (mapper) ->
    mapper.getQuery().dropTable @tableName
