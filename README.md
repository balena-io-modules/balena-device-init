resin-device-init
-----------------

[![npm version](https://badge.fury.io/js/resin-device-init.svg)](http://badge.fury.io/js/resin-device-init)
[![dependencies](https://david-dm.org/resin-io/resin-device-init.png)](https://david-dm.org/resin-io/resin-device-init.png)
[![Build Status](https://travis-ci.org/resin-io/resin-device-init.svg?branch=master)](https://travis-ci.org/resin-io/resin-device-init)

Configure and initialize devices using device specs.

Role
----

The intention of this module is to provide low level access to how Resin.io configures and initialises devices using device specs.

**THIS MODULE IS LOW LEVEL AND IS NOT MEANT TO BE USED BY END USERS DIRECTLY**.

Installation
------------

Install `resin-device-init` by running:

```sh
$ npm install --save resin-device-init
```

Documentation
-------------


* [init](#module_init)
  * [.configure(image, uuid, options)](#module_init.configure) ⇒ <code>Promise.&lt;EventEmitter&gt;</code>
  * [.initialize(image, deviceType, options)](#module_init.initialize) ⇒ <code>Promise.&lt;EventEmitter&gt;</code>

<a name="module_init.configure"></a>
### init.configure(image, uuid, options) ⇒ <code>Promise.&lt;EventEmitter&gt;</code>
This function injects `config.json` into the device.

**Kind**: static method of <code>[init](#module_init)</code>  
**Summary**: Configure an image with an application  
**Returns**: <code>Promise.&lt;EventEmitter&gt;</code> - configuration event emitter  
**Access:** public  

| Param | Type | Description |
| --- | --- | --- |
| image | <code>String</code> | path to image |
| uuid | <code>String</code> | device uuid |
| options | <code>Object</code> | configuration options |

**Example**  
```js
init.configure('my/rpi.img', '7cf02a62a3a84440b1bb5579a3d57469148943278630b17e7fc6c4f7b465c9', network: 'ethernet').then (configuration) ->

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
### init.initialize(image, deviceType, options) ⇒ <code>Promise.&lt;EventEmitter&gt;</code>
**Kind**: static method of <code>[init](#module_init)</code>  
**Summary**: Initialize an image  
**Returns**: <code>Promise.&lt;EventEmitter&gt;</code> - initialization event emitter  
**Access:** public  

| Param | Type | Description |
| --- | --- | --- |
| image | <code>String</code> | path to image |
| deviceType | <code>String</code> | device type slug |
| options | <code>Object</code> | configuration options |

**Example**  
```js
init.initialize('my/rpi.img', 'raspberry-pi', network: 'ethernet').then (configuration) ->

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

If you're having any problem, please [raise an issue](https://github.com/resin-io/resin-device-init/issues/new) on GitHub and the Resin.io team will be happy to help.

Tests
-----

Run the test suite by doing:

```sh
$ npm test
```

Contribute
----------

- Issue Tracker: [github.com/resin-io/resin-device-init/issues](https://github.com/resin-io/resin-device-init/issues)
- Source Code: [github.com/resin-io/resin-device-init](https://github.com/resin-io/resin-device-init)

Before submitting a PR, please make sure that you include tests, and that [coffeelint](http://www.coffeelint.org/) runs without any warning:

```sh
$ gulp lint
```

License
-------

The project is licensed under the MIT license.
