module.exports = function (grunt) {
  grunt.initConfig({
    xml_validator: {
      target: {
        src: [ '**/*.xml', '!node_modules/**' ]
      },
    },
  });


  grunt.loadNpmTasks('grunt-xml-validator');
  grunt.registerTask('validate', ['xml_validator']);

};

