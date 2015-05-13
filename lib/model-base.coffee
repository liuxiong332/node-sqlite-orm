Mixin = require 'mixto'
_ = require 'underscore'
Q = require 'q'

module.exports =
class ModelBaseMixin extends Mixin
  @models = {}

  initModel: (params) ->
    @isInsert = false
    @changeFields = {}
    @query = @constructor.query
    this[key] = val for key, val of params

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
        get: -> this[key] ? null
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
        get: -> this[key] ? null
        set: (val) ->
          origin = this[key]
          setBelongsTo(Model, ChildModel, null, origin) if origin
          this[key] = val
          setBelongsTo(Model, ChildModel, this, val) if val

  @find: (where, opts={}) ->
    unless _.isObject(where)
      @getById(where)
    else
      opts.limit = 1
      @query.selectOne(@tableName, @wrapWhere(where), opts).then (res) =>
        @load(res)

  @findAll: (where, opts) ->
    @query.select(@tableName, @wrapWhere(where), opts).then (results) =>
      console.log 'findAll'
      console.log results
      promises = for res in results
        console.log res
        @load(res)
      Q.all promises

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
        Model = @constructor
        Model.cache.set Model.generateCacheKey(rowId), this
        @isInsert = true
        # Model.loadAssos(this)
    else if _.keys(@changeFields).length is 0
      Q()
    else
      where = "#{keyName}": this[keyName]
      @query.update(tableName, @changeFields, where).then =>
        @changeFields = {}

  @generateCacheKey: (id) -> @tableName + '@' + id

  @getById: (id) ->
    key = @generateCacheKey(id)
    if (model = @cache.get(key))?
      Q(model)
    else
      @query.selectOne(@tableName, @wrapWhere(id)).then (res) =>
        console.log res
        @loadNoCache(res)

  @loadNoCache: (obj) ->
    model = new this
    @isInsert = true
    model['_' + key] = val for key, val of obj
    primaryVal = obj[@primaryKeyName]
    @cache.set @generateCacheKey(primaryVal), model
    @loadAssos(model).then -> model

  @load: (obj) ->
    primaryVal = obj[@primaryKeyName]
    cacheKey = @generateCacheKey(primaryVal)
    if (model = @cache.get(cacheKey))?
      Q(model)
    else
      @loadNoCache(obj)

  @loadAssos: (model) ->
    Q.all [@loadBelongsTo(model), @loadHasOne(model), @loadHasMany(model)]

  @loadBelongsTo: (model) ->
    console.log 'loadBelongsTo'
    promises = []
    @belongsToAssos.forEach (opts, ParentModel) ->
      if (id = model[opts.through])?
        console.log id
        promises.push ParentModel.getById(id).then (parent) ->
          model[opts.as] = parent
    Q.all promises

  @loadHasOne: (model) ->
    keyName = @primaryKeyName
    promises = []
    @hasOneAssos.forEach (opts, ChildModel) ->
      console.log opts
      where = "#{opts.through}": model[keyName]
      promises.push ChildModel.find(where).then (child) ->
        model[opts.as] = child
    Q.all promises

  @loadHasMany: (model) ->
    keyName = @primaryKeyName
    promises = []
    @hasManyAssos.forEach (opts, ChildModel) ->
      where = "#{opts.through}": model[keyName]
      console.log opts
      promises.push ChildModel.findAll(where).then (children) ->
        console.log children
        model[opts.as].splice(0, 0, children)
    Q.all promises

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
