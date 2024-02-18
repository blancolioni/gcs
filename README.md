# gcs
 Generic lexer

Create a lexer by instantiating the generic package GCS.Lexer

See examples folder for an example lexer which scans a subset of Ada tokens.

Intended for creating quick lexers for small languages.

The instantiation of GCS.Lexer makes the following available:
   Open        - open a file for reading
   Open_String - open a string for reading
   Scan        - scan the next token
   Tok         - current token
   Next_Tok    - next token
   Prev_Tok    - previous token
   Tok_Text    - string with text of the current token
   Error       - report an error

See src/gcs-lexer.ads for the full list.