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

function artifactsGenerator (zipOutputDirectory, artifactSubDirectory, extensionFile){
	return function (done) {
		const artifactsOutputDirectory = path.join(zipOutputDirectory, artifactSubDirectory);
		const extensionInfoFile = path.join(zipOutputDirectory, extensionFile);
		const packageFile = path.join(zipOutputDirectory, 'RMExtension.zip')
		gutil.log("Running Ev2ArtifactsGenerator with output directory " + artifactsOutputDirectory);
		gutil.log("Running Ev2ArtifactsGenerator with extension info file in " + extensionInfoFile)
		gutil.log("Running Ev2ArtifactsGenerator with package file " + packageFile)
		var generator = spawn('powershell.exe', ['CDScripts/Ev2ArtifactsGenerator.ps1',
		'-outputDir ' + artifactsOutputDirectory + ' ' + 
		'-ExtensionInfoFile ' + extensionInfoFile + ' ' +
		'-PackageFile ' + packageFile]
		, { stdio: 'inherit' });
		generator.on('exit', function(code, signal) {
			if (code != 0) {
				throw new gutil.PluginError({
					plugin: 'ARM files generator',
					message: 'ARM files generator failed!!!'
				});
			}
			else{
				done();
			}
		});
		generator.on('error', function(err) {
			gutil.log('We may be in a non-windows machine or powershell.exe is not in path.');
			throw new gulpUtil.PluginError({
				plugin: 'ARM files generator',
				message: 'ARM files generator failed!!!'
			});
		});
	}
}

gulp.task("test", function(done){
	// Runs powershell pester tests ( Unit Test)
	var pester = spawn('powershell.exe', ['CDScripts/InvokePester.ps1'], { stdio: 'inherit' });
	pester.on('exit', function(code, signal) {
	if (code != 0) {
		throw new gutil.PluginError({
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
	return gulp.src(tempLocation, { allowEmpty: true }).pipe(clean({force: true}));
});

gulp.task('cleanExistingBuild', function() {
	return gulp.src(outputPath, { allowEmpty: true }).pipe(clean({force: true}));
});

gulp.task('createTempWindowsHandlerPackage', function () {
	gutil.log("Copying windows extension handler files selectively to temp location: " + tempWindowsHandlerFilesPath);
	return gulp.src(['ExtensionHandler/Windows/src/bin/**.**', 'ExtensionHandler/Windows/src/enable.cmd', 'ExtensionHandler/Windows/src/disable.cmd', 'ExtensionHandler/Windows/src/install.cmd', 'ExtensionHandler/Windows/src/uninstall.cmd', 'ExtensionHandler/Windows/src/update.cmd', 'ExtensionHandler/Windows/src/HandlerManifest.json', 'ExtensionHandler/Windows/src/net6.json'],  {base: 'ExtensionHandler/Windows/src/'})
	.pipe(gulp.dest(tempWindowsHandlerFilesPath));
});

gulp.task('createTempLinuxHandlerPackage', function () {
	gutil.log("Copying linux extension handler files selectively to temp location: " + tempLinuxHandlerFilesPath);
	return gulp.src(['ExtensionHandler/Linux/src/**.**', 'ExtensionHandler/Linux/src/Utils/**.**', 'ExtensionHandler/Linux/src/Utils_python2/**.**'],  {base: 'ExtensionHandler/Linux/src/'})
	.pipe(gulp.dest(tempLinuxHandlerFilesPath));
});

gulp.task('copyWindowsHandlerDefinitionFile', function () {
	// copying definition xml file to output location
	return gulp.src(['ExtensionHandler/Windows/ExtensionDefinition_Test_MIGRATED.xml', 'ExtensionHandler/Windows/ExtensionDefinition_Prod_MIGRATED.xml'])
	.pipe(gulp.dest(windowsHandlerArchievePackageLocation));
});

gulp.task('copyLinuxHandlerDefinitionFile', function () {
	// copying definition xml file to output location
	return gulp.src(['ExtensionHandler/Linux/ExtensionDefinition_Test_MIGRATED.xml', 'ExtensionHandler/Linux/ExtensionDefinition_Prod_MIGRATED.xml'])
	.pipe(gulp.dest(linuxHandlerArchievePackageLocation));
});

gulp.task('createWindowsHandlerPackage', function () {
	gutil.log("Archieving the windows extension handler package from location: " + tempWindowsHandlerFilesPath);
	gutil.log("Archieve output location: " + windowsHandlerArchievePackageLocation);
	var tempWindowsHandlerFilesSource = `${tempWindowsHandlerFilesPath}/**`;
	// archieving handler files to output location
	return gulp.src([tempWindowsHandlerFilesSource])
	.pipe(zip('RMExtension.zip'))
	.pipe(gulp.dest(windowsHandlerArchievePackageLocation));
});

gulp.task('createLinuxHandlerPackage', function () {
	gutil.log("Archieving the linux extension handler package from location: " + tempLinuxHandlerFilesPath);
	gutil.log("Archieve output location: " + linuxHandlerArchievePackageLocation);
	var tempLinuxHandlerFilesSource = `${tempLinuxHandlerFilesPath}/**`;
	// archieving handler files to output location
	return gulp.src([tempLinuxHandlerFilesSource])
	.pipe(zip('RMExtension.zip'))
	.pipe(gulp.dest(linuxHandlerArchievePackageLocation));
});

gulp.task('createWindowsUIPackage', function () {
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

gulp.task('createLinuxUIPackage', function () {
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

gulp.task('generateWindowsTestArtifacts', artifactsGenerator(windowsHandlerArchievePackageLocation,"Test","ExtensionDefinition_Test_MIGRATED.xml"));
gulp.task('generateWindowsProdArtifacts', artifactsGenerator(windowsHandlerArchievePackageLocation,"Prod","ExtensionDefinition_Prod_MIGRATED.xml"));
gulp.task('generateLinuxTestArtifacts', artifactsGenerator(linuxHandlerArchievePackageLocation,"Test","ExtensionDefinition_Test_MIGRATED.xml"));
gulp.task('generateLinuxProdArtifacts', artifactsGenerator(linuxHandlerArchievePackageLocation,"Prod","ExtensionDefinition_Prod_MIGRATED.xml"));

gulp.task('build', gulp.series(gulp.parallel('cleanExistingBuild', 'cleanTempFolder'), 
	gulp.parallel(gulp.series('copyLinuxHandlerDefinitionFile', 'createTempLinuxHandlerPackage', 'createLinuxHandlerPackage'), 
	gulp.series('copyWindowsHandlerDefinitionFile', 'createTempWindowsHandlerPackage', 'test', 'createWindowsHandlerPackage')),
	gulp.parallel('generateWindowsTestArtifacts', 'generateWindowsProdArtifacts','generateLinuxTestArtifacts','generateLinuxProdArtifacts'), 'createWindowsUIPackage', 'createLinuxUIPackage'), function() {
    return new Promise(function(resolve, reject) {
		gutil.log("VM extension packages created at " + outputPath);
		console.log("HTTP Server Started");
    	resolve();
	})
});

