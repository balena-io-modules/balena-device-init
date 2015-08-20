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

Promise = require('bluebird')
_ = require('lodash')
path = require('path')
stringToStream = require('string-to-stream')
imagefs = require('resin-image-fs')
resin = require('resin-sdk')

###*
# @summary Get device type manifest by uuid
# @function
# @protected
#
# @param {String} uuid - uuid
# @returns {Promise<Object>} device type manifest
#
# @example
# utils.getManifestByDevice('...').then (manifest) ->
# 	console.log(manifest)
###
exports.getManifestByDevice = (uuid) ->
	resin.models.device.get(uuid)
		.get('device_type')
		.then(resin.models.device.getManifestBySlug)

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
