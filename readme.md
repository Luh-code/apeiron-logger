# Apeiron-logger
Apeiron-logger is a performance oriented, highly customizable logger written in Zig.

Configuration is done at compile-time via config.json. This JSON file is then used for code generation.  
Apeiron-logger also features asynchronous file IO with double buffering.


Verbosity, as well as file name and location can be overridden by using command-line arguments:  
"-f", "--file" - specify a file name; will also enable log rotation  
"-p", "--path" - specify a directory for logs to be saved into  
"-v", "--verbosity" - specify a verbosity for logging to the console  
"-fv", "--file-verbosity" - specify a verbosity for logging to file
