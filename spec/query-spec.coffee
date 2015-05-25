Query = require '../lib/query'
sqlite3 = require('sqlite3').verbose()
path = require 'path'

describe 'query', ->
  [db, query] = []

  beforeEach (done) ->
    filePath = path.resolve(__dirname, 'temp/test.db')
    db = new sqlite3.Database filePath
    query = new Query(db)
    attrs =
      id: {primaryKey: true, type: 'INTEGER'}, name: 'INTEGER'
    query.createTable('table1', attrs).then ->
      done()

  afterEach (done) ->
    query.dropTable('table1').then ->
      db.close done

  it 'insert and select', (done) ->
    query.insert('table1', {name: 'hello'}).then (rowId) ->
      rowId.should.equal 1
    .then -> query.selectOne('table1', {id: 1})
    .then (result) ->
      result.should.eql {id: 1, name: 'hello'}
    .then -> query.update('table1', {name: 'world'}, {id: 1})
    .then -> query.selectOne('table1', {id: 1})
    .then (result) ->
      result.should.eql {id: 1, name: 'world'}
    .then -> query.select('table1')
    .then (results) ->
      results.length.should.equal 1
      results[0].should.eql {id: 1, name: 'world'}
      done()
    .catch done
