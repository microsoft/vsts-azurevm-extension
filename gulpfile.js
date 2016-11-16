var gulp = require('gulp')
var gutil = require('gulp-util');
var spawn = require('child_process').spawn;
var path = require('path');
var zip = require('gulp-zip');
var minimist = require('minimist');
var clean = require('gulp-clean');

var outputPath = '_build';
var options = minimist(process.argv.slice(2));
if(!!options.outputPath) {
	outputPath = options.outputPath;
}

var tempLocation = '_temp';
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

gulp.task('cleanTempFolder', function() {
	return gulp.src(tempLocation).pipe(clean({force: true}));
});

gulp.task('cleanExistingBuild', function() {
	return gulp.src(outputPath).pipe(clean({force: true}));
});

gulp.task('createTempWindowsHandlerPackage', ['test', 'cleanExistingBuild', 'cleanTempFolder'], function () {
	gutil.log("Copying windows extension handler files selectively to temp location: " + tempWindowsHandlerFilesPath);
	return gulp.src(['ExtensionHandler/Windows/src/bin/**.**', 'ExtensionHandler/Windows/src/enable.cmd', 'ExtensionHandler/Windows/src/disable.cmd', 'ExtensionHandler/Windows/src/uninstall.cmd', 'ExtensionHandler/Windows/src/HandlerManifest.json'],  {base: 'ExtensionHandler/Windows/src/'})
	.pipe(gulp.dest(tempWindowsHandlerFilesPath));
});

gulp.task('createTempLinuxHandlerPackage', ['test', 'cleanExistingBuild', 'cleanTempFolder'], function () {
	gutil.log("Copying linux extension handler files selectively to temp location: " + tempLinuxHandlerFilesPath);
	return gulp.src(['ExtensionHandler/Linux/src/**.**', 'ExtensionHandler/Linux/src/Utils/**.**'],  {base: 'ExtensionHandler/Linux/src/'})
	.pipe(gulp.dest(tempLinuxHandlerFilesPath));
});

gulp.task('copyWindowsHandlerDefinitionFile', ['test', 'cleanExistingBuild', 'cleanTempFolder'], function () {
	// copying definition xml file to output location
	return gulp.src(['ExtensionHandler/Windows/ExtensionDefinition_Test.xml', 'ExtensionHandler/Windows/ExtensionDefinition_Prod.xml'])
	.pipe(gulp.dest(windowsHandlerArchievePackageLocation));
});

gulp.task('copyLinuxHandlerDefinitionFile', ['test', 'cleanExistingBuild', 'cleanTempFolder'], function () {
	// copying definition xml file to output location
	return gulp.src(['ExtensionHandler/Linux/ExtensionDefinition_Test.xml', 'ExtensionHandler/Linux/ExtensionDefinition_Prod.xml'])
	.pipe(gulp.dest(linuxHandlerArchievePackageLocation));
});

gulp.task('createWindowsHandlerPackage', ['test', 'createTempWindowsHandlerPackage', 'copyWindowsHandlerDefinitionFile', 'cleanExistingBuild', 'cleanTempFolder'], function () {
	gutil.log("Archieving the windows extension handler package from location: " + tempWindowsHandlerFilesPath);
	gutil.log("Archieve output location: " + windowsHandlerArchievePackageLocation);
	var tempWindowsHandlerFilesSource = path.join(tempWindowsHandlerFilesPath, '**');
	// archieving handler files to output location
	return gulp.src([tempWindowsHandlerFilesSource])
	.pipe(zip('RMExtension.zip'))
	.pipe(gulp.dest(windowsHandlerArchievePackageLocation));
});

gulp.task('createLinuxHandlerPackage', ['test', 'createTempLinuxHandlerPackage', 'copyLinuxHandlerDefinitionFile', 'cleanExistingBuild', 'cleanTempFolder'], function () {
	gutil.log("Archieving the linux extension handler package from location: " + tempLinuxHandlerFilesPath);
	gutil.log("Archieve output location: " + linuxHandlerArchievePackageLocation);
	var tempLinuxHandlerFilesSource = path.join(tempLinuxHandlerFilesPath, '**');
	// archieving handler files to output location
	return gulp.src([tempLinuxHandlerFilesSource])
	.pipe(zip('RMExtension.zip'))
	.pipe(gulp.dest(linuxHandlerArchievePackageLocation));
});

gulp.task('createWindowsUIPackage', ['cleanExistingBuild', 'cleanTempFolder'], function () {
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
	return gulp.src(['UI Package/Windows/Classic/**'])
	.pipe(zip('UIPackage.zip'))
	.pipe(gulp.dest(classicUIPackageLocation));
});

gulp.task('createLinuxUIPackage', ['cleanExistingBuild', 'cleanTempFolder'], function () {
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
	return gulp.src(['UI Package/Linux/Classic/**'])
	.pipe(zip('UIPackage.zip'))
	.pipe(gulp.dest(classicUIPackageLocation));
});

gulp.task('default', ['build']);

gulp.task('build', ['createWindowsHandlerPackage', 'createWindowsUIPackage', 'createLinuxHandlerPackage', 'createLinuxUIPackage'], function() {
    gutil.log("VM extension packages created at " + outputPath);
});
