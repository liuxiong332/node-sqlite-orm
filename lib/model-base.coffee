Mixin = require 'mixto'

module.exports =
class ModelBaseMixin extends Mixin
  @models = {}

  @included: ->
    ModelBaseMixin.models[this.name] = this if this.name

  @extendAttrs: (tableInfo) ->
    for name, opts in tableInfo.attributes when not @::hasOwnProperty(name)
      Object.defineProperty @property, name, {writable: true, value: null}

  find: ->

  findAll: ->

  save: ->

  create: ->
