#include <math.h>
#include <errno.h>
#include "hoc.h"

double errcheck(double, char *);

double
Log(double x)
{
	return errcheck(log(x), "log");
}

double
Log10(double x)
{
	return errcheck(log10(x), "log10");
}

double
Sqrt(double x)
{
	return errcheck(sqrt(x), "sqrt");
}

double
Exp(double x)
{
	return errcheck(exp(x), "exp");
}

double
Asin(double x)
{
	return errcheck(asin(x), "asin");
}

double
Acos(double x)
{
	return errcheck(acos(x), "acos");
}

double
Sinh(double x)
{
	return errcheck(sinh(x), "sinh");
}

double
Cosh(double x)
{
	return errcheck(cosh(x), "cosh");
}

double
Pow(double x, double y)
{
	return errcheck(pow(x,y), "exponentiation");
}

double
integer(double x)
{
	if (x < -2147483648.0 || x > 2147483647.0)
		execerror("argument out of domain", 0);
	return (double)(long)x;
}

double
Isinf(double x)
{
	return (double)isinf(x);
}

double
Isnan(double x)
{
	return (double)isnan(x);
}

double
errcheck(double d, char *s)	/* check result of library call */
{
	if (errno == EDOM) {
		errno = 0;
		execerror(s, "argument out of domain");
	} else if (errno == ERANGE) {
		errno = 0;
		execerror(s, "result out of range");
	}
	return d;
}
