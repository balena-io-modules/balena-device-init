###
Copyright 2016 Resin.io

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
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
