%{
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>

extern int yylex();
extern int yylineno;
extern char *yytext;
extern FILE* yyin;
extern FILE* yyout;
int yyerror();
int erroSem(char*);

extern int asprintf();

char* tabs(int i);
char* closelvls(int newlvl);
char* finalclose();
void printKeyVal(char** res, char* key, char* value);
void sectionUpdate(char* newSection, char** res);

int lvl = 1;
const char* section;
%}
%union{
	int ivalue;
	float fvalue;
	char* svalue;
}

%token ERRO string inumber fnumber TRUE FALSE date time triplequote
%type <ivalue> inumber
%type <fvalue> fnumber 
%type <svalue> string date time AtributeList Atribute Key Section Value Array ValueList Multiline

%%
Toml 								/*		remove last ',' 	  print with proper { }     finalclose write close for open sections */
	: AtributeList					{ $1[strlen($1)-1] = '\0'; fprintf(yyout,"{\n%s%s\n}\n", $1, finalclose()); }	
	;

AtributeList
	: AtributeList Atribute 		{  	char* aux = strdup($2); char* s; char* d; for (s=d=aux;*d=*s;d+=(*s++!='\t'));	/*	remove all '\t' */
										if( aux[0] == '}' ) {						/* 	if Atribute starts with '}' => new section */
											$1[strlen($1)-1] = '\0'; 				/*	new section => no ',' at the end of previous line */
										}
										asprintf(&$$,"%s\n%s",$1,$2); }
	| Atribute 						{ asprintf(&$$,"%s",$1); }
	;

Atribute
	: Key '=' Value 				{ printKeyVal(&$$, $1, $3); }
	| '[' Section ']' 				{ sectionUpdate($2,&$$); }
	;

Section
	: Section '.' string			{ asprintf(&$$,"%s %s", $1, $3); }
	| string						{ asprintf(&$$,"%s", $1); }
	;

Key
	: string 						{ asprintf(&$$,"%s", $1); }
	;

Value
	: string							{ asprintf(&$$,"\"%s\"",$1); }
	| inumber							{ asprintf(&$$,"%i",$1); }
	| fnumber							{ asprintf(&$$,"%lf",$1); }
	| TRUE								{ asprintf(&$$,"true");  }
	| FALSE								{ asprintf(&$$,"false"); }
	| date								{ asprintf(&$$,"\"%s\"",$1);  }
	| time								{ asprintf(&$$,"\"%s\"",$1);  }
	| Array								{ asprintf(&$$,"%s",$1); }
	| triplequote Multiline triplequote	{ asprintf(&$$,"\"\%s\"",$2); }
	;

Array
	: '[' ']' 					{ asprintf(&$$,"[ ]");  }
	| '[' ValueList ']'			{ asprintf(&$$,"[\n%s\n%s]",$2,tabs(lvl)); }
	;	

ValueList
	: ValueList ',' Value 		{ asprintf(&$$,"%s,\n%s%s",$1,tabs(lvl+1),$3); }
	| Value  					{ asprintf(&$$,"%s%s",tabs(lvl+1),$1); }
	;

Multiline
	: Multiline string 			{ asprintf(&$$,"%s\\n%s",$1,$2); }
	| string					{ asprintf(&$$,"%s",$1); }
	;

%%
int main(int argc, char *argv[]){
	if(argc==1) {
		yyparse();
		return 0;
	} else if (argc==2) {
		yyin = fopen(argv[1],"r");
		if (yyin == NULL) {
			printf("Erro na abertura do ficheiro de entrada\n");
			return 1;
		} else {
			yyparse();
			return 0;
		}
	} else if (argc==3) {
		yyin = fopen(argv[1],"r");
		if (yyin==NULL) {
			printf("Erro na abertura do ficheiro de entrada\n");
			return 2;
		}
		yyout = fopen(argv[2],"w");
		if(yyout == NULL) {
			printf("Erro na abertura do ficheiro de escrita\n");
			return 3;
		}
		yyparse();
		return 0;
	} else {
		printf("Número de argumentos inválido\n");
		printf("Pequenos testes imediatos: 		toml2json\n");
		printf("Visualização imediata de ficheiro: 	toml2json ficheiroEntrada\n");
		printf("Conversão para ficheiro: 		toml2json ficheiroEntrada ficheiroSaida\n");
		return 4;
	}
	return 0;
}

int erroSem(char *s) {
	printf("Erro Semântico na linha: %d, %s...\n", yylineno, s);
	return 0;
}

int yyerror(){
  printf("Erro Sintático ou Léxico na linha: %d, com o texto: %s\n", yylineno, yytext);;
  return 0;
}

char* tabs(int i) {
	char* tabs = malloc(sizeof('\t')*i);
	for(int j=0;j<i;j++) {
		tabs[j] = '\t';
	}
	tabs[i] = '\0';
	return tabs;
}

void printKeyVal(char** res, char* key, char* value) {
	asprintf(res,"%s\"%s\": %s,", tabs(lvl),key, value);
}

void sectionUpdate(char* newSection, char** res) {
	int newlvl = 1;
	const char s[2] = " ";
	char* token;
	char* newSectionTemp;
	token = strtok(newSection,s);
	char* aux = "";
	while(token != NULL) {
		newlvl++;
		newSectionTemp = strdup(token);
		token = strtok(NULL, s);		
		if((newlvl>lvl) && (token != NULL)) asprintf(&aux,"%s\"%s\": { \n",tabs(newlvl-1),newSectionTemp); 			/* New section opens more then one section */
	}
	if (newlvl == lvl) {
		section = strdup(newSectionTemp);
		asprintf(res,"%s%s\"%s\": { ",closelvls(newlvl),tabs(newlvl-1),section);
	}
	else if(newlvl > lvl) {
		lvl = newlvl; 
		asprintf(res,"%s%s\"%s\": { ",aux,tabs(lvl-1),newSectionTemp);
		section = strdup(newSection);
	} else {
		section = strdup(newSectionTemp);
		asprintf(res,"%s%s\"%s\": { ",closelvls(newlvl),tabs(newlvl-1),section);
		lvl = newlvl; 
	}
}

char* closelvls(int newlvl) {
	char* close = "";
	int x = lvl;
	while(x>newlvl) {
		x--;
		asprintf(&close,"%s%s}\n",close,tabs(x));
	}
	asprintf(&close,"%s%s},\n",close,tabs(x-1));
	return close;
}

char* finalclose() {
	char* close = "";
	for(int x=lvl; x>1; x--) {
		asprintf(&close,"%s\n%s}",close,tabs(x-1));
	}
	return close;
}