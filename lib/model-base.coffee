Mixin = require 'mixto'
_ = require 'underscore'

module.exports =
class ModelBaseMixin extends Mixin
  @models = {}

  initModel: ->
    @isInsert = false
    @changeFields = {}
    @query = @constructor.query

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

  @extendModel: (mapper, tableInfo) ->
    @query = mapper.getQuery()
    @cache = mapper.cache
    @tableName = tableInfo.tableName
    @primaryKeyName = tableInfo.primaryKeyName
    @extendAttrs tableInfo
    @belongsToAssos = new Map
    @hasOneAssos = new Map
    @hasManyAssos = new Map

  @wrapWhere: (where) ->
    unless _.isObject where
      where = {"#{@primaryKeyName}": where}
    where

  camelCase = (str) -> str[0].toLowerCase() + str[1..]
  pascalCase = (str) -> str[0].toUpper() + str[1..]

  @belongsTo: (TargetModel, opts) ->
    targetName = camelCase(TargetModel.name)
    opts.through ?= targetName + pascalCase(TargetModel.primaryKeyName)
    opts.as ?= targetName
    @belongsToAssos.set TargetModel, opts
    Model = this
    key = '_' + name
    Object.defineProperty @prototype, targetName,
      get: -> this[key]
      set: (val) ->
        origin = this[key]
        this[key] = val
        this[opts.through] = val[Model.primaryKeyName] # set the foreign key
        # {as} = origin.hasOneAssos.get(Model) or origin.hasManyAssos.get(Model)
        # if Array.isArray(as) then as[]
        Model

  @hasMany: (TargetModel, opts) ->
    targetName = camelCase(TargetModel.name) + 's'
    Model = this
    opts.through ?= camelCase(Model.name) + pascalCase(Model.primaryKeyName)
    opts.as ?= targetName
    @hasManyAssos.set TargetModel, opts
    key = '_' + name
    Object.defineProperty @prototype, targetName,
      get: -> this[key]
      set: (val) ->
        origin = this[key]

  @hasOne: (TargetModel) ->
    targetModelName = camelCase(TargetModel.name)
    Model = this
    opts.through ?= camelCase(Model.name) + pascalCase(Model.primaryKeyName)
    opts.as ?= targetModelName
    @hasOneAssos.set TargetModel, opts
    key = '_' + name
    Object.defineProperty @prototype, targetModelName,
      get: -> this[key]
      set: (val) ->
        origin = this[key]
        this[key] = val

  @find: (where, opts={}) ->
    opts.limit = 1
    @query.selectOne(@tableName, @wrapWhere(where), opts).then (res) =>
      @load(res)

  @findAll: (where, opts) ->
    @query.select(@tableName, @wrapWhere(where), opts).then (results) =>
      for res in results
        @load(res)

  @each: (where, opts, step, complete) ->
    if _.isFunction(where)
      step = where
      complete = opts
    else if _.isFunction(opts)
      step = opts
      complete = step
    @query.selectEach(@tableName, @wrapWhere(where), opts, step)

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

  @getById: (id) ->
    key = @tableName + '@' + id
    defer = Q.defer()
    if (val = @cache.get(key))?
      defer.resolve(val)
    else
      @query.selectOne(@tableName, @wrapWhere(id)).then (res) =>
        val = @load(res)
        @cache.set key, val
        defer.resolve val
      .catch (err) -> defer.reject(err)
    defer.promise

  @load: (obj) ->
    model = new this
    @isInsert = true
    model['_' + key] = val for key, val of obj
    model

  @new: (obj) ->
    model = new this
    for key, value of obj when @::hasOwnProperty(key)
      model[key] = value
    model

  @create: (obj) ->
    model = @new(obj)
    model.save().then -> model

  @drop: ->
    @query.dropTable @tableName
