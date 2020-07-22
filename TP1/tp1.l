%{
/* Declaracoes C diversas */
#include <stdio.h>
FILE *origem;
FILE *f;
FILE *r;
int id;
int replyid;
int noReplies;
%}
%option noyywrap
%x comment user datetime com
ws [ \t]
qname [a-zA-ZÀ-ú0-9_\-.:?!\ !\,]*

%%
	BEGIN 0;

[ \t\n]+ ; 

\<li\ class\=\"comment\"						BEGIN comment;

	/* --------------------- User --------------------- */
	/*			EXEMPLOS de user! 
		<h5 class="comment__author"> 
		<a href="https://natura.di.uminho.pt/utilizador/perfil/4febcb41-83c5-43f2-8236-838cffb9c7fc" rel="nofollow">Felipe Azyral </a> 
		</h5>  

		<h5 class="comment__author"> 
	                Conta desactivada por violação das regras de conduta 
	            </h5>  
	*/

	/*	Encontrar o user do comentário:  
		<h5 class="comment__author">  
		Entramos entao no estado user, já com a distinção entre comentário ou resposta feito aqui 
	*/

<comment>\<h5{ws}class\=\"comment\_\_author\"\> 		{	
															if (replyid == 0) {
																noReplies = 0;
																if (id>1) fprintf(f,",\n");
																else fprintf(f,"\n");
																fprintf(f,"\t{\n");
																fprintf(f,"\t\"id\": \"%d\",\n",id);
																fprintf(f,"\t\"user\": \""); 
																id++;
															} else {
																if(replyid>1) fprintf(r,",\n");
																fprintf(r,"\t\t{\n");
																fprintf(r,"\t\t\"id\": \"%d\",\n",replyid);
																fprintf(r,"\t\t\"user\": \""); 
																replyid++;
															}
															BEGIN user;
														}

	/*			Ignorar: 
		<a href="https://natura.di.uminho.pt/utilizador/perfil/b78163aa-b503-424c-82bc-43654c2ff5ab" rel="nofollow">
		</a> 
	*/

<user>\<a{ws}href[^>]+\> 								{;}
<user>\<\/a\>											{;}

	/* O resto é o username do user */
<user>[ \t\n]{2,}		{fprintf(f," ");}
<user>{qname} 											{ 
															if (replyid == 0) fprintf(f,"%s", yytext); 
															else fprintf(r,"%s", yytext); 
														}

	/* Fim da secção de user */														
<user>\<\/h5\>											{
															BEGIN comment;
															if (replyid == 0) fprintf(f,"\",\n");
															else fprintf(r,"\",\n");
														}

	/*--------------------- Date/timestamp --------------------- */									
	/*			EXEMPLO de date e timestamp 
		<a class="comment__permalink">03.10.2019 21:11</a>  

	 	encontrando: <a class="comment__permalink"> 
		entramos no estado datetime, que faz a distinção e escrita entre a data e o timestamp  */

<comment>\<a{ws}class\=\"comment\_\_permalink\"\>					BEGIN datetime;
<datetime>([0-2][1-9]|3[0-1])\.(0[1-9]|1[0-2])\.[0-9]{4} 	{ 	
																if (replyid == 0) {
																	fprintf(f,"\t\"date\": \"%s\",\n", yytext); 
																} else {
																	fprintf(r,"\t\t\"date\": \"%s\",\n", yytext); 
																}
															}

<datetime>([0-1][0-9]|2[0-4]):[0-5][0-9] 					{ 
																if (replyid == 0) {
																	fprintf(f,"\t\"timestamp\": \"%s\",\n",yytext);	
																} else {
																	fprintf(r,"\t\t\"timestamp\": \"%s\",\n",yytext);																	
																}														
																BEGIN comment;
															}

	/*--------------------- Comment Content--------------------- */									

<comment>\<div{ws}class\=\"comment\_\_content\"\> 		{ 	
															if (replyid == 0) {
																fprintf(f,"\t\"commentText\": \""); 
															} else {
																fprintf(r,"\t\t\"commentText\": \"");
															}
															BEGIN com;
														}
<com>\<p\>												{;}														
<com><\/p\>												{;}
<com>[ \t\n]{2,}										{fprintf(f," ");}
<com>{qname}											{ 	
															if (replyid == 0) fprintf(f,"%s",yytext);
															else fprintf(r,"%s", yytext);
														}
<com>\<\/div\> 											{ 	
															if (replyid == 0) {
																fprintf(f,"\",\n");
																fprintf(f,"\t\"likes\": 0,\n");
															} else {
																fprintf(r,"\",\n");
																fprintf(r,"\t\t\"likes\": 0,\n");
																fprintf(r,"\t\t\"hasReplies\": FALSE\n");
																fprintf(r,"\t\t\"numerOfReplies\": 0\n\n");
																fprintf(r,"\t\t\"replies\": [ ]\n");
																fprintf(r,"\t\t}");
															}
															BEGIN comment;
														}

	/*--------------------- Replies? --------------------- */									

	/* 	Caso encontre <ol class="comments__list"> 
		significa que os comentários seguinte, até <\ol> são respostas do comentário anterior, 
		portanto começamos a trabalhar com o id de resposta(reply) 
	*/

<comment>\<ol{ws}class\=\"comments\_\_list\"\>			{ 	
															replyid++;
														}	
<comment>\<\/ol\>										{
															noReplies = replyid-1;
															replyid = 0;
														}


	/* Chegando ao final do comentário processamos a escrita do hasReplies, numberOfReplies e das replies,
	caso existam, estando escritas temporariamente num ficheiro replies.json
	*/
<comment>\<form{ws}class\=\"form{ws}comments\_\_form{ws}expanded\" 			{
																			if(noReplies==0) fprintf(f,"\t\"hasReplies\": FALSE,\n");
																			else fprintf(f,"\t\"hasReplies\": TRUE,\n");
																			fprintf(f,"\t\"numberOfReplies\": %d,\n\n", noReplies);
																			fprintf(f,"\t\"replies\": [");

																			fclose(r);
																			FILE *file;
																			size_t nread;
																			char buf[100];
																			file = fopen("replies.json", "r");
																			if (file) {
																				nread = fread(buf, 1, sizeof buf, file);
																				if (nread>0) fprintf(f,"\n");
																			    while (nread > 0) {
																			        fwrite(buf, sizeof(char), nread,f);
																			        nread = fread(buf, 1, sizeof buf, file);
																			    }
																			    if (ferror(file)) {
																			        /* deal with error */
																			    }
																			    fclose(file);
																			}
																			if (noReplies>0)  fprintf(f,"\n\t]\n\t}");
																			else fprintf(f," ]\n\t}");
																			r = fopen("replies.json","w");

																			BEGIN 0;
																			}

<*>.|\n              	{;}

<<EOF>> { return id; }
%%
int parse(char* source, char* destino) {
	id = 1;
	replyid = 0;
	origem = fopen(source, "r");
	if(origem) yyin = origem;
	f = fopen(destino,"w");
	r = fopen("replies.json","w");
	if (f==NULL) {
		printf("erro na criação de ficheiro");
		return 0;
	}
	fprintf(f,"\"commentThread\": [");
	yylex();
	fprintf(f,"\n]");
	fclose(f);
	fclose(r);
	remove("replies.json");
	return id;
}

int main(int argc, char *argv[]) {
	parse(argv[1], argv[2]);

	return 0;
}

