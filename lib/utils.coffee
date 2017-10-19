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
streamToString = require('stream-to-string')
imagefs = require('resin-image-fs')
resin = require('resin-sdk-preconfigured')

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
		resin.models.device.getManifestBySlug(deviceType)

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

	if not definition.partition?
		definition.image = path.join(image, definition.image)
	else
		definition.image ?= image

	return imagefs.write(definition, stringToStream(config))
