var gulp = require('gulp')
var gutil = require('gulp-util');
var spawn = require('child_process').spawn;
var os = require('os');
var path = require('path');
var zip = require('gulp-zip');
var minimist = require('minimist');

/*var mopts = {
    string: 'outputPath',
};*/

var options = minimist(process.argv.slice(2));

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

gulp.task("copyPackageFiles", function(){

    var tempLocation = os.tmpdir();
    gutil.log(tempLocation);

    return gulp.src(['../RMExtension/bin/**.**', '../RMExtension/enable.cmd', '../RMExtension/disable.cmd', '../RMExtension/HandlerManifest.json'],  {base: '../RMExtension/'})
        .pipe(gulp.dest(path.join(tempLocation, 'VSTSExtension')));
});

gulp.task('zipPackageFiles', function () {

	var tempLocation = os.tmpdir();
	var packageLocation = path.join(tempLocation, 'VSTSExtension/**');
	var packageLocation1 = path.join(tempLocation, 'VSTSExtension1');

	gutil.log(packageLocation);
    return gulp.src([packageLocation])
        .pipe(zip('RMExtension.zip'))
        .pipe(gulp.dest(options.outputPath));
});