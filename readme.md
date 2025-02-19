## Disclaimer
Quite badly written, will be overhauled at some point. Currently very annoying to set up, will be reworked at some point as well.
# Apeiron-logger
Apeiron-logger is a performance oriented, highly customizable logger written in Zig.

Configuration is done at compile-time via config.json. This JSON file is then used for code generation.  
Apeiron-logger also features asynchronous file IO with double buffering.

Verbosity, as well as file name and location can be overridden by using command-line arguments:  
"-f", "--file" - specify a file name for the log file  
"-p", "--path" - specify a directory for logs to be saved into  
"-v", "--verbosity" - specify a verbosity for logging to the console  
"-fv", "--file-verbosity" - specify a verbosity for logging to file

If there is ever a case where a filename is already used, logs get rotated to "\*.old" and then get truncated.

I do not recommend anyone trying to learn from this code. It is an absolute mess, this project was mostly just me learning how Zig works :).  
This will be completely redone at some point - but that point is not right now. Use at your own risk.

Also the maximum lien length is 1000 chars minus the whole metadata like time and co.
