Multizip 0.1
============

Utility for compress and split files.

The utility consists of two programs:

* multizip -> Command line program to compress or split files.
* multiunzip -> Command line program to uncompress or join files.

## Multizip

  Utility to compress and split files or folders.
  
  SYNTAX:
    multizip <input files> [optional parameters]

Optional parameters can be: 

  -h or --help;
    Print help information.
	
  -o <file name> or --output=<filename>
    Set output file name. If not specified, a default name will be used.
	
  -s <max.size> or --size=<max.size>
    Split the compressed file in files of "max.size" kilobytes.
  
  Example 1: Compress the file this.txt to this.zip
    multizip this.txt
  
  Example 2: Compress the files 1.txt and 2.txt to 12.zip
    multizip 1.txt 2.txt -o 12.zip
  
  Example 3: Compress all the *.txt files to text.zip
    multizip *.txt -o text.zip

  Example 4: Compress an split the file a.txt in parts of 10KB
    multizip a.txt -s 10
  
  Compressed files will be saved as the standard name *.zip.
  
  Compressed and splitted files will be saved as several names with a number
  as ordinal: *.0.zp *.1.zp *.2.zp...
	
	
## Multiunzip

  Utility to uncompress and join files or folders compressed or splitted
  by MULTIZIP.
  
  SYNTAX: 
    Multiunzip <input file> [optional parameters]
  
  <input file> is the compressed file. For join splitted files, only the
  *.0.part must be indicated
  
  Optional parameters can be: 
  
  -h or --help
    Print help information.
	
  -f <folder name> or --folder=<fodler name>
    Set output folder where extract compressed files. If not specified, it.
    will be used the same folder of the compressed file.
  
  Example 1: Uncompress the file this.zip to this.zip
    Multiunzip this.zip
  
  Example 2: Join the files text.0.zp, text.1.zp, ...
    Multiunzip text.0.zp
