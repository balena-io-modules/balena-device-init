/*
Copyright 2016 Balena

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

/**
 * @module init
 */

const _ = require('lodash');
const Promise = require('bluebird');
const operations = require('resin-device-operations');
const resinSemver = require('balena-semver');
const utils = require('./utils');
const network = require('./network');

exports.getImageManifest = utils.getImageManifest;
exports.getImageOsVersion = utils.getImageOsVersion;

/**
 * @summary Configure an image with an application
 * @function
 * @public
 *
 * @description
 * This function injects `config.json` and network settings into the image.
 *
 * @param {String} image - path to image
 * @param {Object} manifest - device type manifest
 * @param {Object} config - a fully populated config object
 * @param {Object} [options] - configuration options
 *
 * @returns {Promise<EventEmitter>} configuration event emitter
 *
 * @example
 * init.configure('my/rpi.img', manifest, config).then (configuration) ->
 *
 * 	configuration.on('stdout', process.stdout.write)
 * 	configuration.on('stderr', process.stderr.write)
 *
 * 	configuration.on 'state', (state) ->
 * 		console.log(state.operation.command)
 * 		console.log(state.percentage)
 *
 * 	configuration.on 'error', (error) ->
 * 		throw error
 *
 * 	configuration.on 'end', ->
 * 		console.log('Configuration finished')
 */
exports.configure = function(image, manifest, config, options) {
	if (options == null) { options = {}; }
	return Promise.try(function() {
		// We only know how to find /etc/os-release on specific types of OS image. In future, we'd like to be able
		// to do this for any image, but for now we'll just treat others as unknowable (which means below we'll
		// configure the network to work for _either_ OS version.
		if (((manifest.yocto != null ? manifest.yocto.image : undefined) === 'resin-image') && _.includes(['resinos-img', 'resin-sdcard'], manifest.yocto != null ? manifest.yocto.fstype : undefined)) {
			return utils.getImageOsVersion(image, manifest);
		}}).then(function(osVersion) {
		const {
				configuration
		} = manifest;

		const majorVersion = resinSemver.major(osVersion);

		const configPathDefinition = utils.convertFilePathDefinition(configuration.config);
		return utils.writeConfigJSON(image, config, configPathDefinition)
		.then(function() {
			// Configure for OS2 if it is OS2, or if we're just not sure
			if ((majorVersion == null) || (majorVersion === 2)) {
				return network.configureOS2Network(image, manifest, options);
			}}).then(function() {
			// Configure for OS1 if it is OS1, or if we're just not sure
			if ((majorVersion == null) || (majorVersion === 1)) {
				return network.configureOS1Network(image, manifest, options);
			}}).then(() => operations.execute(image, configuration.operations, options));
	});
};

/**
 * @summary Initialize an image
 * @function
 * @public
 *
 * @param {String} image - path to image
 * @param {Object} manifest - device type manifest
 * @param {Object} options - configuration options
 *
 * @returns {Promise<EventEmitter>} initialization event emitter
 *
 * @example
 * init.initialize('my/rpi.img', manifest, network: 'ethernet').then (configuration) ->
 *
 * 	configuration.on('stdout', process.stdout.write)
 * 	configuration.on('stderr', process.stderr.write)
 *
 * 	configuration.on 'state', (state) ->
 * 		console.log(state.operation.command)
 * 		console.log(state.percentage)
 *
 * 	configuration.on 'burn', (state) ->
 * 		console.log(state)
 *
 * 	configuration.on 'error', (error) ->
 * 		throw error
 *
 * 	configuration.on 'end', ->
 * 		console.log('Configuration finished')
 */
exports.initialize = (image, manifest, options) => operations.execute(image, manifest.initialization.operations, options);
