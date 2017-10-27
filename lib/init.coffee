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

_ = require('lodash')
Promise = require('bluebird')
operations = require('resin-device-operations')
resinSemver = require('resin-semver')
utils = require('./utils')
network = require('./network')

###*
# @summary Configure an image with an application
# @function
# @public
#
# @description
# This function injects `config.json` and network settings into the device.
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
		Promise.try ->
			# We only know how to find /etc/os-release on specific types of OS image. In future, we'd like to be able
			# to do this for any image, but for now we'll just treat others as unknowable (which means below we'll
			# configure the network to work for _either_ OS version.
			if manifest.yocto.image == 'resin-image' and _.includes(['resinos-img', 'resin-sdcard'], manifest.yocto.fstype)
				utils.getImageOsVersion(image)
		.then (osVersion) ->
			configuration = manifest.configuration

			majorVersion = resinSemver.major(osVersion)

			configPathDefinition = utils.convertFilePathDefinition(configuration.config)
			utils.writeConfigJSON(image, config, configPathDefinition)
			.then ->
				# Either configure the correct version, or do both if we're not sure.
				if not majorVersion? || majorVersion == 2
					network.configureOS2Network(image, manifest, options)
				if not majorVersion? || majorVersion == 1
					network.configureOS1Network(image, manifest, options)
			.then ->
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
