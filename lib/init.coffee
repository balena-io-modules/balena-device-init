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
# @param {String} device type - device type slug
# @param {Object} config - a fully populated config object
# @param {Object} [options] - configuration options
#
# @returns {Promise<EventEmitter>} configuration event emitter
#
# @example
# init.configure('my/rpi.img', 'raspberrypi', config).then (configuration) ->
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
exports.configure = (image, deviceType, config, options = {}) ->
	utils.getManifestByDeviceType(image, deviceType)
	.then (manifest) ->
		configuration = manifest.configuration

		# Convert from seconds to milliseconds
		if config.appUpdatePollInterval?
			config.appUpdatePollInterval = String(config.appUpdatePollInterval * 60000)

		utils.writeConfigJSON(image, config, configuration.config).then ->
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
	utils.getManifestByDeviceType(image, deviceType)
	.then (manifest) ->
		return operations.execute(image, manifest.initialization.operations, options)
