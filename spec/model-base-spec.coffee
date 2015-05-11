ModelBaseMixin = require '../lib/model-base'
Mapper = require '../lib/mapper'
Migration = require '../lib/migration'
path = require 'path'

describe 'ModelBaseMixin', ->
  [mapper, FakeModel] = []

  beforeEach (done) ->
    class FakeModel
      ModelBaseMixin.includeInto this
      constructor: (mapper) ->
        @initModel mapper
      Migration.createTable 'FakeModel', (t) ->
        t.addColumn 'id', 'INTEGER', primaryKey: true
        t.addColumn 'name', 'INTEGER'
        t.addColumn 'email', 'TEXT'

    FakeModel.models.FakeModel.should.equal FakeModel
    fileName = path.resolve(__dirname, 'temp/test.db')
    mapper = new Mapper(fileName)
    mapper.sync().then -> done()
    .catch (err) -> done(err)

  afterEach (done) ->
    FakeModel.drop(mapper)
    .then ->
      mapper.close()
      done()
    .catch(done)

  it 'get FakeModel attributes', (done) ->
    FakeModel.prototype.hasOwnProperty('name').should.ok
    FakeModel.prototype.hasOwnProperty('id').should.ok
    FakeModel.tableName.should.equal 'FakeModel'
    FakeModel.primaryKeyName.should.equal 'id'

    FakeModel.create(mapper, {name: 'hello', email: 'hello@xx.xx'})
    .then (model) ->
      model.name.should.equal 'hello'
      done()
    .catch done
