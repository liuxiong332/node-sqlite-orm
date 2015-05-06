ModelBase = require '../lib/model-base'
should = require 'should'

describe 'ModelBase', ->
  it '@included', ->
    class FakeModel extends ModelBase

    FakeModel.models.has(FakeModel).should.ok
