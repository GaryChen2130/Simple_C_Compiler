/*	Definition section */
%{

#include <stdio.h>
#include <stdbool.h>
#include <string.h>

extern int yylineno;
extern int yylex();
extern char* yytext;   // Get current token from lex
extern char buf[256];  // Get current code line from lex

/* Symbol table function - you can add new function if needed. */
int lookup_symbol();
void create_symbol();
void insert_symbol(char *symbol_name,char *entry_name, char *data_name);
void dump_symbol();

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

void Insert_Entry(Entry **,Entry *);
Entry *Remove_Entry(Entry **,int);

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
%type <string> func_def declaration_specs declarator parameter_list

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
    : declaration_specs declarator declaration_list compound_stat	{/*insert_symbol($2, "function", $1);*/}
    | declaration_specs declarator compound_stat			{/*insert_symbol($2, "function", $1);*/}
    | declarator declaration_list compound_stat				{;}
    | declarator compound_stat						{;}
;

declaration_specs 
    : type			{/*$$ = $1;*/}
    | type declaration_specs	{;}
;

declarator 
    : ID				{/*$$ = strcat($1, " ");*/}
    | LB declarator RB			{;}
    | declarator LB parameter_list RB	{/*$$ = strcat($1, $1);*/}
    | declarator LB id_list RB		{;}
    | declarator LB RB			{/*$$ = $1;*/}
;

declaration_list 
    : declaration
    | declaration_list declaration
;

compound_stat 
    : LCB RCB	
    | LCB stat_list RCB       
    | LCB declaration_list RCB		
    | LCB declaration_list stat_list RCB				
;

stat_list 
    : stat
    | stat_list stat
;

declaration 
    : declaration_specs SEMICOLON
    | declaration_specs init_declarator_list SEMICOLON
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
    | PRINT LB ID RB SEMICOLON
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
    : primary_expression
    | postfix_expression LSB expression RSB
    | postfix_expression LB RB
    | postfix_expression LB argv_expression_list RB
    | postfix_expression INC
    | postfix_expression DEC
;

primary_expression 
    : ID
    | I_CONST
    | F_CONST
    | QUATA STR_CONST QUATA
    | TRUE
    | FALSE
    | LB expression RB
;

parameter_list 
    : parameter_declaration				{$$ = "";}
    | parameter_list COMMA parameter_declaration	{$$ = "";}
;

parameter_declaration 
    : declaration_specs declarator
    | declaration_specs
;

argv_expression_list 
    : assign_expression
    | argv_expression_list COMMA assign_expression
;

init_declarator_list 
    : init_declarator
    | init_declarator_list COMMA init_declarator
;

init_declarator 
    : declarator
    | declarator ASGN initializer
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
    : INT { $$ = $1; }
    | FLOAT { $$ = $1; }
    | BOOL  { $$ = $1; }
    | STRING { $$ = $1; }
    | VOID { $$ = $1; }
;

%%

/* C code section */
int main(int argc, char** argv)
{
    yylineno = 0;

    create_symbol();
    printf("1: ");
    yyparse();
    printf("\nTotal lines: %d \n",yylineno);
    dump_symbol();

    return 0;
}

void yyerror(char *s)
{
    printf("\n|-----------------------------------------------|\n");
    printf("| Error found in line %d: %s\n", yylineno, buf);
    printf("| %s", s);
    printf("\n|-----------------------------------------------|\n\n");
}

void create_symbol() {
	table_head = (Entry *)malloc(sizeof(Entry));
	table_head -> entry_num = 0;
	table_head -> scope_level = 0;
}

void insert_symbol(char *symbol_name, char *entry_name, char *data_name) {

	Entry *new_entry = (Entry *)malloc(sizeof(Entry));
	new_entry -> entry_num = ++(table_head -> entry_num);
	new_entry -> scope_level = table_head -> scope_level;
	new_entry -> name = strdup(symbol_name);
	new_entry -> entry_type = strdup(entry_name);
	new_entry -> data_type = strdup(data_name);
	Insert_Entry(&table_head, new_entry);

}

int lookup_symbol() {}

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


Entry *Remove_Entry(Entry **head,int n){

	Entry *cur,*prev;

	cur = *head;
	prev = cur;
	cur = cur -> next;
	while(cur != NULL){
		if((*cur).entry_num == n){
			prev -> next = cur -> next;
			return cur;
		}
		prev = cur;
		cur = cur -> next;
	}

	return NULL;

}







