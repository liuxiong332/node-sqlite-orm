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
    @belongsToAssos = new Map
    @hasOneAssos = new Map
    @hasManyAssos = new Map

  @defineAttr: (name, opts) ->
    key = '_' + name
    opts.default ?= null
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

  @extendAssos: ->
    @extendBelongsTo()
    @extendHasOne()
    @extendHasMany()

  @wrapWhere: (where) ->
    unless _.isObject where
      where = {"#{@primaryKeyName}": where}
    where

  camelCase = (str) -> str[0].toLowerCase() + str[1..]
  pascalCase = (str) -> str[0].toUpperCase() + str[1..]
  privateName = (name) -> '_' + name

  removeFromHasAssos = (ParentModel, ChildModel, parent, child) ->
    if (opts = ParentModel.hasOneAssos.get(ChildModel))?
      parent[privateName(opts.as)] = null
    else if (opts = ParentModel.hasManyAssos.get(ChildModel))?
      children = parent[opts.as]
      index = children.indexOf(child)
      children.splice(index, 1) if index isnt -1

  addIntoHasAssos = (ParentModel, ChildModel, parent, child) ->
    if (opts = ParentModel.hasOneAssos.get(ChildModel))?
      parent[privateName(opts.as)] = child
    else if (opts = ParentModel.hasManyAssos.get(ChildModel))?
      children = parent[opts.as]
      children.push(child)

  setBelongsTo = (ParentModel, ChildModel, parent, child) ->
    if (opts = ChildModel.belongsToAssos.get(ParentModel))?
      child[privateName(opts.as)] = parent
      # set the foreign key
      primaryVal = if parent then parent[ParentModel.primaryKeyName] else null
      child[opts.through] = primaryVal

  defaultThrough = (ParentModel) ->
    camelCase(ParentModel.name) + pascalCase(ParentModel.primaryKeyName)

  @belongsTo: (ParentModel, opts={}) ->
    @belongsToAssos.set ParentModel, opts

  @extendBelongsTo: ->
    Model = this
    @belongsToAssos.forEach (opts, ParentModel) =>
      opts.through ?= defaultThrough(ParentModel)
      opts.as ?= camelCase(ParentModel.name)
      key = privateName(opts.as)
      Object.defineProperty @prototype, opts.as,
        get: -> this[key]
        set: (val) ->
          origin = this[key]
          setBelongsTo(ParentModel, Model, val, this)
          removeFromHasAssos(ParentModel, Model, origin, this) if origin
          addIntoHasAssos(ParentModel, Model, val, this) if val

  _watchHasManyChange: (change, val, Model, ChildModel) ->
    if change.type is 'update'
      removes = [change.oldValue]
      creates = [val[change.name]]
    else if change.type is 'splice'
      removes = change.removed
      index = change.index
      creates = val.slice(index, index + change.addedCount)
    for removed in removes when removed
      setBelongsTo(Model, ChildModel, null, removed)
    for created in creates when created
      setBelongsTo(Model, ChildModel, this, created)

  @hasMany: (ChildModel, opts={}) ->
    @hasManyAssos.set ChildModel, opts

  @extendHasMany: ->
    Model = this
    @hasManyAssos.forEach (opts, ChildModel) =>
      opts.through ?= defaultThrough(this)
      opts.as ?= camelCase(ChildModel.name) + 's'
      key = privateName(opts.as)
      Object.defineProperty @prototype, opts.as, get: ->
        unless (val = this[key])?
          val = this[key] = []
          Array.observe val, (changes) =>
            for change in changes
              @_watchHasManyChange(change, val, Model, ChildModel)
        val

  @hasOne: (ChildModel, opts={}) ->
    @hasOneAssos.set ChildModel, opts

  @extendHasOne: ->
    Model = this
    @hasOneAssos.forEach (opts, ChildModel) =>
      opts.through ?= defaultThrough(this)
      opts.as ?= camelCase(ChildModel.name)
      key = privateName(opts.as)
      Object.defineProperty @prototype, opts.as,
        get: -> this[key]
        set: (val) ->
          origin = this[key]
          setBelongsTo(Model, ChildModel, null, origin) if origin
          this[key] = val
          setBelongsTo(Model, ChildModel, this, val) if val

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
    delete @models[@name]
    @query.dropTable @tableName
