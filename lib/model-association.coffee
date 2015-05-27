Mixin = require 'mixto'
Q = require 'q'
ObserverArray = require './observer-array'
_ = require 'underscore'

module.exports =
class ModelAssociation extends Mixin
  @_initAssos: ->
    @counter = 0
    @belongsToAssos = []
    @hasOneAssos = []
    @hasManyAssos = []
    @hasManyBelongsToAssos = []

  ModelBase = null

  @included: ->
    ModelBase = this

  @extendAssos: ->
    @extendBelongsTo(opts) for opts in @belongsToAssos when not opts.virtual
    @extendHasOne(opts) for opts in @hasOneAssos when not opts.virtual
    @extendHasMany(opts) for opts in @hasManyAssos when not opts.virtual
    for opts in @hasManyBelongsToAssos when not opts.virtual
      @extendHasManyBelongsTo(opts)

  setBelongsTo = (childOpts, child, parent) ->
    child[privateName(childOpts.as)] = parent
    # set the foreign key
    targetName = childOpts.Target.primaryKeyName
    primaryVal = null
    if parent
      primaryVal = parent[targetName]
      unless primaryVal
        throw new Error("parent is invalid, you may need insert to DB first")
    child[childOpts.through] = primaryVal

  belongsToHandler = (opts) ->
    add: (child, parent) -> setBelongsTo(opts, child, parent)
    remove: (child, parent) -> setBelongsTo(opts, child, null)

  createVirtualBelongsTo = (Model, parentOpts) ->
    parentOpts.remoteVirtual = true
    ChildModel = parentOpts.Target
    throw new Error('through is invalid') unless parentOpts.through
    opts =
      through: parentOpts.through
      as: "@#{ChildModel.counter++}", virtual: true, Target: Model
    ChildModel.belongsTo(Model, opts)
    ChildModel.extendBelongsTo(opts, hasAssosHandler(parentOpts.as))
    belongsToHandler(opts)

  getHandlerInBelongsAssos = (Model, parentOpts) ->
    ChildModel = parentOpts.Target
    for childOpts in ChildModel.belongsToAssos when childOpts.Target is Model
      if childOpts.through is parentOpts.through
        return belongsToHandler(childOpts)
    return createVirtualBelongsTo(Model, parentOpts)

  camelCase = (str) -> str[0].toLowerCase() + str[1..]
  pascalCase = (str) -> str[0].toUpperCase() + str[1..]
  privateName = (name) -> '_' + name

  defaultThrough = (ParentModel) ->
    camelCase(ParentModel._name) + pascalCase(ParentModel.primaryKeyName)

  @_getModel: (name) ->
    return name if name instanceof Function
    Model = ModelBase.models[name]
    throw new Error("model #{name} have not defined") unless Model
    Model

  @belongsTo: (ParentModel, opts={}) ->
    opts.through ?= defaultThrough(ParentModel)
    opts.as ?= camelCase(ParentModel._name)
    opts.Target = @_getModel(ParentModel)
    @belongsToAssos.push opts

  removeFromHasMany = (as, parent, child) ->
    children = parent[as]
    children.scopeUnobserve ->
      index = children.indexOf(child)
      children.splice(index, 1) if index isnt -1

  addIntoHasMany = (as, parent, child) ->
    children = parent[as]
    children.scopeUnobserve -> children.push(child)

  hasAssosHandler = (as) ->
    remove: removeFromHasMany.bind(null, as)
    add: addIntoHasMany.bind(null, as)

  hasManyBelongsToAssosHandler = (opts, targetOpts) ->
    MidModel = ModelBase.models[opts.midTableName]
    st = opts.sourceThrough
    tt = opts.targetThrough

    getWhere = (target, source) ->
      sourceKeyName = source.constructor.primaryKeyName
      targetKeyName = target.constructor.primaryKeyName
      "#{st}": source[sourceKeyName]
      "#{tt}": target[targetKeyName]

    add: (target, source) ->
      addIntoHasMany(targetOpts.as, target, source)
      MidModel.create getWhere(target, source)
      .then (midModel) ->
        opts.midModel = targetOpts.midModel = midModel

    remove: (target, source) ->
      removeFromHasMany(targetOpts.as, target, source)
      if opts.midModel
        opts.midModel.destroy()
      else
        MidModel.remove getWhere(target, source)

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
      ParentModel.extendHasMany opts, belongsToHandler(childOpts)
      hasAssosHandler(opts.as)

    getHandlerFromHasOne(Model) or
    getHandlerFromHasMany(Model) or
    createVirtualHasMany(Model, opts)

  getHandlerForHasBelongsAssos = (Model, opts) ->
    Target = opts.Target
    compareTargetOpts = (targetOpts) ->
      targetOpts.Target is Model and
      targetOpts.midTableName is opts.midTableName

    createVirtualHasManyBelongsTo = (Model, opts) ->
      opts.remoteVirtual = true
      targetOpts =
        as: "@#{Target.counter++}"
        sourceThrough: opts.targetThrough
        targetThrough: opts.sourceThrough
        midTableName: opts.midTableName
        virtual: true, Target: Model
      Target.hasManyBelongsTo(Model, targetOpts)
      targetHandler = hasManyBelongsToAssosHandler(targetOpts, opts)
      Target.extendHasManyBelongsTo targetOpts, targetHandler
      hasManyBelongsToAssosHandler(opts, targetOpts)

    for targetOpts in Target.hasManyBelongsToAssos
      if compareTargetOpts(targetOpts)
        return hasManyBelongsToAssosHandler(opts, targetOpts)
    createVirtualHasManyBelongsTo(Model, opts)

  @extendBelongsTo: (opts, handler) ->
    as = opts.as
    key = privateName(as)
    handler ?= getHandlerForHasAssos(this, opts)
    [setHook, getHook] = @_getHook(as)
    Object.defineProperty @prototype, as,
      get: ->
        val = this[key] ? null
        val = getHook(val) if getHook
        val
      set: (val) ->
        origin = this[key]
        val = setHook(val) if setHook
        unless val is origin
          setBelongsTo(opts, this, val ? null)
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
      handler.remove(removed, this)
    for created in creates when created
      handler.add(created, this)

  @hasMany: (ChildModel, opts={}) ->
    opts.through ?= defaultThrough(this)
    opts.as ?= camelCase(ChildModel._name) + 's'
    opts.Target = @_getModel(ChildModel)
    @hasManyAssos.push opts

  arrayGetter = (key, handler) ->
    unless (val = this[key])?
      val = this[key] = new ObserverArray (changes) =>
        for change in changes
          _watchHasManyChange.call(this, change, val, handler)
      # val.observe()
    val

  @extendHasMany: (opts, handler) ->
    handler ?= getHandlerInBelongsAssos(this, opts)
    key = privateName(opts.as)
    Object.defineProperty @prototype, opts.as, get: ->
      arrayGetter.call(this, key, handler)

  @hasManyBelongsTo: (TargetModel, opts={}) ->
    opts.midTableName ?= this._name + TargetModel._name
    opts.sourceThrough ?= defaultThrough(this)
    opts.targetThrough ?= defaultThrough(TargetModel)
    opts.as ?= camelCase(TargetModel._name) + 's'
    opts.Target = @_getModel(TargetModel)
    @hasManyBelongsToAssos.push opts

  @extendHasManyBelongsTo: (opts, handler) ->
    handler ?= getHandlerForHasBelongsAssos(this, opts)
    key = privateName(opts.as)
    Object.defineProperty @prototype, opts.as, get: ->
      arrayGetter.call(this, key, handler)

  @hasOne: (ChildModel, opts={}) ->
    opts.through ?= defaultThrough(this)
    opts.as ?= camelCase(ChildModel._name)
    opts.Target = @_getModel(ChildModel)
    @hasOneAssos.push opts

  @extendHasOne: (opts) ->
    handler = getHandlerInBelongsAssos(this, opts)
    key = privateName(opts.as)
    [setHook, getHook] = @_getHook(opts.as)
    Object.defineProperty @prototype, opts.as,
      get: ->
        val = this[key] ? null
        val = getHook(val) if getHook
        val
      set: (val) ->
        origin = this[key]
        val = setHook(val) if setHook
        unless val is origin
          handler.remove(origin, null) if origin
          this[key] = val ? null
          handler.add(val, this) if val

  @loadAssos: (model) ->
    Q.all [
      @loadBelongsTo(model), @loadHasOne(model), @loadHasMany(model),
      @loadHasManyBelongsTo(model)
    ]

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

  @loadHasManyBelongsTo: (model) ->
    keyName = @primaryKeyName
    promises = []
    @hasManyBelongsToAssos.forEach (opts) ->
      return if opts.virtual
      midModel = ModelBase.models[opts.midTableName]
      where = "#{opts.sourceThrough}": model[keyName]
      promises.push midModel.findAll(where).then (children) ->
        return if children.length is 0
        targetThrough = opts.targetThrough
        targetKeyName = opts.Target.primaryKeyName
        targetIds = (child[targetThrough] for child in children)
        where = "#{targetKeyName}": {'$in': targetIds}
        opts.Target.findAll(where).then (targets) ->
          members = model[opts.as]
          if opts.remoteVirtual
            members.splice(0, 0, targets...)
          else
            members.scopeUnobserve -> members.splice(0, 0, targets...)
    Q.all promises

  destroyAssos: ->
    Model = this.constructor

    this[opts.as] = null for opts in Model.belongsToAssos
    this[opts.as] = null for opts in Model.hasOneAssos
    this[opts.as].clear() for opts in Model.hasManyAssos
    this[opts.as].clear() for opts in Model.hasManyBelongsToAssos
