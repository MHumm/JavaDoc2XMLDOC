# JavaDoc2XMLDOC
Simple JavaDoc to XMLDOC comment syntax converter for Pascal.

With this command line tool you can convert a unit using JavaDoc comment style 
to XMLDOC so the Delphi IDE can use this to show these comments in tooltips when 
hovering over any calls.

Currently only these sections are converted:

* Summary and Description. They are combined into a summary XMLDOC section
* Parameters: for each contained parameter a XMLDOC param tag is created
* Returns: this is converted into an XMLDOC returns section. If a Returns; section
  contains the contents "None." no XMLDOC comment for it will be created. No need 
  to create one for procedures/methods without return value.

To use the tool call it with an input file name as 1st parameter and an
output file name as 2nd parameter. The input file must exist and the output 
path needs to exist as well. Also do not specify the same file name and path 
for both file names, this has not been tested!

Development environment used: Delphi 12.1
License: Apache 2.0
