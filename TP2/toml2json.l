%{
#include "y.tab.h"
%}
%option yylineno
%%
[ \t\n\r]  ;
#[^\n]+	;

[\=\[\]\,\.\{\}]	return yytext[0];

	/* Boolean */
true 						return TRUE;
false						return FALSE;

	/* Integers can start with a +, a - or nothing.
	   Leading zeros are not allowed. 
	   Underscores accepted for better readability*/
(0|(-|\+)?[1-9]((_?)[0-9])*)	{ char* s; char* d; for (s=d=yytext;*d=*s;d+=(*s++!='_'));	// remove os '_' caso existam
							  	  yylval.ivalue = atoi(yytext); 
							  	  return inumber; }

	/* Floats are an integer followed by a fractional and/or an exponent part. */
(-|\+)?[0-9]+((.[0-9]+)|(e(\+|-)?[0-9]+))	{ yylval.fvalue = atof(yytext); 
								  			  return fnumber; }

	/* DateTime 
	#offset datetime
	odt1 = 1979-05-27T07:32:00Z
	odt2 = 1979-05-27T00:32:00-07:00
	odt3 = 1979-05-27T00:32:00.999999-07:00
	# local datetime
	ldt1 = 1979-05-27T07:32:00
	ldt2 = 1979-05-27T00:32:00.999999
	# local date
	ld1 = 1979-05-27
	*/
[0-9]{4}(-[0-9]{2}){2}(T(([0-2][0-9](:[0-6][0-9]){2})(Z|(\+[0-1][0-9]:([03]0|45))?))((.|-|\+)[0-9]+((-|\+|:)[0-9]{2}(:[0-9]{2})?)?)?)? { 
								yytext[yyleng] = '\0';
								yylval.svalue = strdup(yytext); 
								return date; }

	/* Time */
[0-9]{2}(:[0-9]{2}){2}(.[0-9]+)?		{ yytext[yyleng] = '\0';
										  yylval.svalue = strdup(yytext); 
										  return time; }

	/* multi line strings: 
	"""
	string
	newline
	"""	or ''' str ''' */
(\"|\'){3}							{ return triplequote; }



	/* abc-d_e | ("abcde" | 'abcde' | 'abc" | "abc') */ 
([a-zA-Z0-9\-\_]+|(\"|\')(.*)(\"|\'))	{ 	if( (yytext[0] =='\"') || (yytext[0] =='\'')) {
												yytext[yyleng-1] = '\0';
												yylval.svalue = strdup(yytext+1);
											} else {
												yytext[yyleng] = '\0';
									  	  		yylval.svalue = strdup(yytext); 
									  	  	}
									  	  	return string;
								  	  	}

.	return ERRO;
