%{
	#include "AST.h"
	#import "SwiftySheets.tab.h"
	
	void count();
	char *unescaped_string(char *str);
%}

%x SL_COMMENT
%x ML_COMMENT
%x INCLUDE


DIGIT		[0-9]
HEX			[0-9a-fA-f]
LETTER		[a-zA-Z_]

%%

"@include"						{ count(); BEGIN(INCLUDE); }
<INCLUDE>[ \t]*      /* eat the whitespace */
<INCLUDE>[^ \t\n]+   { /* got the include file name */
	const char* file = AST_resolve_path(yytext);
	yyin = fopen( file, "r" );
	
	if ( ! yyin ) {
		BEGIN(INITIAL);
		AST_handle_error( "Could not open file" );
		yyterminate();
	}
	
	yypush_buffer_state(yy_create_buffer( yyin, YY_BUF_SIZE ));
	AST_push_state(file);
	
	BEGIN(INITIAL);
}

"//"							{ count(); BEGIN(SL_COMMENT); }
<SL_COMMENT>\n					{ count(); BEGIN(INITIAL); }
<SL_COMMENT><<EOB>>				{ BEGIN(INITIAL); }
<SL_COMMENT>.					{ count(); }

"/*"							{ count(); BEGIN(ML_COMMENT); }
<ML_COMMENT>"*/"				{ count(); BEGIN(INITIAL); }
<ML_COMMENT><<EOB>>				{ BEGIN(INITIAL); }
<ML_COMMENT>.					{ count(); }

<<EOF>> {
	BEGIN(INITIAL);
	
	AST_pop_state();
	yypop_buffer_state();
	
	if ( !YY_CURRENT_BUFFER )
	{
		yyterminate();
	}
}


@(rgb|RGB)						{ count(); yylval.strval = strdup(yytext); return TK_RGB; }
@(rgba|RGBA)					{ count(); yylval.strval = strdup(yytext); return TK_RGBA; }
#{HEX}+							{ count(); yylval.strval = strdup(yytext); return TK_HEXA_LITERAL; }
[-+]?{DIGIT}*\.?{DIGIT}+		{ count(); yylval.strval = strdup(yytext); return TK_DECIMAL_LITERAL; }
[-+]?{DIGIT}+\.?{DIGIT}*		{ count(); yylval.strval = strdup(yytext); return TK_DECIMAL_LITERAL; }
{LETTER}({LETTER}|{DIGIT}|-)*	{ count(); yylval.strval = strdup(yytext); return TK_IDENTIFIER; }
\"(\\.|[^\\"])*\"				{ count(); yylval.strval = unescaped_string(strdup(yytext)); return(TK_STRING_LITERAL); }


[ \t\v\n\f]						{ count(); /* Ignore whitespaces */ }
.								{ count(); yylval.strval = strdup(yytext); return yytext[0]; }

%%

int yywrap() {
	return 1;
}

void count() {
	int i;
	
	for (i = 0; yytext[i] != '\0'; i++) {
		if (yytext[i] == '\n') {
			row++;
			column = 0;
		} else if (yytext[i] == '\t') {
			column += 8 - (column % 8);
		} else {
			column++;
		}		
	}
}

char *unescaped_string(char *str) {
	char *d = str;
	char *s = str + 1; // skip leading '"'
	while(*s) {
		if(*s == '\\') {
			s++;
			switch(*s) {
				case 'a':
					*d++ = '\a';
				break;
				case 'b':
					*d++ = '\b';
				break;
				case 'f':
					*d++ = '\f';
				break;
				case 'n':
					*d++ = '\n';
				break;
				case 'r':
					*d++ = '\r';
				break;
				case 't':
					*d++ = '\t';
				break;
				case 'v':
					*d++ = '\v';
				break;
				default:
					*d++ = *s;
			}
			s++;
		} else {
			*d = *s;
			d = d+1; s = s+1;
		}
	}
	*(--d) = 0;
	return str;
}

