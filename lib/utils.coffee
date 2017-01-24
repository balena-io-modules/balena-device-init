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
rindle = Promise.promisifyAll(require('rindle'))
_ = require('lodash')
path = require('path')
stringToStream = require('string-to-stream')
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
	imagefs.read
		image: image
		partition:
			primary: 1
		path: '/device-type.json'
	.then(rindle.extractAsync)
	.then(JSON.parse)
	.catch ->
		resin.models.device.getManifestBySlug(deviceType)

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

	return new Promise (resolve, reject) ->
		imagefs.write(definition, stringToStream(config)).then (stream) ->
			stream.on('error', reject)
			stream.on('close', resolve)
