Mixin = require 'mixto'

module.exports =
class ModelBase extends Mixin
  @models = new Set

  @included: ->
    ModelBase.models.add this
