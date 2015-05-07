ModelBaseMixin = require '../lib/model-base'
should = require 'should'

describe 'ModelBaseMixin', ->
  it '@included', ->
    class FakeModel
      ModelBaseMixin.includeInto this
    FakeModel.models.has(FakeModel).should.ok
