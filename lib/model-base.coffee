Mixin = require 'mixto'

module.exports =
class ModelBaseMixin extends Mixin
  @models = new Set

  @included: ->
    ModelBaseMixin.models.add this

  find: ->

  findAll: ->
