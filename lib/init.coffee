###
The MIT License

Copyright (c) 2015 Resin.io, Inc. https://resin.io.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
###

###*
# @module init
###

Promise = require('bluebird')
resin = require('resin-sdk')
deviceConfig = require('resin-device-config')
operations = require('resin-device-operations')
utils = require('./utils')

###*
# @summary Configure an image with an application
# @function
# @public
#
# @description
# This function injects `config.json` into the device.
#
# @param {String} image - path to image
# @param {String} uuid - device uuid
# @param {Object} options - configuration options
#
# @returns {Promise<EventEmitter>} configuration event emitter
#
# @example
# init.configure('my/rpi.img', '7cf02a62a3a84440b1bb5579a3d57469148943278630b17e7fc6c4f7b465c9', network: 'ethernet').then (configuration) ->
#
# 	configuration.on('stdout', process.stdout.write)
# 	configuration.on('stderr', process.stderr.write)
#
# 	configuration.on 'state', (state) ->
# 		console.log(state.operation.command)
# 		console.log(state.percentage)
#
# 	configuration.on 'error', (error) ->
# 		throw error
#
# 	configuration.on 'end', ->
# 		console.log('Configuration finished')
###
exports.configure = (image, uuid, options) ->
	Promise.props
		manifest: utils.getManifestByDevice(uuid)
		config: deviceConfig.get(uuid, options)
	.then (results) ->
		configuration = results.manifest.configuration

		# Convert from seconds to milliseconds
		if options.appUpdatePollInterval?
			results.config.appUpdatePollInterval = String(options.appUpdatePollInterval * 60000)

		utils.writeConfigJSON(image, results.config, configuration.config).then ->
			return operations.execute(image, configuration.operations, options)

###*
# @summary Initialize an image
# @function
# @public
#
# @param {String} image - path to image
# @param {String} deviceType - device type slug
# @param {Object} options - configuration options
#
# @returns {Promise<EventEmitter>} initialization event emitter
#
# @example
# init.initialize('my/rpi.img', 'raspberry-pi', network: 'ethernet').then (configuration) ->
#
# 	configuration.on('stdout', process.stdout.write)
# 	configuration.on('stderr', process.stderr.write)
#
# 	configuration.on 'state', (state) ->
# 		console.log(state.operation.command)
# 		console.log(state.percentage)
#
# 	configuration.on 'burn', (state) ->
# 		console.log(state)
#
# 	configuration.on 'error', (error) ->
# 		throw error
#
# 	configuration.on 'end', ->
# 		console.log('Configuration finished')
###
exports.initialize = (image, deviceType, options) ->
	resin.models.device.getManifestBySlug(deviceType).then (manifest) ->
		return operations.execute(image, manifest.initialization.operations, options)
