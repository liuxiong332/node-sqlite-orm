Mixin = require 'mixto'
Q = require 'q'
ObserverArray = require './observer-array'
_ = require 'underscore'

module.exports =
class ModelAssociation extends Mixin
  @initAssos: ->
    @belongsToAssos = new Map
    @hasOneAssos = new Map
    @hasManyAssos = new Map

  @extendAssos: ->
    @extendBelongsTo()
    @extendHasOne()
    @extendHasMany()

  removeFromHasAssos = (ParentModel, ChildModel, parent, child) ->
    if (opts = ParentModel.hasOneAssos.get(ChildModel))?
      parent[privateName(opts.as)] = null
    else if (opts = ParentModel.hasManyAssos.get(ChildModel))?
      children = parent[opts.as]
      children.scopeUnobserve ->
        index = children.indexOf(child)
        children.splice(index, 1) if index isnt -1

  addIntoHasAssos = (ParentModel, ChildModel, parent, child) ->
    if (opts = ParentModel.hasOneAssos.get(ChildModel))?
      parent[privateName(opts.as)] = child
    else if (opts = ParentModel.hasManyAssos.get(ChildModel))?
      children = parent[opts.as]
      children.scopeUnobserve -> children.push(child)

  setBelongsTo = (ParentModel, ChildModel, parent, child) ->
    if (opts = ChildModel.belongsToAssos.get(ParentModel))?
      child[privateName(opts.as)] = parent
      # set the foreign key
      primaryVal = if parent then parent[ParentModel.primaryKeyName] else null
      child[opts.through] = primaryVal

  camelCase = (str) -> str[0].toLowerCase() + str[1..]
  pascalCase = (str) -> str[0].toUpperCase() + str[1..]
  privateName = (name) -> '_' + name

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

  _watchHasManyChange = (change, val, Model, ChildModel) ->
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
      opts.as ?= camelCase(ChildModel.name) + 's'
      key = privateName(opts.as)
      Object.defineProperty @prototype, opts.as, get: ->
        unless (val = this[key])?
          val = this[key] = new ObserverArray (changes) =>
            for change in changes
              _watchHasManyChange.call(this, change, val, Model, ChildModel)
          val.observe()
        val

  @hasOne: (ChildModel, opts={}) ->
    @hasOneAssos.set ChildModel, opts

  @extendHasOne: ->
    Model = this
    @hasOneAssos.forEach (opts, ChildModel) =>
      opts.as ?= camelCase(ChildModel.name)
      key = privateName(opts.as)
      Object.defineProperty @prototype, opts.as,
        get: -> this[key] ? null
        set: (val) ->
          origin = this[key]
          setBelongsTo(Model, ChildModel, null, origin) if origin
          this[key] = val
          setBelongsTo(Model, ChildModel, this, val) if val

  @loadAssos: (model) ->
    Q.all [@loadBelongsTo(model), @loadHasOne(model), @loadHasMany(model)]

  @loadBelongsTo: (model) ->
    promises = []
    @belongsToAssos.forEach (opts, ParentModel) ->
      if (id = model[opts.through])?
        promises.push ParentModel.getById(id).then (parent) ->
          model[privateName(opts.as)] = parent
    Q.all promises

  @loadHasOne: (model) ->
    keyName = @primaryKeyName
    promises = []
    @hasOneAssos.forEach (opts, ChildModel) =>
      opts.through ?= ChildModel.belongsToAssos.get(this).through
      where = "#{opts.through}": model[keyName]
      promises.push ChildModel.find(where).then (child) ->
        model[privateName(opts.as)] = child
    Q.all promises

  @loadHasMany: (model) ->
    keyName = @primaryKeyName
    promises = []
    @hasManyAssos.forEach (opts, ChildModel) =>
      opts.through ?= ChildModel.belongsToAssos.get(this).through
      where = "#{opts.through}": model[keyName]
      promises.push ChildModel.findAll(where).then (children) ->
        members = model[opts.as]
        members.scopeUnobserve -> members.splice(0, 0, children)
    Q.all promises
