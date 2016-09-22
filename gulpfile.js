var gulp = require('gulp')
var gutil = require('gulp-util');
var spawn = require('child_process').spawn;
var os = require('os');
var path = require('path');
var zip = require('gulp-zip');
var minimist = require('minimist');

var tempLocation = os.tmpdir();
var tempPackageLocation = path.join(tempLocation, 'VSTSExtensionTemp');
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

gulp.task("copyPackageFiles", ['test'], function(){

	var tempWindowsHandlerPackageLocation = path.join(tempPackageLocation, 'ExtensionHandler/Windows');
    gutil.log("Copying windows extensionm handler files selectively to temp location: " + tempWindowsHandlerPackageLocation);

    return gulp.src(['ExtensionHandler/Windows/src/bin/**.**', 'ExtensionHandler/Windows/src/enable.cmd', 'ExtensionHandler/Windows/src/disable.cmd', 'ExtensionHandler/Windows/src/HandlerManifest.json'],  {base: 'ExtensionHandler/Windows/src/'})
        .pipe(gulp.dest(tempWindowsHandlerPackageLocation));
});

gulp.task('build', ['copyPackageFiles'], function () {
	
	var tempWindowsHandlerPackageLocation = path.join(tempLocation, 'VSTSExtensionTemp/ExtensionHandler/Windows/**');
	var windowsHandlerArchievePackageLocation = path.join(outputPath, 'ExtensionHandler/Windows');
	gutil.log("Archieving the windows extension handler package from location: " + tempWindowsHandlerPackageLocation);
	gutil.log("Archieve output location: " + windowsHandlerArchievePackageLocation);

	// archieving handler files to output location
    gulp.src([tempWindowsHandlerPackageLocation])
        .pipe(zip('RMExtension.zip'))
        .pipe(gulp.dest(windowsHandlerArchievePackageLocation));

    // copying definition xml file to output location
    gulp.src(['ExtensionHandler/Windows/ExtensionDefinition_Test.xml'])
    	.pipe(gulp.dest(windowsHandlerArchievePackageLocation));

    gutil.log("VM extension packages created at " + outputPath);
});

gulp.task('default', ['build']);