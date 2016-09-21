var gulp = require('gulp')
var gutil = require('gulp-util');
var spawn = require('child_process').spawn;
var os = require('os');
var path = require('path');
var zip = require('gulp-zip');
var minimist = require('minimist');

var tempLocation = os.tmpdir();
var tempPackageLocation = path.join(tempLocation, 'VSTSExtensionTemp');
var outputPath = path.join(tempLocation, 'VSTSExtensionPackage');
var options = minimist(process.argv.slice(2));
if(!!options.outputPath) {
	outputPath = options.outputPath;
}


gulp.task("test", function(done){

    // Runs powershell pester tests ( Unit Test)
    var pester = spawn('powershell.exe', ['.\\InvokePester.ps1'], { stdio: 'inherit' });
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

    gutil.log("Copying files selectively to temp location: " + tempPackageLocation);

    return gulp.src(['../ExtensionHandler/Windows/src/bin/**.**', '../ExtensionHandler/Windows/src/enable.cmd', '../ExtensionHandler/Windows/src/disable.cmd', '../ExtensionHandler/Windows/src/HandlerManifest.json'],  {base: '../ExtensionHandler/Windows/src/'})
        .pipe(gulp.dest(tempPackageLocation));
});

gulp.task('build', ['copyPackageFiles'], function () {
	
	var sourceLocation = path.join(tempLocation, 'VSTSExtensionTemp/**');
	gutil.log("Archieving the package from location: " + sourceLocation);
	gutil.log("Archieve output location: " + outputPath);

	// archieving handler files to output location
    gulp.src([sourceLocation])
        .pipe(zip('RMExtension.zip'))
        .pipe(gulp.dest(outputPath));

    // copying definition xml file to output location
    gulp.src(['../ExtensionHandler/Windows/ExtensionDefinition_Test.xml'])
    	.pipe(gulp.dest(outputPath));

    gutil.log("VM extension packaged created at " + outputPath);
});

gulp.task('default', ['build']);