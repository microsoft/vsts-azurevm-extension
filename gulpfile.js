var gulp = require('gulp')
var gutil = require('gulp-util');
var spawn = require('child_process').spawn;
var os = require('os');
var path = require('path');
var zip = require('gulp-zip');
var minimist = require('minimist');

var tempLocation = os.tmpdir();
var tempPackagePath = path.join(tempLocation, 'VSTSExtensionTemp');
var outputPath = '_build';
var options = minimist(process.argv.slice(2));
if(!!options.outputPath) {
	outputPath = options.outputPath;
}


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

gulp.task('createWindowsHandlerPackage', ['test'], function () {
	
	var tempWindowsHandlerFilesPath = path.join(tempPackagePath, 'ExtensionHandler/Windows');
    gutil.log("Copying windows extensionm handler files selectively to temp location: " + tempWindowsHandlerFilesPath);

    gulp.src(['ExtensionHandler/Windows/src/bin/**.**', 'ExtensionHandler/Windows/src/enable.cmd', 'ExtensionHandler/Windows/src/disable.cmd', 'ExtensionHandler/Windows/src/HandlerManifest.json'],  {base: 'ExtensionHandler/Windows/src/'})
        .pipe(gulp.dest(tempWindowsHandlerFilesPath));


	var windowsHandlerArchievePackageLocation = path.join(outputPath, 'ExtensionHandler/Windows');
	gutil.log("Archieving the windows extension handler package from location: " + tempWindowsHandlerFilesPath);
	gutil.log("Archieve output location: " + windowsHandlerArchievePackageLocation);

    var tempWindowsHandlerFilesSource = path.join(tempWindowsHandlerFilesPath, '**');
	// archieving handler files to output location
    gulp.src([tempWindowsHandlerFilesSource])
        .pipe(zip('RMExtension.zip'))
        .pipe(gulp.dest(windowsHandlerArchievePackageLocation));

    // copying definition xml file to output location
    gulp.src(['ExtensionHandler/Windows/ExtensionDefinition_Test.xml'])
    	.pipe(gulp.dest(windowsHandlerArchievePackageLocation));
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
    gulp.src(['UI Package/Windows/Classic/**'])
        .pipe(zip('UIPackage.zip'))
        .pipe(gulp.dest(classicUIPackageLocation));

});

gulp.task('copyCDScripts', function () {
    gulp.src(['CDScripts/**'], {base: '.'})
        .pipe(gulp.dest(outputPath));
});

gulp.task('default', ['build']);

gulp.task('build', ['createWindowsHandlerPackage', 'createWindowsUIPackage', 'copyCDScripts'], function() {
    gutil.log("VM extension packages created at " + outputPath);
});