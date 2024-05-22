%{
#define _POSIX_C_SOURCE 200809L
#include <string.h>
#include <stdint.h>
#include "hoc.h"

void yyerror(char *);
int yylex(void);
extern int indef;

#define	code2(c1,c2)	code(c1); code(c2)
#define	code3(c1,c2,c3)	code(c1); code(c2); code(c3)
%}
%union {
	Symbol	*sym;	/* symbol table pointer */
	Inst	*inst;	/* machine instruction */
	int	narg;	/* number of arguments */
	Formal	*formals;	/* list of formal parameters */
}
%token	<sym>	NUMBER STRING PRINT VAR BLTIN UNDEF WHILE FOR IF ELSE
%token	<sym>	FUNCTION PROCEDURE RETURN FUNC PROC READ
%type	<formals>	formals
%type	<inst>	expr stmt asgn prlist stmtlist
%type	<inst>	cond while for if begin end
%type	<sym>	procname
%type	<narg>	arglist
%right	'=' ADDEQ SUBEQ MULEQ DIVEQ MODEQ
%left	OR
%left	AND
%left	GT GE LT LE EQ NE
%left	'+' '-'
%left	'*' '/' '%'
%left	UNARYMINUS NOT INC DEC
%right	'^'
%%
list:	  /* nothing */
	| list '\n'
	| list defn '\n'
	| list asgn '\n'  { code2(xpop, STOP); return 1; }
	| list stmt '\n'  { code(STOP); return 1; }
	| list expr '\n'  { code2(printtop, STOP); return 1; }
	| list error '\n' { yyerrok; }
	;
asgn:	  VAR '=' expr { code3(varpush,(Inst)$1,assign); $$=$3; }
	| VAR ADDEQ expr	{ code3(varpush,(Inst)$1,addeq); $$=$3; }
	| VAR SUBEQ expr	{ code3(varpush,(Inst)$1,subeq); $$=$3; }
	| VAR MULEQ expr	{ code3(varpush,(Inst)$1,muleq); $$=$3; }
	| VAR DIVEQ expr	{ code3(varpush,(Inst)$1,diveq); $$=$3; }
	| VAR MODEQ expr	{ code3(varpush,(Inst)$1,modeq); $$=$3; }
	;
stmt:	  expr	{ code(xpop); }
	| RETURN { defnonly("return"); code(procret); }
	| RETURN expr
	        { defnonly("return"); $$=$2; code(funcret); }
	| PROCEDURE begin '(' arglist ')'
		{ $$ = $2; code3(call, (Inst)$1, (Inst)(uintptr_t)$4); }
	| PRINT prlist	{ $$ = $2; }
	| while '(' cond ')' stmt end {
		($1)[1] = (Inst)$5;	/* body of loop */
		($1)[2] = (Inst)$6; }	/* end, if cond fails */
	| for '(' cond ';' cond ';' cond ')' stmt end {
		($1)[1] = (Inst)$5;	/* condition */
		($1)[2] = (Inst)$7;	/* post loop */
		($1)[3] = (Inst)$9;	/* body of loop */
		($1)[4] = (Inst)$10; }	/* end, if cond fails */
	| if '(' cond ')' stmt end {	/* else-less if */
		($1)[1] = (Inst)$5;	/* thenpart */
		($1)[3] = (Inst)$6; }	/* end, if cond fails */
	| if '(' cond ')' stmt end ELSE stmt end {	/* if with else */
		($1)[1] = (Inst)$5;	/* thenpart */
		($1)[2] = (Inst)$8;	/* elsepart */
		($1)[3] = (Inst)$9; }	/* end, if cond fails */
	| '{' stmtlist '}'	{ $$ = $2; }
	;
cond:	   expr 	{ code(STOP); }
	;
while:	  WHILE	{ $$ = code3(whilecode,STOP,STOP); }
	;
for:	  FOR	{ $$ = code(forcode); code3(STOP,STOP,STOP); code(STOP); }
	;
if:	  IF	{ $$ = code(ifcode); code3(STOP,STOP,STOP); }
	;
begin:	  /* nothing */		{ $$ = progp; }
	;
end:	  /* nothing */		{ code(STOP); $$ = progp; }
	;
stmtlist: /* nothing */		{ $$ = progp; }
	| stmtlist '\n'
	| stmtlist stmt
	;
expr:	  NUMBER { $$ = code2(constpush, (Inst)$1); }
	| VAR	 { $$ = code3(varpush, (Inst)$1, eval); }
	| asgn
	| FUNCTION begin '(' arglist ')'
		{ $$ = $2; code3(call,(Inst)$1,(Inst)(uintptr_t)$4); }
	| READ '(' VAR ')' { $$ = code2(varread, (Inst)$3); }
	| BLTIN '(' expr ')' { $$=$3; code2(bltin, (Inst)$1->u.ptr); }
	| '(' expr ')'	{ $$ = $2; }
	| expr '+' expr	{ code(add); }
	| expr '-' expr	{ code(sub); }
	| expr '*' expr	{ code(mul); }
	| expr '/' expr	{ code(divop); }
	| expr '%' expr	{ code(mod); }
	| expr '^' expr	{ code (power); }
	| '-' expr   %prec UNARYMINUS   { $$=$2; code(negate); }
	| expr GT expr	{ code(gt); }
	| expr GE expr	{ code(ge); }
	| expr LT expr	{ code(lt); }
	| expr LE expr	{ code(le); }
	| expr EQ expr	{ code(eq); }
	| expr NE expr	{ code(ne); }
	| expr AND expr	{ code(and); }
	| expr OR expr	{ code(or); }
	| NOT expr	{ $$ = $2; code(not); }
	| INC VAR	{ $$ = code2(preinc,(Inst)$2); }
	| DEC VAR	{ $$ = code2(predec,(Inst)$2); }
	| VAR INC	{ $$ = code2(postinc,(Inst)$1); }
	| VAR DEC	{ $$ = code2(postdec,(Inst)$1); }
	;
prlist:	  expr			{ code(prexpr); }
	| STRING		{ $$ = code2(prstr, (Inst)$1); }
	| prlist ',' expr	{ code(prexpr); }
	| prlist ',' STRING	{ code2(prstr, (Inst)$3); }
	;
defn:	  FUNC procname { $2->type=FUNCTION; indef=1; }
	    '(' formals ')' stmt { code(procret); define($2, $5); indef=0; }
	| PROC procname { $2->type=PROCEDURE; indef=1; }
	    '(' formals ')' stmt { code(procret); define($2, $5); indef=0; }
	;
formals:	{ $$ = 0; }
	| VAR			{ $$ = formallist($1, 0); }
	| VAR ',' formals	{ $$ = formallist($1, $3); }
	;
procname: VAR
	| FUNCTION
	| PROCEDURE
	;
arglist:  /* nothing */ 	{ $$ = 0; }
	| expr			{ $$ = 1; }
	| arglist ',' expr	{ $$ = $1 + 1; }
	;
%%
	/* end of grammar */
#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <setjmp.h>
#include <errno.h>
#include <ctype.h>

char	*progname;
int	lineno = 1;
jmp_buf	begin;
char	*infile;	/* input file name */
FILE	*fin;		/* input file pointer */
char	**gargv;	/* global argument list */
int	gargc;

int c = '\n';	/* global for use by warning() */

int	backslash(int), follow(int, int, int);
void	run(void);
void	warning(char *, char *);

int
yylex(void)		/* hoc6 */
{
	while ((c = getc(fin)) == ' ' || c == '\t')
		;
	if (c == EOF)
		return 0;
	if (c == '\\') {
		c = getc(fin);
		if (c == '\n') {
			lineno++;
			return yylex();
		}
	}
	if (c == '#') {		/* comment */
		while ((c = getc(fin)) != '\n' && c != EOF)
			;
		if (c == '\n')
			lineno++;
		return c;
	}
	if (c == '.' || isdigit(c)) {	/* number */
		double d;
		ungetc(c, fin);
		fscanf(fin, "%lf", &d);
		yylval.sym = install("", NUMBER, d);
		return NUMBER;
	}
	if (isalpha(c) || c == '_' || c >= 0x80) {
		Symbol *s;
		char sbuf[100], *p = sbuf;
		do {
			if (p >= sbuf + sizeof(sbuf) - 1) {
				*p = '\0';
				execerror("name too long", sbuf);
			}
			*p++ = c;
		} while ((c = getc(fin)) != EOF && (isalnum(c) || c == '_' || c >= 0x80));
		ungetc(c, fin);
		*p = '\0';
		if ((s = lookup(sbuf)) == 0)
			s = install(sbuf, UNDEF, 0.0);
		yylval.sym = s;
		return s->type == UNDEF ? VAR : s->type;
	}
	if (c == '"') {	/* quoted string */
		char sbuf[100], *p;
		for (p = sbuf; (c = getc(fin)) != '"'; p++) {
			if (c == '\n' || c == EOF)
				execerror("missing quote", "");
			if (p >= sbuf + sizeof(sbuf) - 1) {
				*p = '\0';
				execerror("string too long", sbuf);
			}
			*p = backslash(c);
		}
		*p = 0;
		yylval.sym = (Symbol *)emalloc(strlen(sbuf)+1);
		strcpy((char*)yylval.sym, sbuf);
		return STRING;
	}
	switch (c) {
	case '+':	return follow('+', INC, '+') == INC ? INC : follow('=', ADDEQ, '+');
	case '-':	return follow('-', DEC, '-') == DEC ? DEC : follow('=', SUBEQ, '-');
	case '*':	return follow('=', MULEQ, '*');
	case '/':	return follow('=', DIVEQ, '/');
	case '%':	return follow('=', MODEQ, '%');
	case '>':	return follow('=', GE, GT);
	case '<':	return follow('=', LE, LT);
	case '=':	return follow('=', EQ, '=');
	case '!':	return follow('=', NE, NOT);
	case '|':	return follow('|', OR, '|');
	case '&':	return follow('&', AND, '&');
	case '\n':	lineno++; return '\n';
	default:	return c;
	}
}

int
backslash(int c)	/* get next char with \'s interpreted */
{
	static char transtab[] = "b\bf\fn\nr\rt\t";
	if (c != '\\')
		return c;
	c = getc(fin);
	if (islower(c) && strchr(transtab, c))
		return strchr(transtab, c)[1];
	return c;
}

int
follow(int expect, int ifyes, int ifno)	/* look ahead for >=, etc. */
{
	int c = getc(fin);

	if (c == expect)
		return ifyes;
	ungetc(c, fin);
	return ifno;
}

void
yyerror(char* s)	/* report compile-time error */
{
	execerror(s, 0);
}

void
execerror(char *s, char *t)	/* recover from run-time error */
{
	warning(s, t);
	fseek(fin, 0L, 2);	/* flush rest of file */
	restoreall();
	longjmp(begin, 0);
}

void
fpecatch(int sig)	/* catch floating point exceptions */
{
	execerror("floating point exception", 0);
}

void
intcatch(int sig)	/* catch interrupts */
{
	execerror("interrupt", 0);
}

void
run(void)	/* execute until EOF */
{
	setjmp(begin);
	signal(SIGINT, intcatch);
	signal(SIGFPE, fpecatch);
	for (initcode(); yyparse(); initcode())
		execute(progbase);
}

int
efclose(FILE *fp, const char *name)	/* Safely close output file */
{
	int ret = 0;

	fflush(fp);
	if (ferror(fp)) {
		fprintf(stderr, "%s: %s: ", progname, name);
		perror("");
		ret = 1;
	}
	if (fclose(fp) && !ret) {
		fprintf(stderr, "%s: can't close %s\n", progname, name);
		ret = 1;
	}
	return ret;
}

int
main(int argc, char* argv[])	/* hoc6 */
{
	static int first = 1;
#ifdef YYDEBUG
	/* extern int yydebug;
	yydebug=2; */
#endif
	progname = argv[0];
	init();
	if (argc == 1) {	/* fake an argument list */
		static char *stdinonly[] = { "-" };

		gargv = stdinonly;
		gargc = 1;
	} else if (first) {	/* for interrupts */
		first = 0;
		gargv = argv+1;
		gargc = argc-1;
	}
	while (moreinput())
		run();
	return efclose(stdout, "<stdout>");
}

int
moreinput(void)
{
	char *expr;
	static char buf[64];
	int fd;

	if (gargc-- <= 0)
		return 0;
	if (fin && fin != stdin)
		fclose(fin);
	infile = *gargv++;
	lineno = 1;
	if (strcmp(infile, "-") == 0) {
		fin = stdin;
		infile = 0;
		return 1;
	}
	if (strncmp(infile, "-e", 2) == 0) {
		if (infile[2] == 0) {
			if (gargc == 0) {
				fprintf(stderr, "%s: no argument for -e\n", progname);
				return 0;
			}
			gargc--;
			expr = *gargv++;
		} else
			expr = infile+2;
		sprintf(buf, "/tmp/hocXXXXXXX");
		fd = mkstemp(buf);
		if (fd < 0) {
			fprintf(stderr, "%s: can't create temp. file\n", progname);
			return 0;
		}
		remove(buf);
		fin = fdopen(fd, "r+");
		if (fin == NULL) {
			fprintf(stderr, "%s: can't open temp. file\n", progname);
			return 0;
		}
		fprintf(fin, "%s\n", expr);
		fseek(fin, 0L, 0);
	} else if ((fin = fopen(infile, "r")) == NULL) {
		fprintf(stderr, "%s: can't open %s\n", progname, infile);
		return moreinput();
	}
	return 1;
}

void
warning(char *s, char *t)	/* print warning message */
{
	fprintf(stderr, "%s: %s", progname, s);
	if (t)
		fprintf(stderr, " %s", t);
	if (infile)
		fprintf(stderr, " in %s", infile);
	fprintf(stderr, " near line %d\n", lineno);
	while (c != '\n' && c != EOF)
		if ((c = getc(fin)) == '\n')	/* flush rest of input line */
			lineno++;
		else if (c == EOF && errno == EINTR) {
			clearerr(fin);
			errno = 0;
		}
}

void
defnonly(char *s)	/* warn if illegal definition */
{
	if (!indef)
		execerror(s, "used outside definition");
}
