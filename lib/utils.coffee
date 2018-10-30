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

Promise = require('bluebird')
_ = require('lodash')
rindle = Promise.promisifyAll(require('rindle'))
path = require('path')
stringToStream = require('string-to-stream')
imagefs = require('resin-image-fs')
sdk = require('balena-sdk').fromSharedOptions()

###*
# @summary Get device type manifest by a device type name
# @function
# @protected
#
# @param {String} image - path to image
# @param {String} deviceType - device type slug
# @returns {Promise<Object>} device type manifest
#
# @example
# utils.getManifestByDeviceType('path/to/image.img', 'raspberry-pi').then (manifest) ->
# 	console.log(manifest)
###
exports.getManifestByDeviceType = (image, deviceType) ->

	# Attempt to read manifest from the first
	# partition, but fallback to the API if
	# we encounter any errors along the way.
	Promise.using imagefs.read(
		image: image
		partition: 1
		path: '/device-type.json'
	), rindle.extractAsync
	.then(JSON.parse)
	.catch ->
		sdk.models.device.getManifestBySlug(deviceType)

###*
# @summary Convert a device type file definition to resin-image-fs v4 format
# @function
# @protected
#
# @param {Object} definition - write definition
#
# @returns {Object} a converted write definition
#
# @example
# utils.convertFileDefinition
# 	partition:
# 		primary: 4
# 		logical: 1
# 	path: '/config.json'
###
exports.convertFilePathDefinition = (inputDefinition) ->
	definition = _.cloneDeep(inputDefinition)

	if _.isObject(definition.partition)
		# Partition numbering is now numerical, following the linux
		# conventions in 5.95 of the TLDP's system admin guide:
		# http://www.tldp.org/LDP/sag/html/partitions.html#DEV-FILES-PARTS
		if definition.partition.logical?
			definition.partition = definition.partition.logical + 4
		else
			definition.partition = definition.partition.primary

	return definition


###*
# @summary Add image info to a device type config definition
# @function
# @protected
#
# @param {String} image - image path
# @param {Object} definition - write definition
#
# @returns {Object} a write definition
#
# @example
# utils.definitionForImage 'my/rpi.img',
# 	partition:
# 		primary: 4
# 		logical: 1
# 	path: '/config.json'
###
exports.definitionForImage = (image, configDefinition) ->
	configDefinition = _.cloneDeep(configDefinition)

	if configDefinition.image?
		# Sometimes (e.g. edison) our 'image' is a folder of images, and the
		# config specifies which one within that we should be using
		configDefinition.image = path.join(image, configDefinition.image)
	else
		configDefinition.image = image

	return configDefinition


###*
# @summary Get image OS version
# @function
# @protected
#
# @param {String} image - path to image
# @returns {Promise<string|null>} ResinOS version, or null if it could not be determined
#
# @example
# utils.getImageOsVersion('path/to/image.img').then (version) ->
# 	console.log(version)
###
exports.getImageOsVersion = (image) ->
	Promise.resolve imagefs.readFile
		image: image
		partition: 2
		path: '/etc/os-release'
	.then (osReleaseString) ->
		parsedOsRelease = _(osReleaseString)
			.split('\n')
			.map (line) ->
				match = line.match(/(.*)=(.*)/)
				if match
					return [
						match[1],
						match[2].replace(/^"(.*)"$/, '$1').replace(/^'(.*)'$/, '$1')
					]
				else
					return false
			.filter()
			.fromPairs()
			.value()

		if parsedOsRelease.NAME != 'Resin OS' and parsedOsRelease.NAME != 'balenaOS'
			return null
		else
			return parsedOsRelease.VERSION || null
	.catchReturn(null)

###*
# @summary Write config.json to image
# @function
# @protected
#
# @param {String} image - image path
# @param {Object} config - config.json object
# @param {Object} definition - write definition
#
# @returns {Promise}
#
# @example
# utils.writeConfigJSON 'my/rpi.img',
# 	hello: 'world'
# ,
# 	partition:
# 		primary: 4
# 		logical: 1
# 	path: '/config.json'
###
exports.writeConfigJSON = (image, config, definition) ->
	config = JSON.stringify(config)

	definition = exports.definitionForImage(image, definition)

	return imagefs.write(definition, stringToStream(config))
