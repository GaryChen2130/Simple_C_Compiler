/*	Definition section */
%{

#include <stdio.h>
#include <stdbool.h>
#include <string.h>

int error_num;
extern int yylineno;
extern int yylex();
extern char* yytext;   // Get current token from lex
char* error_msg;
extern char buf[256];  // Get current code line from lex

/* Symbol table function - you can add new function if needed. */
int lookup_symbol(char *);
void create_symbol();
void insert_symbol(char *symbol_name,char *entry_name, char *data_name);
void dump_symbol();

int syntax_error_flag;

typedef struct entry{

	int entry_num;
	char *name;
	char *entry_type;
        char *data_type;
        int scope_level;
        char *parameters;
        struct entry *next;

} Entry;

Entry *table_head;

void Insert_Entry(Entry **, Entry *);
Entry *Remove_Entry();
void yysemantic(int);
void Print_Table(int);

%}

/* Use variable or self-defined structure to represent
 * nonterminal and token type
 */
%union {
    int i_val;
    double f_val;
    char* string;
}

/* Token without return */
%token PRINT 
%token IF ELSE FOR WHILE
%token SEMICOLON RET CONT BREAK
%token ADD SUB MUL DIV MOD INC DEC
%token MT LT MTE LTE EQ NE
%token ASGN ADDASGN SUBASGN MULASGN DIVASGN MODASGN
%token AND OR NOT LB RB LCB RCB LSB RSB COMMA QUATA

/* Token with return, which need to sepcify type */
%token <i_val> I_CONST
%token <f_val> F_CONST
%token <string> STR_CONST
%token <string> ID
%token <string> STRING INT FLOAT BOOL VOID TRUE FALSE

/* Nonterminal with return, which need to sepcify type */
%type <string> type
%type <string> func_def declaration declaration_specs declarator 
%type <string> parameter_list parameter_declaration
%type <string> init_declarator_list init_declarator
%type <string> postfix_expression primary_expression
%type <string> id_var

/* Yacc will start at this nonterminal */
%start program

/* Grammar section */
%%

program
    : global_declaration
    | program global_declaration
;

global_declaration 
    : func_def
    | declaration
;

func_def 
    : declaration_specs declarator declaration_list compound_stat 	{insert_symbol($2, "function", $1);}
    | declaration_specs declarator compound_stat 			{insert_symbol($2, "function", $1);}
    | declarator declaration_list compound_stat
    | declarator compound_stat
;

declaration_specs 
    : type			{$$ = $1;}
    | type declaration_specs	{;}
;

declarator 
    : ID							{$$ = strdup(yytext);}
    | LB declarator RB						{;}
    | declarator LB enter_scope parameter_list RB leave_scope	{$$ = strcat(strcat($1,"|"), $4);}
    | declarator LB id_list RB					{;}
    | declarator LB RB						{$$ = $1;}
;

declaration_list 
    : declaration
    | declaration_list declaration
;

compound_stat 
    : LCB enter_scope RCB leave_scope
    | LCB enter_scope block_item_list RCB leave_scope
;
enter_scope : {++(table_head -> scope_level); /*printf("%d\n",table_head -> scope_level);*/}
leave_scope : {--(table_head -> scope_level);}

block_item_list
    : block_item
    | block_item_list block_item
;

block_item 
    : declaration_list
    | stat_list
;

stat_list 
    : stat
    | stat_list stat
;

declaration 
    : declaration_specs SEMICOLON				
    | declaration_specs init_declarator_list SEMICOLON	{	if(lookup_symbol($2) != 1)
									insert_symbol($2, "variable", $1);
								else{
									error_num = 4;
									if(error_msg == NULL)
										error_msg = strdup("Redeclared variable ");
									else
										strcpy(error_msg,"Redeclared variable ");
									strcat(error_msg, $2);
								}
							}
;

stat 
    : compound_stat
    | expression_stat
    | select_stat
    | loop_stat
    | jump_stat
    | print_stat
;

print_stat 
    : PRINT LB QUATA STR_CONST QUATA RB SEMICOLON
    | PRINT LB id_var RB SEMICOLON			{
    								if(lookup_symbol($3) < 0){
									error_num = 2;
									if(error_msg == NULL)
										error_msg = strdup("Undeclared variable ");
									else
										strcpy(error_msg, "Undeclared variable ");
									strcat(error_msg,$3);
								}
							}
;

id_var 
    : ID {$$ = strdup(yytext);}
;

expression_stat 
    : SEMICOLON
    | expression SEMICOLON
;

select_stat 
    : IF LB expression RB stat
    | IF LB expression RB stat ELSE stat
;

loop_stat 
    : WHILE LB expression RB stat
;

jump_stat 
    : CONT SEMICOLON
    | BREAK SEMICOLON
    | RET SEMICOLON
    | RET expression SEMICOLON
;

expression 
    : assign_expression
    | expression COMMA assign_expression
;

assign_expression 
    : logical_or_expression
    | unary_expression assign_op assign_expression
;

logical_or_expression 
    : logical_and_expression
    | logical_or_expression OR logical_and_expression
;

logical_and_expression 
    : equality_expression
    | logical_and_expression AND equality_expression
;

equality_expression 
    : relation_expression
    | equality_expression EQ relation_expression
    | equality_expression NE relation_expression
;

relation_expression 
    : add_expression
    | relation_expression LT add_expression
    | relation_expression MT add_expression
    | relation_expression LTE add_expression
    | relation_expression MTE add_expression
;

add_expression 
    : mul_expression
    | add_expression ADD mul_expression
    | add_expression SUB mul_expression
;

mul_expression 
    : unary_expression
    | mul_expression MUL unary_expression
    | mul_expression DIV unary_expression
    | mul_expression MOD unary_expression
;

unary_expression 
    : postfix_expression
    | INC unary_expression
    | DEC unary_expression
    | unary_op unary_expression
;

postfix_expression 
    : primary_expression				{$$ = $1;}
    | postfix_expression LSB expression RSB
    | postfix_expression LB RB
    | postfix_expression LB argv_expression_list RB	{ if(lookup_symbol($1) < 0){
							  	error_num = 1;
								if(error_msg == NULL)
									error_msg = strdup("Undeclared function ");
								else
									strcpy(error_msg, "Undeclared function ");
								strcat(error_msg,$1);
							  }
							}
    | postfix_expression INC
    | postfix_expression DEC
;

primary_expression 
    : ID			{
					$$ = strdup(yytext);
    					if(lookup_symbol(yytext) < 0){
						error_num = 2;
						if(error_msg == NULL)
							error_msg = strdup("Undeclared variable ");
						else
							strcpy(error_msg, "Undeclared variable ");
						strcat(error_msg,yytext);
					}
				}
    | I_CONST			{;}
    | F_CONST			{;}
    | QUATA STR_CONST QUATA	{;}
    | TRUE
    | FALSE
    | LB expression RB		{;}
;

parameter_list 
    : parameter_declaration				{$$ = $1;}
    | parameter_list COMMA parameter_declaration	{$$ = strcat(strcat($1, ", "), $3);}
;

parameter_declaration 
    : declaration_specs declarator	{$$ = $1; insert_symbol($2, "parameter", $1);}
    | declaration_specs			
;

argv_expression_list 
    : assign_expression
    | argv_expression_list COMMA assign_expression
;

init_declarator_list 
    : init_declarator					{$$ = $1;}
    | init_declarator_list COMMA init_declarator
;

init_declarator 
    : declarator			{$$ = $1;}
    | declarator ASGN initializer	{$$ = $1;}
;

initializer 
    : assign_expression
    | LCB init_list RCB
    | LCB init_list COMMA RCB
;

init_list 
    : initializer
    | init_list COMMA initializer
;

assign_op 
    : ASGN
    | ADDASGN
    | SUBASGN
    | MULASGN
    | DIVASGN
    | MODASGN
;

id_list 
    : ID
    | id_list COMMA ID
;

unary_op 
    : ADD
    | SUB
    | NOT
;

/* actions can be taken when meet the token or rule */
type
    : INT { $$ = strdup(yytext); }
    | FLOAT { $$ = strdup(yytext); }
    | BOOL  { $$ = strdup(yytext); }
    | STRING { $$ = strdup(yytext); }
    | VOID { $$ = strdup(yytext); }
;

%%

/* C code section */
int main(int argc, char** argv)
{
    yylineno = 0;
    error_num = 0;
    error_msg = NULL;
    syntax_error_flag = 0;

    create_symbol();
    yyparse();
    if(syntax_error_flag == 0){
    	Print_Table(0);
    	printf("\nTotal lines: %d \n",yylineno);
    }

    return 0;
}

void yyerror(char *s)
{
    if(error_num != 0)
    	yysemantic(1);
    else
    	printf("%d: %s\n", yylineno + 1,buf);

    syntax_error_flag = 1;
    printf("\n|-----------------------------------------------|\n");
    printf("| Error found in line %d: %s\n", yylineno + 1, buf);
    printf("| %s", s);
    printf("\n|-----------------------------------------------|\n\n");
    memset(buf,'\0',sizeof(buf));
    
}

void yysemantic(int mode){

    	error_num = 0;
	printf("%d: %s\n", yylineno + mode, buf);
    	printf("\n|-----------------------------------------------|\n");
    	printf("| Error found in line %d: %s\n", yylineno + mode, buf);
    	printf("| %s", error_msg);
    	printf("\n|-----------------------------------------------|\n\n");
	if(!mode)memset(buf,'\0',sizeof(buf));

}

void create_symbol() {
	table_head = (Entry *)malloc(sizeof(Entry));
	table_head -> entry_num = 0;
	table_head -> scope_level = 0;
	table_head -> next = NULL;
}

void insert_symbol(char *symbol_name, char *entry_name, char *data_name) {

	//printf("insert symbol\n%s\n%s\n%s\n", symbol_name, entry_name, data_name);
	Entry *new_entry = (Entry *)malloc(sizeof(Entry));
	new_entry -> entry_num = (table_head -> entry_num)++;
	new_entry -> scope_level = table_head -> scope_level;
	new_entry -> name = strdup(symbol_name);
	new_entry -> entry_type = strdup(entry_name);
	new_entry -> data_type = strdup(data_name);
	Insert_Entry(&table_head, new_entry);

}

int lookup_symbol(char *id) {
	
	Entry *cur;
	char *name;

	cur = table_head;
	cur = cur -> next;
	while(cur != NULL){
		name = strdup(cur -> name);
		strcpy(name, strtok(name, "|"));
		if((!strcmp(id, name)) && (cur -> scope_level == table_head -> scope_level))
			break;
		cur = cur -> next;
	}

	if(cur != NULL) return 1; // Find out in the same scope

	cur = table_head;
	cur = cur -> next;
	while(cur != NULL){
		name = strdup(cur -> name);
		strcpy(name, strtok(name, "|"));
		if(!strcmp(id, name))
			break;
		cur = cur -> next;
	}

	if(cur == NULL) return -1; // Not found
	else return 0; // Find out in different scope

}

void dump_symbol() {
    printf("\n%-10s%-10s%-12s%-10s%-10s%-10s\n\n",
           "Index", "Name", "Kind", "Type", "Scope", "Attribute");
}


void Insert_Entry(Entry **head, Entry *new_entry){
	head = &((*head) -> next);
	while(*head != NULL)
		head = &((*head) -> next);
	(*head) = new_entry;
	new_entry -> next = NULL;
	return;
}


Entry *Remove_Entry(){

	int n = table_head -> scope_level;
	Entry *cur,*prev;

	cur = table_head;
	prev = cur;
	cur = cur -> next;
	while(cur != NULL){
		if((*cur).scope_level == n){
			prev -> next = cur -> next;
			return cur;
		}
		prev = cur;
		cur = cur -> next;
	}

	return NULL;

}

void Print_Table(int mode){

	int index = 0,scope,cur_scope,flag = 0;
	char *name,*e,*d,*p;
	Entry *cur;
	if(mode) ++(table_head -> scope_level);

	do{

		cur = Remove_Entry();
		if(cur == NULL){
			if(mode) --(table_head -> scope_level);
			break;
		}

		if(index == 0)dump_symbol();
		name = strtok(cur -> name, "|");
		e = cur -> entry_type;
		d = cur -> data_type;
		scope = cur -> scope_level;
		p = strtok(NULL, "|");
		if(p == NULL) p = "";
		printf("%-10d%-10s%-12s%-10s%-10d%s\n",index++,name,e,d,scope,p);
		flag = 1;

	}
	while(1);

	if(flag) printf("\n");
	return;

}





