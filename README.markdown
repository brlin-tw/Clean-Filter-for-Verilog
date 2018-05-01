# Clean Filter for Verilog
[![Build Status of the latest revision of project on Travis CI](https://travis-ci.org/Lin-Buo-Ren/Clean-Filter-for-Verilog.svg?branch=master)](https://travis-ci.org/Lin-Buo-Ren/Clean-Filter-for-Verilog)  
Clean your Verilog design code!  
<https://github.com/Lin-Buo-Ren/Clean-Filter-for-Verilog>

## How to Use

Clone this repository as your project's submodule, and register `filter.bash` as verilog source files' clean filter.  Refer the `filter` attribute in the  `gitattributes(5)` manual page for more information.

Several runtime configurable options are available, refer the output of `filter.bash --help` for more info.

## Supported Cleaners

The executable path of the following cleaners must be in the executable search `PATH`s.

### vdent

[bmartini/vdent: Verilog Indenter. Simple indent program for Verilog source code. Trims end of line white space and indents lines based on nested depth of code blocks.](https://github.com/bmartini/vdent)

This is the default cleaner.

### iStyle

[thomasrussellmurphy/istyle-verilog-formatter: Open source implementation of a Verilog formatter](https://github.com/thomasrussellmurphy/istyle-verilog-formatter)

Use `--cleaner istyle` to enable this cleaner.

## License

GNU GPLv3+ 
