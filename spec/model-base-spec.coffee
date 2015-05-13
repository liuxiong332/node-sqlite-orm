ModelBaseMixin = require '../lib/model-base'
Mapper = require '../lib/mapper'
Migration = require '../lib/migration'
path = require 'path'

describe 'ModelBaseMixin', ->
  [mapper, FakeModel] = []

  beforeEach (done) ->
    class FakeModel
      ModelBaseMixin.includeInto this
      constructor: ->
        @initModel()
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
    FakeModel.drop()
    .then ->
      mapper.close()
      done()
    .catch(done)

  it 'get FakeModel attributes', (done) ->
    FakeModel.prototype.hasOwnProperty('name').should.ok
    FakeModel.prototype.hasOwnProperty('id').should.ok
    FakeModel.tableName.should.equal 'FakeModel'
    FakeModel.primaryKeyName.should.equal 'id'

    FakeModel.create({name: 'hello', email: 'hello@xx.xx'})
    .then (model) ->
      model.name.should.equal 'hello'
      model.email.should.equal 'hello@xx.xx'
      done()
    .catch done

  it 'save attributes', (done) ->
    model = new FakeModel()
    model.name = 'nimei'
    model.save().then ->
      FakeModel.find({name: 'nimei'})
    .then (resModel) ->
      resModel.id.should.equal model.id
    .then ->
      FakeModel.findAll({name: 'nimei'})
    .then (resModels) ->
      resModels.length.should.equal 1
      resModels[0].id.should.equal model.id
    .then ->
      FakeModel.each {name: 'nimei'}, (err, res) ->
        return done(err) if err
        res.id.should.equal model.id
    .then -> done()
    .catch done

describe 'ModelBaseMixin association', ->
  beforeEach (done) ->
    Migration.createTable 'ParentModel', (t) ->
      t.addColumn 'id', 'INTEGER', primaryKey: true

    Migration.createTable 'ChildModel', (t) ->
      t.addColumn 'id', 'INTEGER', primaryKey: true
      t.addReference 'parentModelId', 'ParentModel'

    class ParentModel
      class ChildModel
        ModelBaseMixin.includeInto this
        constructor: -> @initModel()
        @belongsTo ParentModel

      ModelBaseMixin.includeInto this
      constructor: -> @initModel()
      @hasOne ChildModel

    mapper = new Mapper path.resolve(__dirname, 'temp/test.db')
    mapper.sync().then -> done()
    .catch (err) -> done(err)

  afterEach (done) ->
    FakeModel.drop().then ->
      mapper.close()
      done()
    .catch(done)

  it 'hasOne', ->
