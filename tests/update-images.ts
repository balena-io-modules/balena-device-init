import * as http from 'http';
import * as path from 'path';
import * as fs from 'fs';

function downloadImageIfNotExists(deviceType, version) {
	let url = `http://img.resin.io/api/v1/image/${deviceType}?version=${version}`;
	let targetPath = path.join(__dirname, 'tests', 'images');

	fs.access(targetPath, (err) => {
		if (!err) return; // File already exists

		console.log('Downloading ', url);
		let file = fs.createWriteStream(targetPath);
		let request = http.get(url, function(response) {
		  response.pipe(file);
		});
	});
}

downloadImageIfNotExists('raspberrypi3', '2.3.0+rev1.prod');
downloadImageIfNotExists('raspberrypi3', '2.7.5+rev1.prod');
downloadImageIfNotExists('raspberrypi3', '1.26.0');
downloadImageIfNotExists('edison', '2.7.5+rev1.prod');
downloadImageIfNotExists('jetson-tx2', '2.7.5+rev1.prod');
