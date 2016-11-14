var gulp = require('gulp')
var gutil = require('gulp-util');
var spawn = require('child_process').spawn;
var os = require('os');
var path = require('path');
var zip = require('gulp-zip');
var minimist = require('minimist');

var outputPath = '_build';
var options = minimist(process.argv.slice(2));
if(!!options.outputPath) {
	outputPath = options.outputPath;
}

var tempLocation = os.tmpdir();
var tempPackagePath = path.join(tempLocation, 'VSTSExtensionTemp');
var tempWindowsHandlerFilesPath = path.join(tempPackagePath, 'ExtensionHandler/Windows');
var windowsHandlerArchievePackageLocation = path.join(outputPath, 'ExtensionHandler/Windows');
var tempLinuxHandlerFilesPath = path.join(tempPackagePath, 'ExtensionHandler/Linux');
var linuxHandlerArchievePackageLocation = path.join(outputPath, 'ExtensionHandler/Linux');

gulp.task("test", function(done){
	// Runs powershell pester tests ( Unit Test)
	var pester = spawn('powershell.exe', ['CDScripts/InvokePester.ps1'], { stdio: 'inherit' });
	pester.on('exit', function(code, signal) {
	if (code != 0) {
		throw new gulpUtil.PluginError({
		plugin: 'test',
		message: 'Pester Tests Failed!!!'
		});
	}
	else {
		done();
	}
	});
	pester.on('error', function(err) {
	gutil.log('We may be in a non-windows machine or powershell.exe is not in path. Skip pester tests.');
	done();
	}); 
});

gulp.task('createTempHandlerPackage', ['test'], function () {
	gutil.log("Copying windows extension handler files selectively to temp location: " + tempWindowsHandlerFilesPath);
	gulp.src(['ExtensionHandler/Windows/src/bin/**.**', 'ExtensionHandler/Windows/src/enable.cmd', 'ExtensionHandler/Windows/src/disable.cmd', 'ExtensionHandler/Windows/src/uninstall.cmd', 'ExtensionHandler/Windows/src/HandlerManifest.json'],  {base: 'ExtensionHandler/Windows/src/'})
	.pipe(gulp.dest(tempWindowsHandlerFilesPath));
	gutil.log("Copying linux extension handler files selectively to temp location: " + tempLinuxHandlerFilesPath);
	gulp.src(['ExtensionHandler/Linux/src/**.**', 'ExtensionHandler/Linux/src/Utils/**.**'],  {base: 'ExtensionHandler/Linux/src/'})
	.pipe(gulp.dest(tempLinuxHandlerFilesPath));
});

gulp.task('copyHandlerDefinitionFile', ['test'], function () {
	// copying definition xml file to output location
	gulp.src(['ExtensionHandler/Windows/ExtensionDefinition_Test.xml', 'ExtensionHandler/Windows/ExtensionDefinition_Prod.xml'])
	.pipe(gulp.dest(windowsHandlerArchievePackageLocation));
	// copying definition xml file to output location
	gulp.src(['ExtensionHandler/Linux/manifest.xml', 'ExtensionHandler/Linux/manifest_prod.xml'])
	.pipe(gulp.dest(linuxHandlerArchievePackageLocation));
});

gulp.task('createHandlerPackage', ['test', 'createTempHandlerPackage', 'copyHandlerDefinitionFile'], function () {
	gutil.log("Archieving the windows extension handler package from location: " + tempWindowsHandlerFilesPath);
	gutil.log("Archieve output location: " + windowsHandlerArchievePackageLocation);
	var tempWindowsHandlerFilesSource = path.join(tempWindowsHandlerFilesPath, '**');
	// archieving handler files to output location
	gulp.src([tempWindowsHandlerFilesSource])
	.pipe(zip('RMExtension.zip'))
	.pipe(gulp.dest(windowsHandlerArchievePackageLocation));
	gutil.log("Archieving the linux extension handler package from location: " + tempLinuxHandlerFilesPath);
	gutil.log("Archieve output location: " + linuxHandlerArchievePackageLocation);
	var tempLinuxHandlerFilesSource = path.join(tempLinuxHandlerFilesPath, '**');
	// archieving handler files to output location
	gulp.src([tempLinuxHandlerFilesSource])
	.pipe(zip('RMExtension.zip'))
	.pipe(gulp.dest(linuxHandlerArchievePackageLocation));
});

gulp.task('createUIPackage', function () {
	// Create ARM UI package
	var armUIFilesPath = 'UI Package/Windows/ARM';
	var armUIPackageLocation = path.join(outputPath, armUIFilesPath);
	gutil.log("Archieving the windows extension ARM UI package from location: " + armUIFilesPath);
	gutil.log("Archieve output location: " + armUIPackageLocation);
	// archieving handler files to output location
	gulp.src(['UI Package/Windows/ARM/**'])
	.pipe(zip('UIPackage.zip'))
	.pipe(gulp.dest(armUIPackageLocation));  
	// Create Classic UI package
	var classicUIFilesPath = 'UI Package/Windows/Classic';
	var classicUIPackageLocation = path.join(outputPath, classicUIFilesPath);
	gutil.log("Archieving the windows extension Classic UI package from location: " + classicUIFilesPath);
	gutil.log("Archieve output location: " + classicUIPackageLocation);
	// archieving handler files to output location
	gulp.src(['UI Package/Windows/Classic/**'])
	.pipe(zip('UIPackage.zip'))
	.pipe(gulp.dest(classicUIPackageLocation));
	// Create ARM UI package
	var armUIFilesPath = 'UI Package/Linux/ARM';
	var armUIPackageLocation = path.join(outputPath, armUIFilesPath);
	gutil.log("Archieving the linux extension ARM UI package from location: " + armUIFilesPath);
	gutil.log("Archieve output location: " + armUIPackageLocation);
	// archieving handler files to output location
	gulp.src(['UI Package/Linux/ARM/**'])
	.pipe(zip('UIPackage.zip'))
	.pipe(gulp.dest(armUIPackageLocation));  
	// Create Classic UI package
	var classicUIFilesPath = 'UI Package/Linux/Classic';
	var classicUIPackageLocation = path.join(outputPath, classicUIFilesPath);
	gutil.log("Archieving the linux extension Classic UI package from location: " + classicUIFilesPath);
	gutil.log("Archieve output location: " + classicUIPackageLocation);
	// archieving handler files to output location
	gulp.src(['UI Package/Linux/Classic/**'])
	.pipe(zip('UIPackage.zip'))
	.pipe(gulp.dest(classicUIPackageLocation));
});

gulp.task('default', ['build']);

gulp.task('build', ['createHandlerPackage', 'createUIPackage'], function() {
    gutil.log("VM extension packages created at " + outputPath);
});
