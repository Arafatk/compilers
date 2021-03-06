/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int verbose_flag;
extern int curr_lineno;

extern YYSTYPE cool_yylval;

int string_length = 0;
int comment_depth;
bool strTooLong();
void resetStr();
int strLenErr();
void addToStr(char* str);
/*
 *  Add Your own definitions here
 */



%}

/*
 * Define names for regular expressions here.
 */

DARROW          =>
%x STRING
%x BROKENSTRING
%x COMMENT
DIGIT    [0-9]
ALPHANUMERIC       [a-z0-9A-Z_]

%%
<INITIAL,COMMENT>"(*" {
                    comment_depth++;
                    BEGIN(COMMENT);
                }
<COMMENT>\n     { curr_lineno++; }
<COMMENT>.      {}
<COMMENT>"*)"   {   comment_depth--;
                    if (comment_depth == 0) {
                        BEGIN(INITIAL);
                    }
                }
<COMMENT><<EOF>> {
                    BEGIN(INITIAL);
                    cool_yylval.error_msg = "EOF in comment";
                    return(ERROR);
                }
<INITIAL>"*)"   {
                    cool_yylval.error_msg = "Unmatched *)";
                    return(ERROR);
}

"--".*\n        { curr_lineno++; }  /* discard line */
"--".*          { curr_lineno++; }  /* discard line */




char string_buf[MAX_STR_CONST];
char *string_buf_ptr;
{DIGIT}+                     {cool_yylval.symbol = idtable.add_string(yytext); return INT_CONST;}


\"            {
                    // "starting tag
                    BEGIN(STRING);
                }
<STRING>\"    {
                    // Closing tag"
                    cool_yylval.symbol = stringtable.add_string(string_buf);
                    resetStr();
                    BEGIN(INITIAL);
                    return(STR_CONST);
                }
<STRING>(\0|\\\0) {
                      cool_yylval.error_msg = "String contains null character";
                      BEGIN(BROKENSTRING);
                      return(ERROR);
                }
<BROKENSTRING>.*[\"\n] {
                    //"//Get to the end of broken string
                    BEGIN(INITIAL);
                }
<STRING>\\\n      {
                    // escaped slash
                    // printf("captured: %s\n", yytext);
                    if (strTooLong()) { return strLenErr(); }
                    curr_lineno++;
                    addToStr("\n");
                    string_length++;
                    // printf("buffer: %s\n", string_buf);
                }
<STRING>\n      {
                    // unescaped new line
                    curr_lineno++;
                    BEGIN(INITIAL);
                    resetStr();
                    cool_yylval.error_msg = "Unterminated string constant";
                    return(ERROR);
                }

<STRING><<EOF>> {
                    BEGIN(INITIAL);
                    cool_yylval.error_msg = "EOF in string constant";
                    return(ERROR);
                }

<STRING>\\n      {  // escaped slash, then an n
                    if (strTooLong()) { return strLenErr(); }
                    curr_lineno++;
                    addToStr("\n");
                }

<STRING>\\t     {
                    if (strTooLong()) { return strLenErr(); }
                    string_length++;
                    addToStr("\t");
}
<STRING>\\b     {
                    if (strTooLong()) { return strLenErr(); }
                    string_length++;
                    addToStr("\b");
}
<STRING>\\f     {
                    if (strTooLong()) { return strLenErr(); }
                    string_length++;
                    addToStr("\f");
}
<STRING>\\.     {
                    //escaped character, just add the character
                    if (strTooLong()) { return strLenErr(); }
                    string_length++;
                    addToStr(&strdup(yytext)[1]);
                }
<STRING>.       {
                    if (strTooLong()) { return strLenErr(); }
                    addToStr(yytext);
                    string_length++;
                }

\n          { curr_lineno++; }

[ \r\t\v\f] {}

{DARROW}        { return (DARROW); }
"<-"            { return (ASSIGN); }
"<="            { return (LE); }
"/"             { return '/'; }
"+"             { return '+'; }
"-"             { return '-'; }
"*"             { return '*'; }
"("             { return '('; }
")"             { return ')'; }
"="             { return '='; }
"<"             { return '<'; }
"."             { return '.'; }
"~"             { return '~'; }
","             { return ','; }
";"             { return ';'; }
":"             { return ':'; }
"@"             { return '@'; }
"{"             { return '{'; }
"}"             { return '}'; }

.           {
                              cool_yylval.error_msg = yytext;
                              return(ERROR);
}

(?i:class)      { return(CLASS); }
(?i:else)       { return(ELSE); }
(?i:fi)         { return(FI); }
(?i:if)         { return(IF); }
(?i:in)         { return(IN); }
(?i:inherits)   { return(INHERITS); }
(?i:let)        { return(LET); }
(?i:loop)       { return(LOOP); }
(?i:pool)       { return(POOL); }
(?i:then)       { return(THEN); }
(?i:while)      { return(WHILE); }
(?i:case)       { return(CASE); }
(?i:esac)       { return(ESAC); }
(?i:of)         { return(OF); }
(?i:new)        { return(NEW); }
(?i:isvoid)     { return(ISVOID); }
(?i:not)        { return(NOT); }

[f][A|a][L|l][S|s][E|e]     {cool_yylval.boolean = false; return BOOL_CONST;}
[t][R|r][U|u][E|e]          {cool_yylval.boolean = true;  return BOOL_CONST;}
[T][R|r][U|u][E|e]          {cool_yylval.symbol = idtable.add_string(yytext); return TYPEID;}




[a-z]{ALPHANUMERIC}*         {cool_yylval.symbol = idtable.add_string(yytext); return OBJECTID;}
[A-Z]{ALPHANUMERIC}*         {cool_yylval.symbol = idtable.add_string(yytext); return TYPEID;}

 /*
  *  Nested comments
  */



 /*
  *  The multiple-character operators.
  */
{DARROW}		{ return (DARROW); }

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */


 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for
  *  \n \t \b \f, the result is c.
  *
  */


%%

void addToStr(char* str) {
    strcat(string_buf, str);
}

bool strTooLong() {
  if (string_length + 1 >= MAX_STR_CONST) {
      BEGIN(BROKENSTRING);
      return true;
    }
    return false;
}

void resetStr() {
    string_length = 0;
    string_buf[0] = '\0';
}

int strLenErr() {
  resetStr();
    cool_yylval.error_msg = "String constant too long";
    return ERROR;
}
