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

  @extendAssos: ->
    @extendBelongsTo()
    @extendHasOne()
    @extendHasMany()

  setBelongsTo = (childOpts, parent, child) ->
    child[privateName(childOpts.as)] = parent
    # set the foreign key
    targetName = childOpts.Target.primaryKeyName
    primaryVal = if parent then parent[targetName] else null
    child[childOpts.through] = primaryVal

  getHandlerInBelongsAssos = (Model, parentOpts) ->
    for childOpts in parentOpts.Target.belongsToAssos
      parentOpts.through ?= childOpts.through
      if childOpts.through is parentOpts.through and Model is childOpts.Target
        return setBelongsTo.bind(null, childOpts)

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

  addIntoHasMany = (as, parent, child) ->
    children = parent[as]
    children.scopeUnobserve -> children.push(child)

  changeFromHasOne = (as, parent, child) ->
    parent[privateName(as)] = child

  removeFromHasMany = (as, parent, child) ->
    children = parent[as]
    children.scopeUnobserve ->
      index = children.indexOf(child)
      children.splice(index, 1) if index isnt -1

  # compare the parentOpts with childOpts
  compareParentOpts = (parentOpts, Model, childOpts) ->
    parentOpts.through ?= childOpts.through
    parentOpts.through is childOpts.through and parentOpts.Target is Model

  getHandlerFromHasAssos = (Model, childOpts) ->
    ParentModel = childOpts.Target
    for parentOpts in ParentModel.hasOneAssos
      if compareParentOpts parentOpts, Model, childOpts
        changeHandler = changeFromHasOne.bind(null, parentOpts.as)
        return {remove: changeHandler, add: changeHandler}

    for parentOpts in ParentModel.hasManyAssos
      if compareParentOpts parentOpts, Model, childOpts
        as = parentOpts.as
        remove = removeFromHasMany.bind(null, as)
        add = addIntoHasMany.bind(null, as)
        return {remove, add}

  @extendBelongsTo: ->
    @belongsToAssos.forEach (opts) =>
      key = privateName(opts.as)
      handler = getHandlerFromHasAssos(this, opts)
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
      creates = [val[change.name]]
    else if change.type is 'splice'
      removes = change.removed
      index = change.index
      creates = val.slice(index, index + change.addedCount)
    for removed in removes when removed
      handler(null, removed)
    for created in creates when created
      handler(this, created)

  @hasMany: (ChildModel, opts={}) ->
    opts.as ?= camelCase(ChildModel.name) + 's'
    opts.Target = ChildModel
    @hasManyAssos.push opts

  @extendHasMany: ->
    @hasManyAssos.forEach (opts) =>
      handler = getHandlerInBelongsAssos(this, opts)
      key = privateName(opts.as)
      Object.defineProperty @prototype, opts.as, get: ->
        unless (val = this[key])?
          val = this[key] = new ObserverArray (changes) =>
            for change in changes
              _watchHasManyChange.call(this, change, val, handler)
          val.observe()
        val

  @hasOne: (ChildModel, opts={}) ->
    opts.as ?= camelCase(ChildModel.name)
    opts.Target = ChildModel
    @hasOneAssos.push opts

  @extendHasOne: ->
    @hasOneAssos.forEach (opts) =>
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
      if (id = model[opts.through])?
        promises.push opts.Target.getById(id).then (parent) ->
          model[privateName(opts.as)] = parent
    Q.all promises

  @loadHasOne: (model) ->
    keyName = @primaryKeyName
    promises = []
    @hasOneAssos.forEach (opts) ->
      where = "#{opts.through}": model[keyName]
      promises.push opts.Target.find(where).then (child) ->
        model[privateName(opts.as)] = child
    Q.all promises

  @loadHasMany: (model) ->
    keyName = @primaryKeyName
    promises = []
    @hasManyAssos.forEach (opts) ->
      where = "#{opts.through}": model[keyName]
      promises.push opts.Target.findAll(where).then (children) ->
        members = model[opts.as]
        members.scopeUnobserve -> members.splice(0, 0, children...)
    Q.all promises
