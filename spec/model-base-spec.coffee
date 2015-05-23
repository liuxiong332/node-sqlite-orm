ModelBaseMixin = require '../lib/model-base'
Mapper = require '../lib/mapper'
Migration = require '../lib/migration'
path = require 'path'
Q = require 'q'

describe 'ModelBaseMixin', ->
  [mapper, FakeModel] = []

  beforeEach (done) ->
    class FakeModel
      ModelBaseMixin.includeInto this
      constructor: ->
        @initModel()
      Migration.createTable 'FakeModel', (t) ->
        t.addColumn 'name', 'INTEGER'
        t.addColumn 'email', 'TEXT'

    FakeModel.models.FakeModel.should.equal FakeModel
    fileName = path.resolve(__dirname, 'temp/test.db')
    mapper = new Mapper(fileName)
    mapper.sync().then -> done()
    .catch (err) -> done(err)

  afterEach (done) ->
    mapper.dropAllTables()
    .then ->
      Migration.clear()
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

  it 'transaction', (done) ->
    mapper.beginTransaction()
    .then -> mapper.endTransaction()
    .then -> done()

describe 'ModelBaseMixin basic association', ->
  [ParentModel, ChildModel, SomeModel, mapper] = []
  beforeEach (done) ->
    Migration.createTable 'ParentModel', (t) ->
      t.addColumn 'name', 'TEXT'

    Migration.createTable 'ChildModel', (t) ->
      t.addColumn 'name', 'TEXT'
      t.addReference 'parentModelId', 'ParentModel'

    Migration.createTable 'SomeModel', (t) ->
      t.addColumn 'name', 'TEXT'
      t.addReference 'parentModelId', 'ParentModel'

    class ChildModel
      ModelBaseMixin.includeInto this
      constructor: (params) -> @initModel params

      @initAssos: ->
        @belongsTo ParentModel

    class SomeModel
      ModelBaseMixin.includeInto this
      constructor: (params) -> @initModel params

      @initAssos: ->
        @belongsTo ParentModel

    class ParentModel
      ModelBaseMixin.includeInto this
      constructor: (params) -> @initModel params
      @initAssos: ->
        @hasOne ChildModel
        @hasMany SomeModel

    mapper = new Mapper path.resolve(__dirname, 'temp/test.db')
    mapper.sync().then -> done()
    .catch (err) -> done(err)

  afterEach (done) ->
    mapper.dropAllTables()
    .then ->
      Migration.clear()
      mapper.close()
      done()
    .catch(done)

  it 'belongsTo', (done) ->
    child = new ChildModel name: 'child'
    parent = new ParentModel name: 'parent'
    Q.all [child.save(), parent.save()]
    .then ->
      child.parentModel = parent
      child.parentModel.should.equal parent
      child.parentModelId.should.equal parent.id
      parent.childModel.should.equal child
    .then ->
      child.save()
    .then -> done()
    .catch done

  it 'hasOne', (done) ->
    child = new ChildModel name: 'child'
    parent = new ParentModel name: 'parent'
    Q.all [child.save(), parent.save()]
    .then ->
      parent.childModel = child
      parent.childModel.should.equal child
      child.parentModel.should.equal parent
      child.parentModelId.should.equal parent.id
    .then ->
      parent.childModel = null
      child.save()
    .then -> done()
    .catch done

  it 'belongsTo N-1', (done) ->
    child = new SomeModel name: 'child'
    parent = new ParentModel name: 'parent'
    Q.all [child.save(), parent.save()]
    .then ->
      child.parentModel = parent
      child.parentModel.should.equal parent
      child.parentModelId.should.equal parent.id
      parent.someModels.get(0).should.equal child

      child.parentModel = null
      parent.someModels.length.should.equal 0
    .then -> done()
    .catch done

  it 'hasMany', (done) ->
    child = new SomeModel name: 'child'
    parent = new ParentModel name: 'parent'
    child.save().then ->
      parent.save()
    .then ->
      parent.someModels.push child
      Q.delay(0)
    .then ->
      child.parentModelId.should.equal parent.id
      child.parentModel.should.equal parent
      parent.someModels.pop()
      Q.delay(0)
    .then ->
      (child.parentModelId is null).should.ok
    .then ->
      mapper.cache.clear()
      SomeModel.getById(1)
    .then (model) ->
      done()
    .catch done

  it 'load', (done) ->
    child = new SomeModel name: 'child'
    parent = new ParentModel name: 'parent'
    Q.all([child.save(), parent.save()])
    .then ->
      parent.someModels.push child
      Q.delay(0)
    .then -> Q.all [child.save(), parent.save()]
    .then ->
      mapper.cache.clear()
      SomeModel.getById(1)
    .then (child) ->
      child.parentModel.should.ok
      done()
    .catch done

describe 'ModelBaseMixin association to self', ->
  [Model, mapper] = []

  beforeEach (done) ->
    Migration.createTable 'Model', (t) ->
      t.addColumn 'name', 'TEXT'
      t.addReference 'parentId', 'Model'

    class Model
      ModelBaseMixin.includeInto this
      constructor: (params) -> @initModel params
      @belongsTo Model, {through: 'parentId', as: 'parent'}
      @hasMany Model, {as: 'children'}

    mapper = new Mapper path.resolve(__dirname, 'temp/test.db')
    mapper.sync().then -> done()
    .catch (err) -> done(err)

  afterEach (done) ->
    Model.drop().then ->
      Migration.clear()
      mapper.close()
      done()
    .catch(done)

  it 'belongsTo and hasMany', (done) ->
    models = for i in [0..2]
      new Model name: "model#{i}"
    Q.all (model.save() for model in models)
    .then ->
      models[0].children.splice(0, 0, models[1], models[2])
    .then ->
      models[0].children.length.should.equal 2
      models[1].parent.should.equal models[0]
      models[2].parent.should.equal models[0]
      Q.all (model.save() for model in models)
    .then ->
      mapper.cache.clear()
      Model.getById(1)
    .then (model0) ->
      model0.children.length.should.equal 2
      model0.children.get(0).parent.should.equal model0
      model0.children.get(1).parent.should.equal model0
    .then -> done()
    .catch done

describe 'ModelBaseMixin in asymmetric association', ->
    [Model, mapper] = []

    beforeEach (done) ->
      Migration.createTable 'Model', (t) ->
        t.addColumn 'name', 'TEXT'
        t.addReference 'parentId', 'Model'
        t.addReference 'childId', 'Model'

      class Model
        ModelBaseMixin.includeInto this
        constructor: (params) -> @initModel params
        # @belongsTo Model, {through: 'parentId', as: 'parent'}
        @initAssos: ->
          @hasMany Model, {as: 'children', through: 'parentId'}
          @belongsTo Model, {as: 'parent', through: 'childId'}

      mapper = new Mapper path.resolve(__dirname, 'temp/test.db')
      mapper.sync().then -> done()
      .catch (err) -> done(err)

    afterEach (done) ->
      Model.drop().then ->
        Migration.clear()
        mapper.close()
        done()
      .catch(done)

    it 'work properly', (done) ->
      models = for i in [0..2]
        new Model name: "#{i}"
      Q.all (model.save() for model in models)
      .then ->
        models[0].children.push models[1]
        models[0].parent = models[2]
        Q.delay(0)
      .then ->
        models[1]["@1"].should.equal models[0]
        models[2]["@0"].get(0).should.equal models[0]
        Q.all (model.save() for model in models)
      .then ->
        mapper.cache.clear()
        Model.getById(1)
      .then (model) ->
        Q.delay()
        model
      .then (model) ->
        model.parent.name.should.equal '2'
        model.parent['@0'].get(0).should.equal model
        model1 = model.children.get(0)
        model1.name.should.equal '1'
        model1['@1'].should.equal model
        model1.destroy().then -> model
      .then (model) ->
        model.children.length.should.equal 0
        model.parent.destroy().then -> model
      .then (model) ->
        done()
      .catch done
