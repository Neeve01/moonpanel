const { src, watch, dest, series } = require('gulp');
const { spawn } = require('child_process');
const through2 = require('through2');
const luamin = require('luamin');
const del = require('del');

function clean() {
	return del(['lua/**/*']);
}
const _compileMoonScript = () => through2.obj((file, _, cb) => {
	if (file.isBuffer()) {
		const moonc = spawn('moonc', ['--']);

		let stdout = '';
		let stderr = '';

		const code = file.contents.toString();
		const lines = code.split(/\r?\n/);
		let header = '';
		for (const line of lines) {
			if (line != '' && !line.startsWith('--')) break;
			header += line + '\n';
		}

		moonc.stdin.write(code);
		moonc.stdin.end();

		moonc.stdout.on('data', data => { stdout += data; });
		moonc.stderr.on('data', data => { stderr += data; });
		moonc.on('close', () => {
			if (stderr) cb(stderr);
			else {
				file.path = file.path.substr(0, file.path.lastIndexOf('.')) + '.txt';
				// file.contents = Buffer.from(header + luamin.minify(stdout));
				file.contents = Buffer.from(header + stdout);
				cb(null, file);
			}
		});
	}
});

function moon() {
	del(['moonpanel/**/*'])
	return src('moon/**/*.moon')
		.pipe(_compileMoonScript())
		.pipe(dest('moonpanel'));
}

function _watch() {
	watch(['moon/**/*.moon'], moon);
}

exports.moon = moon;
exports.watch = _watch;
exports.default = _watch;