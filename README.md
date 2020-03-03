balena-device-init
-----------------

[![npm version](https://badge.fury.io/js/balena-device-init.svg)](http://badge.fury.io/js/balena-device-init)
[![dependencies](https://david-dm.org/balena-io/balena-device-init.png)](https://david-dm.org/balena-io/balena-device-init.png)
[![Build Status](https://travis-ci.org/balena-io/balena-device-init.svg?branch=master)](https://travis-ci.org/balena-io/balena-device-init)

Configure and initialize devices using device specs.

Role
----

The intention of this module is to provide low level access to how balena configures and initialises devices using device specs.

**THIS MODULE IS LOW LEVEL AND IS NOT MEANT TO BE USED BY END USERS DIRECTLY**.

Installation
------------

Install `balena-device-init` by running:

```sh
$ npm install --save balena-device-init
```

Documentation
-------------


* [init](#module_init)
    * [.configure(image, manifest, config, [options])](#module_init.configure) ⇒ <code>Promise.&lt;EventEmitter&gt;</code>
    * [.initialize(image, manifest, options)](#module_init.initialize) ⇒ <code>Promise.&lt;EventEmitter&gt;</code>

<a name="module_init.configure"></a>

### init.configure(image, manifest, config, [options]) ⇒ <code>Promise.&lt;EventEmitter&gt;</code>
This function injects `config.json` and network settings into the image.

**Kind**: static method of [<code>init</code>](#module_init)  
**Summary**: Configure an image with an application  
**Returns**: <code>Promise.&lt;EventEmitter&gt;</code> - configuration event emitter  
**Access**: public  

| Param | Type | Description |
| --- | --- | --- |
| image | <code>String</code> | path to image |
| manifest | <code>Object</code> | device type manifest |
| config | <code>Object</code> | a fully populated config object |
| [options] | <code>Object</code> | configuration options |

**Example**  
```js
init.configure('my/rpi.img', manifest, config).then (configuration) ->

	configuration.on('stdout', process.stdout.write)
	configuration.on('stderr', process.stderr.write)

	configuration.on 'state', (state) ->
		console.log(state.operation.command)
		console.log(state.percentage)

	configuration.on 'error', (error) ->
		throw error

	configuration.on 'end', ->
		console.log('Configuration finished')
```
<a name="module_init.initialize"></a>

### init.initialize(image, manifest, options) ⇒ <code>Promise.&lt;EventEmitter&gt;</code>
**Kind**: static method of [<code>init</code>](#module_init)  
**Summary**: Initialize an image  
**Returns**: <code>Promise.&lt;EventEmitter&gt;</code> - initialization event emitter  
**Access**: public  

| Param | Type | Description |
| --- | --- | --- |
| image | <code>String</code> | path to image |
| manifest | <code>Object</code> | device type manifest |
| options | <code>Object</code> | configuration options |

**Example**  
```js
init.initialize('my/rpi.img', manifest, network: 'ethernet').then (configuration) ->

	configuration.on('stdout', process.stdout.write)
	configuration.on('stderr', process.stderr.write)

	configuration.on 'state', (state) ->
		console.log(state.operation.command)
		console.log(state.percentage)

	configuration.on 'burn', (state) ->
		console.log(state)

	configuration.on 'error', (error) ->
		throw error

	configuration.on 'end', ->
		console.log('Configuration finished')
```

Support
-------

If you're having any problem, please [raise an issue](https://github.com/balena-io/balena-device-init/issues/new) on GitHub and the balena team will be happy to help.

Tests
-----

Create an `.env` file and put the following lines in it, replacing the asterisks
with the valid credentials for a test user on [balena-staging.com](https://balena-staging.com)

```
TEST_EMAIL=***
TEST_PASSWORD=***
```

Run the test suite by doing:

```sh
$ npm test
```

Contribute
----------

- Issue Tracker: [github.com/balena-io/balena-device-init/issues](https://github.com/balena-io/balena-device-init/issues)
- Source Code: [github.com/balena-io/balena-device-init](https://github.com/balena-io/balena-device-init)

Before submitting a PR, please make sure that you include tests, and that [coffeelint](http://www.coffeelint.org/) runs without any warning:

```sh
$ gulp lint
```

You can then run the tests with:

```sh
npm test
```

License
-------

The project is licensed under the Apache 2.0 license.
