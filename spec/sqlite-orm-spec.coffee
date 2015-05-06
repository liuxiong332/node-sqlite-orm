
sqliteOrm = require '../lib/sqlite-orm'

assert = require 'should' 

describe 'sqliteOrm', ->

  it 'should be awesome', -> 
    sqliteOrm().should.equal('awesome')
