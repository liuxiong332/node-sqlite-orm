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
      model.email.should.equal 'hello@xx.xx'
      done()
    .catch done

  it 'save attributes', (done) ->
    model = new FakeModel(mapper)
    model.name = 'nimei'
    model.save().then ->
      FakeModel.find(mapper, {name: 'nimei'})
    .then (resModel) ->
      resModel.id.should.equal model.id
    .then ->
      FakeModel.findAll(mapper, {name: 'nimei'})
    .then (resModels) ->
      resModels.length.should.equal 1
      resModels[0].id.should.equal model.id
    .then ->
      FakeModel.each mapper, {name: 'nimei'}, (err, res) ->
        return done(err) if err
        res.id.should.equal model.id
    .then -> done()
    .catch done
