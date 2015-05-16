# sqlite-orm
[![NPM version][npm-image]][npm-url] [![Build Status][travis-image]][travis-url] [![Dependency Status][daviddm-image]][daviddm-url] [![Coverage Status][coveralls-image]][coveralls-url]

the ORM framework for sqlite


## Install

```bash
$ npm install --save sqlite-orm
```


## Usage

the coffeescript sample code

```coffeescript
Mapper = require 'sqlite-orm'
path = require 'path'
Migration = Mapper.Migration
ModelBase = Mapper.ModelBase

Migration.createTable 'ParentModel', (t) ->
  t.addColumn 'id', 'INTEGER', primaryKey: true
  t.addColumn 'name', 'TEXT'

Migration.createTable 'ChildModel', (t) ->
  t.addColumn 'id', 'INTEGER', primaryKey: true
  t.addColumn 'name', 'TEXT'
  t.addReference 'parentModelId', 'ParentModel'

class ParentModel

  class ChildModel
    ModelBase.includeInto this
    constructor: (params) -> @initModel params
    @belongsTo ParentModel

  ModelBase.includeInto this
  constructor: (params) -> @initModel params
  @hasOne ChildModel

mapper = new Mapper path.resolve(__dirname, 'test.db')
mapper.sync()
```

the corresponding javascript code

```javascript
var Mapper = require('sqlite-orm');
var Migration = Mapper.Migration;
var ModelBase = Mapper.ModelBase;
var path = require('path');

Migration.createTable('ParentModel', function(t) {
  t.addColumn('id', 'INTEGER', {primaryKey: true});
  t.addColumn('name', 'TEXT');
});

Migration.createTable('ChildModel', function(t) {
  t.addColumn('id', 'INTEGER', {primaryKey: true});
  t.addColumn('name', 'TEXT');
  t.addReference('parentModelId', 'ParentModel');
});

function ParentModel(params) {
  this.initModel(params);
}
ModelBase.includeInto(ParentModel);

function ChildModel(params) {
  this.initModel(params);
}
ModelBase.includeInto(ChildModel);

ParentModel.hasOne(ChildModel);
ChildModel.belongsTo(ParentModel);

mapper = new Mapper(path.resolve(__dirname, 'test.db'));
mapper.sync().then(function() {
});
```

## API

### Mapper

**sync** `function()` synchronize the model definition and the database

  *return*: `Promise`

**close** `function()` close the database

  *return*: `Promise`

**Migration** `Migration` get the Migration class

**ModelBase** `ModelBase` get the ModelBase class

**INTEGER** `String` the INTEGER data type

**REAL** `String` the REAL data type

**TEXT** `String` the TEXT data type

**BLOB** `String` the BLOB data type

### Migration

**createTable**: `function(tableName, callback)` create the database table

  *tableName*: `String`

  *callback*: `function(tableInfo)` create the columns in this callback

    *tableInfo*: `TableInfo` the class to create the columns and index

**clear**: `function()` clear the table definition

### TableInfo

**addColumn**: `function(name, type, opts)` add the table column

  *name*: `String` the column name

  *type*: `String` the column data type, such as `INTEGER` or `TEXT`

  *opts*: `Object` the column options

**addIndex**: `function(names...)` add index for the specific column

  *names*: `Array` the column names that need index

**addReference**: `function(name, tableName, opts)` add foreign key

  *name*: the column name that need index

  *tableName*: the name of table that the index will point to

  *opts*: `Object` the index options

### ModelBase

**@hasOne**: `function(ChildModel, opts)` declare this Model has one child Model

  *ChildModel*: `ModelBase` the child Model class

  *opts*: `Object` the options used for hasOne association

    *as*: `String`(optional) the property name to refer to the ChildModel instance,
    the default value is "#{childModel}". e.g. ChildModel is 'ChildModel', then the as
    value is `childModel`

**@hasMany**: `function(ChildModel, opts)` declare this Model has many children.

*ChildModel*: `ModelBase` the child Model class

*opts*: `Object` the options used for hasOne association

  *as*: `String`(optional) the property name to refer to the ChildModel instances,
  the default value is "#{childModels}". e.g. ChildModel is 'ChildModel', then the as
  value is `childModels`

**@belongsTo**: `function(ParentModel, opts)` declare this Model is member of ParentModel

  *ParentModel*: `ModelBase` the parent Model class

  *opts*: `Object` the options used for hasOne association

    *through*: `String`(optional) the column name that used for foreign key,
    the default value is "#{ParentModel}#{primaryKey}". e.g. ParentModel name is 'ParentModel',
    primaryKey is 'id', then the foreign key is `parentModelId`.

    *as*: `String`(optional) the property name to refer to the ParentModel instance,
    the default value is "#{ParentModel}". e.g. ParentModel is 'ParentModel', then the as
    value is `parentModel`

**@new**: `function(obj)` create a new model object, not saved into database

  *obj*: `Object` the attributes list

**@create**: `function(obj)` just like `@new`, but save into database

**@drop**: `function()` drop the table

**@find**: `function(where, opts)` find the object that match the `where` statement

**@findAll**: `function(where, opts)` find all of object match the condition

## Contributing

In lieu of a formal styleguide, take care to maintain the existing coding style. Add unit tests for any new or changed functionality. Lint and test your code using [gulp](http://gulpjs.com/).


## License

Copyright (c) 2015 liuxiong. Licensed under the MIT license.



[npm-url]: https://npmjs.org/package/sqlite-orm
[npm-image]: https://badge.fury.io/js/sqlite-orm.svg
[travis-url]: https://travis-ci.org/liuxiong332/sqlite-orm
[travis-image]: https://travis-ci.org/liuxiong332/sqlite-orm.svg?branch=master
[daviddm-url]: https://david-dm.org/liuxiong332/sqlite-orm
[daviddm-image]: https://david-dm.org/liuxiong332/sqlite-orm.svg?theme=shields.io
[coveralls-url]: https://coveralls.io/r/liuxiong332/sqlite-orm
[coveralls-image]: https://coveralls.io/repos/liuxiong332/sqlite-orm/badge.png
