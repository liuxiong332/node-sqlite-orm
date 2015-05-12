Mixin = require 'mixto'
_ = require 'underscore'

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
    key = '_' + name
    Object.defineProperty @prototype, name,
      get: -> this[key] ? opts.default
      set: (val) ->
        this[key] = val
        @changeFields[name] = val

  # apply tableInfo's attributes into the Model's prototype,
  # so that the model has the db column variables
  @extendAttrs: (tableInfo) ->
    for name, opts of tableInfo.attributes when not @::hasOwnProperty(name)
      @defineAttr name, opts

  Object.defineProperty this, 'tableName', {writable: true}
  Object.defineProperty this, 'primaryKeyName', {writable: true}

  @extendModel: (tableName, tableInfo) ->
    @tableName = tableName
    @primaryKeyName = tableInfo.primaryKeyName
    @extendAttrs tableInfo

  @wrapWhere: (where) ->
    unless _.isObject where
      where = {"#{@primaryKeyName}": where}
    where

  @find: (mapper, where, opts={}) ->
    opts.limit = 1
    mapper.query.selectOne(@tableName, @wrapWhere(where), opts).then (res) =>
      @load(mapper, res)

  @findAll: (mapper, where, opts) ->
    mapper.query.select(@tableName, @wrapWhere(where), opts).then (results) =>
      for res in results
        @load(mapper, res)

  @each: (mapper, where, opts, step, complete) ->
    if _.isFunction(where)
      step = where
      complete = opts
    else if _.isFunction(opts)
      step = opts
      complete = step
    mapper.query.selectEach(@tableName, @wrapWhere(where), opts, step)

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

  @load: (mapper, obj) ->
    model = new this(mapper)
    @isInsert = true
    model['_' + key] = val for key, val of obj
    model

  @new: (mapper, obj) ->
    model = new this(mapper)
    for key, value of obj when @::hasOwnProperty(key)
      model[key] = value
    model

  @create: (mapper, obj) ->
    model = @new(mapper, obj)
    model.save().then -> model

  @drop: (mapper) ->
    mapper.getQuery().dropTable @tableName
