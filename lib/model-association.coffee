Mixin = require 'mixto'
Q = require 'q'
ObserverArray = require './observer-array'
_ = require 'underscore'

module.exports =
class ModelAssociation extends Mixin
  @_initAssos: ->
    @belongsToAssos = []
    @hasOneAssos = []
    @hasManyAssos = []
    @hasManyBelongsToAssos = []

  @extendAssos: ->
    @counter = 0
    belongsToAssos = _.clone(@belongsToAssos)
    hasManyAssos =  _.clone(@hasManyAssos)
    @extendBelongsTo(opts) for opts in belongsToAssos
    @extendHasOne(opts) for opts in @hasOneAssos
    @extendHasMany(opts) for opts in hasManyAssos

  setBelongsTo = (childOpts, parent, child) ->
    child[privateName(childOpts.as)] = parent
    # set the foreign key
    targetName = childOpts.Target.primaryKeyName
    primaryVal = null
    if parent
      primaryVal = parent[targetName]
      unless primaryVal
        throw new Error("parent is invalid, you may need insert to DB first")
    child[childOpts.through] = primaryVal

  createVirtualBelongsTo = (Model, parentOpts) ->
    parentOpts.remoteVirtual = true
    ChildModel = parentOpts.Target
    throw new Error('through is invalid') unless parentOpts.through
    opts =
      through: parentOpts.through
      as: "@#{ChildModel.counter++}", virtual: true, Target: Model
    ChildModel.belongsTo(Model, opts)
    ChildModel.extendBelongsTo(opts, hasAssosHandler(parentOpts.as))
    return setBelongsTo.bind(null, opts)

  getHandlerInBelongsAssos = (Model, parentOpts) ->
    ChildModel = parentOpts.Target
    for childOpts in ChildModel.belongsToAssos when childOpts.Target is Model
      if childOpts.through is parentOpts.through
        return setBelongsTo.bind(null, childOpts)
    return createVirtualBelongsTo(Model, parentOpts)

  camelCase = (str) -> str[0].toLowerCase() + str[1..]
  pascalCase = (str) -> str[0].toUpperCase() + str[1..]
  privateName = (name) -> '_' + name

  defaultThrough = (ParentModel) ->
    camelCase(ParentModel.name) + pascalCase(ParentModel.primaryKeyName)

  @belongsTo: (ParentModel, opts={}) ->
    opts.through ?= defaultThrough(ParentModel)
    opts.as ?= camelCase(ParentModel.name)
    opts.Target = ParentModel
    @belongsToAssos.push opts

  hasAssosHandler = (as) ->
    removeFromHasMany = (parent, child) ->
      children = parent[as]
      children.scopeUnobserve ->
        index = children.indexOf(child)
        children.splice(index, 1) if index isnt -1

    addIntoHasMany = (parent, child) ->
      children = parent[as]
      children.scopeUnobserve -> children.push(child)

    return {remove: removeFromHasMany, add: addIntoHasMany}

  getHandlerForHasAssos = (Model, opts) ->
    ParentModel = opts.Target
    getHandlerFromHasOne = (Model) ->
      for parentOpts in ParentModel.hasOneAssos
        if parentOpts.Target is Model and opts.through is parentOpts.through
          changeHandler = (parent, child) ->
            parent[privateName(parentOpts.as)] = child
          return {remove: changeHandler, add: changeHandler}

    getHandlerFromHasMany = (Model) ->
      for parentOpts in ParentModel.hasManyAssos
        if parentOpts.Target is Model and opts.through is parentOpts.through
          return hasAssosHandler(parentOpts.as)

    createVirtualHasMany = (Model, childOpts) ->
      childOpts.remoteVirtual = true
      opts =
        as: "@#{ParentModel.counter++}"
        through: childOpts.through, virtual: true, Target: Model
      ParentModel.hasMany(Model, opts)
      ParentModel.extendHasMany opts, setBelongsTo.bind(null, childOpts)
      hasAssosHandler(opts.as)

    getHandlerFromHasOne(Model) or
    getHandlerFromHasMany(Model) or
    createVirtualHasMany(Model, opts)

  # getHandlerForHasBelongsAssos = (Model, opts) ->
  #   Target = opts.Target
  #   for targetOpts in @Target.hasManyBelongsToAssos
  #     if targetOpts.Target is Model

  @extendBelongsTo: (opts, handler) ->
    key = privateName(opts.as)
    handler ?= getHandlerForHasAssos(this, opts)
    Object.defineProperty @prototype, opts.as,
      get: -> this[key] ? null
      set: (val) ->
        origin = this[key]
        setBelongsTo(opts, val, this)
        if handler
          handler.remove(origin, this) if origin
          handler.add(val, this) if val

  _watchHasManyChange = (change, val, handler) ->
    if change.type is 'update'
      removes = [change.oldValue]
      creates = [val.get(change.name)]
    else if change.type is 'splice'
      removes = change.removed
      index = change.index
      creates = val.slice(index, index + change.addedCount)
    for removed in removes when removed
      handler(null, removed)
    for created in creates when created
      handler(this, created)

  @hasMany: (ChildModel, opts={}) ->
    opts.through ?= defaultThrough(this)
    opts.as ?= camelCase(ChildModel.name) + 's'
    opts.Target = ChildModel
    @hasManyAssos.push opts

  @extendHasMany: (opts, handler) ->
    handler ?= getHandlerInBelongsAssos(this, opts)
    key = privateName(opts.as)
    Object.defineProperty @prototype, opts.as, get: ->
      unless (val = this[key])?
        val = this[key] = new ObserverArray (changes) =>
          for change in changes
            _watchHasManyChange.call(this, change, val, handler)
        val.observe()
      val

  @hasManyBelongsTo: (TargetModel, opts={}) ->
    opts.midTableName = this.name + TargetModel.name
    opts.sourceThrough ?= defaultThrough(this)
    opts.targetThrough ?= defaultThrough(TargetModel)
    opts.as ?= camelCase(TargetModel.name) + 's'
    opts.Target = TargetModel
    @hasManyBelongsToAssos.push opts

  @extendHasManyBelongsTo: (opts, handler) ->
    handler ?= getHandlerInBelongsAssos(this, opts)
    key = privateName(opts.as)
    Object.defineProperty @prototype, opts.as, get: ->
      unless (val = this[key])?
        val = this[key] = new ObserverArray (changes) =>
          for change in changes
            _watchHasManyChange.call(this, change, val, handler)
        val.observe()
      val

  @hasOne: (ChildModel, opts={}) ->
    opts.through ?= defaultThrough(this)
    opts.as ?= camelCase(ChildModel.name)
    opts.Target = ChildModel
    @hasOneAssos.push opts

  @extendHasOne: (opts) ->
    handler = getHandlerInBelongsAssos(this, opts)
    key = privateName(opts.as)
    Object.defineProperty @prototype, opts.as,
      get: -> this[key] ? null
      set: (val) ->
        origin = this[key]
        handler(null, origin) if origin
        this[key] = val
        handler(this, val) if val

  @loadAssos: (model) ->
    Q.all [@loadBelongsTo(model), @loadHasOne(model), @loadHasMany(model)]

  @loadBelongsTo: (model) ->
    promises = []
    @belongsToAssos.forEach (opts) ->
      if not opts.virtual and (id = model[opts.through])?
        promises.push opts.Target.getById(id).then (parent) ->
          if parent
            as = if opts.remoteVirtual then opts.as else privateName(opts.as)
            model[as] = parent
    Q.all promises

  @loadHasOne: (model) ->
    keyName = @primaryKeyName
    promises = []
    @hasOneAssos.forEach (opts) ->
      return if opts.virtual
      where = "#{opts.through}": model[keyName]
      promises.push opts.Target.find(where).then (child) ->
        model[privateName(opts.as)] = child if child
    Q.all promises

  @loadHasMany: (model) ->
    keyName = @primaryKeyName
    promises = []
    @hasManyAssos.forEach (opts) ->
      return if opts.virtual
      where = "#{opts.through}": model[keyName]
      promises.push opts.Target.findAll(where).then (children) ->
        return if children.length is 0
        members = model[opts.as]
        if opts.remoteVirtual
          members.splice(0, 0, children...)
        else
          members.scopeUnobserve -> members.splice(0, 0, children...)
    Q.all promises

  destroyAssos: ->
    Model = this.constructor

    this[opts.as] = null for opts in Model.belongsToAssos
    this[opts.as] = null for opts in Model.hasOneAssos
    for opts in Model.hasManyAssos
      children = this[opts.as]
      children.splice(0, children.length)
